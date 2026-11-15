extends Node

signal network_changed
signal stats_changed(data: Dictionary)
signal routing_failed(device: Node, message: String)

const POWER_DEVICE_SCRIPT := preload("res://scripts/PowerDevice.gd")
const ROCK_DRILL_SCRIPT := preload("res://scripts/RockDrill.gd")
const CABLE_SEGMENT_SCRIPT := preload("res://scripts/CableSegment.gd")
const CELL_SIZE := 16
const PANEL_OUTPUT_KW := 100.0
const BATTERY_CAPACITY_KWH := 500.0
const ICE_DRILL_DEMAND_KW := 60.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const NETWORK_SOLAR := "solar_to_transformer"
const NETWORK_TRANSFORMED := "transformer_to_battery"
const NETWORK_BATTERY := "battery_to_consumers"
const PATH_NEW_CELL_COST := 1.0
const PATH_EXISTING_CELL_COST := 0.82
const PATH_TURN_COST := 0.42
const PATH_PARALLEL_COST := 0.28
## Crossing two electrical channels is permitted: channels remain separate in
## grid logic, but must not become an invisible wall. The high cost makes the
## routing choose a clear detour whenever one exists.
const PATH_FOREIGN_CABLE_CROSSING_COST := 4.0
## With the full weight, the search heads straight toward its goal even over very
## large distances. Existing cable segments remain preferred by their lower cost.
const PATH_HEURISTIC_SCALE := 1.0
const PATH_START_DIRECTION := 4
## The budget is deliberately broad. Cost stays controlled through A* search in
## a dynamic corridor rather than a maximum radius that would break distant grids.
const PATH_SEARCH_BUDGET := 50_000
const PATH_CORRIDOR_PADDING := 96

var panels: Array[PowerDevice] = []
var batteries: Array[PowerDevice] = []
# Compatibility: `transformer` continues to indicate the first list item for
# HUD and legacy tests. The real grid can, however, have multiple transformers.
var transformers: Array[PowerDevice] = []
var transformer: PowerDevice
var consumers: Array[Dictionary] = []
var cables: Dictionary = {}
var _pending_cable_visuals: Array[CableSegment] = []
var _cable_visual_generation := 0
var cable_cells_by_network: Dictionary = {}
var cable_attachments_by_network: Dictionary = {}
var connection_ok: Dictionary = {}
var _grids_by_transformer: Dictionary = {}
var _transformer_for_device: Dictionary = {}

## HUD- and test-compatible summary: real energy belongs to each individual
## battery PowerDevice rather than this global grid.
var battery_energy_kwh: float:
	get:
		return _get_total_battery_energy()
	set(value):
		_set_total_battery_energy(value)
var production_kw := 0.0
var demand_kw := 0.0
var network_powered := false
var network_status := "GRID INCOMPLETE"
var _stats_timer := 0.0
var _routing_failure_keys: Dictionary = {}


func _process(delta: float) -> void:
	_update_energy(delta)
	_stats_timer += delta
	if _stats_timer >= 0.20:
		_stats_timer = 0.0
		stats_changed.emit(get_stats())


func has_transformer() -> bool:
	_cleanup_invalid()
	return not transformers.is_empty()


func is_day() -> bool:
	return WorldClock.is_day()


