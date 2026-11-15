extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		push_error("Impossibile caricare la scena principale")
		quit(1)
		return
	await process_frame
	await process_frame
	var power_grid: Node = root.get_node("PowerGrid")
	power_grid.call("reset_for_new_mission")
	var network_id := "solar_to_transformer"
	var goal := Vector2i(49, 45)
	var first_start := Vector2i(42, 52)
	var second_start := Vector2i(46, 52)
	var first_path: Array = power_grid.call("_find_path", first_start, goal, network_id)
	_expect(not first_path.is_empty(), "Test assertion failed")
	if not first_path.is_empty():
		power_grid.call("_add_path", first_path, Vector2i.LEFT, Vector2i.RIGHT, network_id)
	var second_path: Array = power_grid.call("_find_path", second_start, goal, network_id)
	var direct_cells := absi(goal.x - second_start.x) + absi(goal.y - second_start.y) + 1
	_expect(not second_path.is_empty(), "Test assertion failed")
	_expect(second_path.size() <= direct_cells + 1, "Test assertion failed")
	_expect(_count_turns(second_path) <= 2, "Test assertion failed")
	var minimum_allowed_x := mini(second_start.x, goal.x) - 1
	for cell in second_path:
		_expect(Vector2i(cell).x >= minimum_allowed_x, "Test assertion failed")
	var dome := BaseDome.new()
	dome.setup("dome_small", 1, false)
	current_scene.add_child(dome)
	dome.global_position = BaseDome.world_position_for(Vector2i(64, 64))
	await process_frame
	var dome_cells: Array[Vector2i] = dome.get_occupied_power_cells()
	var dome_path: Array = power_grid.call("_find_path", Vector2i(56, 64), Vector2i(72, 64), network_id)
	_expect(not dome_path.is_empty(), "Test assertion failed")
	for cell in dome_path:
		_expect(not dome_cells.has(Vector2i(cell)), "Test assertion failed")
	dome.queue_free()
	await process_frame
	var far_start := Vector2i(-700, -700)
	var far_goal := Vector2i(700, -700)
	var far_path: Array = power_grid.call("_find_path", far_start, far_goal, "far_range_test")
	_expect(not far_path.is_empty(), "Test assertion failed")
	_expect(far_path.size() >= int(power_grid.call("_manhattan", far_start, far_goal)) + 1, "Test assertion failed")

	var foreign_wall: Dictionary = {}
	for y in range(4, 197):
		foreign_wall[Vector2i(100, y)] = true
	power_grid.cable_cells_by_network["foreign_cable_test"] = foreign_wall
	var crossing_path: Array = power_grid.call("_find_path", Vector2i(96, 100), Vector2i(104, 100), "crossing_cable_test")
	_expect(not crossing_path.is_empty(), "Test assertion failed")
	var crosses_foreign_cable := false
	for cell_variant in crossing_path:
		if foreign_wall.has(Vector2i(cell_variant)):
			crosses_foreign_cable = true
			break
	_expect(crosses_foreign_cable, "Test assertion failed")
	power_grid.cable_cells_by_network.erase("foreign_cable_test")

	var inventory: Node = root.get_node("Inventory")
	var suits: Node = root.get_node("SuitSystem")
	_expect(_backpack_has_no_suits(inventory, suits), "Test assertion failed")
	inventory.call("add_item", "suit_reinforced", "Reinforced EVA Suit", 1, false)
	_expect(_backpack_has_no_suits(inventory, suits), "Test assertion failed")
	_expect(bool(suits.call("owns_suit", "suit_reinforced")), "Test assertion failed")
	var inventory_ui := current_scene.get_node_or_null("InventoryUI")
	_expect(inventory_ui != null and inventory_ui.find_child("SuitEquipmentPanel", true, false) != null, "Test assertion failed")
	_expect(inventory_ui != null and inventory_ui.find_child("SuitSlot", true, false) != null, "Test assertion failed")
	_finish()


func _count_turns(path: Array) -> int:
	var turns := 0
	var previous_direction := Vector2i.ZERO
	for index in range(1, path.size()):
		var direction := Vector2i(path[index]) - Vector2i(path[index - 1])
		if previous_direction != Vector2i.ZERO and direction != previous_direction:
			turns += 1
		previous_direction = direction
	return turns


func _backpack_has_no_suits(inventory: Node, suits: Node) -> bool:
	for item in inventory.backpack:
		if bool(suits.call("is_suit", str(item.get("id", "")))):
			return false
	return true


func _finish() -> void:
	if failures.is_empty():
		print("CABLE_PATHFINDING_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
