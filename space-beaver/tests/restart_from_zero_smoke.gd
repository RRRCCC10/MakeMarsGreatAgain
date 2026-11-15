extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	root.get_node("Economy").spend(500_000_000)
	root.get_node("Inventory").add_item("battery", "Battery", 2, true)
	root.get_node("Oxygen").oxygen = 12.0
	root.get_node("Hunger").hunger = 13.0
	root.get_node("Hydration").thirst = 14.0
	root.get_node("Temperature").core_temperature_c = 31.0
	root.get_node("DeliveryManager").queue_item("solar_panel", {"name": "Solar Panel", "placeable": true}, 1)
	root.get_node("GameState").restart_from_scratch()
	await process_frame
	await process_frame
	await process_frame
	_expect(root.get_node("Economy").balance == 10_000_000_000, "Test assertion failed")
	_expect(root.get_node("Inventory").count_item("battery") == 0, "Test assertion failed")
	_expect(root.get_node("Oxygen").oxygen > 99.9, "Test assertion failed")
	_expect(root.get_node("Hunger").hunger > 99.9, "Test assertion failed")
	_expect(root.get_node("Hydration").thirst > 99.9, "Test assertion failed")
	_expect(root.get_node("Temperature").core_temperature_c > 36.9, "Test assertion failed")
	_expect(root.get_node("DeliveryManager").pending_order.is_empty(), "Test assertion failed")
	var authored_rock_count := 0
	for rock in current_scene.get_tree().get_nodes_in_group("collectible_rocks"):
		if bool(rock.is_authored):
			authored_rock_count += 1
	_expect(authored_rock_count == 125, "Test assertion failed")
	if failures.is_empty():
		print("RESTART_FROM_ZERO_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
