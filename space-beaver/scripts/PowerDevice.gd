class_name PowerDevice
extends Node2D

const SOLAR_TEXTURE := preload("res://assets/sprites/machines/solar-panel-spritesheet.png")
const TRANSFORMER_SHEET := preload("res://assets/sprites/machines/transformer-spritesheet.png")
const BATTERY_SHEET := preload("res://assets/sprites/machines/battery-spritesheet.png")
const ICE_DRILL_SHEET := preload("res://assets/sprites/machines/ice-drill-spritesheet.png")
const SOLAR_TARP_TEXTURE := preload("res://assets/sprites/machines/solar-panel-tarp.png")
const SOLAR_SAND_TEXTURES := {
	1: preload("res://assets/sprites/machines/sand/dirty/solar-panel.png"),
	2: preload("res://assets/sprites/machines/sand/covered/solar-panel.png"),
	3: preload("res://assets/sprites/machines/sand/buried/solar-panel.png"),
}
const TRANSFORMER_SAND_SHEETS := {
	1: preload("res://assets/sprites/machines/sand/dirty/transformer.png"),
	2: preload("res://assets/sprites/machines/sand/covered/transformer.png"),
	3: preload("res://assets/sprites/machines/sand/buried/transformer.png"),
}
const TRANSFORMER_FRAME_SIZE := Vector2i(32, 32)
const BATTERY_FRAME_SIZE := Vector2i(16, 16)
const ICE_DRILL_FRAME_SIZE := Vector2i(32, 48)
const BATTERY_CAPACITY_KWH := 500.0
const ICE_DRILL_DEMAND_KW := 60.0
const ICE_DRILL_WATER_L_PER_HOUR := 80.0
const ICE_DRILL_WATER_STORAGE_CAPACITY_L := 500.0
const WATER_BOTTLE_REFILL_DISTANCE := 58.0
const TILE_SIZE := 16

var device_id := ""
var origin_cell := Vector2i.ZERO
var is_preview := false
var placement_rotation := 0
var powered := false
var flow_state := 0
var animation_frame := 0
var animation_timer := 0.0
var battery_energy_kwh := 0.0
var battery_charge_ratio := 0.0
var water_extracted_liters := 0.0
var water_transported_liters := 0.0
var water_storage_liters := 0.0
var fluid_output_connected := false
var network_enabled := false
var incident_faulted := false
var sand_accumulation := 0
var solar_tarped := false
var solar_destroyed := false
var solar_burial_evaluated := false
var refill_feedback := ""
var stock_items: Array[Dictionary] = []
var sprite: Sprite2D
var status_indicator: Polygon2D
var night_light: PointLight2D
var physics_body: StaticBody2D


func setup(new_id: String, cell: Vector2i, preview: bool = false, new_placement_rotation: int = 0) -> void:
	device_id = new_id
	origin_cell = cell
	is_preview = preview
	placement_rotation = posmod(new_placement_rotation, 4)
	if is_node_ready():
		_apply_placement_rotation()
		_refresh_texture()


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	z_index = 2
	_apply_placement_rotation()
	_refresh_texture()
	_setup_night_light()
	_setup_collision()
	if device_id == "ice_drill" and not is_preview:
		add_to_group("ice_drills")
	if not is_preview:
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("register_target", self, "machine", _incident_display_name())
		var sandstorms := get_node_or_null("/root/SandstormManager")
		if sandstorms != null:
			sandstorms.call("register_target", self, _incident_display_name())


func _exit_tree() -> void:
	if not is_preview:
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("unregister_target", self, "machine")
		var sandstorms := get_node_or_null("/root/SandstormManager")
		if sandstorms != null:
			sandstorms.call("unregister_target", self)


