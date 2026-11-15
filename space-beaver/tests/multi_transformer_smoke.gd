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
	var shop := root.get_node("Shop")
	var economy := root.get_node("Economy")
	var player := current_scene.get_node("player") as Node2D
	grid.reset_for_new_mission()
	player.global_position = Vector2(-8_000.0, -8_000.0)
	economy.call("add_funds", 3_000_000_000)
	_expect(bool(shop.call("purchase", "transformer")) and bool(shop.call("purchase", "transformer")), "Test assertion failed")

	var first := _place_network(grid, Vector2i(-220, 180))
	var second := _place_network(grid, Vector2i(220, 180))
	if first.is_empty() or second.is_empty():
		_finish()
		return
	for device in [first.get("panel"), first.get("transformer"), first.get("battery"), second.get("panel"), second.get("transformer"), second.get("battery")]:
		if device != null:
			device.set_network_enabled(true)
	grid.rebuild_network()
	var first_transformer = first.get("transformer")
	var second_transformer = second.get("transformer")
	var first_consumer := first.get("consumer") as TestConsumer
	var second_consumer := second.get("consumer") as TestConsumer
	_expect(grid.transformers.size() == 2, "Test assertion failed")
	_expect(bool(grid.connection_ok.get(first_transformer, false)) and bool(grid.connection_ok.get(second_transformer, false)), "Test assertion failed")
	_expect(grid._transformer_for_device.get(first_consumer) == first_transformer and grid._transformer_for_device.get(second_consumer) == second_transformer, "Test assertion failed")

	second.get("panel").set_network_enabled(false)
	grid.rebuild_network()
	clock.running = true
	clock.time_scale = 1.0
	clock.set_game_hour(12.0)
	grid._update_energy(1.0)
	_expect(first_consumer.powered, "Test assertion failed")
	_expect(not second_consumer.powered, "Test assertion failed")
	_expect(grid.network_status == "INDEPENDENT GRIDS · 1/2 ACTIVE", "Test assertion failed")
	clock.running = false
	_finish()


func _place_network(grid: Node, origin: Vector2i) -> Dictionary:
	var panel = grid.place_device(current_scene, "solar_panel", origin)
	var transformer = grid.place_device(current_scene, "transformer", origin + Vector2i(6, 0))
	var battery = grid.place_device(current_scene, "battery", origin + Vector2i(11, -1))
	if panel == null or transformer == null or battery == null:
		_fail("Unable to place a distant test grid")
		return {}
	var consumer := TestConsumer.new()
	consumer.name = "Carico di prova"
	current_scene.add_child(consumer)
	grid.register_consumer(consumer, origin + Vector2i(16, -1), 50.0, Vector2i.LEFT)
	return {"panel": panel, "transformer": transformer, "battery": battery, "consumer": consumer}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MULTI_TRANSFORMER_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MULTI_TRANSFORMER_SMOKE_FAIL: " + failure)
	quit(1)
