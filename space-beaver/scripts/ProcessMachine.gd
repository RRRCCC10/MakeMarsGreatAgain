class_name ProcessMachine
extends Node2D

const ELECTROLYZER_SHEET := preload("res://assets/electrolyzer.png")
const SABATIER_SHEET := preload("res://assets/sabatier.png")
const ELECTROLYZER_FRAME := Vector2i(32, 32)
const SABATIER_FRAME := Vector2i(48, 48)
const CELL_SIZE := 16
const ELECTROLYZER_DEMAND_KW := 65.0
const SABATIER_DEMAND_KW := 50.0
const WATER_L_PER_HOUR := 40.0
const HYDROGEN_KG_PER_HOUR := 4.0
const OXYGEN_KG_PER_HOUR := 35.6
const SABATIER_HYDROGEN_KG_PER_HOUR := 4.0
const SABATIER_METHANE_KG_PER_HOUR := 4.0

var device_id := ""
var origin_cell := Vector2i.ZERO
var is_preview := false
var placement_rotation := 0
var powered := false
var animation_frame := 0
var animation_timer := 0.0
var simulation_elapsed := 0.0
var hydrogen_flow_kg := 0.0
var oxygen_flow_kg := 0.0
var water_consumed_liters := 0.0
var methane_produced_kg := 0.0
var network_enabled := true
var incident_faulted := false
var sprite: Sprite2D
var indicator: Polygon2D
var body: StaticBody2D


func setup(new_id: String, cell: Vector2i, preview: bool = false, new_placement_rotation: int = 0) -> void:
	device_id = new_id
	origin_cell = cell
	is_preview = preview
	placement_rotation = posmod(new_placement_rotation, 4)
	if is_node_ready():
		_apply_placement_rotation()
		_refresh_texture()


static func footprint_cells(item_id: String, origin: Vector2i) -> Array[Vector2i]:
	var size := Vector2i(2, 2) if item_id == "electrolyzer" else Vector2i(3, 3)
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(origin + Vector2i(x, y))
	return cells


static func world_position_for(item_id: String, cell: Vector2i) -> Vector2:
	var half := Vector2(16.0, 16.0) if item_id == "electrolyzer" else Vector2(24.0, 24.0)
	return Vector2(cell * CELL_SIZE) + half


static func sabatier_target_cell() -> Vector2i:
	var landing := _find_landing_sequence()
	if landing == null:
		return Vector2i(100000, 100000)
	# La macchina 48x48 si trova sul lato sinistro del modulo di lancio,
	# con un margine visibile di 8px e senza sovrapporsi alla sua impronta.
	var target_center := landing.global_position + Vector2(-64.0, 0.0)
	return Vector2i(floori((target_center.x - 24.0) / CELL_SIZE), floori((target_center.y - 24.0) / CELL_SIZE))


static func _find_landing_sequence() -> MissionLandingSequence:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("LandingSequence") as MissionLandingSequence


func _ready() -> void:
	z_index = 2
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_apply_placement_rotation()
	_refresh_texture()
	if not is_preview:
		_setup_indicator()
		_setup_collision()
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("register_target", self, "machine", get_display_name())


func _exit_tree() -> void:
	if not is_preview:
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("unregister_target", self, "machine")


func _process(delta: float) -> void:
	if is_preview:
		return
	if incident_faulted or not powered:
		simulation_elapsed = 0.0
		hydrogen_flow_kg = 0.0
		oxygen_flow_kg = 0.0
		return
	simulation_elapsed += delta
	animation_timer += delta
	if animation_timer < 0.12:
		return
	animation_timer = 0.0
	animation_frame = (animation_frame + 1) % 4
	_refresh_texture()
	var elapsed := simulation_elapsed
	simulation_elapsed = 0.0
	var hours := WorldClock.get_game_hours_for_real_delta(elapsed)
	if device_id == "electrolyzer":
		_process_electrolysis(hours)
	else:
		_process_sabatier(hours)


