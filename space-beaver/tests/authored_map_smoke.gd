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
	_expect(map != null, "Test assertion failed")
	if map != null:
		_expect(map.has_method("get_source_id"), "Test assertion failed")
		_expect(map.get_node_or_null("TerrainAccents") != null, "Test assertion failed")
		_expect(map.call("get_world_rect") == Rect2i(Vector2i(-1000, -1000), Vector2i(2000, 2000)), "Test assertion failed")
		_expect(int(map.call("get_loaded_chunk_count")) <= 9, "Test assertion failed")
		_expect(int(map.call("get_loaded_cell_count")) < 2000 * 2000, "Test assertion failed")
		var samples := {
			Vector2i.ZERO: [0, "The landing site must use the original orange terrain"],
			Vector2i(0, -500): [3, "The southern polar edge must use dusty ice"],
			Vector2i(850, -500): [0, "The polar region must have a semicircular edge, not a horizontal strip"],
			Vector2i(-430, -260): [2, "The crater floor must be rocky"],
			Vector2i(-300, -260): [5, "The crater must have a basaltic ring"],
			Vector2i(-220, -260): [1, "Crater terrain assertion failed"],
		}
		for cell in samples:
			map.call("ensure_cell_loaded", cell)
			var expected: Array = samples[cell]
			_expect(int(map.call("get_source_id", cell)) == int(expected[0]), str(expected[1]))
		var terrain := map.get_node_or_null("TerrainChunk_3_3/Terrain") as TileMapLayer
		_expect(terrain != null and terrain.tile_set != null and terrain.tile_set.get_source_count() == 6, "Test assertion failed")

	var variants := {}
	var authored_rock_count := 0
	for rock in get_nodes_in_group("collectible_rocks"):
		if not bool(rock.is_authored):
			continue
		authored_rock_count += 1
		variants[rock.rock_variant] = true
	_expect(authored_rock_count == 125, "Test assertion failed")
	_expect(variants.size() == 10, "Test assertion failed")

	if failures.is_empty():
		print("AUTHORED_MAP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