func get_mouse_cell(camera: Camera2D) -> Vector2i:
	var mouse := camera.get_global_mouse_position()
	return Vector2i(floori(mouse.x / CELL_SIZE), floori(mouse.y / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL_SIZE) + Vector2.ONE * CELL_SIZE * 0.5


func device_world_position(item_id: String, cell: Vector2i, _placement_rotation: int = 0) -> Vector2:
	if item_id == "solar_panel":
		return Vector2(cell * CELL_SIZE) + Vector2(16.0, 8.0)
	if item_id in ["transformer", "ice_drill", "rock_drill"]:
		# The cable axis remains aligned to the center of the 16 px row identified
		# by origin_cell, regardless of frame height.
		return Vector2(cell * CELL_SIZE) + Vector2(16.0, 8.0)
	return cell_to_world(cell)


func can_place_device(item_id: String, cell: Vector2i, placement_rotation: int = 0) -> bool:
	if item_id in ["electrolyzer", "sabatier"]:
		return can_place_process_machine(item_id, cell, placement_rotation)
	if item_id not in ["solar_panel", "transformer", "battery", "ice_drill", "rock_drill"]:
		return false
	var occupied := _footprint_for(item_id, cell, placement_rotation)
	var blocked := _get_blocked_cells()
	for occupied_cell in occupied:
		if blocked.has(occupied_cell):
			return false
		if PipeManager.get_pipe(occupied_cell) != null:
			return false
	if item_id == "solar_panel":
		var panel_output := PowerDevice.rotated_cell_for(item_id, cell, cell + Vector2i(2, 0), placement_rotation)
		if blocked.has(panel_output):
			return false
	if item_id == "ice_drill":
		var water_output := PowerDevice.rotated_cell_for(item_id, cell, cell + Vector2i(2, 0), placement_rotation)
		var required_opening := PowerDevice.rotate_direction(Vector2i.LEFT, placement_rotation)
		if not PipeManager.can_attach_fluid_source(water_output, PipeSegment.Category.WATER, required_opening):
			return false
	return true


func can_place_process_machine(item_id: String, cell: Vector2i, placement_rotation: int = 0) -> bool:
	if item_id not in ["electrolyzer", "sabatier"]:
		return false
	if item_id == "sabatier" and cell != ProcessMachine.sabatier_target_cell():
		return false
	var occupied := ProcessMachine.footprint_cells(item_id, cell)
	var blocked := _get_blocked_cells()
	for occupied_cell in occupied:
		if blocked.has(occupied_cell) or PipeManager.get_pipe(occupied_cell) != null:
			return false
	return true


func place_process_machine(parent: Node, item_id: String, cell: Vector2i, placement_rotation: int = 0) -> ProcessMachine:
	if not can_place_process_machine(item_id, cell, placement_rotation):
		return null
	var machine := ProcessMachine.new()
	machine.setup(item_id, cell, false, placement_rotation)
	parent.add_child(machine)
	machine.global_position = ProcessMachine.world_position_for(item_id, cell)
	register_consumer(machine, machine.get_power_connection_cell(), machine.get_power_demand_kw(), machine.get_power_attach_direction())
	if item_id == "electrolyzer":
		PipeManager.register_fluid_source(machine, machine.get_hydrogen_output_cell(), PipeSegment.Category.HYDROGEN, machine.get_hydrogen_output_required_opening())
		PipeManager.register_fluid_source(machine, machine.get_oxygen_output_cell(), PipeSegment.Category.OXYGEN, machine.get_oxygen_output_required_opening())
	for input_port in machine.get_fluid_input_ports():
		PipeManager.register_fluid_input(machine, input_port["cell"], input_port["category"], input_port["required_opening"])
	BuildableRegistry.register_buildable(machine, machine.get_display_name(), "machine", pickup_process_machine.bind(machine))
	rebuild_network()
	return machine


func pickup_process_machine(machine: ProcessMachine) -> bool:
	if not is_instance_valid(machine) or not Inventory.can_add_item(machine.device_id):
		return false
	if not Inventory.add_item(machine.device_id, machine.get_display_name(), 1, true):
		return false
	unregister_consumer(machine)
	PipeManager.unregister_fluid_source(machine)
	BuildableRegistry.unregister_buildable(machine)
	machine.queue_free()
	call_deferred("rebuild_network")
	return true


func place_device(parent: Node, item_id: String, cell: Vector2i, placement_rotation: int = 0) -> Node2D:
	if not can_place_device(item_id, cell, placement_rotation):
		return null
	if item_id == "rock_drill":
		var rock_drill := ROCK_DRILL_SCRIPT.new() as RockDrill
		rock_drill.setup(cell, false, placement_rotation)
		parent.add_child(rock_drill)
		rock_drill.global_position = device_world_position(item_id, cell, placement_rotation)
		consumers.append({
			"node": rock_drill,
			"connection_cell": rock_drill.get_power_connection_cell(),
			"demand_kw": rock_drill.get_power_demand_kw(),
			"attach_direction": rock_drill.get_power_attach_direction(),
		})
		BuildableRegistry.register_buildable(rock_drill, rock_drill.get_display_name(), "machine", pickup_rock_drill.bind(rock_drill))
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			achievements.call("record", "first_extraction")
		rebuild_network()
		return rock_drill
	var device := POWER_DEVICE_SCRIPT.new() as PowerDevice
	device.setup(item_id, cell, false, placement_rotation)
	parent.add_child(device)
	device.global_position = device_world_position(item_id, cell, placement_rotation)
	match item_id:
		"solar_panel":
			panels.append(device)
		"transformer":
			transformers.append(device)
			if not is_instance_valid(transformer):
				transformer = device
		"battery":
			batteries.append(device)
		"ice_drill":
			consumers.append({
				"node": device,
				"connection_cell": device.get_power_input_cell(),
				"demand_kw": ICE_DRILL_DEMAND_KW,
				"attach_direction": device.get_power_input_attach_direction(),
			})
			PipeManager.register_fluid_source(device, device.get_fluid_output_cell(), PipeSegment.Category.WATER, device.get_fluid_output_required_opening())
	var buildable_kind := "machine" if item_id == "ice_drill" else "power_device"
	BuildableRegistry.register_buildable(device, _display_name(item_id), buildable_kind, pickup_device.bind(device))
	if item_id == "ice_drill":
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			achievements.call("record", "ice_drill")
	rebuild_network()
	return device


func pickup_rock_drill(rock_drill: RockDrill) -> bool:
	if not is_instance_valid(rock_drill) or not Inventory.can_add_item("rock_drill"):
		return false
	if not Inventory.add_item("rock_drill", "Mineral Drill", 1, true):
		return false
	rock_drill.close_storage()
	unregister_consumer(rock_drill)
	BuildableRegistry.unregister_buildable(rock_drill)
	rock_drill.queue_free()
	call_deferred("rebuild_network")
	return true


func pickup_device(device: PowerDevice) -> bool:
	if not is_instance_valid(device) or not Inventory.can_add_item(device.device_id):
		return false
	if not Inventory.add_item(device.device_id, _display_name(device.device_id), 1, true):
		return false
	panels.erase(device)
	batteries.erase(device)
	transformers.erase(device)
	if device.device_id == "ice_drill":
		unregister_consumer(device)
		PipeManager.unregister_fluid_source(device)
	if transformer == device:
		_refresh_primary_transformer()
	BuildableRegistry.unregister_buildable(device)
	device.queue_free()
	call_deferred("rebuild_network")
	return true


func register_consumer(node: Node2D, connection_cell: Vector2i, demand: float, attach_direction: Vector2i = Vector2i.LEFT) -> void:
	unregister_consumer(node)
	consumers.append({
		"node": node,
		"connection_cell": connection_cell,
		"demand_kw": maxf(0.0, demand),
		"attach_direction": attach_direction,
	})
	rebuild_network()


func unregister_consumer(node: Node) -> void:
	for index in range(consumers.size() - 1, -1, -1):
		var registered: Node = consumers[index].get("node")
		if not is_instance_valid(registered) or registered == node:
			consumers.remove_at(index)
	connection_ok.erase(node)
	rebuild_network()


func request_rebuild() -> void:
	call_deferred("rebuild_network")


func rebuild_network() -> void:
	_cleanup_invalid()
	_clear_cables()
	connection_ok.clear()
	_grids_by_transformer.clear()
	_transformer_for_device.clear()
	for current_transformer in transformers:
		connection_ok[current_transformer] = false
		if _device_network_enabled(current_transformer):
			_grids_by_transformer[current_transformer.get_instance_id()] = {
				"transformer": current_transformer,
				"panels": [],
				"batteries": [],
				"consumers": [],
				"chain_ready": false,
			}
	if _grids_by_transformer.is_empty():
		_routing_failure_keys.clear()
		_finalize_network_visuals()
		return

	# Every transformer creates three private channels (panels, transformed power,
	# battery). Cables may graphically cross but never connect in logic, keeping
	# grids independent.
	var failed_routing_nodes: Array = []
	for panel in panels:
		if not _device_network_enabled(panel):
			connection_ok[panel] = false
			continue
		var assigned := false
		for current_transformer in _sorted_transformers_for_cell(panel.get_power_output_cell(), true):
			var path := _find_path(panel.get_power_output_cell(), current_transformer.get_power_input_cell(), _network_id(current_transformer, NETWORK_SOLAR))
			if path.is_empty():
				continue
			_add_path(path, panel.get_power_output_attach_direction(), current_transformer.get_power_input_attach_direction(), _network_id(current_transformer, NETWORK_SOLAR))
			_register_grid_device(current_transformer, "panels", panel)
			connection_ok[panel] = true
			assigned = true
			break
		if not assigned:
			connection_ok[panel] = false
			failed_routing_nodes.append(panel)

	for battery in batteries:
		if not _device_network_enabled(battery):
			connection_ok[battery] = false
			continue
		var assigned := false
		for current_transformer in _sorted_transformers_for_cell(battery.get_power_input_cell(), false):
			var path := _find_path(current_transformer.get_power_output_cell(), battery.get_power_input_cell(), _network_id(current_transformer, NETWORK_TRANSFORMED))
			if path.is_empty():
				continue
			_add_path(path, current_transformer.get_power_output_attach_direction(), battery.get_power_input_attach_direction(), _network_id(current_transformer, NETWORK_TRANSFORMED))
			_register_grid_device(current_transformer, "batteries", battery)
			connection_ok[battery] = true
			assigned = true
			break
		if not assigned:
			connection_ok[battery] = false
			failed_routing_nodes.append(battery)

	for consumer in consumers:
		var node: Node2D = consumer.get("node") as Node2D
		if not _device_network_enabled(node):
			connection_ok[node] = false
			continue
		var consumer_cell := Vector2i(consumer["connection_cell"])
		var assigned := false
		for route_variant in _consumer_routes_for_cell(consumer_cell):
			var route: Dictionary = route_variant
			var path := _find_path(Vector2i(route["supply_cell"]), consumer_cell, str(route["network_id"]))
			if path.is_empty():
				continue
			_add_path(path, Vector2i(route["supply_attach"]), Vector2i(consumer["attach_direction"]), str(route["network_id"]))
			_register_grid_device(route["transformer"] as PowerDevice, "consumers", node)
			connection_ok[node] = true
			assigned = true
			break
		if not assigned:
			connection_ok[node] = false
			failed_routing_nodes.append(node)

	for current_transformer in transformers:
		if not _device_network_enabled(current_transformer):
			connection_ok[current_transformer] = false
			continue
		var grid: Dictionary = _grid_for_transformer(current_transformer)
		var has_panels := not (grid.get("panels", []) as Array).is_empty()
		var has_downstream := not (grid.get("batteries", []) as Array).is_empty() or not (grid.get("consumers", []) as Array).is_empty()
		var chain_ready := has_panels and has_downstream
		grid["chain_ready"] = chain_ready
		_grids_by_transformer[current_transformer.get_instance_id()] = grid
		connection_ok[current_transformer] = chain_ready
	_finalize_network_visuals()
	_report_routing_failures(failed_routing_nodes)


func _network_id(current_transformer: PowerDevice, section: String) -> String:
	return "grid_%s:%s" % [current_transformer.get_instance_id(), section]


func _grid_for_transformer(current_transformer: PowerDevice) -> Dictionary:
	return _grids_by_transformer.get(current_transformer.get_instance_id(), {}) as Dictionary


func _register_grid_device(current_transformer: PowerDevice, category: String, device: Node) -> void:
	var grid := _grid_for_transformer(current_transformer)
	if grid.is_empty():
		return
	var devices: Array = grid.get(category, []) as Array
	if device not in devices:
		devices.append(device)
	grid[category] = devices
	_grids_by_transformer[current_transformer.get_instance_id()] = grid
	_transformer_for_device[device] = current_transformer


func _sorted_transformers_for_cell(target: Vector2i, use_input: bool) -> Array[PowerDevice]:
	var result: Array[PowerDevice] = []
	for current_transformer in transformers:
		if is_instance_valid(current_transformer) and _device_network_enabled(current_transformer):
			result.append(current_transformer)
	result.sort_custom(func(first: PowerDevice, second: PowerDevice) -> bool:
		var first_cell := first.get_power_input_cell() if use_input else first.get_power_output_cell()
		var second_cell := second.get_power_input_cell() if use_input else second.get_power_output_cell()
		return _manhattan(first_cell, target) < _manhattan(second_cell, target)
	)
	return result


func _consumer_routes_for_cell(target: Vector2i) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for current_transformer in transformers:
		if not is_instance_valid(current_transformer) or not _device_network_enabled(current_transformer):
			continue
		var grid := _grid_for_transformer(current_transformer)
		var grid_batteries: Array = grid.get("batteries", []) as Array
		if grid_batteries.is_empty():
			routes.append({
				"transformer": current_transformer,
				"supply_cell": current_transformer.get_power_output_cell(),
				"supply_attach": current_transformer.get_power_output_attach_direction(),
				"network_id": _network_id(current_transformer, NETWORK_TRANSFORMED),
				"distance": _manhattan(current_transformer.get_power_output_cell(), target),
			})
			continue
		for battery_variant in grid_batteries:
			var battery := battery_variant as PowerDevice
			if battery == null or not is_instance_valid(battery):
				continue
			routes.append({
				"transformer": current_transformer,
				"supply_cell": battery.get_power_output_cell(),
				"supply_attach": battery.get_power_output_attach_direction(),
				"network_id": _network_id(current_transformer, NETWORK_BATTERY),
				"distance": _manhattan(battery.get_power_output_cell(), target),
			})
	routes.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first["distance"]) < float(second["distance"]))
	return routes


