extends Node

signal network_changed
signal stats_changed(data: Dictionary)

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
const NETWORK_IDS: Array[String] = [NETWORK_SOLAR, NETWORK_TRANSFORMED, NETWORK_BATTERY]
const PATH_NEW_CELL_COST := 1.0
const PATH_EXISTING_CELL_COST := 0.82
const PATH_TURN_COST := 0.42
const PATH_PARALLEL_COST := 0.28
const PATH_HEURISTIC_SCALE := 0.80
const PATH_START_DIRECTION := 4

var panels: Array[PowerDevice] = []
var batteries: Array[PowerDevice] = []
var transformer: PowerDevice
var consumers: Array[Dictionary] = []
var cables: Dictionary = {}
var _pending_cable_visuals: Array[CableSegment] = []
var _cable_visual_generation := 0
var cable_cells_by_network: Dictionary = {}
var cable_attachments_by_network: Dictionary = {}
var connection_ok: Dictionary = {}

## Riepilogo compatibile con HUD e test: l'energia reale appartiene a ogni
## singolo PowerDevice di tipo batteria, non piu' a questa rete globale.
var battery_energy_kwh: float:
	get:
		return _get_total_battery_energy()
	set(value):
		_set_total_battery_energy(value)
var production_kw := 0.0
var demand_kw := 0.0
var network_powered := false
var network_status := "RETE INCOMPLETA"
var _stats_timer := 0.0


func _process(delta: float) -> void:
	_update_energy(delta)
	_stats_timer += delta
	if _stats_timer >= 0.20:
		_stats_timer = 0.0
		stats_changed.emit(get_stats())


func has_transformer() -> bool:
	return is_instance_valid(transformer)


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
		# Il frame reale e' 32x32. L'asse dei cavi resta allineato
		# al centro della riga da 16px identificata da origin_cell.
		return Vector2(cell * CELL_SIZE) + Vector2(16.0, 8.0)
	return cell_to_world(cell)


func can_place_device(item_id: String, cell: Vector2i, placement_rotation: int = 0) -> bool:
	if item_id in ["electrolyzer", "sabatier"]:
		return can_place_process_machine(item_id, cell, placement_rotation)
	if item_id not in ["solar_panel", "transformer", "battery", "ice_drill", "rock_drill"]:
		return false
	if item_id == "transformer" and has_transformer():
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
	if not Inventory.add_item("rock_drill", "Trivella mineraria", 1, true):
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
	if device.device_id == "ice_drill":
		unregister_consumer(device)
		PipeManager.unregister_fluid_source(device)
	if transformer == device:
		transformer = null
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
	if not has_transformer() or not _device_network_enabled(transformer):
		_finalize_network_visuals()
		return

	# Le tre sezioni non condividono celle: prima della trasformazione,
	# dopo il trasformatore e dopo la batteria sono reti elettriche distinte.
	var transformer_input := transformer.get_power_input_cell()
	for panel in panels:
		if not _device_network_enabled(panel):
			connection_ok[panel] = false
			continue
		var panel_output := panel.get_power_output_cell()
		var path := _find_path(panel_output, transformer_input, NETWORK_SOLAR)
		var connected := not path.is_empty()
		connection_ok[panel] = connected
		if connected:
			_add_path(path, panel.get_power_output_attach_direction(), transformer.get_power_input_attach_direction(), NETWORK_SOLAR)

	var transformer_output := transformer.get_power_output_cell()
	for battery in batteries:
		if not _device_network_enabled(battery):
			connection_ok[battery] = false
			continue
		var battery_input := battery.get_power_input_cell()
		var path := _find_path(transformer_output, battery_input, NETWORK_TRANSFORMED)
		var connected := not path.is_empty()
		connection_ok[battery] = connected
		if connected:
			_add_path(path, transformer.get_power_output_attach_direction(), battery.get_power_input_attach_direction(), NETWORK_TRANSFORMED)

	var connected_batteries := _connected_batteries()
	var use_battery_bus := not connected_batteries.is_empty()
	var has_connected_consumer := false
	for consumer in consumers:
		var node: Node2D = consumer.get("node") as Node2D
		if not _device_network_enabled(node):
			connection_ok[node] = false
			continue
		var consumer_cell := Vector2i(consumer["connection_cell"])
		var supply_cell := transformer_output
		var supply_network := NETWORK_TRANSFORMED
		var supply_attach := transformer.get_power_output_attach_direction()
		if use_battery_bus:
			var closest := _closest_connected_battery(consumer_cell)
			if closest == null:
				connection_ok[node] = false
				continue
			supply_cell = closest.get_power_output_cell()
			supply_network = NETWORK_BATTERY
			supply_attach = closest.get_power_output_attach_direction()
		var path := _find_path(supply_cell, consumer_cell, supply_network)
		var connected := not path.is_empty()
		connection_ok[node] = connected
		if connected:
			has_connected_consumer = true
			_add_path(path, supply_attach, Vector2i(consumer["attach_direction"]), supply_network)

	# Con una batteria collegata, l'uscita alimenta il bus di accumulo.
	# Senza batterie, i macchinari vengono collegati direttamente all'uscita
	# trasformata e dipendono dalla produzione solare istantanea.
	var has_downstream := use_battery_bus or has_connected_consumer
	connection_ok[transformer] = _connected_panel_count() > 0 and has_downstream
	_finalize_network_visuals()


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
	## Modello unico per la pagina di distribuzione: ogni sorgente, accumulo e
	## carico resta selezionabile singolarmente, senza dover cercare lo sprite
	## sulla mappa. Il nodo reale è mantenuto nel record per il pulsante manuale.
	_cleanup_invalid()
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for panel in panels:
		_append_network_device(result, seen, panel, "GENERAZIONE", PANEL_OUTPUT_KW * WorldClock.get_solar_factor(), "produzione disponibile")
	if is_instance_valid(transformer):
		_append_network_device(result, seen, transformer, "CONVERSIONE", 0.0, "ponte tra le sezioni della rete")
	for battery in batteries:
		var stored := battery.get_battery_energy_kwh()
		_append_network_device(result, seen, battery, "ACCUMULO", stored, "%.0f / %.0f kWh" % [stored, BATTERY_CAPACITY_KWH])
	for consumer in consumers:
		var node := consumer.get("node") as Node
		var demand := float(consumer.get("demand_kw", 0.0))
		if is_instance_valid(node) and node.has_method("get_power_demand_kw"):
			demand = float(node.call("get_power_demand_kw"))
		_append_network_device(result, seen, node, "CONSUMO", demand, "richiesta nominale")
	return result


