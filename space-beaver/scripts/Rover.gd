class_name Rover
extends CharacterBody2D

## Veicolo EVA indipendente dalla rete della base. I pannelli integrati sono
## apribili solo da fermo e caricano una batteria dedicata durante il giorno.

signal battery_changed(energy_kwh: float, capacity_kwh: float)
signal occupancy_changed(occupied: bool)

const IDLE_SHEET := preload("res://assets/rover/rover_idle.png")
const DRIVER_IDLE_SHEET := preload("res://assets/rover/rover_driver_idle.png")
const DRIVER_RIGHT_SHEET := preload("res://assets/rover/rover_driver_right.png")
const DRIVER_LEFT_SHEET := preload("res://assets/rover/rover_driver_left.png")
const DRIVER_UP_SHEET := preload("res://assets/rover/rover_driver_up.png")
const DRIVER_DOWN_SHEET := preload("res://assets/rover/rover_driver_down.png")
const OPENING_SHEET := preload("res://assets/rover/rover_opening.png")
const CLOSING_SHEET := preload("res://assets/rover/rover_closing.png")

const INTERACTION_DISTANCE := 74.0
const ROVER_SPEED := 310.0
const BATTERY_CAPACITY_KWH := 120.0
const STARTING_ENERGY_KWH := 72.0
const SOLAR_CHARGE_KW := 18.0
const DRIVING_DEMAND_KW := 7.5
const PANEL_FRAME_TIME := 0.11
const IDLE_COLUMNS := 4
const MOVING_COLUMNS := 4
const DIRECTION_ROWS := 4
const PANEL_COLUMNS := 4

enum PanelState { CLOSED, OPENING, OPEN, CLOSING }

var is_preview := false
var battery_energy_kwh := STARTING_ENERGY_KWH
var panel_state := PanelState.CLOSED
var incident_faulted := false
var animation_elapsed := 0.0
var facing_index := 0 # destra, sinistra, alto, basso
var driver: Node2D
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var interaction_label: Label
var boarding_click_area: Area2D


static func placement_world_position(cell: Vector2i) -> Vector2:
	# Rover largo tre tile e alto due: il click corrisponde alla tile superiore sinistra.
	return Vector2(cell * 16) + Vector2(24.0, 16.0)


static func can_place_at(world_position: Vector2) -> bool:
	var footprint_points := [
		world_position + Vector2(-20.0, -9.0),
		world_position + Vector2(20.0, -9.0),
		world_position + Vector2(-20.0, 9.0),
		world_position + Vector2(20.0, 9.0),
	]
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var map_provider := tree.get_first_node_in_group("world_map_provider")
	if map_provider != null and map_provider.has_method("is_world_position_inside"):
		# Lascia spazio al telaio del rover: anche il mezzo parcheggiato non può
		# sporgere oltre il bordo della mappa.
		if not bool(map_provider.call("is_world_position_inside", world_position, 24.0)):
			return false
	var registry := tree.root.get_node_or_null("BuildableRegistry")
	var player := tree.get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(world_position) < 36.0:
		return false
	if registry != null:
		for entry in registry.call("get_entries"):
			var structure := entry.get("node") as Node2D
			if structure == null or not is_instance_valid(structure):
				continue
			if structure.has_method("contains_world_point"):
				for point in footprint_points:
					if bool(structure.call("contains_world_point", point)):
						return false
	for rock in tree.get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and is_instance_valid(rock) and (rock as Node2D).global_position.distance_to(world_position) < 34.0:
			return false
	return true


static func place(parent: Node, cell: Vector2i, battery_energy_kwh: float = STARTING_ENERGY_KWH) -> Rover:
	var target_position := placement_world_position(cell)
	if not can_place_at(target_position):
		return null
	var rover := Rover.new()
	rover.position = target_position
	rover.battery_energy_kwh = clampf(battery_energy_kwh, 0.0, BATTERY_CAPACITY_KWH)
	parent.add_child(rover)
	return rover


