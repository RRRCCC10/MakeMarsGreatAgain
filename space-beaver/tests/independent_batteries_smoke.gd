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
	var panel = power_grid.place_device(scene, "solar_panel", Vector2i(-9, 7))
	var transformer = power_grid.place_device(scene, "transformer", Vector2i(-3, 7))
	var battery_a = power_grid.place_device(scene, "battery", Vector2i(2, 6))
	var battery_b = power_grid.place_device(scene, "battery", Vector2i(2, 9))
	for device in [panel, transformer, battery_a, battery_b]:
		device.set_network_enabled(true)
	power_grid.rebuild_network()

	_expect(bool(power_grid.connection_ok.get(transformer, false)), "Test assertion failed")
	_expect(transformer.get_connection_label() == "CONNECTED TO GRID", "Test assertion failed")

	battery_a.set_battery_energy_kwh(100.0)
	battery_b.set_battery_energy_kwh(300.0)
	battery_b.set_network_enabled(false)
	power_grid.rebuild_network()
	clock.running = true
	clock.time_scale = 1.0
	clock.set_game_hour(12.0)
	power_grid._update_energy(20.0)
	_expect(is_equal_approx(battery_a.get_battery_energy_kwh(), 200.0), "Test assertion failed")
	_expect(is_equal_approx(battery_b.get_battery_energy_kwh(), 300.0), "Test assertion failed")
	_expect(battery_a.flow_state == 1 and battery_b.flow_state == 0, "Test assertion failed")

	var consumer := Node2D.new()
	scene.add_child(consumer)
	power_grid.register_consumer(consumer, Vector2i(7, 6), 50.0, Vector2i.LEFT)
	power_grid.rebuild_network()
	clock.set_game_hour(0.0)
	power_grid._update_energy(20.0)
	_expect(is_equal_approx(battery_a.get_battery_energy_kwh(), 150.0), "Test assertion failed")
	_expect(is_equal_approx(battery_b.get_battery_energy_kwh(), 300.0), "Test assertion failed")
	_expect(battery_a.flow_state == -1 and battery_b.flow_state == 0, "Test assertion failed")

	battery_b.set_network_enabled(true)
	power_grid.rebuild_network()
	clock.set_game_hour(12.0)
	power_grid._update_energy(20.0)
	_expect(is_equal_approx(battery_a.get_battery_energy_kwh(), 175.0), "Test assertion failed")
	_expect(is_equal_approx(battery_b.get_battery_energy_kwh(), 325.0), "Test assertion failed")

	clock.running = false
	if failures.is_empty():
		print("INDEPENDENT_BATTERIES_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
