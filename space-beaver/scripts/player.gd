extends CharacterBody2D

const SPEED := 190.0
const PICKUP_DISTANCE := 70.0
const FRAME_SIZE := Vector2i(32, 32)
const PLAYER_SHEET := preload("res://sprites/player-spritesheet.png")
const MIN_CAMERA_ZOOM := 0.35
const MAX_CAMERA_ZOOM := 3.0
const ZOOM_FACTOR := 1.18

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var facing := "down"
var mounted_rover: Node2D
var _rover_board_key_down := false


func _ready() -> void:
	add_to_group("player")
	# Le rocce usano il layer 2: il giocatore ci urta, il rover no.
	collision_mask = 3
	animated_sprite.sprite_frames = _make_sprite_frames()
	animated_sprite.play("idle_down")
	SuitSystem.equipped_changed.connect(_on_suit_equipped)
	_on_suit_equipped(SuitSystem.equipped_suit_id, SuitSystem.get_equipped_definition())


func _physics_process(_delta: float) -> void:
	_poll_rover_board_hotkey()
	# Il bordo segue la mappa dipinta (2.000 × 2.000 tile), non la camera.
	# Viene applicato anche da fermo per correggere eventuali posizioni caricate
	# fuori area senza permettere di camminare nel vuoto oltre il bordo.
	_clamp_to_world_bounds()
	if _ui_blocks_world_actions() and not _ui_allows_world_movement():
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED * SuitSystem.get_movement_multiplier() * Radiation.get_movement_multiplier() * Temperature.get_movement_multiplier()
	move_and_slide()
	_clamp_to_world_bounds()
	_update_animation(direction)


func _clamp_to_world_bounds() -> void:
	var map_provider := get_tree().get_first_node_in_group("world_map_provider")
	if map_provider == null or not map_provider.has_method("clamp_world_position"):
		return
	global_position = map_provider.call("clamp_world_position", global_position, 11.0)


func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0.0 else "left"
		else:
			facing = "down" if direction.y > 0.0 else "up"
	var animation_name := ("walk_" if direction != Vector2.ZERO else "idle_") + facing
	animated_sprite.flip_h = false
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _make_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# Riga 1: idle. Righe 2-5: basso, alto, sinistra, destra.
	_add_animation(frames, "idle_down", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "idle_up", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "idle_left", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "idle_right", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "walk_down", 1, [0, 1, 2, 3, 4], 8.0)
	_add_animation(frames, "walk_up", 2, [0, 1, 2, 3, 4], 8.0)
	_add_animation(frames, "walk_left", 3, [0, 1, 2, 3, 4], 8.0)
	_add_animation(frames, "walk_right", 4, [0, 1, 2, 3, 4], 8.0)
	return frames