func _process(delta: float) -> void:
	_update_night_light()
	if incident_faulted:
		return
	if device_id == "ice_drill" and not is_preview:
		var pipe_manager := get_node_or_null("/root/PipeManager")
		fluid_output_connected = pipe_manager != null and bool(pipe_manager.call("is_source_connected", self))
		if powered:
			var produced := ICE_DRILL_WATER_L_PER_HOUR * WorldClock.get_game_hours_for_real_delta(delta)
			var storable := minf(maxf(0.0, produced), maxf(0.0, ICE_DRILL_WATER_STORAGE_CAPACITY_L - water_storage_liters))
			water_extracted_liters += storable
			water_storage_liters += storable
			if fluid_output_connected:
				water_transported_liters += storable
	if is_preview or device_id == "solar_panel":
		return
	var should_animate := device_id == "transformer" and powered
	should_animate = should_animate or (device_id == "battery" and flow_state != 0)
	should_animate = should_animate or (device_id == "ice_drill" and powered)
	if not should_animate:
		return
	animation_timer += delta
	if animation_timer < 0.10:
		return
	animation_timer = 0.0
	# Transformer has four 32×32 frames. Battery instead has four frames for
	# each of the five rows that show charge.
	animation_frame = (animation_frame + 1) % 4
	_refresh_texture()


func set_power_state(new_powered: bool, new_flow_state: int = 0) -> void:
	powered = new_powered and not incident_faulted and not solar_destroyed
	flow_state = new_flow_state if not incident_faulted and not solar_destroyed else 0
	if not powered and device_id in ["transformer", "ice_drill"]:
		animation_frame = 0
		_refresh_texture()
	_update_night_light()


func set_powered(new_powered: bool) -> void:
	set_power_state(new_powered, flow_state)


func set_network_enabled(enabled: bool) -> void:
	if is_preview or network_enabled == enabled:
		return
	network_enabled = enabled
	if not network_enabled:
		set_power_state(false, 0)
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")


func is_network_enabled() -> bool:
	return network_enabled


func get_connection_label() -> String:
	if solar_destroyed:
		return "DESTROYED BY SAND — remove and replace"
	if incident_faulted:
		return "FAULT — approach and repair"
	if not network_enabled:
		return "DISCONNECTED"
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid == null:
		return "ENABLED - GRID UNAVAILABLE"
	var connection_map: Dictionary = power_grid.get("connection_ok")
	return "CONNECTED TO GRID" if bool(connection_map.get(self, false)) else "ENABLED - AWAITING GRID"


func get_interaction_summary() -> String:
	match device_id:
		"solar_panel":
			if solar_destroyed:
				return "PANEL DESTROYED BY STORM · remove it and buy a replacement"
			if solar_tarped:
				return "PROTECTIVE TARP INSTALLED · T to remove it"
			var available_kw := 100.0 * WorldClock.get_solar_factor() * get_solar_output_multiplier()
			return "Available output: %d kW · sand: %s" % [roundi(available_kw), _sand_label()]
		"transformer":
			return "Electrical-section transformation and isolation"
		"battery":
			return "Charge: %.1f / %.0f kWh  ·  %d%%" % [battery_energy_kwh, BATTERY_CAPACITY_KWH, roundi(battery_charge_ratio * 100.0)]
		"ice_drill":
			var summary := "Use: 60 kW  ·  Water: %.0f L/h" % get_fluid_output_rate_lph()
			var refill_prompt := get_bottle_refill_prompt()
			if not refill_prompt.is_empty():
				return summary + "\n" + refill_prompt
			var inventory := get_node_or_null("/root/Inventory")
			if inventory != null and int(inventory.call("count_item", "water_bottle")) > 0:
				return summary + "\nWATER BOTTLE: select it and press E to refill"
			return summary
	return "Electrical device"


func set_incident_faulted(_target_id: String, value: bool) -> void:
	if incident_faulted == value:
		return
	incident_faulted = value
	if incident_faulted:
		set_power_state(false, 0)
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")


func is_incident_faulted(_target_id: String = "machine") -> bool:
	return incident_faulted


func is_incident_operational() -> bool:
	return not incident_faulted and not solar_destroyed


func can_receive_incident(_target_id: String = "machine") -> bool:
	return not is_preview and not incident_faulted and not solar_destroyed


func get_incident_repair_position(_target_id: String = "machine") -> Vector2:
	return global_position


func get_sand_accumulation() -> int:
	return sand_accumulation


func set_sand_accumulation(level: int) -> void:
	var clamped := clampi(level, 0, 3)
	if sand_accumulation == clamped:
		return
	sand_accumulation = clamped
	if clamped < 3:
		solar_burial_evaluated = false
	_refresh_texture()
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")


func get_sand_clean_position() -> Vector2:
	return global_position


func can_clean_sand() -> bool:
	return not solar_destroyed


func is_sand_protected() -> bool:
	return device_id == "solar_panel" and solar_tarped


