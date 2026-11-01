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
	_expect(not first_path.is_empty(), "Il primo pannello deve trovare un percorso")
	if not first_path.is_empty():
		power_grid.call("_add_path", first_path, Vector2i.LEFT, Vector2i.RIGHT, network_id)
	var second_path: Array = power_grid.call("_find_path", second_start, goal, network_id)
	var direct_cells := absi(goal.x - second_start.x) + absi(goal.y - second_start.y) + 1
	_expect(not second_path.is_empty(), "Il secondo pannello deve trovare un percorso")
	_expect(second_path.size() <= direct_cells + 1, "Il riuso dei cavi non deve produrre una deviazione lunga")
	_expect(_count_turns(second_path) <= 2, "Un collegamento libero deve usare al massimo due curve")
	var minimum_allowed_x := mini(second_start.x, goal.x) - 1
	for cell in second_path:
		_expect(Vector2i(cell).x >= minimum_allowed_x, "Il percorso non deve tornare verso il pannello lontano per inseguire il vecchio cavo")

	var inventory: Node = root.get_node("Inventory")
	var suits: Node = root.get_node("SuitSystem")
	_expect(_backpack_has_no_suits(inventory, suits), "Le tute non devono occupare slot dello zaino")
	inventory.call("add_item", "suit_reinforced", "Tuta EVA rinforzata", 1, false)
	_expect(_backpack_has_no_suits(inventory, suits), "Anche una tuta acquistata deve restare nello slot equipaggiamento")
	_expect(bool(suits.call("owns_suit", "suit_reinforced")), "La tuta ritirata deve risultare posseduta")
	var inventory_ui := current_scene.get_node_or_null("InventoryUI")
	_expect(inventory_ui != null and inventory_ui.find_child("SuitEquipmentPanel", true, false) != null, "L'inventario deve avere un pannello equipaggiamento separato")
	_expect(inventory_ui != null and inventory_ui.find_child("SuitSlot", true, false) != null, "Il pannello deve contenere uno slot tuta dedicato")
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