func _process_electrolysis(hours: float) -> void:
	# I gas sono un flusso, non una scorta: ogni tick sostituisce l'output
	# precedente. Se manca una linea d'uscita non si spreca/immagazzina acqua.
	hydrogen_flow_kg = 0.0
	oxygen_flow_kg = 0.0
	var hydrogen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.HYDROGEN)
	var oxygen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.OXYGEN)
	if not hydrogen_connected and not oxygen_connected:
		return
	var water: float = PipeManager.consume_connected_resource(get_water_input_cell(), Vector2i.RIGHT, PipeSegment.Category.WATER, WATER_L_PER_HOUR * hours)
	if water <= 0.0:
		return
	water_consumed_liters += water
	var hydrogen: float = water * HYDROGEN_KG_PER_HOUR / WATER_L_PER_HOUR
	var oxygen: float = water * OXYGEN_KG_PER_HOUR / WATER_L_PER_HOUR
	# Le quantità restano disponibili solo per l'intervallo corrente e solo
	# sulle uscite collegate; quelle scollegate scaricano all'esterno.
	hydrogen_flow_kg = hydrogen if hydrogen_connected else 0.0
	oxygen_flow_kg = oxygen if oxygen_connected else 0.0


func get_fluid_output_available_for_category(category: int) -> float:
	if device_id == "electrolyzer" and category == PipeSegment.Category.OXYGEN:
		return oxygen_flow_kg
	if device_id == "electrolyzer" and category == PipeSegment.Category.HYDROGEN:
		return hydrogen_flow_kg
	return 0.0


func _process_sabatier(hours: float) -> void:
	var rocket := _find_landing_sequence()
	if rocket == null:
		return
	var room := rocket.get_methane_capacity_kg() - rocket.methane_kg
	if room <= 0.001:
		return
	var hydrogen_needed := minf(SABATIER_HYDROGEN_KG_PER_HOUR * hours, room)
	var hydrogen: float = PipeManager.consume_connected_resource(get_hydrogen_input_cell(), Vector2i.RIGHT, PipeSegment.Category.HYDROGEN, hydrogen_needed)
	if hydrogen <= 0.0:
		return
	var methane := minf(hydrogen * SABATIER_METHANE_KG_PER_HOUR / SABATIER_HYDROGEN_KG_PER_HOUR, room)
	methane_produced_kg += rocket.load_methane_kg(methane)


func set_powered(value: bool) -> void:
	powered = value and not incident_faulted
	if indicator != null:
		indicator.visible = powered and not is_preview
	if not powered:
		animation_frame = 0
		_refresh_texture()


func set_network_enabled(value: bool) -> void:
	if is_preview or network_enabled == value:
		return
	network_enabled = value
	if not network_enabled:
		set_powered(false)
	PowerGrid.request_rebuild()


func is_network_enabled() -> bool:
	return network_enabled


func get_power_connection_cell() -> Vector2i:
	return _rotated_port_cell(origin_cell + (Vector2i(2, 0) if device_id == "electrolyzer" else Vector2i(1, 3)))


func get_power_attach_direction() -> Vector2i:
	return _rotate_direction(Vector2i.LEFT if device_id == "electrolyzer" else Vector2i.UP)


func get_power_demand_kw() -> float:
	return ELECTROLYZER_DEMAND_KW if device_id == "electrolyzer" else SABATIER_DEMAND_KW


func get_water_input_cell() -> Vector2i:
	# Ingresso sul fianco sinistro della tile inferiore sinistra.
	return _rotated_port_cell(origin_cell + Vector2i.LEFT + Vector2i.DOWN)


func get_hydrogen_input_cell() -> Vector2i:
	return _rotated_port_cell(origin_cell + Vector2i.LEFT + Vector2i.DOWN)


func get_hydrogen_output_cell() -> Vector2i:
	# H₂ esce dal fianco sinistro della tile superiore sinistra.
	return _rotated_port_cell(origin_cell + Vector2i.LEFT)


func get_oxygen_output_cell() -> Vector2i:
	# O₂ esce dal fianco destro della tile superiore destra.
	return _rotated_port_cell(origin_cell + Vector2i(2, 0))


func get_hydrogen_output_required_opening() -> Vector2i:
	return _rotate_direction(Vector2i.RIGHT)


func get_oxygen_output_required_opening() -> Vector2i:
	return _rotate_direction(Vector2i.LEFT)


func get_fluid_input_ports() -> Array[Dictionary]:
	if device_id == "electrolyzer":
		return [{"cell": get_water_input_cell(), "category": PipeSegment.Category.WATER, "required_opening": _rotate_direction(Vector2i.RIGHT)}]
	return [{"cell": get_hydrogen_input_cell(), "category": PipeSegment.Category.HYDROGEN, "required_opening": _rotate_direction(Vector2i.RIGHT)}]