func on_sand_buried() -> void:
	if device_id == "solar_panel":
		if solar_tarped or solar_destroyed:
			return
		if solar_burial_evaluated:
			return
		solar_burial_evaluated = true
		# An exposed panel has two-thirds of the third-layer total-failure chance
		# and cannot be repaired.
		if randf() < 2.0 / 3.0:
			solar_destroyed = true
			network_enabled = false
			set_power_state(false, 0)
			_refresh_texture()
			var power_grid := get_node_or_null("/root/PowerGrid")
			if power_grid != null:
				power_grid.call("request_rebuild")
			var sandstorms := get_node_or_null("/root/SandstormManager")
			if sandstorms != null:
				sandstorms.call("show_notification", "SOLAR PANEL DESTROYED\nSand damaged the cells: remove it and buy a replacement.")
		return
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("force_incident", self, "machine")


func can_toggle_solar_tarp() -> bool:
	return not is_preview and device_id == "solar_panel" and not solar_destroyed


func toggle_solar_tarp() -> bool:
	if not can_toggle_solar_tarp():
		return false
	solar_tarped = not solar_tarped
	_refresh_texture()
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")
	return solar_tarped


func is_solar_tarped() -> bool:
	return solar_tarped


func is_solar_destroyed() -> bool:
	return solar_destroyed


func get_solar_output_multiplier() -> float:
	if device_id != "solar_panel" or solar_destroyed or solar_tarped:
		return 0.0 if device_id == "solar_panel" else 1.0
	return [1.0, 0.66, 0.30, 0.0][sand_accumulation]


func _sand_label() -> String:
	return ["CLEAN", "DIRTY", "COVERED", "BURIED"][sand_accumulation]


func _incident_display_name() -> String:
	match device_id:
		"solar_panel":
			return "SOLAR PANEL"
		"transformer":
			return "TRANSFORMER"
		"battery":
			return "BATTERY"
		"ice_drill":
			return "ICE DRILL"
	return "ELECTRICAL DEVICE"


func get_bottle_refill_prompt() -> String:
	if device_id != "ice_drill":
		return ""
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null:
		return ""
	var bottle: Dictionary = inventory.call("get_selected_item")
	if str(bottle.get("id", "")) != "water_bottle":
		return ""
	var capacity := float(bottle.get("capacity_liters", 2.0))
	var current := float(bottle.get("liters", 0.0))
	if current >= capacity - 0.001:
		return "WATER BOTTLE ALREADY FULL"
	if water_storage_liters < 0.05:
		var production_state := "drill producing" if powered else "power the drill to produce more water"
		return "WATER BOTTLE · reserve empty · %s" % production_state
	return "E · REFILL WATER BOTTLE · reserve %.1f L%s" % [water_storage_liters, (" · " + refill_feedback if not refill_feedback.is_empty() else "")]


func try_refill_selected_bottle(player: Node2D) -> bool:
	if is_preview or device_id != "ice_drill" or player == null:
		return false
	if player.global_position.distance_to(global_position) > WATER_BOTTLE_REFILL_DISTANCE:
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null:
		return false
	var bottle: Dictionary = inventory.call("get_selected_item")
	if str(bottle.get("id", "")) != "water_bottle":
		return false
	if water_storage_liters < 0.05:
		refill_feedback = "insufficient water reserve"
		return true
	var transferred := float(inventory.call("refill_selected_water_bottle", water_storage_liters))
	if transferred <= 0.0001:
		refill_feedback = "water bottle already full"
		return true
	water_storage_liters = maxf(0.0, water_storage_liters - transferred)
	refill_feedback = "+%.1f L refilled" % transferred
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null:
		achievements.call("record", "refill_bottle")
	return true


func get_stock_items() -> Array[Dictionary]:
	return stock_items.duplicate(true)


func take_stock_item(index: int = 0) -> bool:
	if index < 0 or index >= stock_items.size():
		return false
	var item := stock_items[index]
	var count := int(item.get("count", 0))
	if count <= 0:
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not bool(inventory.call("add_item", str(item.get("id", "")), str(item.get("name", "Output")), 1, bool(item.get("placeable", false)))):
		return false
	item["count"] = count - 1
	if int(item["count"]) <= 0:
		stock_items.remove_at(index)
	return true