func _ready() -> void:
	# Il rover deve restare sopra terreno, cupola e piattaforma anche se vengono
	# riordinati nodi o layer dei chunk durante il caricamento della mappa.
	z_as_relative = false
	z_index = 10
	_setup_sprite()
	_setup_collision()
	_setup_interaction_label()
	if is_preview:
		collision_shape.disabled = true
		return
	# Le anteprime di piazzamento sono nodi temporanei invisibili: non devono
	# comparire nella ricerca del rover reale, nel dock o negli input.
	add_to_group("rovers")
	_setup_boarding_click_area()
	var registry := _service("BuildableRegistry")
	if registry != null:
		registry.call("register_buildable", self, "ROVER DI ESPLORAZIONE", "vehicle", pickup)
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("register_target", self, "vehicle", "ROVER DI ESPLORAZIONE")
	_refresh_visual()


func _exit_tree() -> void:
	if not is_preview:
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("unregister_target", self, "vehicle")
		var registry := _service("BuildableRegistry")
		if registry != null:
			registry.call("unregister_buildable", self)


func _physics_process(delta: float) -> void:
	if is_preview:
		return
	var moving := false
	if is_instance_valid(driver) and not incident_faulted and panel_state == PanelState.CLOSED and not _movement_blocked():
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if battery_energy_kwh > 0.01:
			velocity = direction * ROVER_SPEED
			moving = direction != Vector2.ZERO
			if moving:
				_set_facing_from_direction(direction)
				_consume_driving_energy(delta)
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_world_bounds()
	else:
		velocity = Vector2.ZERO
	if is_instance_valid(driver):
		driver.global_position = global_position
	_update_vehicle_visual(moving)


func _clamp_to_world_bounds() -> void:
	var map_provider := get_tree().get_first_node_in_group("world_map_provider")
	if map_provider == null or not map_provider.has_method("clamp_world_position"):
		return
	global_position = map_provider.call("clamp_world_position", global_position, 24.0)


func _process(delta: float) -> void:
	if is_preview:
		_refresh_visual()
		return
	_update_docked_draw_order()
	_update_panel_animation(delta)
	_charge_from_solar(delta)
	_update_interaction_label()


func _update_docked_draw_order() -> void:
	var docked := false
	for dome in get_tree().get_nodes_in_group("base_domes"):
		if is_instance_valid(dome) and dome.has_method("is_rover_on_charging_pad") and bool(dome.call("is_rover_on_charging_pad", self)):
			docked = true
			break
	z_index = 10


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or is_preview:
		return
	if _input_blocked():
		return
	if _is_control_key(event, KEY_E):
		if is_instance_valid(driver):
			exit_rover()
			get_viewport().set_input_as_handled()
			return
		# Ridondanza intenzionale rispetto al player: il rover è responsabile
		# anche del proprio ingresso, così nessun pannello o macchinario può
		# sottrarre E prima dell'imbarco.
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and can_board(player) and board(player):
			get_viewport().set_input_as_handled()
			return
	# F e' un comando locale del rover, non una scorciatoia globale. Senza
	# questo controllo un rover remoto poteva rubare F alla camera d'aria.
	if _is_control_key(event, KEY_F) and _is_player_nearby() and _can_toggle_panels():
		toggle_panels()
		get_viewport().set_input_as_handled()


func can_board(player: Node2D) -> bool:
	return not is_preview and not incident_faulted and not is_instance_valid(driver) and panel_state == PanelState.CLOSED and battery_energy_kwh > 0.01 and player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE


func board(player: Node2D) -> bool:
	if not can_board(player):
		return false
	driver = player
	if player.has_method("mount_rover"):
		player.call("mount_rover", self)
	else:
		player.visible = false
		player.set_physics_process(false)
	driver.global_position = global_position
	occupancy_changed.emit(true)
	_refresh_visual()
	return true


func exit_rover() -> bool:
	if not is_instance_valid(driver):
		return false
	var exiting_driver := driver
	driver = null
	velocity = Vector2.ZERO
	var exit_direction := _exit_direction()
	var exit_position := global_position + exit_direction * 35.0
	if exiting_driver.has_method("dismount_rover"):
		exiting_driver.call("dismount_rover", exit_position)
	else:
		exiting_driver.global_position = exit_position
		exiting_driver.visible = true
		exiting_driver.set_physics_process(true)
	occupancy_changed.emit(false)
	_refresh_visual()
	return true


