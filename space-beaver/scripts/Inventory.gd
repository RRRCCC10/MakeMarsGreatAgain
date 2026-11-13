extends Node

signal changed

const HOTBAR_SIZE := 5
const BACKPACK_SIZE := 20
const ROVER_ITEM_ID := "rover"
const FIELD_CAMERA_ITEM_ID := "field_camera"
const ROVER_STARTING_BATTERY_KWH := 72.0
const RockResource = preload("res://scripts/rock.gd")

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
	_close_ui_modal()
	changed.emit()


func add_rock(rock_variant: String = "roccia_rossa") -> bool:
	var definition: Dictionary = RockResource.definition_for(rock_variant)
	return add_item(
		str(definition.get("item_id", "rock_roccia_rossa")),
		str(definition.get("name", "Pietra")),
		1,
		false,
	)


func is_rock_item(item_id: String) -> bool:
	return item_id.begins_with("rock_") or item_id == "rock"


func get_first_rock_sample() -> Dictionary:
	for collection in [hotbar, backpack]:
		for item in collection:
			if is_rock_item(str(item.get("id", ""))) and int(item.get("count", 0)) > 0:
				return item.duplicate(true)
	return {}


func take_first_rock_sample() -> Dictionary:
	## Estrae un singolo campione da qualunque slot, preservando lo stack delle
	## pietre dello stesso tipo. I laboratori non dipendono dallo slot selezionato.
	for collection in [hotbar, backpack]:
		for index in collection.size():
			var item: Dictionary = collection[index]
			if not is_rock_item(str(item.get("id", ""))) or int(item.get("count", 0)) <= 0:
				continue
			var sample := {"id": str(item.get("id", "")), "name": str(item.get("name", "Pietra"))}
			item["count"] = int(item.get("count", 0)) - 1
			if int(item["count"]) <= 0:
				collection[index] = {}
			changed.emit()
			return sample
	return {}


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


func add_item(item_id: String, item_name: String, amount: int = 1, placeable: bool = true, configuration: Dictionary = {}) -> bool:
	if amount <= 0:
		return false
	var suit_system := get_node_or_null("/root/SuitSystem")
	if suit_system != null and bool(suit_system.call("is_suit", item_id)):
		return amount == 1 and bool(suit_system.call("acquire_suit", item_id))
	if item_id == ROVER_ITEM_ID:
		return _add_rover_units(amount, ROVER_STARTING_BATTERY_KWH, item_name, placeable)
	if not can_add_item(item_id):
		return false
	for item in hotbar + backpack:
		if item.get("id", "") == item_id and item.get("configuration", {}) == configuration and int(item.get("count", 0)) < 99:
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
				"configuration": configuration.duplicate(true),
			}
			changed.emit()
			return true
	return false


func add_rover(battery_energy_kwh: float) -> bool:
	"""Aggiunge un rover mantenendo la carica effettiva del suo pacco batteria."""
	return _add_rover_units(1, battery_energy_kwh, "Rover esplorativo", true)


func grant_field_camera() -> bool:
	## Ricompensa fisica della Sacca campioni. La telecamera viene consegnata
	## nello zaino, non comprata nello shop; il giocatore la puo' poi equipaggiare
	## in uno dei due slot rapidi centrali come qualunque altro strumento.
	if count_item(FIELD_CAMERA_ITEM_ID) > 0:
		return true
	for index in BACKPACK_SIZE:
		if backpack[index].is_empty():
			backpack[index] = {
				"id": FIELD_CAMERA_ITEM_ID,
				"name": "Telecamera scientifica",
				"count": 1,
				"placeable": false,
				"tool": true,
			}
			changed.emit()
			return true
	# Otto campioni non possono realisticamente saturare i venti slot iniziali,
	# ma in caso di partita modificata proviamo anche gli slot rapidi liberi.
	for index in [1, 2]:
		if hotbar[index].is_empty():
			hotbar[index] = {
				"id": FIELD_CAMERA_ITEM_ID,
				"name": "Telecamera scientifica",
				"count": 1,
				"placeable": false,
				"tool": true,
			}
			changed.emit()
			return true
	return false