func get_battery_capacity() -> float:
	return batteries.size() * BATTERY_CAPACITY_KWH


func get_connected_battery_capacity() -> float:
	return _connected_batteries().size() * BATTERY_CAPACITY_KWH


func get_stats() -> Dictionary:
	return {
		"hour": WorldClock.game_hour,
		"is_day": is_day(),
		"phase": WorldClock.get_phase_label(),
		"solar_factor": WorldClock.get_solar_factor(),
		"production_kw": production_kw,
		"demand_kw": demand_kw,
		"battery_kwh": _get_total_battery_energy(),
		"battery_capacity_kwh": get_battery_capacity(),
		"connected_battery_kwh": _get_connected_battery_energy(),
		"connected_battery_capacity_kwh": get_connected_battery_capacity(),
		"batteries_connected": _connected_batteries().size(),
		"batteries_total": batteries.size(),
		"battery_autonomy_hours": _get_battery_autonomy_hours(),
		"powered": network_powered,
		"status": network_status,
		"panels_connected": _connected_panel_count(),
		"panels_total": panels.size(),
	}


func get_network_devices() -> Array[Dictionary]:
	## Unified model for the distribution page. Each source, store, and load stays
	## individually selectable without hunting for a sprite on the map. The real
	## node stays in the record for the manual button.
	_cleanup_invalid()
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for panel in panels:
		_append_network_device(result, seen, panel, "GENERATION", PANEL_OUTPUT_KW * WorldClock.get_solar_factor(), "available production")
	for current_transformer in transformers:
		_append_network_device(result, seen, current_transformer, "CONVERSION", 0.0, "bridge for its independent grid")
	for battery in batteries:
		var stored := battery.get_battery_energy_kwh()
		_append_network_device(result, seen, battery, "STORAGE", stored, "%.0f / %.0f kWh" % [stored, BATTERY_CAPACITY_KWH])
	for consumer in consumers:
		var node := consumer.get("node") as Node
		var demand := float(consumer.get("demand_kw", 0.0))
		if is_instance_valid(node) and node.has_method("get_power_demand_kw"):
			demand = float(node.call("get_power_demand_kw"))
		_append_network_device(result, seen, node, "CONSUMPTION", demand, "rated demand")
	return result


