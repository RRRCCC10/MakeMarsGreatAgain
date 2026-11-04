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
	_expect(map != null, "La scena principale deve contenere il nodo Map")
	if map != null:
		_expect(map.has_method("get_source_id"), "Map deve fornire le tile autoriali ai sistemi di gioco")
		_expect(map.get_node_or_null("TerrainAccents") != null, "Map deve mantenere il layer TerrainAccents")
		_expect(map.call("get_world_rect") == Rect2i(Vector2i(-1000, -1000), Vector2i(2000, 2000)), "La mappa deve misurare 2.000 per 2.000 tile")
		_expect(int(map.call("get_loaded_chunk_count")) <= 9, "All'avvio devono essere caricati soltanto i chunk vicini")
		_expect(int(map.call("get_loaded_cell_count")) < 2000 * 2000, "All'avvio non devono essere caricate tutte le tile")
		var samples := {
			Vector2i.ZERO: [0, "Il punto di atterraggio deve usare il terreno arancione originale"],
			Vector2i(0, -500): [3, "Il bordo meridionale del polo deve usare ghiaccio polveroso"],
			Vector2i(850, -500): [0, "Il polo deve avere un bordo semicircolare, non una fascia orizzontale"],
			Vector2i(-430, -260): [2, "Il fondo del cratere deve essere pietroso"],
			Vector2i(-300, -260): [5, "Il cratere deve avere un anello basaltico"],
			Vector2i(-220, -260): [1, "Il cratere deve avere regolite rossa all'esterno"],
		}
		for cell in samples:
			map.call("ensure_cell_loaded", cell)
			var expected: Array = samples[cell]
			_expect(int(map.call("get_source_id", cell)) == int(expected[0]), str(expected[1]))
		var terrain := map.get_node_or_null("TerrainChunk_3_3/Terrain") as TileMapLayer
		_expect(terrain != null and terrain.tile_set != null and terrain.tile_set.get_source_count() == 6, "Il TileSet condiviso deve contenere il terreno originale e le cinque nuove texture")

	var variants := {}
	var authored_rock_count := 0
	for rock in get_nodes_in_group("collectible_rocks"):
		if not bool(rock.is_authored):
			continue
		authored_rock_count += 1
		variants[rock.rock_variant] = true
	_expect(authored_rock_count == 125, "Le rocce autoriali devono restare nodi espliciti e distribuiti nella scena")
	_expect(variants.size() == 10, "Tutte le dieci varianti di roccia devono essere piazzate")

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
