extends Node2D

## Mappa autoriale suddivisa in asset statici da 256 × 256 tile.
## Il mondo completo resta 2.000 × 2.000 tile, ma in scena vivono soltanto
## i nove chunk attorno al giocatore. Le scene dei chunk non contengono
## logica procedurale: sono il risultato della TileMap dipinta dall'autore.

const TILE_SIZE := 16
const CHUNK_SIZE := 256
const CHUNK_COUNT := Vector2i(8, 8)
const WORLD_RECT := Rect2i(Vector2i(-1000, -1000), Vector2i(2000, 2000))
const ACTIVE_RADIUS := 1
const CHUNK_PATH := "res://Scenes/map_chunks/terrain_%d_%d.tscn"

var player: Node2D
var loaded_chunks: Dictionary = {}
var persistent_chunks: Dictionary = {}
var current_chunk := Vector2i(-9999, -9999)


func _ready() -> void:
	add_to_group("world_map_provider")
	if not BuildableRegistry.entries_changed.is_connected(_on_buildable_entries_changed):
		BuildableRegistry.entries_changed.connect(_on_buildable_entries_changed)
	call_deferred("_setup")


func _setup() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("MapStreaming: player non trovato")
		return
	_refresh_persistent_chunks()
	_update_active_chunks(true)


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_active_chunks(false)


func _update_active_chunks(force: bool) -> void:
	var next_chunk := world_to_chunk(player.global_position)
	if not force and next_chunk == current_chunk:
		return
	current_chunk = next_chunk
	for y in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for x in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			_ensure_chunk(next_chunk + Vector2i(x, y))
	for chunk in loaded_chunks.keys():
		if not persistent_chunks.has(chunk) and max(abs(chunk.x - next_chunk.x), abs(chunk.y - next_chunk.y)) > ACTIVE_RADIUS:
			var terrain_chunk: Node = loaded_chunks[chunk]
			if is_instance_valid(terrain_chunk):
				terrain_chunk.queue_free()
			loaded_chunks.erase(chunk)


func _ensure_chunk(chunk: Vector2i) -> void:
	if loaded_chunks.has(chunk) or not _is_valid_chunk(chunk):
		return
	var chunk_scene := load(CHUNK_PATH % [chunk.x, chunk.y]) as PackedScene
	if chunk_scene == null:
		push_error("MapStreaming: chunk mancante %s" % (CHUNK_PATH % [chunk.x, chunk.y]))
		return
	var terrain_chunk := chunk_scene.instantiate()
	terrain_chunk.name = "TerrainChunk_%d_%d" % [chunk.x, chunk.y]
	add_child(terrain_chunk)
	loaded_chunks[chunk] = terrain_chunk


func get_source_id(cell: Vector2i) -> int:
	if not WORLD_RECT.has_point(cell):
		return -1
	var chunk := cell_to_chunk(cell)
	var terrain_chunk: Node = loaded_chunks.get(chunk)
	if terrain_chunk == null or not is_instance_valid(terrain_chunk):
		return -1
	var terrain := terrain_chunk.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		return -1
	return terrain.get_cell_source_id(cell - chunk_origin(chunk))


func ensure_cell_loaded(cell: Vector2i) -> void:
	if WORLD_RECT.has_point(cell):
		_ensure_chunk(cell_to_chunk(cell))


func is_chunk_loaded(chunk: Vector2i) -> bool:
	return loaded_chunks.has(chunk) and is_instance_valid(loaded_chunks[chunk])


func is_chunk_persistent(chunk: Vector2i) -> bool:
	return persistent_chunks.has(chunk)


func get_world_rect() -> Rect2i:
	return WORLD_RECT


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * (TILE_SIZE * 0.5)


func cell_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x - WORLD_RECT.position.x) / CHUNK_SIZE),
		floori(float(cell.y - WORLD_RECT.position.y) / CHUNK_SIZE)
	)


func world_to_chunk(world_position: Vector2) -> Vector2i:
	return cell_to_chunk(world_to_cell(world_position))


func chunk_origin(chunk: Vector2i) -> Vector2i:
	return WORLD_RECT.position + chunk * CHUNK_SIZE


func get_loaded_chunk_count() -> int:
	return loaded_chunks.size()


func get_loaded_cell_count() -> int:
	return loaded_chunks.size() * CHUNK_SIZE * CHUNK_SIZE


func get_persistent_chunk_count() -> int:
	return persistent_chunks.size()


func _on_buildable_entries_changed() -> void:
	var changed := _refresh_persistent_chunks()
	if changed and player != null:
		_update_active_chunks(true)


func _refresh_persistent_chunks() -> bool:
	var next_persistent: Dictionary = {}
	for entry in BuildableRegistry.get_entries():
		# I tubi non hanno simulazioni autonome. Tutti gli altri elementi
		# registrati sono strutture o macchinari e mantengono vivo il chunk.
		if str(entry.get("kind", "")) == "pipe":
			continue
		var structure := entry.get("node") as Node2D
		if structure == null or not is_instance_valid(structure):
			continue
		var structure_chunk := world_to_chunk(structure.global_position)
		if not _is_valid_chunk(structure_chunk):
			continue
		next_persistent[structure_chunk] = true
	if next_persistent == persistent_chunks:
		return false
	persistent_chunks = next_persistent
	for chunk in persistent_chunks:
		_ensure_chunk(chunk)
	return true


func _is_valid_chunk(chunk: Vector2i) -> bool:
	return chunk.x >= 0 and chunk.y >= 0 and chunk.x < CHUNK_COUNT.x and chunk.y < CHUNK_COUNT.y