func set_device_network_enabled(device: Node, enabled: bool) -> bool:
	if not is_instance_valid(device) or not device.has_method("set_network_enabled"):
		return false
	device.call("set_network_enabled", enabled)
	# Some buildings update their registration deferred. An immediate rebuild makes
	# the new connection visible on the page already.
	rebuild_network()
	stats_changed.emit(get_stats())
	return true


func _append_network_device(result: Array[Dictionary], seen: Dictionary, device: Node, role: String, power_value_kw: float, detail: String) -> void:
	if not is_instance_valid(device):
		return
	var instance_key := device.get_instance_id()
	if seen.has(instance_key):
		return
	seen[instance_key] = true
	var enabled := _device_network_enabled(device)
	var connected := bool(connection_ok.get(device, false))
	var powered := false
	if device.get("powered") != null:
		powered = bool(device.get("powered"))
	var display_name := _network_device_display_name(device, role)
	var status := "DISCONNECTED"
	if enabled and not connected:
		status = "CABLE NOT CONNECTED"
	elif enabled and role == "GENERATION" and power_value_kw <= 0.01:
		status = "AWAITING LIGHT"
	elif enabled and powered:
		status = "OPERATIONAL"
	elif enabled and connected:
		status = "CONNECTED · AWAITING POWER"
	result.append({
		"node": device,
		"name": display_name,
		"role": role,
		"enabled": enabled,
		"connected": connected,
		"powered": powered,
		"status": status,
		"power_kw": maxf(0.0, power_value_kw),
		"detail": detail,
		"can_toggle": device.has_method("set_network_enabled") and device.has_method("is_network_enabled"),
	})


func _fallback_network_device_name(role: String) -> String:
	match role:
		"GENERATION":
			return "SOLAR PANEL"
		"CONVERSION":
			return "POWER TRANSFORMER"
		"STORAGE":
			return "STORAGE BATTERY"
		"CONSUMPTION":
			return "POWER CONSUMER"
	return "POWER DEVICE"


func _network_device_display_name(device: Node, role: String) -> String:
	var display_name := str(device.name).strip_edges().to_upper()
	if device.has_method("get_display_name"):
		display_name = str(device.call("get_display_name")).strip_edges().to_upper()
	if _is_technical_node_name(display_name):
		# Object.get() returns null when a generic Node2D does not expose device_id.
		# Converting it to a string would produce "<null>" and prevent the card's
		# descriptive fallback.
		var raw_device_id: Variant = device.get("device_id")
		var device_id := str(raw_device_id).strip_edges() if raw_device_id is String or raw_device_id is StringName else ""
		if not device_id.is_empty():
			display_name = _display_name(device_id).to_upper()
	if _is_technical_node_name(display_name):
		return _fallback_network_device_name(role)
	return display_name


func _is_technical_node_name(value: String) -> bool:
	var normalized := value.strip_edges().to_upper()
	return normalized.is_empty() or normalized in ["NODE", "NODE2D", "OBJECT"] or normalized.begins_with("@") or normalized.begins_with("NODE@") or normalized.begins_with("NODE2D@") or normalized.begins_with("_NODE2D_") or normalized.begins_with("NODE2D_")


