extends SceneTree

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
	var page := current_scene.get_node_or_null("PowerUI")
	var grid := root.get_node_or_null("PowerGrid")
	var ui_state := root.get_node_or_null("UIState")
	var inventory := root.get_node_or_null("Inventory")
	_expect(page != null and grid != null and ui_state != null and inventory != null, "mancano la pagina o i servizi della rete")
	if page == null or grid == null or ui_state == null or inventory == null:
		_finish()
		return
	var page_root := page.get_node_or_null("PowerNetworkRoot") as Control
	_expect(page_root != null and not page_root.visible, "il sistema elettrico non deve lasciare un HUD sempre visibile")

	var power_device_script := load("res://scripts/PowerDevice.gd") as Script
	var base_dome_script := load("res://scripts/BaseDome.gd") as Script
	_expect(power_device_script != null and base_dome_script != null, "impossibile caricare gli elementi elettrici di test")
	if power_device_script == null or base_dome_script == null:
		_finish()
		return
	var panel := power_device_script.new() as Node2D
	panel.call("setup", "solar_panel", Vector2i(1600, 1600), false)
	current_scene.add_child(panel)
	grid.get("panels").append(panel)
	var dome := base_dome_script.new() as Node2D
	dome.call("setup", "dome_small", 1, false, {})
	dome.global_position = Vector2(2800.0, 2800.0)
	current_scene.add_child(dome)
	await process_frame
	grid.call("register_consumer", dome, dome.call("get_power_connection_cell"), dome.call("get_power_demand_kw"), dome.call("get_power_attach_direction"))
	grid.call("rebuild_network")

	_expect(bool(page.call("open")), "L deve poter aprire il centro di distribuzione")
	await process_frame
	_expect(page_root.visible, "la pagina elettrica deve essere visibile dopo l'apertura")
	_expect(str(ui_state.get("active_modal")) == "power_network", "la pagina deve bloccare il mondo come GUI modale")
	_expect(not bool(inventory.call("open")), "l'inventario non deve aprirsi sopra la pagina elettrica")
	var devices: Array = grid.call("get_network_devices")
	_expect(_has_device(devices, panel) and _has_device(devices, dome), "pannelli e cupole devono comparire singolarmente nella pagina")
	_expect(bool(grid.call("set_device_network_enabled", panel, true)), "un pannello deve poter essere collegato dalla pagina")
	_expect(bool(panel.call("is_network_enabled")), "il pannello deve risultare collegato dopo il comando")
	page.call("_toggle_device", dome, false)
	_expect(not bool(dome.call("is_network_enabled")), "la pagina deve poter scollegare una singola cupola")
	page.call("_toggle_device", dome, true)
	_expect(bool(dome.call("is_network_enabled")), "la pagina deve poter ricollegare una singola cupola")
	page.call("_unhandled_input", _key(KEY_ESCAPE))
	_expect(not page_root.visible and not bool(ui_state.call("has_open_modal")), "Esc deve chiudere la pagina e liberare il mondo")
	_finish()


func _has_device(devices: Array, target: Node) -> bool:
	for entry_variant in devices:
		var entry: Dictionary = entry_variant
		if entry.get("node") == target:
			return true
	return false


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("POWER_NETWORK_PAGE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("POWER_NETWORK_PAGE_SMOKE_FAIL: " + failure)
	quit(1)
