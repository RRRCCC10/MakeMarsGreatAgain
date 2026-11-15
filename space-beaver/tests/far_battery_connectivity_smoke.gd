extends SceneTree


class TestConsumer extends Node2D:
	var powered := false

	func set_powered(value: bool) -> void:
		powered = value


var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var grid := root.get_node("PowerGrid")
	var clock := root.get_node("WorldClock")
	var player := current_scene.get_node("player") as Node2D
	grid.reset_for_new_mission()
	player.global_position = Vector2(-8_000.0, -8_000.0)
	var panel = grid.place_device(current_scene, "solar_panel", Vector2i(-700, -700))
	var transformer = grid.place_device(current_scene, "transformer", Vector2i(-694, -700))
	var battery = grid.place_device(current_scene, "battery", Vector2i(550, -700))
	_expect(panel != null and transformer != null and battery != null, "Test assertion failed")
	if panel == null or transformer == null or battery == null:
		_finish()
		return
	var consumer := TestConsumer.new()
	current_scene.add_child(consumer)
	grid.register_consumer(consumer, Vector2i(556, -700), 50.0, Vector2i.LEFT)
	for device in [panel, transformer, battery]:
		device.set_network_enabled(true)
	grid.rebuild_network()
	_expect(bool(grid.connection_ok.get(battery, false)), "Test assertion failed")
	_expect(bool(grid.connection_ok.get(consumer, false)), "Test assertion failed")
	clock.running = true
	clock.set_game_hour(12.0)
	grid._update_energy(0.1)
	_expect(consumer.powered, "Test assertion failed")

	grid.reset_for_new_mission()
	var close_transformer = grid.place_device(current_scene, "transformer", Vector2i(40, 40))
	var close_battery = grid.place_device(current_scene, "battery", Vector2i(36, 40))
	_expect(close_transformer != null and close_battery != null, "Test assertion failed")
	if close_transformer != null and close_battery != null:
		close_transformer.set_network_enabled(true)
		close_battery.set_network_enabled(true)
		player.global_position = grid.cell_to_world(close_transformer.get_power_output_cell())
		grid.rebuild_network()
		_expect(bool(grid.connection_ok.get(close_battery, false)), "Test assertion failed")
	clock.running = false
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FAR_BATTERY_CONNECTIVITY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAR_BATTERY_CONNECTIVITY_SMOKE_FAIL: " + failure)
	quit(1)