func get_occupied_power_cells() -> Array[Vector2i]:
	return footprint_cells(device_id, origin_cell)


func get_display_name() -> String:
	return "ELETTROLIZZATORE" if device_id == "electrolyzer" else "REATTORE SABATIER"


func get_connection_label() -> String:
	if incident_faulted:
		return "GUASTO — avvicinati e ripara"
	var connected := bool(PowerGrid.connection_ok.get(self, false))
	if not network_enabled:
		return "DISATTIVATO"
	return "ALIMENTATO" if connected and powered else ("COLLEGATO - IN ATTESA DI POTENZA" if connected else "RETE ELETTRICA NON COLLEGATA")


func get_interaction_summary() -> String:
	if device_id == "electrolyzer":
		var hydrogen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.HYDROGEN)
		var oxygen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.OXYGEN)
		return "H₂ %s · O₂ %s · flusso continuo (senza serbatoi)" % ["TUBO" if hydrogen_connected else "SCOLLEGATO", "TUBO" if oxygen_connected else "SCOLLEGATO"]
	return "Metano nel razzo: %.1f / %.0f kg" % [_find_landing_sequence().methane_kg if _find_landing_sequence() != null else 0.0, _find_landing_sequence().get_methane_capacity_kg() if _find_landing_sequence() != null else 0.0]


func get_stock_items() -> Array[Dictionary]:
	# Le risorse di processo non sono oggetti da raccogliere a mano: idrogeno
	# e ossigeno sono disponibili sulle rispettive tubazioni, il metano va al razzo.
	return []


func get_inventory_output_label() -> String:
	return "OUTPUT  ·  H₂/O₂ tramite tubi" if device_id == "electrolyzer" else "OUTPUT  ·  CH₄ caricato direttamente nel razzo"


func consume_fluid_resource_for_category(category: int, amount: float) -> float:
	if device_id != "electrolyzer" or amount <= 0.0:
		return 0.0
	if category == PipeSegment.Category.HYDROGEN:
		var transferred_h2 := minf(amount, hydrogen_flow_kg)
		hydrogen_flow_kg -= transferred_h2
		return transferred_h2
	if category == PipeSegment.Category.OXYGEN:
		var transferred_o2 := minf(amount, oxygen_flow_kg)
		oxygen_flow_kg -= transferred_o2
		return transferred_o2
	return 0.0


func get_machine_specs() -> Dictionary:
	if device_id == "electrolyzer":
		var water_connected := _is_input_connected(get_water_input_cell(), Vector2i.RIGHT, PipeSegment.Category.WATER)
		var hydrogen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.HYDROGEN)
		var oxygen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.OXYGEN)
		var has_output := hydrogen_connected or oxygen_connected
		var status := "GUASTO — RIPARAZIONE RICHIESTA" if incident_faulted else ("IN PRODUZIONE" if powered and water_connected and has_output else get_connection_label())
		if powered and not water_connected:
			status = "IN ATTESA DI ACQUA"
		elif powered and water_connected and not has_output:
			status = "IN ATTESA DI TUBI USCITA"
		return {
			"title": "ELETTROLIZZATORE DELL'ACQUA",
			"category": "PRODUZIONE DI PROPELLENTI",
			"status": status,
			"status_color": Color("ff6258") if incident_faulted else (Color("72eda0") if powered and water_connected and has_output else Color("ffb45d")),
			"principle": "L'elettrolisi scinde l'acqua in H₂ e O₂ e li fornisce in continuo sulle rispettive linee, senza serbatoi interni.",
			"specs": ["Consumo elettrico: %.0f kW" % ELECTROLYZER_DEMAND_KW, "Ingresso acqua: basso-sinistra (%s)" % ("collegato" if water_connected else "non collegato"), "Consumo nominale: %.0f L/h acqua" % WATER_L_PER_HOUR, "Produzione nominale: H₂ %.1f kg/h · O₂ %.1f kg/h" % [HYDROGEN_KG_PER_HOUR, OXYGEN_KG_PER_HOUR], "Funzionamento: flusso diretto, senza serbatoi", "Uscite indipendenti: H₂ %s · O₂ %s" % ["collegato" if hydrogen_connected else "scollegato", "collegato" if oxygen_connected else "scollegato"]],
		}
	var rocket := _find_landing_sequence()
	var h2_connected := _is_input_connected(get_hydrogen_input_cell(), Vector2i.RIGHT, PipeSegment.Category.HYDROGEN)
	return {
		"title": "REATTORE SABATIER",
		"category": "PRODUZIONE DI PROPELLENTI",
		"status": "GUASTO — RIPARAZIONE RICHIESTA" if incident_faulted else ("CARICAMENTO RAZZO" if powered and h2_connected and rocket != null else get_connection_label()),
		"status_color": Color("ff6258") if incident_faulted else (Color("72eda0") if powered and h2_connected else Color("ffb45d")),
		"principle": "La reazione di Sabatier combina idrogeno e anidride carbonica per sintetizzare metano. Il metano viene trasferito direttamente al razzo, senza tubazioni d'uscita.",
		"specs": ["Consumo elettrico: %.0f kW" % SABATIER_DEMAND_KW, "Ingresso H₂: lato sinistro (%s)" % ("collegato" if h2_connected else "non collegato"), "Produzione nominale: %.1f kg/h CH₄" % SABATIER_METHANE_KG_PER_HOUR, "Uscita CH₄: caricamento diretto del razzo", "Carburante razzo: %.1f / %.0f kg" % [rocket.methane_kg, rocket.get_methane_capacity_kg()] if rocket != null else "Razzo non disponibile", "Posizione vincolata: immediatamente a sinistra del razzo"],
	}


