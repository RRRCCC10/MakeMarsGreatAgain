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

	var map := current_scene.get_node_or_null("Map")
	var player := current_scene.get_node_or_null("player")
	_expect(map != null and player != null, "La scena deve avere Map e player")
	if map != null and player != null:
		var pixel_rect: Rect2 = map.call("get_world_pixel_rect")
		_expect(pixel_rect.size == Vector2(32000.0, 32000.0), "Il confine deve coprire 2.000 × 2.000 tile da 16 px")
		var margin := 11.0
		player.global_position = pixel_rect.position - Vector2(500.0, 500.0)
		player.call("_physics_process", 0.1)
		_expect(player.global_position.x >= pixel_rect.position.x + margin, "Il player non deve uscire dal bordo sinistro")
		_expect(player.global_position.y >= pixel_rect.position.y + margin, "Il player non deve uscire dal bordo superiore")

		player.global_position = pixel_rect.end + Vector2(500.0, 500.0)
		player.call("_physics_process", 0.1)
		_expect(player.global_position.x <= pixel_rect.end.x - margin, "Il player non deve uscire dal bordo destro")
		_expect(player.global_position.y <= pixel_rect.end.y - margin, "Il player non deve uscire dal bordo inferiore")
		_expect(bool(map.call("is_world_position_inside", player.global_position, margin)), "La posizione finale deve essere dentro la mappa")

	if failures.is_empty():
		print("WORLD_BOUNDS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