func toggle_panels() -> bool:
	if incident_faulted or not _can_toggle_panels():
		return false
	if panel_state == PanelState.CLOSED:
		panel_state = PanelState.OPENING
	else:
		panel_state = PanelState.CLOSING
	animation_elapsed = 0.0
	_refresh_visual()
	return true


func is_panels_open() -> bool:
	return panel_state == PanelState.OPEN


func get_battery_percent() -> float:
	return battery_energy_kwh / BATTERY_CAPACITY_KWH * 100.0


func contains_world_point(world_point: Vector2) -> bool:
	# La collisione è concentrata sulle ruote, così il rover si legge come un mezzo basso.
	return Rect2(global_position + Vector2(-23.0, -9.0), Vector2(46.0, 20.0)).has_point(world_point)


func pickup() -> bool:
	var inventory := _service("Inventory")
	if is_instance_valid(driver) or inventory == null or not bool(inventory.call("can_add_item", "rover")):
		return false
	if not bool(inventory.call("add_rover", battery_energy_kwh)):
		return false
	queue_free()
	return true


func can_be_recalled_to_base() -> bool:
	return not is_instance_valid(driver) and panel_state == PanelState.CLOSED


func prepare_base_recall(target_position: Vector2) -> bool:
	if not can_be_recalled_to_base():
		return false
	velocity = Vector2.ZERO
	global_position = target_position
	present_docked_at_base()
	return true


func present_docked_at_base() -> void:
	# Anche un rover creato prima di un aggiornamento del gioco deve tornare
	# leggibile sul dock: vista laterale arancione, sprite riattivato e layer alto.
	facing_index = 0
	visible = true
	z_as_relative = false
	z_index = 10
	if is_instance_valid(sprite):
		sprite.visible = true
		sprite.modulate = Color.WHITE
		_refresh_visual()


func get_machine_specs() -> Dictionary:
	var solar_factor := _solar_factor()
	var panels_label := "APERTI · ricarica solare %.1f kW" % (SOLAR_CHARGE_KW * solar_factor) if is_panels_open() else "CHIUSI"
	var status := "GUASTO — RIPARAZIONE RICHIESTA" if incident_faulted else ("IN MARCIA" if is_instance_valid(driver) and panel_state == PanelState.CLOSED else ("RICARICA SOLARE" if is_panels_open() and solar_factor > 0.0 else "PRONTO"))
	return {
		"title": "ROVER DI ESPLORAZIONE EVA",
		"category": "VEICOLO SCIENTIFICO E LOGISTICO",
		"status": status,
		"status_color": Color("ff6258") if incident_faulted else (Color("72eda0") if battery_energy_kwh > 0.0 else Color("ff776d")),
		"principle": "Un pacco batteria dedicato alimenta trazione e sistemi di bordo. I pannelli fotovoltaici dispiegabili riconvertono la luce marziana in energia durante il giorno, senza gravare sulla rete della base.",
		"specs": [
			"Batteria dedicata: %.1f / %.0f kWh · %d%%" % [battery_energy_kwh, BATTERY_CAPACITY_KWH, roundi(get_battery_percent())],
			"Trazione: %.1f kW durante la marcia" % DRIVING_DEMAND_KW,
			"Pannelli: %s" % panels_label,
			"Comandi: E sali/scendi · F pannelli (solo a piedi)",
			"Autonomia: indipendente dalla rete elettrica",
		],
	}


func set_incident_faulted(_target_id: String, value: bool) -> void:
	if incident_faulted == value:
		return
	incident_faulted = value
	if incident_faulted:
		velocity = Vector2.ZERO
		if is_instance_valid(driver):
			exit_rover()
	_update_interaction_label()


func is_incident_faulted(_target_id: String = "vehicle") -> bool:
	return incident_faulted


func is_incident_operational() -> bool:
	return not incident_faulted


func can_receive_incident(_target_id: String = "vehicle") -> bool:
	return not is_preview and not incident_faulted and not is_instance_valid(driver) and panel_state == PanelState.CLOSED


func get_incident_repair_position(_target_id: String = "vehicle") -> Vector2:
	return global_position


func _setup_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.y_sort_enabled = true
	add_child(sprite)


func _setup_collision() -> void:
	collision_layer = 1
	collision_mask = 1
	collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(42.0, 16.0)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0.0, 7.0)
	add_child(collision_shape)