func _update_energy(delta: float) -> void:
	var solar_factor := WorldClock.get_solar_factor()
	production_kw = 0.0
	demand_kw = 0.0
	var energy_step := WorldClock.get_game_hours_for_real_delta(delta)
	var battery_flows: Dictionary = {}
	var powered_grid_count := 0
	var status_by_grid: Array[String] = []
	var stable_grid_ready := false
	for grid_key_variant in _grids_by_transformer.keys():
		# Keys are transformer integer instance IDs. Type them explicitly to avoid
		# the ambiguous inference reported by the Godot parser.
		var grid_key: int = int(grid_key_variant)
		var grid: Dictionary = _grids_by_transformer[grid_key]
		var current_transformer := grid.get("transformer") as PowerDevice
		if current_transformer == null or not is_instance_valid(current_transformer):
			continue
		var grid_panels := _power_devices_from(grid.get("panels", []) as Array)
		var grid_batteries := _power_devices_from(grid.get("batteries", []) as Array)
		var grid_consumers: Array = grid.get("consumers", []) as Array
		var chain_ready := bool(grid.get("chain_ready", false)) and bool(connection_ok.get(current_transformer, false))
		var grid_production := _panel_output_multiplier(grid_panels) * PANEL_OUTPUT_KW * solar_factor if chain_ready else 0.0
		var grid_demand := 0.0
		for node_variant in grid_consumers:
			var node := node_variant as Node
			if is_instance_valid(node) and bool(connection_ok.get(node, false)):
				grid_demand += _consumer_demand_kw(node)
		production_kw += grid_production
		demand_kw += grid_demand
		var grid_powered := false
		var grid_status := "GRID INCOMPLETE"
		if not chain_ready:
			grid_status = "GRID DISCONNECTED" if not _device_network_enabled(current_transformer) else "GRID INCOMPLETE"
		elif grid_production >= grid_demand:
			grid_powered = true
			var surplus := grid_production - grid_demand
			var charged := _charge_batteries(grid_batteries, surplus * energy_step, battery_flows)
			if charged > 0.0001:
				grid_status = "CHARGING"
			elif grid_batteries.is_empty():
				grid_status = "DIRECT GRID"
			else:
				grid_status = "GRID ACTIVE"
		else:
			var deficit_energy := (grid_demand - grid_production) * energy_step
			var available_energy := _get_battery_energy(grid_batteries)
			if available_energy + 0.0001 >= deficit_energy:
				grid_powered = true
				_discharge_batteries(grid_batteries, deficit_energy, battery_flows)
				grid_status = "BATTERY"
			else:
				# Every grid discharges only its own batteries, keeping two distant bases
				# genuinely independent even during the night.
				_discharge_batteries(grid_batteries, available_energy, battery_flows)
				grid_status = "BLACKOUT"
		if grid_powered:
			powered_grid_count += 1
		if grid_powered and not grid_batteries.is_empty() and not grid_panels.is_empty():
			stable_grid_ready = true
		status_by_grid.append(grid_status)
		grid["production_kw"] = grid_production
		grid["demand_kw"] = grid_demand
		grid["powered"] = grid_powered
		grid["status"] = grid_status
		_grids_by_transformer[grid_key] = grid

	network_powered = powered_grid_count > 0
	if _grids_by_transformer.is_empty():
		network_status = "GRID DISCONNECTED" if has_transformer() else "GRID INCOMPLETE"
	elif _grids_by_transformer.size() == 1:
		network_status = status_by_grid.front() if not status_by_grid.is_empty() else "GRID INCOMPLETE"
	elif powered_grid_count == _grids_by_transformer.size():
		network_status = "INDEPENDENT GRIDS ACTIVE"
	elif powered_grid_count > 0:
		network_status = "INDEPENDENT GRIDS · %d/%d ACTIVE" % [powered_grid_count, _grids_by_transformer.size()]
	else:
		network_status = "INDEPENDENT GRIDS INCOMPLETE"
	for panel in panels:
		panel.set_power_state(connection_ok.get(panel, false) and solar_factor > 0.001, 0)
	for current_transformer in transformers:
		var transformer_grid := _grid_for_transformer(current_transformer)
		var transformer_production := float(transformer_grid.get("production_kw", 0.0))
		var transformer_demand := float(transformer_grid.get("demand_kw", 0.0))
		current_transformer.set_power_state(bool(connection_ok.get(current_transformer, false)) and transformer_production > 0.001, 1 if transformer_production > transformer_demand else 0)
	for battery in batteries:
		var connected := bool(connection_ok.get(battery, false))
		battery.set_power_state(connected, int(battery_flows.get(battery, 0)) if connected else 0)
	for consumer in consumers:
		var node: Node = consumer.get("node")
		var current_transformer := _transformer_for_device.get(node) as PowerDevice
		var grid := _grid_for_transformer(current_transformer) if current_transformer != null else {}
		var powered: bool = bool(grid.get("powered", false)) and bool(connection_ok.get(node, false))
		if is_instance_valid(node) and node.has_method("set_powered"):
			node.set_powered(powered)
	if stable_grid_ready:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			achievements.call("record", "stable_grid")


func _power_devices_from(values: Array) -> Array[PowerDevice]:
	var result: Array[PowerDevice] = []
	for value in values:
		var device := value as PowerDevice
		if device != null and is_instance_valid(device):
			result.append(device)
	return result


func _panel_output_multiplier(grid_panels: Array[PowerDevice]) -> float:
	var total := 0.0
	for panel in grid_panels:
		if not bool(connection_ok.get(panel, false)):
			continue
		total += float(panel.call("get_solar_output_multiplier")) if panel.has_method("get_solar_output_multiplier") else 1.0
	return total


func _consumer_demand_kw(node: Node) -> float:
	if node != null and is_instance_valid(node) and node.has_method("get_power_demand_kw"):
		return maxf(0.0, float(node.call("get_power_demand_kw")))
	for consumer in consumers:
		if consumer.get("node") == node:
			return maxf(0.0, float(consumer.get("demand_kw", 0.0)))
	return 0.0


func _get_battery_autonomy_hours() -> float:
	var deficit_kw := demand_kw - production_kw
	if deficit_kw <= 0.001:
		return -1.0
	return _get_connected_battery_energy() / deficit_kw


func _charge_batteries(targets: Array[PowerDevice], energy_kwh: float, flows: Dictionary) -> float:
	var remaining := maxf(0.0, energy_kwh)
	var transferred := 0.0
	var active: Array[PowerDevice] = targets.duplicate()
	while remaining > 0.0001 and not active.is_empty():
		var share := remaining / active.size()
		var next_active: Array[PowerDevice] = []
		var round_transfer := 0.0
		for battery in active:
			var room := battery.get_battery_available_capacity_kwh()
			var amount := minf(room, share)
			if amount > 0.0001:
				battery.set_battery_energy_kwh(battery.get_battery_energy_kwh() + amount)
				flows[battery] = 1
				remaining -= amount
				transferred += amount
				round_transfer += amount
			if room - amount > 0.0001:
				next_active.append(battery)
		if round_transfer <= 0.0001:
			break
		active = next_active
	return transferred