func set_device_network_enabled(device: Node, enabled: bool) -> bool:
	if not is_instance_valid(device) or not device.has_method("set_network_enabled"):
		return false
	device.call("set_network_enabled", enabled)
	# Alcuni edifici aggiornano la propria registrazione in differita; il rebuild
	# immediato rende già visibile il nuovo collegamento nella pagina.
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
	var display_name := str(device.name).to_upper()
	if device.has_method("get_display_name"):
		display_name = str(device.call("get_display_name")).to_upper()
	var status := "DISCONNESSO"
	if enabled and not connected:
		status = "CAVO NON COLLEGATO"
	elif enabled and role == "GENERAZIONE" and power_value_kw <= 0.01:
		status = "IN ATTESA DI LUCE"
	elif enabled and powered:
		status = "OPERATIVO"
	elif enabled and connected:
		status = "COLLEGATO · IN ATTESA"
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


func _update_energy(delta: float) -> void:
	var connected_batteries := _connected_batteries()
	var chain_ready := has_transformer() and bool(connection_ok.get(transformer, false))
	var solar_factor := WorldClock.get_solar_factor()
	production_kw = _connected_panel_count() * PANEL_OUTPUT_KW * solar_factor if chain_ready else 0.0
	demand_kw = 0.0
	for consumer in consumers:
		var node: Node = consumer.get("node")
		if is_instance_valid(node) and connection_ok.get(node, false):
			demand_kw += float(consumer.get("demand_kw", 0.0))
	var energy_step := WorldClock.get_game_hours_for_real_delta(delta)
	var battery_flows: Dictionary = {}
	if not chain_ready:
		network_powered = false
		network_status = "RETE DISCONNESSA" if has_transformer() and not _device_network_enabled(transformer) else "RETE INCOMPLETA"
	elif production_kw >= demand_kw:
		network_powered = true
		var surplus := production_kw - demand_kw
		var charged := _charge_batteries(connected_batteries, surplus * energy_step, battery_flows)
		if charged > 0.0001:
			network_status = "IN CARICA"
		elif connected_batteries.is_empty():
			network_status = "RETE DIRETTA"
		else:
			network_status = "RETE ATTIVA"
	else:
		var deficit_energy := (demand_kw - production_kw) * energy_step
		var available_energy := _get_battery_energy(connected_batteries)
		if available_energy + 0.0001 >= deficit_energy:
			network_powered = true
			_discharge_batteries(connected_batteries, deficit_energy, battery_flows)
			network_status = "BATTERIA"
		else:
			# Le batterie collegate cedono l'energia residua; quelle isolate
			# restano completamente immutate.
			_discharge_batteries(connected_batteries, available_energy, battery_flows)
			network_powered = false
			network_status = "BLACKOUT"
	for panel in panels:
		panel.set_power_state(connection_ok.get(panel, false) and solar_factor > 0.001, 0)
	if is_instance_valid(transformer):
		transformer.set_power_state(chain_ready and production_kw > 0.001, 1 if production_kw > demand_kw else 0)
	for battery in batteries:
		var connected := bool(connection_ok.get(battery, false))
		battery.set_power_state(connected, int(battery_flows.get(battery, 0)) if connected else 0)
	for consumer in consumers:
		var node: Node = consumer.get("node")
		var powered: bool = network_powered and bool(connection_ok.get(node, false))
		if is_instance_valid(node) and node.has_method("set_powered"):
			node.set_powered(powered)
	if network_powered and _connected_panel_count() > 0 and not connected_batteries.is_empty() and has_transformer():
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			achievements.call("record", "stable_grid")


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
	# Compatibilita' con salvataggi/test precedenti: quando viene impostato
	# un totale, lo distribuiamo nelle batterie reali senza superarne la
	# capacita'. Durante il gioco questa proprieta' non viene usata per i
	# flussi, che rimangono rigorosamente per-dispositivo.
	var remaining := clampf(value, 0.0, get_battery_capacity())
	for battery in batteries:
		var assigned := minf(remaining, BATTERY_CAPACITY_KWH)
		battery.set_battery_energy_kwh(assigned)
		remaining -= assigned


