extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var power_grid: Node = root.get_node("PowerGrid")
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Unable to load the main scene: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var scene := current_scene
	var player: Node2D = scene.get_node("player")
	var origin := Vector2i(24, 24)
	var machine: Node2D
	for offset in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(4, 4)]:
		var candidate: Vector2i = origin + Vector2i(offset)
		if power_grid.can_place_process_machine("electrolyzer", candidate):
			machine = power_grid.place_process_machine(scene, "electrolyzer", candidate)
			if machine != null:
				break
	_expect(machine != null, "Test assertion failed")
	if machine == null:
		_finish()
		return
	player.global_position = machine.global_position
	var builder: Node = scene.get_node("player/Node")
	builder.call("_update_nearby_machine_ui")
	_expect(builder.nearby_machine == machine, "Test assertion failed")
	_expect(builder.nearby_machine_root.visible, "Test assertion failed")
	_expect(builder.nearby_machine_stock.text.contains("H₂/O₂ through pipes"), "Test assertion failed")
	_expect(machine.get_stock_items().is_empty(), "Test assertion failed")
	var entry: Dictionary = root.get_node("BuildableRegistry").find_at(machine.global_position)
	builder.call("_show_machine_info", entry)
	_expect(builder.machine_info_root.visible, "Test assertion failed")
	_expect(str(builder.machine_title.text).contains("ELECTROLYZER"), "Test assertion failed")
	builder.call("_close_machine_info")
	var rocket: Node2D = scene.get_node("LandingSequence")
	var sabatier_cell := Vector2i(
		floori((rocket.global_position.x - 64.0 - 24.0) / 16.0),
		floori((rocket.global_position.y - 24.0) / 16.0)
	)
	var sabatier = power_grid.place_process_machine(scene, "sabatier", sabatier_cell)
	_expect(sabatier != null, "Test assertion failed")
	if sabatier != null:
		player.global_position = sabatier.global_position
		builder.call("_update_nearby_machine_ui")
		_expect(builder.nearby_machine == sabatier, "Test assertion failed")
		_expect(builder.nearby_machine_stock.text.contains("CH₄ loaded directly"), "Test assertion failed")
		var sabatier_entry: Dictionary = root.get_node("BuildableRegistry").find_at(sabatier.global_position)
		builder.call("_show_machine_info", sabatier_entry)
		_expect(builder.machine_info_root.visible, "Test assertion failed")
		_expect(str(builder.machine_title.text).contains("SABATIER"), "Test assertion failed")
		builder.call("_close_machine_info")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PROCESS_MACHINE_UI_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
