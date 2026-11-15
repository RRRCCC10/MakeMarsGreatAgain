extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Impossibile caricare la scena principale")
		quit(1)
		return
	await process_frame
	await process_frame
	var delivery: Node = root.get_node("DeliveryManager")
	var inventory: Node = root.get_node("Inventory")
	var shop: Node = root.get_node("Shop")
	var economy: Node = root.get_node("Economy")
	economy.balance = 10_000_000_000
	_expect(shop.get_category_ids().size() >= 2, "Test assertion failed")
	_expect(shop.purchase("solar_panel"), "Test assertion failed")
	_expect(shop.purchase("battery"), "Test assertion failed")
	_expect(inventory.count_item("solar_panel") == 0 and inventory.count_item("battery") == 0, "Test assertion failed")
	_expect(delivery.pending_order.size() == 2, "Test assertion failed")
	_expect(delivery.active_capsules.is_empty(), "Test assertion failed")
	delivery.call("_dispatch_pending_order")
	await process_frame
	_expect(delivery.active_capsules.size() == 1, "Test assertion failed")
	var capsule: Node = delivery.active_capsules[0] if not delivery.active_capsules.is_empty() else null
	if capsule != null:
		var capsule_collision := capsule.get("collision_shape") as CollisionShape2D
		_expect(capsule_collision != null and capsule_collision.disabled, "Test assertion failed")
		capsule.call("_land")
		await process_frame
		_expect(not capsule_collision.disabled, "Test assertion failed")
		_expect(int(capsule.call("get_total_item_count")) == 2, "Test assertion failed")
		capsule.call("collect_all")
		await process_frame
		_expect(inventory.count_item("solar_panel") == 1 and inventory.count_item("battery") == 1, "Test assertion failed")
		_expect(delivery.active_capsules.is_empty(), "Test assertion failed")
	var dome := BaseDome.new()
	dome.setup("dome_small", 1, false)
	current_scene.add_child(dome)
	dome.global_position = Vector2(1600.0, 1600.0)
	await process_frame
	_expect(not bool(delivery.call("_landing_position_is_clear", dome.global_position)), "Test assertion failed")
	_expect(not bool(delivery.call("_landing_position_is_clear", dome.global_position + Vector2(52.0, 0.0))), "Test assertion failed")
	dome.queue_free()

	var pipe_manager: Node = root.get_node("PipeManager")
	var pipe_cell := Vector2i(112, 112)
	var money_before_pipe := int(economy.balance)
	var pipe := pipe_manager.call("place_pipe", current_scene, pipe_cell, PipeSegment.ShapeType.STRAIGHT, false) as PipeSegment
	_expect(pipe != null, "Test assertion failed")
	if pipe != null:
		_expect(int(economy.balance) == money_before_pipe - 100_000_000, "Test assertion failed")
		_expect(bool(pipe_manager.call("remove_pipe", pipe_cell)), "Test assertion failed")
		_expect(int(economy.balance) == money_before_pipe, "Test assertion failed")

	var power_device_script := load("res://scripts/PowerDevice.gd")
	var drill = power_device_script.new()
	drill.setup("ice_drill", Vector2i(20, 20), false)
	current_scene.add_child(drill)
	await process_frame
	var drill_body := drill.get_node_or_null("StructureCollision") as StaticBody2D
	var drill_shape := drill_body.get_child(0) as CollisionShape2D if drill_body != null else null
	_expect(drill_body != null and drill_shape != null, "Test assertion failed")
	_expect(drill_shape != null and drill_shape.position.y >= 14.0, "Test assertion failed")
	for device_id in ["solar_panel", "transformer", "battery"]:
		var device = power_device_script.new()
		device.setup(device_id, Vector2i.ZERO, false)
		current_scene.add_child(device)
		await process_frame
		_expect(device.get_node_or_null("StructureCollision") != null, "Test assertion failed")
	var game_state: Node = root.get_node("GameState")
	var oxygen_data: Dictionary = game_state.call("_get_death_data", "oxygen")
	var water_data: Dictionary = game_state.call("_get_death_data", "water")
	var food_data: Dictionary = game_state.call("_get_death_data", "food")
	_expect(str(oxygen_data.get("title", "")).contains("OXYGEN"), "Test assertion failed")
	_expect(str(water_data.get("title", "")).contains("DISIDRATAZIONE"), "Test assertion failed")
	_expect(str(food_data.get("title", "")).contains("ALIMENTARI"), "Test assertion failed")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("DELIVERY_DEATH_COLLISION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
