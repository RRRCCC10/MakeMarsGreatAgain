extends SceneTree

## Utility monouso: spezza la vecchia TileMap autoriale in 64 scene statiche.
## Non viene caricata dal gioco; si esegue solo quando la mappa viene ridipinta.

const TILE_SIZE := 16
const CHUNK_SIZE := 256
const WORLD_RECT := Rect2i(Vector2i(-1000, -1000), Vector2i(2000, 2000))
const CHUNK_COUNT := Vector2i(8, 8)


func _init() -> void:
	call_deferred("_split")


func _split() -> void:
	var source_scene := load("res://Scenes/map.tscn") as PackedScene
	if source_scene == null:
		push_error("Impossibile caricare la TileMap autoriale")
		quit(1)
		return
	var source_map := source_scene.instantiate()
	var source_terrain := source_map.get_node_or_null("Terrain") as TileMapLayer
	if source_terrain == null or source_terrain.tile_set == null:
		push_error("Terrain o TileSet non trovato nella mappa autoriale")
		quit(1)
		return
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("res://Scenes/map_chunks"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("res://resources"))
	var tile_set_result := ResourceSaver.save(source_terrain.tile_set, "res://resources/terrain_tileset.tres")
	if tile_set_result != OK:
		push_error("Salvataggio TileSet fallito: %d" % tile_set_result)
		quit(1)
		return
	var shared_tile_set := load("res://resources/terrain_tileset.tres") as TileSet
	if shared_tile_set == null:
		push_error("Impossibile ricaricare il TileSet condiviso")
		quit(1)
		return
	for y in range(CHUNK_COUNT.y):
		for x in range(CHUNK_COUNT.x):
			_save_chunk(source_terrain, shared_tile_set, Vector2i(x, y))
	print("AUTHORED_MAP_SPLIT_OK")
	quit(0)


func _save_chunk(source_terrain: TileMapLayer, shared_tile_set: TileSet, chunk: Vector2i) -> void:
	var origin := WORLD_RECT.position + chunk * CHUNK_SIZE
	var root := Node2D.new()
	root.name = "TerrainChunk"
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = shared_tile_set
	terrain.position = Vector2(origin * TILE_SIZE)
	root.add_child(terrain)
	terrain.owner = root
	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var source_cell := origin + Vector2i(local_x, local_y)
			var source_id := source_terrain.get_cell_source_id(source_cell)
			terrain.set_cell(
				Vector2i(local_x, local_y),
				source_id,
				source_terrain.get_cell_atlas_coords(source_cell),
				source_terrain.get_cell_alternative_tile(source_cell)
			)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		push_error("Impossibile creare il chunk %s" % chunk)
		return
	var save_result := ResourceSaver.save(packed, "res://Scenes/map_chunks/terrain_%d_%d.tscn" % [chunk.x, chunk.y])
	if save_result != OK:
		push_error("Impossibile salvare il chunk %s" % chunk)