func _add_animation(frames: SpriteFrames, name: String, row: int, columns: Array, speed: float) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, speed)
	frames.set_animation_loop(name, true)
	for column in columns:
		var frame := AtlasTexture.new()
		frame.atlas = PLAYER_SHEET
		frame.region = Rect2(Vector2i(column, row) * FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(name, frame)


func nearest_rock() -> Node2D:
	var closest: Node2D = null
	var closest_distance := PICKUP_DISTANCE
	for rock in get_tree().get_nodes_in_group("collectible_rocks"):
		if not rock is Node2D:
			continue
		var distance := global_position.distance_to(rock.global_position)
		if distance < closest_distance:
			closest = rock
			closest_distance = distance
	return closest


func nearest_delivery_capsule() -> Node:
	var closest: Node = null
	var closest_distance := PICKUP_DISTANCE
	for capsule in get_tree().get_nodes_in_group("delivery_capsules"):
		if not capsule is Node2D or not capsule.has_method("is_landed") or not bool(capsule.call("is_landed")):
			continue
		var distance := global_position.distance_to(capsule.global_position)
		if distance < closest_distance:
			closest = capsule
			closest_distance = distance
	return closest


func nearest_rover() -> Node:
	var closest: Node2D = null
	var closest_distance := PICKUP_DISTANCE
	for rover in get_tree().get_nodes_in_group("rovers"):
		if not rover is Node2D or not rover.has_method("can_board"):
			continue
		var rover_node := rover as Node2D
		var distance := global_position.distance_to(rover_node.global_position)
		if distance < closest_distance and bool(rover.call("can_board", self)):
			closest = rover_node
			closest_distance = distance
	return closest


func nearest_research_machine() -> Node2D:
	var closest: Node2D = null
	var closest_distance := PICKUP_DISTANCE
	for machine in get_tree().get_nodes_in_group("research_machines"):
		if not machine is Node2D or not machine.has_method("try_interact"):
			continue
		var machine_node := machine as Node2D
		var distance := global_position.distance_to(machine_node.global_position)
		if distance < closest_distance:
			closest = machine_node
			closest_distance = distance
	return closest


func nearest_ice_drill() -> Node2D:
	var closest: Node2D = null
	var closest_distance := PICKUP_DISTANCE
	for drill in get_tree().get_nodes_in_group("ice_drills"):
		if not drill is Node2D or not drill.has_method("try_refill_selected_bottle"):
			continue
		var drill_node := drill as Node2D
		var distance := global_position.distance_to(drill_node.global_position)
		if distance < closest_distance:
			closest = drill_node
			closest_distance = distance
	return closest


func nearest_rock_drill() -> Node2D:
	var closest: Node2D = null
	var closest_distance := PICKUP_DISTANCE
	for drill in get_tree().get_nodes_in_group("rock_drills"):
		if not drill is Node2D or not drill.has_method("open_storage"):
			continue
		var drill_node := drill as Node2D
		var distance := global_position.distance_to(drill_node.global_position)
		if distance < closest_distance:
			closest = drill_node
			closest_distance = distance
	return closest


func mount_rover(rover: Node2D) -> void:
	mounted_rover = rover
	velocity = Vector2.ZERO
	visible = false
	set_physics_process(false)
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null:
		collider.disabled = true


func dismount_rover(exit_position: Vector2) -> void:
	mounted_rover = null
	global_position = exit_position
	visible = true
	set_physics_process(true)
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null:
		collider.disabled = false


func is_driving_rover() -> bool:
	return is_instance_valid(mounted_rover)


func _try_board_nearby_rover() -> bool:
	if is_driving_rover() or _ui_blocks_world_actions():
		return false
	var nearby_rover := nearest_rover()
	return nearby_rover != null and bool(nearby_rover.call("board", self))


func _poll_rover_board_hotkey() -> void:
	# Fallback indipendente dal routing degli eventi: alcuni pannelli di gioco
	# consumano _unhandled_input, ma lo stato fisico della tastiera resta valido.
	var e_down := Input.is_key_pressed(KEY_E)
	if e_down and not _rover_board_key_down:
		_try_board_nearby_rover()
	_rover_board_key_down = e_down


func _input(event: InputEvent) -> void:
	# Il gestore del macchinario è un figlio del player e usa _unhandled_input:
	# se il rover veniva controllato lì, un macchinario vicino poteva consumare E
	# prima della salita. Il veicolo va gestito nel passaggio input prioritario.
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not _is_control_key(event, KEY_E):
		return
	if _try_board_nearby_rover():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _ui_is_minimap_active():
		if event is InputEventMouseButton and event.pressed:
			var active_map_ui := get_tree().get_first_node_in_group("world_map_ui")
			if active_map_ui != null and active_map_ui.has_method("handle_mouse_wheel") and bool(active_map_ui.call("handle_mouse_wheel", event)):
				get_viewport().set_input_as_handled()
		return
	if _ui_blocks_world_actions():
		return
	if event is InputEventMouseButton and event.pressed:
		var map_ui := get_tree().get_first_node_in_group("world_map_ui")
		if map_ui != null and map_ui.has_method("handle_mouse_wheel") and bool(map_ui.call("handle_mouse_wheel", event)):
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom(camera.zoom.x * ZOOM_FACTOR)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom(camera.zoom.x / ZOOM_FACTOR)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var control_key := _get_control_key(event)
		if control_key in [KEY_E, KEY_F, KEY_W, KEY_A, KEY_S, KEY_D] and not is_driving_rover():
			for dome in get_tree().get_nodes_in_group("base_domes"):
				if is_instance_valid(dome) and dome.has_method("handle_airlock_key") and bool(dome.call("handle_airlock_key", self, control_key)):
					get_viewport().set_input_as_handled()
					return
		if control_key == KEY_U and not is_driving_rover():
			var upgrade_machine := nearest_research_machine()
			if upgrade_machine != null and bool(upgrade_machine.call("try_upgrade", self)):
				get_viewport().set_input_as_handled()
				return
		if control_key != KEY_E:
			return
		# Il rover riceve lo stesso evento e gestisce l'uscita del pilota.
		if is_driving_rover():
			return
		var capsule := nearest_delivery_capsule()
		if capsule != null:
			capsule.call("collect_all")
			get_viewport().set_input_as_handled()
			return
		var drill := nearest_ice_drill()
		if drill != null and str(Inventory.get_selected_item().get("id", "")) == "water_bottle":
			if bool(drill.call("try_refill_selected_bottle", self)):
				get_viewport().set_input_as_handled()
				return
		var rock_drill := nearest_rock_drill()
		if rock_drill != null and bool(rock_drill.call("open_storage", self)):
			get_viewport().set_input_as_handled()
			return
		var research_machine := nearest_research_machine()
		if research_machine != null and bool(research_machine.call("try_interact", self)):
			get_viewport().set_input_as_handled()
			return
		var rock := nearest_rock()
		if rock != null and rock.has_method("collect") and bool(rock.call("collect")):
			get_viewport().set_input_as_handled()


func _set_camera_zoom(value: float) -> void:
	var clamped := clampf(value, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	camera.zoom = Vector2.ONE * clamped


func _is_control_key(event: InputEventKey, keycode: Key) -> bool:
	return event.keycode == keycode or event.physical_keycode == keycode


func _get_control_key(event: InputEventKey) -> Key:
	for keycode in [KEY_E, KEY_F, KEY_U, KEY_W, KEY_A, KEY_S, KEY_D]:
		if event.physical_keycode == keycode:
			return keycode
	return event.keycode


func _ui_state() -> Node:
	return get_node_or_null("/root/UIState")


func _ui_blocks_world_actions() -> bool:
	var ui_state := _ui_state()
	return ui_state != null and bool(ui_state.call("blocks_world_actions"))


func _ui_allows_world_movement() -> bool:
	var ui_state := _ui_state()
	return ui_state != null and bool(ui_state.call("allows_world_movement"))


func _ui_is_minimap_active() -> bool:
	var ui_state := _ui_state()
	return ui_state != null and bool(ui_state.call("is_modal_active", &"minimap"))


func _on_suit_equipped(_suit_id: String, definition: Dictionary) -> void:
	animated_sprite.self_modulate = definition.get("tint", Color.WHITE)
