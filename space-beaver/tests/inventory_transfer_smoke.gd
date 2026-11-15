extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory := root.get_node_or_null("Inventory")
	_expect(inventory != null, "L'autoload Inventory deve essere disponibile")
	if inventory == null:
		_finish()
		return
	inventory.call("reset_for_new_mission")
	_expect(bool(inventory.call("add_item", "xrd_diffractometer", "Diffrattometro XRD", 1, true)), "Il macchinario deve entrare nello zaino")
	var xrd_backpack_index := _find_slot(inventory.get("backpack"), "xrd_diffractometer")
	inventory.call("select_backpack", xrd_backpack_index)
	_expect(bool(inventory.call("move_selected_to_hotbar", 1)), "Un macchinario selezionato deve potersi spostare dallo zaino alla hotbar")
	_expect(str(inventory.get("hotbar")[1].get("id", "")) == "xrd_diffractometer", "Il diffrattometro deve occupare lo slot rapido scelto")
	_expect(bool(inventory.call("move_hotbar_to_backpack", 1)), "Un macchinario in hotbar deve potersi riporre nello zaino")
	_expect(inventory.get("hotbar")[1].is_empty(), "Lo slot rapido deve liberarsi dopo il trasferimento nello zaino")
	_expect(_find_slot(inventory.get("backpack"), "xrd_diffractometer") >= 0, "Il macchinario riposto non deve essere perso")
	_expect(bool(inventory.call("add_item", "raman_spectrometer", "Spettrometro Raman", 1, true)), "Un secondo macchinario deve entrare nello zaino")
	var raman_index := _find_slot(inventory.get("backpack"), "raman_spectrometer")
	inventory.call("select_backpack", raman_index)
	_expect(bool(inventory.call("move_selected_to_hotbar", 2)), "Il secondo macchinario deve equipaggiarsi in uno slot rapido")
	var xrd_index_after := _find_slot(inventory.get("backpack"), "xrd_diffractometer")
	inventory.call("select_backpack", xrd_index_after)
	_expect(bool(inventory.call("move_selected_to_hotbar", 2)), "Mettere un macchinario su uno slot già occupato deve scambiarli")
	_expect(str(inventory.get("hotbar")[2].get("id", "")) == "xrd_diffractometer", "Lo scambio deve equipaggiare l'oggetto selezionato")
	_expect(_find_slot(inventory.get("backpack"), "raman_spectrometer") >= 0, "Lo scambio deve riportare il vecchio macchinario nello zaino")
	_expect(bool(inventory.call("add_item", "potato_seeds", "Semi di patate", 1, false)), "Un oggetto non piazzabile deve entrare nello zaino")
	var seeds_index := _find_slot(inventory.get("backpack"), "potato_seeds")
	inventory.call("select_backpack", seeds_index)
	_expect(bool(inventory.call("move_selected_to_hotbar", 4)), "Anche semi e scorte devono potersi spostare in qualunque slot rapido")
	_expect(str(inventory.get("hotbar")[4].get("id", "")) == "potato_seeds", "L'oggetto non piazzabile deve occupare lo slot rapido scelto")
	_finish()


func _find_slot(slots: Array, item_id: String) -> int:
	for index in range(slots.size()):
		if str(slots[index].get("id", "")) == item_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("INVENTORY_TRANSFER_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("INVENTORY_TRANSFER_SMOKE_FAIL: " + failure)
	quit(1)