func peek_selected_rover_battery() -> float:
	var item := get_selected_item()
	if str(item.get("id", "")) != ROVER_ITEM_ID or int(item.get("count", 0)) <= 0:
		return -1.0
	_ensure_rover_battery_list(item)
	var batteries: Array = item["battery_kwhs"]
	return clampf(float(batteries[0]), 0.0, 120.0) if not batteries.is_empty() else ROVER_STARTING_BATTERY_KWH


func _add_rover_units(amount: int, battery_energy_kwh: float, item_name: String, placeable: bool) -> bool:
	if amount <= 0 or not can_add_item(ROVER_ITEM_ID):
		return false
	var remaining := amount
	for item in hotbar + backpack:
		if str(item.get("id", "")) != ROVER_ITEM_ID or int(item.get("count", 0)) >= 99:
			continue
		_ensure_rover_battery_list(item)
		var batteries: Array = item["battery_kwhs"]
		var capacity := mini(remaining, 99 - int(item.get("count", 0)))
		for _index in capacity:
			batteries.append(clampf(battery_energy_kwh, 0.0, 120.0) if remaining == 1 else ROVER_STARTING_BATTERY_KWH)
		item["count"] = int(item.get("count", 0)) + capacity
		remaining -= capacity
		if remaining <= 0:
			changed.emit()
			return true
	for index in BACKPACK_SIZE:
		if not backpack[index].is_empty():
			continue
		var batteries: Array = []
		for _index in amount:
			batteries.append(clampf(battery_energy_kwh, 0.0, 120.0) if amount == 1 else ROVER_STARTING_BATTERY_KWH)
		backpack[index] = {
			"id": ROVER_ITEM_ID,
			"name": item_name,
			"count": amount,
			"placeable": placeable,
			"battery_kwhs": batteries,
		}
		changed.emit()
		return true
	return false


func _ensure_rover_battery_list(item: Dictionary) -> void:
	var count := maxi(0, int(item.get("count", 0)))
	var batteries: Array = item.get("battery_kwhs", [])
	while batteries.size() < count:
		batteries.append(ROVER_STARTING_BATTERY_KWH)
	while batteries.size() > count:
		batteries.pop_back()
	item["battery_kwhs"] = batteries


func count_item(item_id: String) -> int:
	var suit_system := get_node_or_null("/root/SuitSystem")
	if suit_system != null and bool(suit_system.call("is_suit", item_id)):
		return 1 if bool(suit_system.call("owns_suit", item_id)) else 0
	var total := 0
	for item in hotbar + backpack:
		if item.get("id", "") == item_id:
			total += int(item.get("count", 0))
	return total


func consume_item(item_id: String, amount: int = 1) -> bool:
	"""Consuma un oggetto ovunque si trovi, senza obbligare il giocatore a selezionarlo."""
	if amount <= 0 or count_item(item_id) < amount:
		return false
	var remaining := amount
	for collection in [hotbar, backpack]:
		for index in collection.size():
			var item: Dictionary = collection[index]
			if str(item.get("id", "")) != item_id:
				continue
			var removed := mini(remaining, int(item.get("count", 0)))
			item["count"] = int(item.get("count", 0)) - removed
			remaining -= removed
			if int(item["count"]) <= 0:
				collection[index] = {}
			if remaining <= 0:
				changed.emit()
				return true
	changed.emit()
	return false


func get_selected_item() -> Dictionary:
	return hotbar[selected_hotbar_index]


