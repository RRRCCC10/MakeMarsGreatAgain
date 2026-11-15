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
	var map: Node = scene.get_node("Map")
	var player := scene.get_node("player") as Node2D
	var map_ui: Node = scene.get_node("WorldMapUI")
	var power_grid: Node = root.get_node("PowerGrid")
	var delivery_manager: Node = root.get_node("DeliveryManager")
	var remote_cell := Vector2i(720, 720)
	var device: Node = power_grid.call("place_device", scene, "solar_panel", remote_cell)
	_expect(device != null, "Test assertion failed")
	await process_frame
	var remote_chunk: Vector2i = map.call("cell_to_chunk", remote_cell)
	_expect(bool(map.call("is_chunk_persistent", remote_chunk)), "Test assertion failed")
	_expect(bool(map.call("is_chunk_loaded", remote_chunk)), "Test assertion failed")

	player.global_position = map.call("cell_to_world", Vector2i(-640, 620))
	await process_frame
	await process_frame
	_expect(bool(map.call("is_chunk_loaded", remote_chunk)), "Test assertion failed")
	_expect(Array(power_grid.get("panels")).has(device), "Test assertion failed")

	var delivery_position: Vector2 = player.global_position
	var selected_drop: Vector2 = delivery_manager.call("_choose_landing_position")
	_expect(selected_drop.distance_to(delivery_position) <= 230.0, "Test assertion failed")
	_expect(selected_drop.distance_to(Vector2.ZERO) > 5000.0, "Test assertion failed")

	var capsule_script: Script = load("res://scripts/DeliveryCapsule.gd")
	var capsule: Node2D = capsule_script.new()
	var expected_marker_position := player.global_position + Vector2(128.0, 0.0)
	var empty_contents: Array[Dictionary] = []
	capsule.setup(empty_contents, expected_marker_position)
	scene.add_child(capsule)
	await process_frame
	var counts: Dictionary = map_ui.call("get_map_marker_counts")
	_expect(int(counts.get("structures", 0)) >= 2, "Test assertion failed")
	_expect(int(counts.get("airdrops", 0)) == 1, "Test assertion failed")
	var found_device_icon := false
	for marker in map_ui.call("get_structure_map_markers"):
		if marker.get("node") == device:
			found_device_icon = marker.get("texture") != null
	_expect(found_device_icon, "Test assertion failed")
	var found_drop_marker := false
	for marker in map_ui.call("get_airdrop_map_markers"):
		if marker.get("node") == capsule:
			found_drop_marker = marker.get("world_position") == expected_marker_position and marker.get("texture") != null
	_expect(found_drop_marker, "Test assertion failed")

	if failures.is_empty():
		print("STREAMING_MAP_MARKERS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