func set_incident_faulted(_target_id: String, value: bool) -> void:
	if incident_faulted == value:
		return
	incident_faulted = value
	if incident_faulted:
		set_powered(false)
	PowerGrid.request_rebuild()


func is_incident_faulted(_target_id: String = "machine") -> bool:
	return incident_faulted


func is_incident_operational() -> bool:
	return not incident_faulted


func can_receive_incident(_target_id: String = "machine") -> bool:
	return not is_preview and not incident_faulted


func get_incident_repair_position(_target_id: String = "machine") -> Vector2:
	return global_position


func contains_world_point(point: Vector2) -> bool:
	var size := Vector2(32.0, 32.0) if device_id == "electrolyzer" else Vector2(48.0, 48.0)
	return Rect2(global_position - size * 0.5, size).has_point(point)


func _is_input_connected(cell: Vector2i, opening: Vector2i, category: int) -> bool:
	return PipeManager.is_input_connected(cell, opening, category)


func _refresh_texture() -> void:
	if sprite == null:
		return
	var atlas := AtlasTexture.new()
	var frame_size := ELECTROLYZER_FRAME if device_id == "electrolyzer" else SABATIER_FRAME
	atlas.atlas = ELECTROLYZER_SHEET if device_id == "electrolyzer" else SABATIER_SHEET
	atlas.region = Rect2(Vector2i(animation_frame if powered else 0, 0) * frame_size, frame_size)
	sprite.texture = atlas


func _setup_indicator() -> void:
	indicator = Polygon2D.new()
	indicator.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
	indicator.position = Vector2(0, -12 if device_id == "electrolyzer" else -20)
	indicator.color = Color("72eda0")
	indicator.visible = false
	add_child(indicator)


func _setup_collision() -> void:
	body = StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 22) if device_id == "electrolyzer" else Vector2(42, 34)
	collision.shape = shape
	collision.position.y = 4
	body.add_child(collision)
	add_child(body)


func _rotated_port_cell(native_cell: Vector2i) -> Vector2i:
	var center := world_position_for(device_id, origin_cell)
	var native_center := Vector2(native_cell * CELL_SIZE) + Vector2.ONE * CELL_SIZE * 0.5
	var rotated_center := center + (native_center - center).rotated(float(placement_rotation) * PI * 0.5)
	return Vector2i(floori(rotated_center.x / CELL_SIZE), floori(rotated_center.y / CELL_SIZE))


func _rotate_direction(direction: Vector2i) -> Vector2i:
	var result := direction
	for _turn in placement_rotation:
		result = Vector2i(-result.y, result.x)
	return result


func _apply_placement_rotation() -> void:
	rotation = float(placement_rotation) * PI * 0.5