func refill_selected_water_bottle(available_liters: float) -> float:
	## Riempie esclusivamente la borraccia che il giocatore ha effettivamente in mano.
	## Restituisce i litri prelevati, così la trivella può sottrarli dalla propria riserva.
	var bottle := get_selected_item()
	if str(bottle.get("id", "")) != "water_bottle" or available_liters <= 0.0:
		return 0.0
	var capacity := maxf(0.0, float(bottle.get("capacity_liters", 2.0)))
	var current := clampf(float(bottle.get("liters", 0.0)), 0.0, capacity)
	var transferred := minf(maxf(0.0, capacity - current), available_liters)
	if transferred <= 0.0001:
		return 0.0
	bottle["liters"] = roundf((current + transferred) * 10.0) / 10.0
	changed.emit()
	return transferred


func select_hotbar(index: int) -> void:
	if index >= 0 and index < HOTBAR_SIZE:
		selected_hotbar_index = index
		changed.emit()


func select_backpack(index: int) -> void:
	if index >= 0 and index < BACKPACK_SIZE:
		selected_backpack_index = index if not backpack[index].is_empty() else -1
		changed.emit()


func move_selected_to_hotbar(index: int) -> bool:
	if selected_backpack_index < 0 or index < 0 or index >= HOTBAR_SIZE:
		return false
	# Slot 1, 4 e 5 sono riservati allo strumento e alle scorte di sopravvivenza.
	if index == 0 or index >= 3:
		return false
	var item := backpack[selected_backpack_index]
	if item.is_empty() or (not bool(item.get("placeable", false)) and not bool(item.get("tool", false))):
		return false
	var previous := hotbar[index]
	hotbar[index] = item
	backpack[selected_backpack_index] = previous
	selected_backpack_index = -1
	selected_hotbar_index = index
	changed.emit()
	return true


func can_move_hotbar_to_backpack(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE:
		return false
	var item := hotbar[index]
	if item.is_empty() or (not bool(item.get("placeable", false)) and not bool(item.get("tool", false))):
		return false
	for slot in backpack:
		if slot.is_empty():
			return true
	return false


func move_hotbar_to_backpack(index: int) -> bool:
	## Con l'inventario aperto un click su un macchinario nella hotbar lo ripone
	## nello zaino. Gli slot riservati (tubi, acqua, razioni) non sono quindi
	## spostabili per errore, mentre tutti i costruibili lo sono.
	if not can_move_hotbar_to_backpack(index):
		return false
	for backpack_index in BACKPACK_SIZE:
		if not backpack[backpack_index].is_empty():
			continue
		backpack[backpack_index] = hotbar[index]
		hotbar[index] = {}
		selected_hotbar_index = clampi(selected_hotbar_index, 0, HOTBAR_SIZE - 1)
		selected_backpack_index = backpack_index
		changed.emit()
		return true
	return false


func consume_selected_item() -> bool:
	var item := get_selected_item()
	if item.is_empty() or int(item.get("count", 0)) <= 0:
		return false
	if str(item.get("id", "")) == ROVER_ITEM_ID:
		_ensure_rover_battery_list(item)
		var batteries: Array = item["battery_kwhs"]
		if not batteries.is_empty():
			batteries.pop_front()
	item["count"] -= 1
	if item["count"] <= 0:
		# Le razioni devono restare visibili a zero, per rendere chiaro che sono finite.
		if item.get("id", "") == "food_ration":
			item["count"] = 0
		else:
			hotbar[selected_hotbar_index] = {}
	changed.emit()
	return true


func open() -> bool:
	if is_open:
		return true
	if not _try_open_ui_modal():
		return false
	is_open = true
	selected_backpack_index = -1
	changed.emit()
	return true


func close() -> void:
	if not is_open:
		_close_ui_modal()
		return
	is_open = false
	selected_backpack_index = -1
	_close_ui_modal()
	changed.emit()


func toggle_open() -> bool:
	if is_open:
		close()
		return false
	return open()


func _try_open_ui_modal() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state == null or bool(ui_state.call("try_open_modal", &"inventory"))


func _close_ui_modal() -> void:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", &"inventory")