func set_battery_charge_ratio(value: float) -> void:
	set_battery_energy_kwh(clampf(value, 0.0, 1.0) * BATTERY_CAPACITY_KWH)


func set_battery_energy_kwh(value: float) -> void:
	battery_energy_kwh = clampf(value, 0.0, BATTERY_CAPACITY_KWH)
	battery_charge_ratio = battery_energy_kwh / BATTERY_CAPACITY_KWH
	if device_id == "battery":
		_refresh_texture()
	_update_night_light()


func get_battery_energy_kwh() -> float:
	return battery_energy_kwh


func get_battery_available_capacity_kwh() -> float:
	return maxf(0.0, BATTERY_CAPACITY_KWH - battery_energy_kwh)


func get_occupied_power_cells() -> Array[Vector2i]:
	return footprint_cells_for(device_id, origin_cell, placement_rotation)


func contains_world_point(world_point: Vector2) -> bool:
	var point_cell := Vector2i(floori(world_point.x / TILE_SIZE), floori(world_point.y / TILE_SIZE))
	return point_cell in get_occupied_power_cells()


func get_fluid_output_cell() -> Vector2i:
	return rotated_cell_for(device_id, origin_cell, origin_cell + Vector2i(2, 0), placement_rotation)


func get_fluid_output_required_opening() -> Vector2i:
	return rotate_direction(Vector2i.LEFT, placement_rotation)


func get_power_input_cell() -> Vector2i:
	return rotated_cell_for(device_id, origin_cell, origin_cell + Vector2i.LEFT, placement_rotation)


func get_power_input_attach_direction() -> Vector2i:
	return rotate_direction(Vector2i.RIGHT, placement_rotation)


func get_power_output_cell() -> Vector2i:
	var native_cell := origin_cell + (Vector2i.RIGHT if device_id == "battery" else Vector2i(2, 0))
	return rotated_cell_for(device_id, origin_cell, native_cell, placement_rotation)


func get_power_output_attach_direction() -> Vector2i:
	return rotate_direction(Vector2i.LEFT, placement_rotation)


static func footprint_cells_for(item_id: String, cell: Vector2i, new_placement_rotation: int = 0) -> Array[Vector2i]:
	var native_cells: Array[Vector2i] = [cell]
	if item_id == "solar_panel":
		native_cells = [cell, cell + Vector2i.RIGHT]
	elif item_id in ["transformer", "ice_drill", "rock_drill"]:
		# Sprite occupies two columns and three rows around the attachment row.
		native_cells = [cell + Vector2i.UP, cell + Vector2i.RIGHT + Vector2i.UP, cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.RIGHT + Vector2i.DOWN]
	var rotated: Array[Vector2i] = []
	for native_cell in native_cells:
		var rotated_cell := rotated_cell_for(item_id, cell, native_cell, new_placement_rotation)
		if rotated_cell not in rotated:
			rotated.append(rotated_cell)
	return rotated


