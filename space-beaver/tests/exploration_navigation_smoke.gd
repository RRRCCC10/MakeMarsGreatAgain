extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var scene := current_scene
	var scatter: Node = scene.get_node_or_null("RockScatter")
	_expect(scatter != null, "Test assertion failed")
	if scatter != null:
		_expect(int(scatter.call("get_generated_count")) >= 600, "Test assertion failed")
	var generated_base_rocks := 0
	for rock in get_nodes_in_group("collectible_rocks"):
		if not bool(rock.is_authored) and str(rock.rock_variant) == "baseline_stone":
			generated_base_rocks += 1
	_expect(generated_base_rocks > 0, "Test assertion failed")

	var map_ui: Node = scene.get_node_or_null("WorldMapUI")
	_expect(map_ui != null, "Test assertion failed")
	if map_ui != null:
		_expect(int(map_ui.call("get_explored_block_count")) > 0, "Test assertion failed")
		map_ui.call("toggle_map")
		_expect(bool(map_ui.is_open) and map_ui.map_root.visible, "Test assertion failed")
		_expect(not root.get_node("Inventory").is_open and not root.get_node("Shop").is_open and not root.get_node("BuildableRegistry").is_modal_open, "Test assertion failed")
		map_ui.call("toggle_map")
		var map_key := InputEventKey.new()
		map_key.pressed = true
		map_key.keycode = KEY_M
		map_ui._unhandled_input(map_key)
		_expect(bool(map_ui.is_open) and map_ui.map_root.visible, "Test assertion failed")

	var player: Node = scene.get_node("player")
	var camera: Camera2D = player.get_node("Camera2D")
	var original_zoom := camera.zoom.x
	var zoom_in := InputEventMouseButton.new()
	zoom_in.pressed = true
	zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	player._unhandled_input(zoom_in)
	_expect(camera.zoom.x == original_zoom, "Test assertion failed")
	_expect(float(map_ui.map_zoom) > 1.0, "Test assertion failed")
	var center_before_pan: Vector2 = map_ui.call("get_map_view_center_cell")
	var middle_down := InputEventMouseButton.new()
	middle_down.button_index = MOUSE_BUTTON_MIDDLE
	middle_down.pressed = true
	middle_down.position = Vector2(540.0, 320.0)
	map_ui._unhandled_input(middle_down)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(620.0, 320.0)
	drag.relative = Vector2(80.0, 0.0)
	map_ui._unhandled_input(drag)
	var middle_up := InputEventMouseButton.new()
	middle_up.button_index = MOUSE_BUTTON_MIDDLE
	middle_up.pressed = false
	middle_up.position = drag.position
	map_ui._unhandled_input(middle_up)
	var center_after_pan: Vector2 = map_ui.call("get_map_view_center_cell")
	_expect(bool(map_ui.map_was_panned) and not bool(map_ui.is_panning), "Test assertion failed")
	_expect(center_after_pan.x < center_before_pan.x, "Test assertion failed")
	map_ui.call("toggle_map")
	var zoom_out := InputEventMouseButton.new()
	zoom_out.pressed = true
	zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	player._unhandled_input(zoom_out)
	_expect(camera.zoom.x < original_zoom, "Test assertion failed")

	if failures.is_empty():
		print("EXPLORATION_NAVIGATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