func _discharge_batteries(targets: Array[PowerDevice], energy_kwh: float, flows: Dictionary) -> float:
	var remaining := maxf(0.0, energy_kwh)
	var transferred := 0.0
	var active: Array[PowerDevice] = targets.duplicate()
	while remaining > 0.0001 and not active.is_empty():
		var share := remaining / active.size()
		var next_active: Array[PowerDevice] = []
		var round_transfer := 0.0
		for battery in active:
			var available := battery.get_battery_energy_kwh()
			var amount := minf(available, share)
			if amount > 0.0001:
				battery.set_battery_energy_kwh(available - amount)
				flows[battery] = -1
				remaining -= amount
				transferred += amount
				round_transfer += amount
			if available - amount > 0.0001:
				next_active.append(battery)
		if round_transfer <= 0.0001:
			break
		active = next_active
	return transferred


func _get_battery_energy(targets: Array[PowerDevice]) -> float:
	var total := 0.0
	for battery in targets:
		if is_instance_valid(battery):
			total += battery.get_battery_energy_kwh()
	return total


func _get_total_battery_energy() -> float:
	return _get_battery_energy(batteries)


func _get_connected_battery_energy() -> float:
	return _get_battery_energy(_connected_batteries())


func _set_total_battery_energy(value: float) -> void:
	# Compatibility with previous saves and tests: when a total is set, distribute
	# it among real batteries without exceeding their capacity. Gameplay never uses
	# this property for flow, which remains strictly per-device.
	var remaining := clampf(value, 0.0, get_battery_capacity())
	for battery in batteries:
		var assigned := minf(remaining, BATTERY_CAPACITY_KWH)
		battery.set_battery_energy_kwh(assigned)
		remaining -= assigned


func _find_path(start: Vector2i, goal: Vector2i, network_id: String) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var blocked := _get_blocked_cells(true)
	# A cable happily reuses cells from its own current. Other sections are not
	# physical obstacles: a crossing preserves distinct network IDs and therefore
	# cannot merge two grids by mistake.
	var foreign_cable_cells: Dictionary = {}
	for other_network_id_variant in cable_cells_by_network.keys():
		var other_network_id := str(other_network_id_variant)
		if other_network_id == network_id:
			continue
		var other_cells: Dictionary = cable_cells_by_network.get(other_network_id, {})
		for other_cell in other_cells.keys():
			foreign_cable_cells[other_cell] = true
	blocked.erase(start)
	blocked.erase(goal)
	var own_cells: Dictionary = cable_cells_by_network.get(network_id, {})
	# There is no longer an artificial maximum radius around two devices. A path
	# can cross the whole map; physical map limits nevertheless bound the search.
	var min_x := mini(start.x, goal.x) - PATH_CORRIDOR_PADDING
	var max_x := maxi(start.x, goal.x) + PATH_CORRIDOR_PADDING
	var min_y := mini(start.y, goal.y) - PATH_CORRIDOR_PADDING
	var max_y := maxi(start.y, goal.y) + PATH_CORRIDOR_PADDING
	var map_provider := get_tree().get_first_node_in_group("world_map_provider")
	if map_provider != null and map_provider.has_method("get_world_rect"):
		var world_rect_variant = map_provider.call("get_world_rect")
		if world_rect_variant is Rect2i:
			var world_rect: Rect2i = world_rect_variant
			min_x = maxi(min_x, world_rect.position.x)
			max_x = mini(max_x, world_rect.end.x - 1)
			min_y = maxi(min_y, world_rect.position.y)
			max_y = mini(max_y, world_rect.end.y - 1)
	# State also includes arrival direction. Two paths on the same cell with a
	# different orientation are not equivalent: a turn has a real cost and is
	# avoided when unnecessary.
	var start_state := Vector3i(start.x, start.y, PATH_START_DIRECTION)
	var open_heap: Array[Dictionary] = []
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_state: 0.0}
	var turn_count: Dictionary = {start_state: 0}
	_path_heap_push(open_heap, start_state, _manhattan(start, goal) * PATH_HEURISTIC_SCALE, 0, 0.0)
	var expanded_states := 0
	while not open_heap.is_empty():
		var queue_entry := _path_heap_pop(open_heap)
		var current_state := Vector3i(queue_entry.get("state", start_state))
		var queued_cost := float(queue_entry.get("cost", INF))
		if queued_cost > float(g_score.get(current_state, INF)) + 0.0001 or closed.has(current_state):
			continue
		expanded_states += 1
		if expanded_states > PATH_SEARCH_BUDGET:
			# A completely closed grid must not turn rebuilding into a game freeze. The
			# caller receives a routing error instead.
			return []
		var current := Vector2i(current_state.x, current_state.y)
		if current == goal:
			return _reconstruct_directed_path(came_from, current_state)
		closed[current_state] = true
		for direction_index in DIRECTIONS.size():
			var direction := DIRECTIONS[direction_index]
			var neighbor := current + direction
			if neighbor.x < min_x or neighbor.x > max_x or neighbor.y < min_y or neighbor.y > max_y:
				continue
			var neighbor_state := Vector3i(neighbor.x, neighbor.y, direction_index)
			if blocked.has(neighbor) or closed.has(neighbor_state):
				continue
			# Reuse remains advantageous, but not enough to justify serpentine routes
			# much longer than the direct connection.
			var step_cost := PATH_EXISTING_CELL_COST if own_cells.has(neighbor) else PATH_NEW_CELL_COST
			if foreign_cable_cells.has(neighbor):
				step_cost += PATH_FOREIGN_CABLE_CROSSING_COST
			var is_turn := current_state.z != PATH_START_DIRECTION and current_state.z != direction_index
			if is_turn:
				step_cost += PATH_TURN_COST
			if neighbor != goal and not own_cells.has(neighbor):
				step_cost += _parallel_network_penalty(current, neighbor, direction, own_cells)
			var tentative := float(g_score.get(current_state, INF)) + step_cost
			var candidate_turns := int(turn_count.get(current_state, 0)) + (1 if is_turn else 0)
			var known_cost := float(g_score.get(neighbor_state, INF))
			var known_turns := int(turn_count.get(neighbor_state, 1_000_000))
			if tentative > known_cost + 0.0001 or (is_equal_approx(tentative, known_cost) and candidate_turns >= known_turns):
				continue
			came_from[neighbor_state] = current_state
			g_score[neighbor_state] = tentative
			turn_count[neighbor_state] = candidate_turns
			var priority := tentative + _manhattan(neighbor, goal) * PATH_HEURISTIC_SCALE
			_path_heap_push(open_heap, neighbor_state, priority, candidate_turns, tentative)
	return []


