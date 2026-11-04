extends Node2D

## Le posizioni sono deterministiche e dipendono dalle tile già dipinte nella
## mappa. Carichiamo solo i campioni nei chunk vicini: il mondo resta denso
## senza mantenere migliaia di collisioni e label fuori dallo schermo.

const ROCK_SCENE := preload("res://Scenes/rock.tscn")
const TILE_SIZE := 16
const CHUNK_TILES := 64
const CANDIDATE_STEP := 7
const ACTIVE_RADIUS := 2

var map_provider: Node
var player: Node2D
var loaded_chunks: Dictionary = {}
var collected_keys: Dictionary = {}
var current_chunk := Vector2i(999999, 999999)


func _ready() -> void:
	add_to_group("rock_scatter")
	call_deferred("_setup")


func _setup() -> void:
	map_provider = get_parent().get_node_or_null("Map")
	player = get_tree().get_first_node_in_group("player") as Node2D
	if map_provider == null or not map_provider.has_method("get_source_id") or player == null:
		push_error("RockScatter: provider della mappa o player non trovato")
		return
	_update_active_chunks(true)


func _process(_delta: float) -> void:
	if map_provider == null or player == null:
		return
	_update_active_chunks(false)


func _update_active_chunks(force: bool) -> void:
	var next_chunk := _world_to_chunk(player.global_position)
	if not force and next_chunk == current_chunk:
		return
	current_chunk = next_chunk
	for y in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for x in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			_ensure_chunk(next_chunk + Vector2i(x, y))
	for chunk in loaded_chunks.keys():
		if max(abs(chunk.x - next_chunk.x), abs(chunk.y - next_chunk.y)) > ACTIVE_RADIUS + 1:
			var container: Node = loaded_chunks[chunk]
			if is_instance_valid(container):
				container.queue_free()
			loaded_chunks.erase(chunk)


func _ensure_chunk(chunk: Vector2i) -> void:
	if loaded_chunks.has(chunk):
		return
	var container := Node2D.new()
	container.name = "ResourceChunk_%d_%d" % [chunk.x, chunk.y]
	add_child(container)
	loaded_chunks[chunk] = container
	var start := chunk * CHUNK_TILES
	for local_y in range(2, CHUNK_TILES, CANDIDATE_STEP):
		for local_x in range(2, CHUNK_TILES, CANDIDATE_STEP):
			var cell := start + Vector2i(local_x, local_y)
			var source_id := int(map_provider.call("get_source_id", cell))
			if source_id < 0 or not _should_spawn(cell, source_id):
				continue
			var key := "%d:%d" % [cell.x, cell.y]
			if collected_keys.has(key):
				continue
			var rock := ROCK_SCENE.instantiate()
			rock.is_authored = false
			rock.resource_key = key
			rock.rock_variant = _variant_for(source_id, cell)
			rock.position = _cell_to_position(cell, _hash(cell, 31), _hash(cell, 79))
			container.add_child(rock)


func _should_spawn(cell: Vector2i, source_id: int) -> bool:
	var roll := _hash(cell, 11)
	# Anche la sabbia iniziale ha molti campioni della roccia originale.
	# Gli altri biomi sono leggermente più ricchi per premiare l'esplorazione.
	return roll % (3 if source_id == 0 else 2) == 0


func _variant_for(source_id: int, cell: Vector2i) -> String:
	var rare := _hash(cell, 47) % 5 == 0
	match source_id:
		0:
			return "roccia_base"
		1:
			return "pietra_rossastra" if rare else "roccia_rossa"
		2:
			return "roccia_scura" if rare else "roccia_grigia"
		3:
			return "ghiaccio_profondo" if rare else "roccia_ghiacciata"
		4:
			return "ghiaccio_blu" if rare else "ghiaccio_leggero"
		5:
			return "basalto" if rare else "roccia_basaltica"
	return "roccia_base"


func _world_to_chunk(world_position: Vector2) -> Vector2i:
	var chunk_pixels := float(TILE_SIZE * CHUNK_TILES)
	return Vector2i(floori(world_position.x / chunk_pixels), floori(world_position.y / chunk_pixels))


func _cell_to_position(cell: Vector2i, jitter_x: int, jitter_y: int) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(8 + jitter_x % 7 - 3, 8 + jitter_y % 7 - 3)


func _hash(cell: Vector2i, salt: int) -> int:
	# La griglia di campionamento avanza di 8 tile: il mixing finale evita
	# ripetizioni regolari (per esempio tutti i candidati con lo stesso mod 4).
	var value := cell.x * 374761393 + cell.y * 668265263 + salt * 700001
	value = (value ^ (value >> 13)) * 1274126177
	return (value ^ (value >> 16)) & 0x7fffffff


func mark_collected(key: String) -> void:
	collected_keys[key] = true


func get_generated_count() -> int:
	var count := 0
	for container in loaded_chunks.values():
		if is_instance_valid(container):
			count += container.get_child_count()
	return count
