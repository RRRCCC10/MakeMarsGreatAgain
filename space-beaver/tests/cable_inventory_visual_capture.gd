extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var clock: Node = root.get_node("WorldClock")
	var power_grid: Node = root.get_node("PowerGrid")
	clock.running = false
	clock.set_game_hour(12.0)
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var first_panel = power_grid.place_device(current_scene, "solar_panel", Vector2i(-5, 4))
	var second_panel = power_grid.place_device(current_scene, "solar_panel", Vector2i(-1, 4))
	var transformer = power_grid.place_device(current_scene, "transformer", Vector2i(3, -3))
	for device in [first_panel, second_panel, transformer]:
		if device != null:
			device.set_network_enabled(true)
	power_grid.rebuild_network()
	await _save_capture("res://tests/captures/cable_path_clean.png")
	root.get_node("Inventory").toggle_open()
	await _save_capture("res://tests/captures/inventory_suit_slot.png")
	print("CABLE_INVENTORY_VISUAL_CAPTURE_OK")
	quit(0)


func _save_capture(path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Impossibile salvare %s" % path)