func _find_path(start: Vector2i, goal: Vector2i, network_id: String) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var blocked := _get_blocked_cells()
	# Un cavo puo' riutilizzare soltanto celle della propria corrente.
	# Le celle appartenenti alle altre sezioni sono ostacoli, cosi' due
	# correnti diverse non diventano mai una singola giunzione grafica/logica.
	for other_network_id in NETWORK_IDS:
		if other_network_id == network_id:
			continue
		var other_cells: Dictionary = cable_cells_by_network.get(other_network_id, {})
		for other_cell in other_cells.keys():
			blocked[other_cell] = true
	blocked.erase(start)
	blocked.erase(goal)
	var own_cells: Dictionary = cable_cells_by_network.get(network_id, {})
	var margin := 24
	var min_x := mini(start.x, goal.x) - margin
	var max_x := maxi(start.x, goal.x) + margin
	var min_y := mini(start.y, goal.y) - margin
	var max_y := maxi(start.y, goal.y) + margin
	# Lo stato include anche la direzione di arrivo. In questo modo due
	# percorsi sulla stessa cella ma con orientamento diverso non sono
	# equivalenti: una curva ha un costo reale e viene evitata se inutile.
	var start_state := Vector3i(start.x, start.y, PATH_START_DIRECTION)
	var open: Array[Vector3i] = [start_state]
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_state: 0.0}
	var turn_count: Dictionary = {start_state: 0}
	while not open.is_empty():
		var best_index := 0
		var best_score := INF
		var best_turns := 1_000_000
		for index in open.size():
			var candidate_state := open[index]
			var candidate_cell := Vector2i(candidate_state.x, candidate_state.y)
			var score := float(g_score.get(candidate_state, INF)) + _manhattan(candidate_cell, goal) * PATH_HEURISTIC_SCALE
			var candidate_turns := int(turn_count.get(candidate_state, 0))
			if score < best_score - 0.0001 or (is_equal_approx(score, best_score) and candidate_turns < best_turns):
				best_score = score
				best_turns = candidate_turns
				best_index = index
		var current_state: Vector3i = open[best_index]
		open.remove_at(best_index)
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
			# Il riuso resta vantaggioso, ma non abbastanza da giustificare
			# serpentine molto piu' lunghe del collegamento diretto.
			var step_cost := PATH_EXISTING_CELL_COST if own_cells.has(neighbor) else PATH_NEW_CELL_COST
			var is_turn := current_state.z != PATH_START_DIRECTION and current_state.z != direction_index
			if is_turn:
				step_cost += PATH_TURN_COST
			if neighbor != goal and not own_cells.has(neighbor):
				step_cost += _parallel_network_penalty(current, neighbor, direction, own_cells)
			var tentative := float(g_score.get(current_state, INF)) + step_cost
			if tentative >= float(g_score.get(neighbor_state, INF)) - 0.0001:
				continue
			came_from[neighbor_state] = current_state
			g_score[neighbor_state] = tentative
			turn_count[neighbor_state] = int(turn_count.get(current_state, 0)) + (1 if is_turn else 0)
			if neighbor_state not in open:
				open.append(neighbor_state)
	return []


