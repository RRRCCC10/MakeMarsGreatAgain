class_name ProcessMachine
extends Node2D

const ELECTROLYZER_SHEET := preload("res://assets/sprites/machines/electrolyzer.png")
const SABATIER_SHEET := preload("res://assets/sprites/machines/sabatier.png")
const ELECTROLYZER_SAND_SHEETS := {
	1: preload("res://assets/sprites/machines/sand/dirty/electrolyzer.png"),
	2: preload("res://assets/sprites/machines/sand/covered/electrolyzer.png"),
	3: preload("res://assets/sprites/machines/sand/buried/electrolyzer.png"),
}
const SABATIER_SAND_SHEETS := {
	1: preload("res://assets/sprites/machines/sand/dirty/sabatier.png"),
	2: preload("res://assets/sprites/machines/sand/covered/sabatier.png"),
	3: preload("res://assets/sprites/machines/sand/buried/sabatier.png"),
}
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
var sand_accumulation := 0
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
	# The 48×48 machine sits on the landing module's left side with an 8 px
	# visible margin and without overlapping its footprint.
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
		var sandstorms := get_node_or_null("/root/SandstormManager")
		if sandstorms != null:
			sandstorms.call("register_target", self, get_display_name())


func _exit_tree() -> void:
	if not is_preview:
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("unregister_target", self, "machine")
		var sandstorms := get_node_or_null("/root/SandstormManager")
		if sandstorms != null:
			sandstorms.call("unregister_target", self)


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
	# Gases are a flow, not storage: every tick replaces previous output. Missing
	# output lines never waste or store water.
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
	# Quantities remain available only for the current interval and connected
	# outputs; disconnected ones vent outside.
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
	var loaded := rocket.load_methane_kg(methane)
	methane_produced_kg += loaded
	if loaded > 0.0 and rocket.has_method("register_sabatier_operation"):
		# Rocket registration follows real production: it proves placement, power,
		# and H₂ connection rather than a mere machine purchase.
		rocket.call("register_sabatier_operation", self)


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
	# Input on the left side of the lower-left tile.
	return _rotated_port_cell(origin_cell + Vector2i.LEFT + Vector2i.DOWN)


func get_hydrogen_input_cell() -> Vector2i:
	return _rotated_port_cell(origin_cell + Vector2i.LEFT + Vector2i.DOWN)


func get_hydrogen_output_cell() -> Vector2i:
	# H₂ exits the left side of the upper-left tile.
	return _rotated_port_cell(origin_cell + Vector2i.LEFT)


func get_oxygen_output_cell() -> Vector2i:
	# O₂ exits the right side of the upper-right tile.
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
	return "ELECTROLYZER" if device_id == "electrolyzer" else "SABATIER REACTOR"


func get_connection_label() -> String:
	if incident_faulted:
		return "FAULT — approach and repair"
	var connected := bool(PowerGrid.connection_ok.get(self, false))
	if not network_enabled:
		return "DISABLED"
	return "POWERED" if connected and powered else ("CONNECTED - AWAITING POWER" if connected else "POWER GRID NOT CONNECTED")


func get_interaction_summary() -> String:
	if device_id == "electrolyzer":
		var hydrogen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.HYDROGEN)
		var oxygen_connected := PipeManager.is_source_connected(self, PipeSegment.Category.OXYGEN)
		return "H₂ %s · O₂ %s · continuous flow (no tanks)" % ["PIPE" if hydrogen_connected else "DISCONNECTED", "PIPE" if oxygen_connected else "DISCONNECTED"]
	return "Rocket methane: %.1f / %.0f kg" % [_find_landing_sequence().methane_kg if _find_landing_sequence() != null else 0.0, _find_landing_sequence().get_methane_capacity_kg() if _find_landing_sequence() != null else 0.0]


func get_stock_items() -> Array[Dictionary]:
	# Process resources are not hand-collected items: hydrogen and oxygen are
	# available on their pipes while methane goes to the rocket.
	return []


func get_inventory_output_label() -> String:
	return "OUTPUT  ·  H₂/O₂ through pipes" if device_id == "electrolyzer" else "OUTPUT  ·  CH₄ loaded directly into rocket"


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
		var status := "FAULT — REPAIR REQUIRED" if incident_faulted else ("PRODUCING" if powered and water_connected and has_output else get_connection_label())
		if powered and not water_connected:
			status = "AWAITING WATER"
		elif powered and water_connected and not has_output:
			status = "AWAITING OUTPUT PIPES"
		return {
			"title": "WATER ELECTROLYZER",
			"category": "PROPELLANT PRODUCTION",
			"status": status,
			"status_color": Color("ff6258") if incident_faulted else (Color("72eda0") if powered and water_connected and has_output else Color("ffb45d")),
			"principle": "Electrolysis uses energy to split water into H₂ and O₂ and continuously supplies their respective lines without internal tanks.",
			"specs": ["Electrical demand: %.0f kW" % ELECTROLYZER_DEMAND_KW, "Water input: lower-left (%s)" % ("connected" if water_connected else "not connected"), "Rated use: %.0f L/h water" % WATER_L_PER_HOUR, "Rated output: H₂ %.1f kg/h · O₂ %.1f kg/h" % [HYDROGEN_KG_PER_HOUR, OXYGEN_KG_PER_HOUR], "Operation: direct flow, no tanks", "Independent outputs: H₂ %s · O₂ %s" % ["connected" if hydrogen_connected else "disconnected", "connected" if oxygen_connected else "disconnected"]],
		}
	var rocket := _find_landing_sequence()
	var h2_connected := _is_input_connected(get_hydrogen_input_cell(), Vector2i.RIGHT, PipeSegment.Category.HYDROGEN)
	return {
		"title": "SABATIER REACTOR",
		"category": "PROPELLANT PRODUCTION",
		"status": "FAULT — REPAIR REQUIRED" if incident_faulted else ("ROCKET FUELING" if powered and h2_connected and rocket != null else get_connection_label()),
		"status_color": Color("ff6258") if incident_faulted else (Color("72eda0") if powered and h2_connected else Color("ffb45d")),
		"principle": "The Sabatier reaction combines atmospheric CO₂ and hydrogen to synthesize methane and water: CO₂ + 4 H₂ → CH₄ + 2 H₂O. In this game model methane transfers directly to the rocket.",
		"specs": ["Electrical demand: %.0f kW" % SABATIER_DEMAND_KW, "H₂ input: left side (%s)" % ("connected" if h2_connected else "not connected"), "CO₂: supplied by Martian atmosphere (game model)", "Rated output: %.1f kg/h CH₄" % SABATIER_METHANE_KG_PER_HOUR, "CH₄ output: direct rocket fueling", "Rocket fuel: %.1f / %.0f kg" % [rocket.methane_kg, rocket.get_methane_capacity_kg()] if rocket != null else "Rocket unavailable", "Required position: immediately left of the rocket"],
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


func get_sand_accumulation() -> int:
	return sand_accumulation


func set_sand_accumulation(level: int) -> void:
	var clamped := clampi(level, 0, 3)
	if sand_accumulation == clamped:
		return
	sand_accumulation = clamped
	_refresh_texture()


func get_sand_clean_position() -> Vector2:
	return global_position


func on_sand_buried() -> void:
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("force_incident", self, "machine")


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
	if device_id == "electrolyzer":
		atlas.atlas = ELECTROLYZER_SAND_SHEETS.get(sand_accumulation, ELECTROLYZER_SHEET)
	else:
		atlas.atlas = SABATIER_SAND_SHEETS.get(sand_accumulation, SABATIER_SHEET)
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