func _path_heap_push(heap: Array[Dictionary], state: Vector3i, priority: float, turns: int, cost: float) -> void:
	heap.append({"state": state, "priority": priority, "turns": turns, "cost": cost})
	var index := heap.size() - 1
	while index > 0:
		var parent_index := (index - 1) / 2
		if not _path_queue_entry_is_before(heap[index], heap[parent_index]):
			break
		var swap_entry := heap[index]
		heap[index] = heap[parent_index]
		heap[parent_index] = swap_entry
		index = parent_index


func _path_heap_pop(heap: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = heap.front()
	var tail: Dictionary = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = tail
	var index := 0
	while true:
		var left_index := index * 2 + 1
		var right_index := left_index + 1
		var candidate_index := index
		if left_index < heap.size() and _path_queue_entry_is_before(heap[left_index], heap[candidate_index]):
			candidate_index = left_index
		if right_index < heap.size() and _path_queue_entry_is_before(heap[right_index], heap[candidate_index]):
			candidate_index = right_index
		if candidate_index == index:
			break
		var swap_entry := heap[index]
		heap[index] = heap[candidate_index]
		heap[candidate_index] = swap_entry
		index = candidate_index
	return result


func _path_queue_entry_is_before(first: Dictionary, second: Dictionary) -> bool:
	var first_priority := float(first.get("priority", INF))
	var second_priority := float(second.get("priority", INF))
	if first_priority < second_priority - 0.0001:
		return true
	if first_priority > second_priority + 0.0001:
		return false
	return int(first.get("turns", 0)) < int(second.get("turns", 0))


func _report_routing_failures(failed_nodes: Array) -> void:
	var current_keys: Dictionary = {}
	for node_variant in failed_nodes:
		var device := node_variant as Node
		if device == null or not is_instance_valid(device):
			continue
		var key := str(device.get_instance_id())
		current_keys[key] = true
		if _routing_failure_keys.has(key):
			continue
		var device_name := _network_device_name(device)
		var message := "POWER GRID ERROR\n%s: path impossible or blocked. Move the machine to a better position." % device_name
		routing_failed.emit(device, message)
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null and incidents.has_method("show_notification"):
			incidents.call("show_notification", message)
	_routing_failure_keys = current_keys


func _network_device_name(device: Node) -> String:
	return _network_device_display_name(device, "")


func _reconstruct_directed_path(came_from: Dictionary, current_state: Vector3i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i(current_state.x, current_state.y)]
	while came_from.has(current_state):
		current_state = Vector3i(came_from[current_state])
		var cell := Vector2i(current_state.x, current_state.y)
		if result.front() != cell:
			result.push_front(cell)
	return result


func _parallel_network_penalty(current: Vector2i, neighbor: Vector2i, direction: Vector2i, own_cells: Dictionary) -> float:
	# Avoid two long parallel lines one cell apart. The final segment that actually
	# enters the grid is not penalized.
	var perpendiculars: Array[Vector2i]
	if direction.x != 0:
		perpendiculars = [Vector2i.UP, Vector2i.DOWN]
	else:
		perpendiculars = [Vector2i.LEFT, Vector2i.RIGHT]
	for perpendicular in perpendiculars:
		if own_cells.has(neighbor + perpendicular) and not own_cells.has(current + perpendicular):
			continue
		if own_cells.has(neighbor + perpendicular):
			return PATH_PARALLEL_COST
	return 0.0


func _add_path(path: Array[Vector2i], start_attachment: Vector2i, end_attachment: Vector2i, network_id: String) -> void:
	var network_cells: Dictionary = cable_cells_by_network.get(network_id, {})
	for cell in path:
		network_cells[cell] = true
	cable_cells_by_network[network_id] = network_cells
	_add_attachment(path.front(), start_attachment, network_id)
	_add_attachment(path.back(), end_attachment, network_id)


func _add_attachment(cell: Vector2i, direction: Vector2i, network_id: String) -> void:
	var network_attachments: Dictionary = cable_attachments_by_network.get(network_id, {})
	var directions: Array = network_attachments.get(cell, [])
	if direction not in directions:
		directions.append(direction)
	network_attachments[cell] = directions
	cable_attachments_by_network[network_id] = network_attachments


func _finalize_network_visuals() -> void:
	for network_id_variant in cable_cells_by_network.keys():
		var network_id := str(network_id_variant)
		var network_cells: Dictionary = cable_cells_by_network.get(network_id, {})
		var network_attachments: Dictionary = cable_attachments_by_network.get(network_id, {})
		for cell_variant in network_cells.keys():
			var cell := Vector2i(cell_variant)
			var openings: Array[Vector2i] = []
			for direction in DIRECTIONS:
				if network_cells.has(cell + direction):
					openings.append(direction)
			for attachment in network_attachments.get(cell, []):
				var typed_attachment := Vector2i(attachment)
				if typed_attachment not in openings:
					openings.append(typed_attachment)
			var cable := CABLE_SEGMENT_SCRIPT.new() as CableSegment
			cable.setup(cell, openings)
			cable.position = cell_to_world(cell)
			var cable_key := network_id + ":" + str(cell.x) + ":" + str(cell.y)
			_pending_cable_visuals.append(cable)
			call_deferred("_attach_cable_visual", cable, cable_key, _cable_visual_generation)
	network_changed.emit()
	stats_changed.emit(get_stats())


func _attach_cable_visual(cable: CableSegment, cable_key: String, generation: int) -> void:
	_pending_cable_visuals.erase(cable)
	if generation != _cable_visual_generation or not is_instance_valid(cable) or cable.is_queued_for_deletion():
		return
	var scene := get_tree().current_scene
	if scene == null:
		cable.queue_free()
		return
	# This callback is deferred relative to grid rebuilding. SceneTree has unlocked
	# the parent, so insertion does not compete with child setup.
	scene.add_child(cable)
	cables[cable_key] = cable


func _clear_cables() -> void:
	_cable_visual_generation += 1
	for cable in cables.values():
		if is_instance_valid(cable):
			cable.queue_free()
	for cable in _pending_cable_visuals:
		if is_instance_valid(cable):
			cable.queue_free()
	_pending_cable_visuals.clear()
	cables.clear()
	cable_cells_by_network.clear()
	cable_attachments_by_network.clear()


func _get_blocked_cells(block_dome_interiors: bool = false) -> Dictionary:
	var blocked: Dictionary = {}
	# A device cannot appear beneath the astronaut. This applies only to placement:
	# a cable may pass beneath the player and must keep working when they stop near
	# a battery.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and not block_dome_interiors:
		var player_min := Vector2i(floori((player.global_position.x - 12.0) / CELL_SIZE), floori((player.global_position.y - 12.0) / CELL_SIZE))
		var player_max := Vector2i(floori((player.global_position.x + 12.0) / CELL_SIZE), floori((player.global_position.y + 12.0) / CELL_SIZE))
		for y in range(player_min.y, player_max.y + 1):
			for x in range(player_min.x, player_max.x + 1):
				blocked[Vector2i(x, y)] = true
	for panel in panels:
		for cell in panel.get_occupied_power_cells():
			blocked[cell] = true
	for current_transformer in transformers:
		if is_instance_valid(current_transformer):
			for cell in current_transformer.get_occupied_power_cells():
				blocked[cell] = true
	for battery in batteries:
		for cell in battery.get_occupied_power_cells():
			blocked[cell] = true
	for rock in get_tree().get_nodes_in_group("collectible_rocks"):
		if not rock is Node2D:
			continue
		var rock_position: Vector2 = rock.global_position
		var min_cell := Vector2i(floori((rock_position.x - 14.0) / CELL_SIZE), floori((rock_position.y - 14.0) / CELL_SIZE))
		var max_cell := Vector2i(floori((rock_position.x + 14.0) / CELL_SIZE), floori((rock_position.y + 14.0) / CELL_SIZE))
		for y in range(min_cell.y, max_cell.y + 1):
			for x in range(min_cell.x, max_cell.x + 1):
				blocked[Vector2i(x, y)] = true
	for entry in BuildableRegistry.get_entries():
		if entry.get("kind", "") in ["pipe", "power_device"]:
			continue
		var node: Node = entry.get("node")
		# For placement, interior dome modules remain usable. Cables, however, cannot
		# cross a dome: the route is calculated with block_dome_interiors=true.
		if is_instance_valid(node) and node.is_in_group("base_domes") and not node.is_in_group("greenhouses"):
			if not block_dome_interiors:
				continue
		if is_instance_valid(node) and node.has_method("get_occupied_power_cells"):
			for cell in node.get_occupied_power_cells():
				blocked[cell] = true
	return blocked


func _footprint_for(item_id: String, cell: Vector2i, placement_rotation: int = 0) -> Array[Vector2i]:
	return PowerDevice.footprint_cells_for(item_id, cell, placement_rotation)


func _closest_connected_battery(target: Vector2i) -> PowerDevice:
	var closest: PowerDevice
	var best_distance := INF
	for battery in batteries:
		if not connection_ok.get(battery, false):
			continue
		var distance := _manhattan(battery.origin_cell, target)
		if distance < best_distance:
			best_distance = distance
			closest = battery
	return closest


func _connected_batteries() -> Array[PowerDevice]:
	var result: Array[PowerDevice] = []
	for battery in batteries:
		if connection_ok.get(battery, false):
			result.append(battery)
	return result


func _connected_panel_count() -> int:
	var total := 0
	for panel in panels:
		if connection_ok.get(panel, false):
			total += 1
	return total


func _connected_panel_output_multiplier() -> float:
	var total := 0.0
	for panel in panels:
		if not connection_ok.get(panel, false):
			continue
		if panel.has_method("get_solar_output_multiplier"):
			total += float(panel.call("get_solar_output_multiplier"))
		else:
			total += 1.0
	return total


func _device_network_enabled(device: Node) -> bool:
	if not is_instance_valid(device):
		return false
	# A fault interrupts the physical node without changing the player-selected
	# connection. After repair, the grid rebuilds and resumes.
	if device.has_method("is_incident_operational") and not bool(device.call("is_incident_operational")):
		return false
	if device.has_method("is_network_enabled"):
		return bool(device.call("is_network_enabled"))
	# Keep any non-interactive service consumers compatible.
	return true


func _cleanup_invalid() -> void:
	for index in range(panels.size() - 1, -1, -1):
		if not is_instance_valid(panels[index]):
			panels.remove_at(index)
	for index in range(batteries.size() - 1, -1, -1):
		if not is_instance_valid(batteries[index]):
			batteries.remove_at(index)
	for index in range(consumers.size() - 1, -1, -1):
		if not is_instance_valid(consumers[index].get("node")):
			consumers.remove_at(index)
	for index in range(transformers.size() - 1, -1, -1):
		if not is_instance_valid(transformers[index]):
			transformers.remove_at(index)
	_refresh_primary_transformer()


func _manhattan(first: Vector2i, second: Vector2i) -> float:
	return float(absi(first.x - second.x) + absi(first.y - second.y))


func _display_name(item_id: String) -> String:
	match item_id:
		"solar_panel":
			return "SOLAR PANEL"
		"transformer":
			return "TRANSFORMER"
		"battery":
			return "BATTERY"
		"ice_drill":
			return "ICE DRILL"
		"rock_drill":
			return "MINERAL DRILL"
	return "POWER DEVICE"


func _refresh_primary_transformer() -> void:
	transformer = transformers.front() if not transformers.is_empty() else null


func reset_for_new_mission() -> void:
	_clear_cables()
	panels.clear()
	batteries.clear()
	transformers.clear()
	transformer = null
	consumers.clear()
	connection_ok.clear()
	_grids_by_transformer.clear()
	_transformer_for_device.clear()
	production_kw = 0.0
	demand_kw = 0.0
	network_powered = false
	network_status = "GRID INCOMPLETE"
	_stats_timer = 0.0
	_routing_failure_keys.clear()
	network_changed.emit()
	stats_changed.emit(get_stats())
