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
	_expect(shop.get_category_ids().size() >= 2, "Lo shop deve essere organizzato in categorie")
	_expect(shop.purchase("solar_panel"), "Il pannello deve poter essere ordinato")
	_expect(shop.purchase("battery"), "La batteria deve poter essere ordinata nello stesso intervallo")
	_expect(inventory.count_item("solar_panel") == 0 and inventory.count_item("battery") == 0, "Gli acquisti non devono entrare subito nell'inventario")
	_expect(delivery.pending_order.size() == 2, "Gli acquisti ravvicinati devono stare nello stesso ordine")
	_expect(delivery.active_capsules.is_empty(), "La capsula non deve partire prima della fine della finestra")
	delivery.call("_dispatch_pending_order")
	await process_frame
	_expect(delivery.active_capsules.size() == 1, "Un ordine aggregato deve creare una sola capsula")
	var capsule: Node = delivery.active_capsules[0] if not delivery.active_capsules.is_empty() else null
	if capsule != null:
		var capsule_collision := capsule.get("collision_shape") as CollisionShape2D
		_expect(capsule_collision != null and capsule_collision.disabled, "La capsula in volo non deve avere hitbox")
		capsule.call("_land")
		await process_frame
		_expect(not capsule_collision.disabled, "La capsula atterrata deve avere hitbox")
		_expect(int(capsule.call("get_total_item_count")) == 2, "La capsula deve conservare tutto il contenuto dell'ordine")
		capsule.call("collect_all")
		await process_frame
		_expect(inventory.count_item("solar_panel") == 1 and inventory.count_item("battery") == 1, "Il ritiro deve trasferire tutti gli oggetti nell'inventario")
		_expect(delivery.active_capsules.is_empty(), "La capsula vuota deve scomparire")

	var power_device_script := load("res://scripts/PowerDevice.gd")
	var drill = power_device_script.new()
	drill.setup("ice_drill", Vector2i(20, 20), false)
	current_scene.add_child(drill)
	await process_frame
	var drill_body := drill.get_node_or_null("StructureCollision") as StaticBody2D
	var drill_shape := drill_body.get_child(0) as CollisionShape2D if drill_body != null else null
	_expect(drill_body != null and drill_shape != null, "La trivella deve avere una hitbox fisica")
	_expect(drill_shape != null and drill_shape.position.y >= 14.0, "L'hitbox della trivella deve occupare soltanto la base inferiore")
	for device_id in ["solar_panel", "transformer", "battery"]:
		var device = power_device_script.new()
		device.setup(device_id, Vector2i.ZERO, false)
		current_scene.add_child(device)
		await process_frame
		_expect(device.get_node_or_null("StructureCollision") != null, "%s deve avere una hitbox" % device_id)

	var game_state: Node = root.get_node("GameState")
	var oxygen_data: Dictionary = game_state.call("_get_death_data", "oxygen")
	var water_data: Dictionary = game_state.call("_get_death_data", "water")
	var food_data: Dictionary = game_state.call("_get_death_data", "food")
	_expect(str(oxygen_data.get("title", "")).contains("OSSIGENO"), "Deve esistere il finale custom per l'ossigeno")
	_expect(str(water_data.get("title", "")).contains("DISIDRATAZIONE"), "Deve esistere il finale custom per l'acqua")
	_expect(str(food_data.get("title", "")).contains("ALIMENTARI"), "Deve esistere il finale custom per il cibo")
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