func _setup_interaction_label() -> void:
	interaction_label = Label.new()
	interaction_label.position = Vector2(-104.0, -46.0)
	interaction_label.size = Vector2(208.0, 34.0)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 11)
	interaction_label.add_theme_color_override("font_color", Color("d8f3f2"))
	interaction_label.add_theme_color_override("font_outline_color", Color("071015"))
	interaction_label.add_theme_constant_override("outline_size", 3)
	interaction_label.z_as_relative = false
	interaction_label.z_index = 20
	interaction_label.visible = false
	add_child(interaction_label)


func _setup_boarding_click_area() -> void:
	# Via alternativa intenzionale: quando il player e' gia' vicino al rover,
	# un click sul mezzo esegue la stessa azione di E. Il layer 4 non collide
	# con player, rocce o tubi; serve solo al picking del mouse.
	boarding_click_area = Area2D.new()
	boarding_click_area.name = "BoardingClickArea"
	boarding_click_area.collision_layer = 4
	boarding_click_area.collision_mask = 0
	boarding_click_area.input_pickable = true
	var click_shape := CollisionShape2D.new()
	click_shape.name = "BoardingClickHitbox"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(52.0, 34.0)
	click_shape.shape = rectangle
	boarding_click_area.add_child(click_shape)
	boarding_click_area.input_event.connect(_on_boarding_click)
	add_child(boarding_click_area)


