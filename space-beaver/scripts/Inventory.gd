extends Node

signal changed

const HOTBAR_SIZE := 5
const BACKPACK_SIZE := 20

var hotbar: Array[Dictionary] = []
var backpack: Array[Dictionary] = []
var selected_hotbar_index := 0
var selected_backpack_index := -1
var is_open := false


func _ready() -> void:
	reset_for_new_mission()


func reset_for_new_mission() -> void:
	hotbar.clear()
	backpack.clear()
	for i in HOTBAR_SIZE:
		hotbar.append({})
	for i in BACKPACK_SIZE:
		backpack.append({})
	# Slot 1: strumento tubi. Gli ultimi due slot sono le scorte personali.
	hotbar[0] = {"id": "pipe_hammer", "name": "Tubi", "placeable": false, "tool": true}
	hotbar[3] = {"id": "water_bottle", "name": "Acqua", "liters": 2.0, "capacity_liters": 2.0, "placeable": false}
	hotbar[4] = {"id": "food_ration", "name": "Razioni", "count": 3, "placeable": false}
	selected_hotbar_index = 0
	selected_backpack_index = -1
	is_open = false
	changed.emit()


func add_rock() -> bool:
	for i in BACKPACK_SIZE:
		if backpack[i].get("id", "") == "rock" and backpack[i].get("count", 0) < 99:
			backpack[i]["count"] += 1
			changed.emit()
			return true
	for i in BACKPACK_SIZE:
		if backpack[i].is_empty():
			backpack[i] = {"id": "rock", "name": "Pietra", "count": 1, "placeable": false}
			changed.emit()
			return true
	return false


func can_add_item(item_id: String) -> bool:
	var suit_system := get_node_or_null("/root/SuitSystem")
	if suit_system != null and bool(suit_system.call("is_suit", item_id)):
		return not bool(suit_system.call("owns_suit", item_id))
	for item in hotbar + backpack:
		if item.get("id", "") == item_id and int(item.get("count", 0)) < 99:
			return true
	for item in backpack:
		if item.is_empty():
			return true
	return false


func add_item(item_id: String, item_name: String, amount: int = 1, placeable: bool = true) -> bool:
	if amount <= 0:
		return false
	var suit_system := get_node_or_null("/root/SuitSystem")
	if suit_system != null and bool(suit_system.call("is_suit", item_id)):
		return amount == 1 and bool(suit_system.call("acquire_suit", item_id))
	if not can_add_item(item_id):
		return false
	for item in hotbar + backpack:
		if item.get("id", "") == item_id and int(item.get("count", 0)) < 99:
			item["count"] = mini(99, int(item.get("count", 0)) + amount)
			changed.emit()
			return true
	for index in BACKPACK_SIZE:
		if backpack[index].is_empty():
			backpack[index] = {
				"id": item_id,
				"name": item_name,
				"count": amount,
				"placeable": placeable,
			}
			changed.emit()
			return true
	return false


func count_item(item_id: String) -> int:
	var suit_system := get_node_or_null("/root/SuitSystem")
	if suit_system != null and bool(suit_system.call("is_suit", item_id)):
		return 1 if bool(suit_system.call("owns_suit", item_id)) else 0
	var total := 0
	for item in hotbar + backpack:
		if item.get("id", "") == item_id:
			total += int(item.get("count", 0))
	return total


func get_selected_item() -> Dictionary:
	return hotbar[selected_hotbar_index]


func select_hotbar(index: int) -> void:
	if index >= 0 and index < HOTBAR_SIZE:
		selected_hotbar_index = index
		changed.emit()


func select_backpack(index: int) -> void:
	if index >= 0 and index < BACKPACK_SIZE:
		selected_backpack_index = index if not backpack[index].is_empty() else -1
		changed.emit()


func move_selected_to_hotbar(index: int) -> void:
	if selected_backpack_index < 0 or index < 0 or index >= HOTBAR_SIZE:
		return
	# Slot 1, 4 e 5 sono riservati allo strumento e alle scorte di sopravvivenza.
	if index == 0 or index >= 3:
		return
	var item := backpack[selected_backpack_index]
	if item.is_empty() or not item.get("placeable", false):
		return
	var previous := hotbar[index]
	hotbar[index] = item
	backpack[selected_backpack_index] = previous
	selected_backpack_index = -1
	selected_hotbar_index = index
	changed.emit()


func consume_selected_item() -> bool:
	var item := get_selected_item()
	if item.is_empty() or int(item.get("count", 0)) <= 0:
		return false
	item["count"] -= 1
	if item["count"] <= 0:
		# Le razioni devono restare visibili a zero, per rendere chiaro che sono finite.
		if item.get("id", "") == "food_ration":
			item["count"] = 0
		else:
			hotbar[selected_hotbar_index] = {}
	changed.emit()
	return true


func toggle_open() -> void:
	is_open = not is_open
	selected_backpack_index = -1
	changed.emit()