func _reconstruct_directed_path(came_from: Dictionary, current_state: Vector3i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i(current_state.x, current_state.y)]
	while came_from.has(current_state):
		current_state = Vector3i(came_from[current_state])
		var cell := Vector2i(current_state.x, current_state.y)
		if result.front() != cell:
			result.push_front(cell)
	return result


func _parallel_network_penalty(current: Vector2i, neighbor: Vector2i, direction: Vector2i, own_cells: Dictionary) -> float:
	# Evita due linee lunghe e parallele a una sola cella di distanza.
	# Il tratto finale che entra davvero nella rete non viene penalizzato.
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
	for network_id in NETWORK_IDS:
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
	# Questo callback e' differito rispetto al rebuild della rete: il SceneTree
	# ha sbloccato il parent e l'aggiunta non compete con setup dei suoi figli.
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
	for network_id in NETWORK_IDS:
		cable_cells_by_network[network_id] = {}
		cable_attachments_by_network[network_id] = {}


func _get_blocked_cells() -> Dictionary:
	var blocked: Dictionary = {}
	# Un dispositivo non può comparire sotto l'astronauta. Riserviamo il suo
	# collider completo, non soltanto la cella centrale del click.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var player_min := Vector2i(floori((player.global_position.x - 12.0) / CELL_SIZE), floori((player.global_position.y - 12.0) / CELL_SIZE))
		var player_max := Vector2i(floori((player.global_position.x + 12.0) / CELL_SIZE), floori((player.global_position.y + 12.0) / CELL_SIZE))
		for y in range(player_min.y, player_max.y + 1):
			for x in range(player_min.x, player_max.x + 1):
				blocked[Vector2i(x, y)] = true
	for panel in panels:
		for cell in panel.get_occupied_power_cells():
			blocked[cell] = true
	if is_instance_valid(transformer):
		for cell in transformer.get_occupied_power_cells():
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
		# Le cupole abitative sono contenitori: le loro pareti bloccano il
		# movimento del player, non l'installazione dei macchinari interni.
		if is_instance_valid(node) and node.is_in_group("base_domes") and not node.is_in_group("greenhouses"):
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


func _device_network_enabled(device: Node) -> bool:
	if not is_instance_valid(device):
		return false
	# Un guasto interrompe il nodo fisico senza alterarne il collegamento scelto
	# dal giocatore. Dopo la riparazione la rete viene ricostruita e riparte.
	if device.has_method("is_incident_operational") and not bool(device.call("is_incident_operational")):
		return false
	if device.has_method("is_network_enabled"):
		return bool(device.call("is_network_enabled"))
	# Mantiene compatibili eventuali consumatori di servizio non interattivi.
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
	if not is_instance_valid(transformer):
		transformer = null


func _manhattan(first: Vector2i, second: Vector2i) -> float:
	return float(absi(first.x - second.x) + absi(first.y - second.y))


func _display_name(item_id: String) -> String:
	match item_id:
		"solar_panel":
			return "PANNELLO SOLARE"
		"transformer":
			return "TRASFORMATORE"
		"battery":
			return "BATTERIA"
		"ice_drill":
			return "TRIVELLA DI GHIACCIO"
		"rock_drill":
			return "TRIVELLA MINERARIA"
	return "DISPOSITIVO ELETTRICO"


func reset_for_new_mission() -> void:
	_clear_cables()
	panels.clear()
	batteries.clear()
	transformer = null
	consumers.clear()
	connection_ok.clear()
	production_kw = 0.0
	demand_kw = 0.0
	network_powered = false
	network_status = "RETE INCOMPLETA"
	_stats_timer = 0.0
	network_changed.emit()
	stats_changed.emit(get_stats())