func _on_boarding_click(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT or _input_blocked():
		return
	if is_instance_valid(driver):
		exit_rover()
		get_viewport().set_input_as_handled()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and can_board(player) and board(player):
		get_viewport().set_input_as_handled()


func _update_vehicle_visual(moving: bool) -> void:
	if panel_state != PanelState.CLOSED:
		return
	if is_instance_valid(driver) and moving:
		var moving_frame := floori(Time.get_ticks_msec() / 85.0) % MOVING_COLUMNS
		sprite.texture = _atlas_frame(_driver_moving_sheet(), moving_frame, 0, MOVING_COLUMNS, 1)
		sprite.position = Vector2.ZERO
	elif is_instance_valid(driver):
		sprite.texture = _atlas_frame(DRIVER_IDLE_SHEET, facing_index, 0, IDLE_COLUMNS, 1)
		sprite.position = Vector2.ZERO
	else:
		sprite.texture = _atlas_frame(IDLE_SHEET, facing_index, 0, IDLE_COLUMNS, 1)
		sprite.position = Vector2.ZERO


func _update_panel_animation(delta: float) -> void:
	if panel_state not in [PanelState.OPENING, PanelState.CLOSING]:
		return
	animation_elapsed += delta
	var frame_index := mini(PANEL_COLUMNS - 1, floori(animation_elapsed / PANEL_FRAME_TIME))
	var sheet := OPENING_SHEET if panel_state == PanelState.OPENING else CLOSING_SHEET
	sprite.texture = _atlas_frame(sheet, frame_index, facing_index, PANEL_COLUMNS, DIRECTION_ROWS)
	sprite.position = Vector2.ZERO
	if frame_index >= PANEL_COLUMNS - 1:
		panel_state = PanelState.OPEN if panel_state == PanelState.OPENING else PanelState.CLOSED
		animation_elapsed = 0.0
		_refresh_visual()


func _refresh_visual() -> void:
	if sprite == null:
		return
	if panel_state == PanelState.OPEN:
		sprite.texture = _atlas_frame(OPENING_SHEET, PANEL_COLUMNS - 1, facing_index, PANEL_COLUMNS, DIRECTION_ROWS)
		sprite.position = Vector2.ZERO
		return
	if panel_state in [PanelState.OPENING, PanelState.CLOSING]:
		return
	_update_vehicle_visual(false)


func _atlas_frame(sheet: Texture2D, column: int, row: int, columns: int, rows: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var frame_size := Vector2i(sheet.get_width() / columns, sheet.get_height() / rows)
	atlas.region = Rect2(Vector2i(column, row) * frame_size, frame_size)
	return atlas


func _set_facing_from_direction(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing_index = 0 if direction.x > 0.0 else 1
	else:
		facing_index = 3 if direction.y > 0.0 else 2


func _driver_moving_sheet() -> Texture2D:
	match facing_index:
		0:
			return DRIVER_RIGHT_SHEET
		1:
			return DRIVER_LEFT_SHEET
		2:
			return DRIVER_UP_SHEET
	return DRIVER_DOWN_SHEET


func _exit_direction() -> Vector2:
	match facing_index:
		0:
			return Vector2.DOWN
		1:
			return Vector2.UP
		2:
			return Vector2.LEFT
	return Vector2.RIGHT


func _can_toggle_panels() -> bool:
	# I pannelli estesi non sono sicuri con il pilota a bordo: bisogna scendere.
	return not is_instance_valid(driver) and panel_state in [PanelState.CLOSED, PanelState.OPEN] and velocity.length_squared() < 1.0


func _is_player_nearby() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and is_instance_valid(player) and player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE


func _charge_from_solar(delta: float) -> void:
	if incident_faulted or battery_energy_kwh >= BATTERY_CAPACITY_KWH:
		return
	var charge_rate_kw := _get_base_pad_charge_rate_kw()
	if charge_rate_kw <= 0.0 and is_panels_open():
		charge_rate_kw = SOLAR_CHARGE_KW * _solar_factor()
	if charge_rate_kw <= 0.0:
		return
	var charged := charge_rate_kw * _game_hours_for_delta(delta)
	if charged <= 0.0:
		return
	battery_energy_kwh = minf(BATTERY_CAPACITY_KWH, battery_energy_kwh + charged)
	battery_changed.emit(battery_energy_kwh, BATTERY_CAPACITY_KWH)


func _get_base_pad_charge_rate_kw() -> float:
	for dome in get_tree().get_nodes_in_group("base_domes"):
		if is_instance_valid(dome) and dome.has_method("is_rover_on_charging_pad") and bool(dome.call("is_rover_on_charging_pad", self)):
			return float(dome.call("get_rover_pad_charge_rate_kw"))
	return 0.0


func _consume_driving_energy(delta: float) -> void:
	var consumed := DRIVING_DEMAND_KW * _game_hours_for_delta(delta)
	battery_energy_kwh = maxf(0.0, battery_energy_kwh - consumed)
	battery_changed.emit(battery_energy_kwh, BATTERY_CAPACITY_KWH)


func _input_blocked() -> bool:
	return _ui_blocks_world_actions() or get_tree().paused


func _movement_blocked() -> bool:
	return (_ui_blocks_world_actions() and not _ui_allows_world_movement()) or get_tree().paused


func _ui_blocks_world_actions() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state != null and bool(ui_state.call("blocks_world_actions"))


func _ui_allows_world_movement() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state != null and bool(ui_state.call("allows_world_movement"))


func _is_control_key(event: InputEventKey, keycode: Key) -> bool:
	return event.keycode == keycode or event.physical_keycode == keycode


func _solar_factor() -> float:
	var clock := _service("WorldClock")
	return float(clock.call("get_solar_factor")) if clock != null else 0.0


func _game_hours_for_delta(delta: float) -> float:
	var clock := _service("WorldClock")
	return float(clock.call("get_game_hours_for_real_delta", delta)) if clock != null else 0.0


func _service(service_name: String) -> Node:
	return get_tree().root.get_node_or_null(service_name)


func _update_interaction_label() -> void:
	if interaction_label == null:
		return
	if is_instance_valid(driver):
		interaction_label.visible = true
		interaction_label.text = "E / CLICK · SCENDI\nSCENDI PRIMA DI APRIRE I PANNELLI · %d%%" % roundi(get_battery_percent())
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var nearby := player != null and player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE
	interaction_label.visible = nearby
	if not nearby:
		return
	if incident_faulted:
		interaction_label.text = "ROVER IN GUASTO\nE · RIPARA SISTEMI DI BORDO"
		return
	if panel_state == PanelState.CLOSED:
		interaction_label.text = "E / CLICK · SALI    F · APRI PANNELLI\nBATTERIA %d%%" % roundi(get_battery_percent())
	elif panel_state == PanelState.OPEN:
		interaction_label.text = "F · CHIUDI PANNELLI\nRICARICA %d%%" % roundi(get_battery_percent())
	else:
		interaction_label.text = "PANNELLI IN MOVIMENTO\nBATTERIA %d%%" % roundi(get_battery_percent())