static func rotated_cell_for(item_id: String, cell: Vector2i, native_cell: Vector2i, new_placement_rotation: int = 0) -> Vector2i:
	var center := _base_world_position_for(item_id, cell)
	var native_center := Vector2(native_cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE * 0.5
	var rotated_center := center + (native_center - center).rotated(float(posmod(new_placement_rotation, 4)) * PI * 0.5)
	return Vector2i(floori(rotated_center.x / TILE_SIZE), floori(rotated_center.y / TILE_SIZE))


static func rotate_direction(direction: Vector2i, new_placement_rotation: int = 0) -> Vector2i:
	var result := direction
	for _turn in posmod(new_placement_rotation, 4):
		result = Vector2i(-result.y, result.x)
	return result


static func _base_world_position_for(item_id: String, cell: Vector2i) -> Vector2:
	if item_id in ["solar_panel", "transformer", "ice_drill", "rock_drill"]:
		return Vector2(cell * TILE_SIZE) + Vector2(16.0, 8.0)
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE * 0.5


func _apply_placement_rotation() -> void:
	rotation = float(placement_rotation) * PI * 0.5


func get_fluid_output_rate_lph() -> float:
	return ICE_DRILL_WATER_L_PER_HOUR if device_id == "ice_drill" and powered and fluid_output_connected else 0.0


func consume_fluid_resource(amount: float) -> float:
	if device_id != "ice_drill" or amount <= 0.0:
		return 0.0
	var transferred := minf(amount, water_storage_liters)
	water_storage_liters -= transferred
	return transferred


func get_machine_specs() -> Dictionary:
	match device_id:
		"solar_panel":
			var solar_connection := get_connection_label()
			return {
				"title": "PHOTOVOLTAIC SOLAR PANEL",
				"category": "ELECTRICAL GENERATION",
				"status": solar_connection if not network_enabled else ("OUTPUT ACTIVE" if powered else "NO OUTPUT"),
				"status_color": Color("72eda0") if powered else Color("ffb45d"),
				"principle": "Photovoltaic cells convert solar photons into direct current through the photovoltaic effect in semiconductors.",
				"specs": ["Rated power: 100 kW", "Output: proportional to sunlight", "Night output: 0 kW", "Electrical output: right side", "Grid: %s" % solar_connection],
			}
		"transformer":
			var transformer_connection := get_connection_label()
			return {
				"title": "POWER TRANSFORMER",
				"category": "ELECTRICAL CONDITIONING",
				"status": transformer_connection if not network_enabled else ("OPERATING" if powered else transformer_connection),
				"status_color": Color("72eda0") if powered else Color("ffb45d"),
				"principle": "Electromagnetic induction transfers energy between isolated windings and adapts voltage and current for the storage network.",
				"specs": ["Input: panel network", "Output: transformed network", "Separate electrical channels", "Every transformer creates an independent network", "Grid: %s" % transformer_connection],
			}
		"battery":
			var charge_percent := roundi(battery_charge_ratio * 100.0)
			var battery_connection := get_connection_label()
			var battery_status := battery_connection
			if network_enabled and battery_connection == "CONNECTED TO GRID":
				battery_status = "CHARGE %d%%" % charge_percent
			return {
				"title": "STORAGE BATTERY",
				"category": "ENERGY STORAGE",
				"status": battery_status,
				"status_color": Color("69c8ff") if charge_percent > 0 else Color("ff655d"),
				"principle": "Electrical energy is stored as reversible chemical energy and returned to the grid when solar output cannot cover load.",
				"specs": ["Capacity: %.0f kWh" % BATTERY_CAPACITY_KWH, "Stored energy: %.1f kWh" % battery_energy_kwh, "State of charge: %d%%" % charge_percent, "Flow: %s" % _flow_label(), "Night supply: available", "Grid: %s" % battery_connection],
			}
		"ice_drill":
			var pipe_status := "CONNECTED - WATER ON NETWORK" if fluid_output_connected else "WATER OUTPUT NOT CONNECTED"
			var drill_connection := get_connection_label()
			return {
				"title": "ICE EXTRACTION DRILL",
				"category": "ISRU - IN-SITU RESOURCE UTILIZATION",
				"status": drill_connection if not network_enabled else ("OPERATIONAL" if powered else drill_connection),
				"status_color": Color("72eda0") if powered else Color("ff655d"),
				"principle": "Game ISRU model: the drill head bores ice-bearing Martian regolith; recovered ice is separated and melted into liquid water.",
				"specs": ["Electrical demand: 60 kW", "Rated output: %.0f L/h" % ICE_DRILL_WATER_L_PER_HOUR, "Output: right, center cell", "Piping: %s" % pipe_status, "Water extracted: %.1f L" % water_extracted_liters, "Drill reserve: %.1f / %.0f L" % [water_storage_liters, ICE_DRILL_WATER_STORAGE_CAPACITY_L], "Water transferred: %.1f L" % water_transported_liters, "Water bottle: select it and press E near the drill", "Grid: %s" % drill_connection],
			}
	return {"title": "MACHINE", "category": "SYSTEM", "status": "UNKNOWN", "status_color": Color.WHITE, "principle": "", "specs": []}


func _flow_label() -> String:
	if flow_state > 0:
		return "CHARGING"
	if flow_state < 0:
		return "DISCHARGING"
	return "STABLE"


func _refresh_texture() -> void:
	if sprite == null:
		return
	sprite.modulate = Color.WHITE
	if device_id == "solar_panel":
		if solar_tarped:
			sprite.texture = SOLAR_TARP_TEXTURE
		elif sand_accumulation > 0:
			sprite.texture = SOLAR_SAND_TEXTURES[sand_accumulation]
			if solar_destroyed:
				sprite.modulate = Color(1.0, 0.42, 0.34)
		else:
			sprite.texture = SOLAR_TEXTURE
		return
	var atlas := AtlasTexture.new()
	if device_id == "transformer":
		atlas.atlas = TRANSFORMER_SAND_SHEETS.get(sand_accumulation, TRANSFORMER_SHEET)
		var transformer_column := animation_frame % 2
		var transformer_row := floori(float(animation_frame) / 2.0)
		atlas.region = Rect2(
			Vector2i(transformer_column, transformer_row) * TRANSFORMER_FRAME_SIZE,
			TRANSFORMER_FRAME_SIZE
		)
	elif device_id == "ice_drill":
		atlas.atlas = ICE_DRILL_SHEET
		var drill_column := animation_frame % 2
		var drill_row := floori(float(animation_frame) / 2.0)
		atlas.region = Rect2(
			Vector2i(drill_column, drill_row) * ICE_DRILL_FRAME_SIZE,
			ICE_DRILL_FRAME_SIZE
		)
	else:
		atlas.atlas = BATTERY_SHEET
		if sand_accumulation > 0:
			sprite.modulate = Color(1.0, 0.76 - float(sand_accumulation) * 0.10, 0.56 - float(sand_accumulation) * 0.10)
		# Row 0 is full and row 4 is empty. Every row contains four animation
		# frames that must never alter charge.
		var charge_band := clampi(floori(battery_charge_ratio * 5.0), 0, 4)
		var battery_row := 4 - charge_band
		atlas.region = Rect2(
			Vector2i(animation_frame % 4, battery_row) * BATTERY_FRAME_SIZE,
			BATTERY_FRAME_SIZE
		)
	sprite.texture = atlas


func _setup_night_light() -> void:
	if device_id == "solar_panel":
		return
	status_indicator = Polygon2D.new()
	status_indicator.name = "StatusLight"
	status_indicator.polygon = PackedVector2Array([
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
		Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
	])
	status_indicator.position = Vector2(0.0, -5.0 if device_id == "battery" else (-18.0 if device_id == "ice_drill" else -8.0))
	status_indicator.z_index = 4
	add_child(status_indicator)

	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var light_texture := GradientTexture2D.new()
	light_texture.width = 64
	light_texture.height = 64
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	light_texture.gradient = gradient
	night_light = PointLight2D.new()
	night_light.name = "NightGlow"
	night_light.texture = light_texture
	night_light.texture_scale = 0.75 if device_id == "battery" else 1.1
	night_light.shadow_enabled = false
	night_light.enabled = false
	add_child(night_light)
	_update_night_light()


func _update_night_light() -> void:
	if status_indicator == null or night_light == null:
		return
	var active := powered and not is_preview
	var light_color := Color("69c8ff")
	if device_id == "battery":
		if flow_state > 0:
			light_color = Color("72eda0")
		elif flow_state < 0:
			light_color = Color("69a7ff")
		elif battery_charge_ratio <= 0.01:
			light_color = Color("ff5d57")
		else:
			light_color = Color("ffd36a")
	elif device_id == "ice_drill":
		light_color = Color("52c7ff") if fluid_output_connected else Color("ffb45d")
	status_indicator.color = light_color
	status_indicator.visible = active
	var night_amount := WorldClock.get_artificial_light_factor()
	night_light.color = light_color
	night_light.energy = (0.58 if device_id == "battery" else 0.72) * night_amount
	night_light.enabled = active and night_amount > 0.01


func _setup_collision() -> void:
	if is_preview:
		return
	physics_body = StaticBody2D.new()
	physics_body.name = "StructureCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	match device_id:
		"solar_panel":
			shape.size = Vector2(30.0, 12.0)
			collision.position = Vector2(0.0, 2.0)
		"transformer":
			shape.size = Vector2(28.0, 18.0)
			collision.position = Vector2(0.0, 6.0)
		"battery":
			shape.size = Vector2(14.0, 12.0)
			collision.position = Vector2(0.0, 2.0)
		"ice_drill":
			# Only the base occupies ground; the upper portion stays passable when
			# the player walks behind the drill.
			shape.size = Vector2(27.0, 15.0)
			collision.position = Vector2(0.0, 15.0)
		_:
			shape.size = Vector2(14.0, 14.0)
	collision.shape = shape
	physics_body.add_child(collision)
	add_child(physics_body)
