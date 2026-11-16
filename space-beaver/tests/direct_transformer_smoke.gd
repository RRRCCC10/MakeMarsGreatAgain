extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock: Node = root.get_node("WorldClock")
	var power_grid: Node = root.get_node("PowerGrid")
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Unable to load the main scene: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var scene: Node = current_scene
	var panel = power_grid.place_device(scene, "solar_panel", Vector2i(-8, 6))
	var transformer = power_grid.place_device(scene, "transformer", Vector2i(-2, 6))
	var drill = power_grid.place_device(scene, "ice_drill", Vector2i(4, 6))
	for device in [panel, transformer, drill]:
		device.set_network_enabled(true)
	power_grid.rebuild_network()

	_expect(power_grid.batteries.is_empty(), "Test assertion failed")
	_expect(bool(power_grid.connection_ok.get(transformer, false)), "Test assertion failed")
	_expect(bool(power_grid.connection_ok.get(drill, false)), "Test assertion failed")
	_expect(transformer.get_connection_label() == "CONNECTED TO GRID", "Test assertion failed")

	clock.running = true
	clock.time_scale = 1.0
	clock.set_game_hour(12.0)
	power_grid._update_energy(1.0)
	_expect(is_equal_approx(power_grid.production_kw, 100.0), "Test assertion failed")
	_expect(is_equal_approx(power_grid.demand_kw, 60.0), "Test assertion failed")
	_expect(power_grid.network_powered and drill.powered, "Test assertion failed")
	_expect(power_grid.network_status == "DIRECT GRID", "Test assertion failed")

	clock.set_game_hour(0.0)
	power_grid._update_energy(1.0)
	_expect(not power_grid.network_powered and not drill.powered, "Test assertion failed")
	_expect(power_grid.network_status == "BLACKOUT", "Test assertion failed")

	clock.running = false
	if failures.is_empty():
		print("DIRECT_TRANSFORMER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
