extends SceneTree

## Smoke test del contratto di input delle GUI. Verifica i casi che in passato
## lasciavano il mondo attivo: finestre sovrapposte, E/azioni e movimento.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var ui_state := root.get_node_or_null("UIState")
	var inventory := root.get_node_or_null("Inventory")
	var shop := root.get_node_or_null("Shop")
	var achievements := root.get_node_or_null("AchievementManager")
	var registry := root.get_node_or_null("BuildableRegistry")
	var player := current_scene.get_node_or_null("player") as Node2D
	var board := current_scene.get_node_or_null("AchievementBoard")
	var map_ui := current_scene.get_node_or_null("WorldMapUI")
	var inventory_ui := current_scene.get_node_or_null("InventoryUI")
	var shop_ui := current_scene.get_node_or_null("ShopUI")
	var quick_actions_ui := current_scene.get_node_or_null("QuickActionsUI")
	var achievement_success_ui := current_scene.get_node_or_null("AchievementSuccessUI")
	_expect(ui_state != null and inventory != null and shop != null and achievements != null and registry != null and player != null and board != null and map_ui != null and inventory_ui != null and shop_ui != null and quick_actions_ui != null and achievement_success_ui != null, "mancano i nodi necessari alla verifica GUI")
	if ui_state == null or inventory == null or shop == null or achievements == null or registry == null or player == null or board == null or map_ui == null or inventory_ui == null or shop_ui == null or quick_actions_ui == null or achievement_success_ui == null:
		_finish()
		return

	inventory.call("close")
	shop.call("close")
	ui_state.call("reset_for_new_mission")
	inventory.call("reset_for_new_mission")
	_expect(bool(inventory.call("add_item", "potato_seeds", "Semi di patate", 1, false)), "I semi di prova devono entrare nello zaino")
	var seed_index := _find_inventory_slot(inventory.get("backpack"), "potato_seeds")
	_expect(seed_index >= 0, "I semi di prova devono avere uno slot nello zaino")
	_expect(bool(inventory.call("open")), "l'inventario deve aprirsi quando non esiste una GUI modale")
	_expect(str(ui_state.get("active_modal")) == "inventory", "l'inventario deve registrarsi come GUI attiva")
	await process_frame
	var backpack_buttons: Array = inventory_ui.get("backpack_buttons")
	var hotbar_buttons: Array = inventory_ui.get("hotbar_buttons")
	var quick_actions_root := quick_actions_ui.get("_root") as Control
	var achievement_root := achievement_success_ui.get("_root") as Control
	_expect(quick_actions_root != null and not quick_actions_root.visible, "I pulsanti rapidi devono sparire mentre lo zaino è aperto")
	_expect(achievement_root != null and _all_controls_ignore_mouse(achievement_root), "La notifica achievement non deve intercettare click della GUI")
	_expect(seed_index >= 0 and seed_index < backpack_buttons.size(), "Il pulsante dello slot zaino deve esistere")
	_expect(hotbar_buttons.size() > 1, "I pulsanti della hotbar devono esistere")
	if seed_index >= 0 and seed_index < backpack_buttons.size() and hotbar_buttons.size() > 1:
		(backpack_buttons[seed_index] as Button).pressed.emit()
		await process_frame
		_expect(int(inventory.get("selected_backpack_index")) == seed_index, "Il click del pulsante zaino deve selezionare l'oggetto")
		(hotbar_buttons[1] as Button).pressed.emit()
		await process_frame
		_expect(str(inventory.get("hotbar")[1].get("id", "")) == "potato_seeds", "Il click del pulsante hotbar deve spostare l'oggetto selezionato")
	board.call("open")
	_expect(not bool(achievements.get("is_board_open")), "la tavola non deve aprirsi sopra l'inventario")
	_expect(not bool(map_ui.call("open_map")), "la minimappa non deve aprirsi sopra l'inventario")
	var player_start := player.global_position
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_right")
	_expect(player.global_position.distance_to(player_start) < 0.01, "con inventario aperto il player non deve muoversi")
	inventory_ui.call("_input", _key(KEY_ESCAPE))
	_expect(not bool(inventory.get("is_open")), "Esc deve chiudere l'inventario")

	_expect(bool(shop.call("open")), "lo shop deve aprirsi dopo la chiusura dell'inventario")
	board.call("open")
	_expect(not bool(achievements.get("is_board_open")), "la tavola non deve aprirsi sopra lo shop")
	_expect(not bool(registry.call("open_modal")), "un pannello del mondo non deve aprirsi sopra lo shop")
	shop_ui.call("_input", _key(KEY_B))
	_expect(not bool(shop.get("is_open")), "B deve chiudere lo shop quando è lo shop attivo")

	board.call("open")
	_expect(bool(achievements.get("is_board_open")), "la tavola deve aprirsi a mondo libero")
	_expect(not bool(inventory.call("open")), "l'inventario non deve aprirsi sopra la tavola")
	board.call("_unhandled_input", _key(KEY_ESCAPE))
	_expect(not bool(achievements.get("is_board_open")), "Esc deve chiudere la tavola achievement")

	_expect(bool(map_ui.call("open_map")), "la minimappa deve aprirsi a mondo libero")
	_expect(bool(ui_state.call("blocks_world_actions")), "la minimappa deve bloccare le azioni nel mondo")
	_expect(bool(ui_state.call("allows_world_movement")), "la minimappa deve essere l'eccezione che consente il movimento")
	_expect(not bool(inventory.call("open")), "l'inventario non deve aprirsi mentre la minimappa è aperta")
	_expect(not bool(registry.call("open_modal")), "nessun pannello macchina deve aprirsi sopra la minimappa")
	player_start = player.global_position
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_right")
	_expect(player.global_position.x > player_start.x, "la minimappa deve consentire al player di camminare")
	map_ui.call("_unhandled_input", _key(KEY_ESCAPE))
	_expect(not bool(map_ui.get("is_open")), "Esc deve chiudere la minimappa")
	_expect(not bool(ui_state.call("has_open_modal")), "chiudere la minimappa deve liberare il mondo")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _find_inventory_slot(slots: Array, item_id: String) -> int:
	for index in range(slots.size()):
		if str(slots[index].get("id", "")) == item_id:
			return index
	return -1


func _all_controls_ignore_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_controls_ignore_mouse(child):
			return false
	return true


func _finish() -> void:
	if failures.is_empty():
		print("UI_MODAL_INPUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("UI_MODAL_INPUT_SMOKE_FAIL: " + failure)
	quit(1)
