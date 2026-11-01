extends Node

signal network_changed

const PIPE_SCENE := preload("res://Scenes/pipe.tscn")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PIPE_TILE_SIZE := 16
const PIPE_COST := 100_000_000

var pipes: Dictionary = {}
var fluid_sources: Array[Dictionary] = []


func can_place_pipe(cell: Vector2i, shape_type: int, is_vertical: bool) -> bool:
	if pipes.has(cell):
		return false
	if _cell_is_inside_buildable(cell):
		return false
	if not Economy.can_afford(PIPE_COST):
		return false
	var categories := _neighbor_categories(cell, shape_type, is_vertical)
	# Non si possono unire accidentalmente due reti con fluidi incompatibili.
	return categories.size() <= 1


func place_pipe(parent: Node, cell: Vector2i, shape_type: int, is_vertical: bool) -> PipeSegment:
	if not can_place_pipe(cell, shape_type, is_vertical):
		return null
	if not Economy.spend(PIPE_COST):
		return null
	var pipe := PIPE_SCENE.instantiate() as PipeSegment
	pipe.setup(cell, shape_type, is_vertical)
	parent.add_child(pipe)
	pipe.global_position = _cell_center(cell)
	pipes[cell] = pipe
	BuildableRegistry.register_buildable(pipe, "TUBO", "pipe", remove_pipe.bind(cell))
	_recalculate_component(cell)
	network_changed.emit()
	return pipe


func remove_pipe(cell: Vector2i) -> bool:
	var pipe := get_pipe(cell)
	if pipe == null:
		return false
	BuildableRegistry.unregister_buildable(pipe)
	pipes.erase(cell)
	pipe.queue_free()
	for direction in DIRECTIONS:
		if pipes.has(cell + direction):
			_recalculate_component(cell + direction)
	network_changed.emit()
	return true


func register_fluid_source(source: Node2D, output_cell: Vector2i, category: int, required_opening: Vector2i = Vector2i.LEFT) -> void:
	unregister_fluid_source(source, false)
	fluid_sources.append({
		"node": source,
		"cell": output_cell,
		"category": category,
		"required_opening": required_opening,
	})
	var pipe := get_pipe(output_cell)
	if pipe != null and pipe.has_opening(required_opening) and _component_accepts_category(output_cell, category):
		_recalculate_component(output_cell)
	network_changed.emit()


func unregister_fluid_source(source: Node, emit_change: bool = true) -> void:
	for index in range(fluid_sources.size() - 1, -1, -1):
		var registered: Node = fluid_sources[index].get("node")
		if not is_instance_valid(registered) or registered == source:
			fluid_sources.remove_at(index)
	if emit_change:
		network_changed.emit()


func can_attach_fluid_source(output_cell: Vector2i, category: int, required_opening: Vector2i = Vector2i.LEFT) -> bool:
	var pipe := get_pipe(output_cell)
	if pipe == null:
		return true
	return pipe.has_opening(required_opening) and _component_accepts_category(output_cell, category)


func is_source_connected(source: Node) -> bool:
	_cleanup_fluid_sources()
	for definition in fluid_sources:
		if definition.get("node") != source:
			continue
		var cell := Vector2i(definition.get("cell", Vector2i.ZERO))
		var required_opening := Vector2i(definition.get("required_opening", Vector2i.LEFT))
		var category := int(definition.get("category", PipeSegment.Category.GENERIC))
		var pipe := get_pipe(cell)
		return pipe != null and pipe.has_opening(required_opening) and pipe.category == category
	return false


func get_pipe(cell: Vector2i) -> PipeSegment:
	return pipes.get(cell) as PipeSegment


func are_connected(first: Vector2i, second: Vector2i) -> bool:
	var delta := second - first
	if delta not in DIRECTIONS:
		return false
	var first_pipe := get_pipe(first)
	var second_pipe := get_pipe(second)
	return first_pipe != null and second_pipe != null and first_pipe.has_opening(delta) and second_pipe.has_opening(-delta)


func connected_neighbors(cell: Vector2i) -> Array[PipeSegment]:
	var result: Array[PipeSegment] = []
	for direction in DIRECTIONS:
		var neighbor_cell := cell + direction
		if are_connected(cell, neighbor_cell):
			result.append(get_pipe(neighbor_cell))
	return result


func set_pipe_category(cell: Vector2i, new_category: int) -> bool:
	var pipe := get_pipe(cell)
	if pipe == null or new_category < PipeSegment.Category.GENERIC or new_category > PipeSegment.Category.HYDROGEN:
		return false
	var component := get_network(cell)
	for member in component:
		if member.category != PipeSegment.Category.GENERIC and member.category != new_category:
			return false
	pipe.set_category(new_category)
	_recalculate_component(cell)
	network_changed.emit()
	return true


func get_network(start_cell: Vector2i) -> Array[PipeSegment]:
	var result: Array[PipeSegment] = []
	if not pipes.has(start_cell):
		return result
	var visited: Dictionary = {}
	var pending: Array[Vector2i] = [start_cell]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		var pipe: PipeSegment = get_pipe(cell)
		if pipe == null:
			continue
		result.append(pipe)
		for direction in DIRECTIONS:
			var neighbor_cell: Vector2i = cell + direction
			if not visited.has(neighbor_cell) and are_connected(cell, neighbor_cell):
				pending.append(neighbor_cell)
	return result


func _recalculate_component(start_cell: Vector2i) -> void:
	var component := get_network(start_cell)
	var inherited_category := PipeSegment.Category.GENERIC
	for source in fluid_sources:
		var source_cell := Vector2i(source.get("cell", Vector2i.ZERO))
		var source_pipe := get_pipe(source_cell)
		if source_pipe == null or source_pipe not in component:
			continue
		var required_opening := Vector2i(source.get("required_opening", Vector2i.LEFT))
		if source_pipe.has_opening(required_opening):
			inherited_category = int(source.get("category", PipeSegment.Category.GENERIC))
			break
	for pipe in component:
		if inherited_category == PipeSegment.Category.GENERIC and pipe.category != PipeSegment.Category.GENERIC:
			inherited_category = pipe.category
			break
	if inherited_category == PipeSegment.Category.GENERIC:
		return
	for pipe in component:
		if pipe.category == PipeSegment.Category.GENERIC:
			pipe.set_category(inherited_category)


func _neighbor_categories(cell: Vector2i, shape_type: int, is_vertical: bool) -> Dictionary:
	var categories: Dictionary = {}
	var candidate_openings := _openings_for(shape_type, is_vertical)
	for source in fluid_sources:
		if Vector2i(source.get("cell", Vector2i.ZERO)) != cell:
			continue
		var required_opening := Vector2i(source.get("required_opening", Vector2i.LEFT))
		if required_opening in candidate_openings:
			categories[int(source.get("category", PipeSegment.Category.GENERIC))] = true
	for direction in candidate_openings:
		var neighbor := get_pipe(cell + direction)
		if neighbor == null or not neighbor.has_opening(-direction):
			continue
		if neighbor.category != PipeSegment.Category.GENERIC:
			categories[neighbor.category] = true
	return categories


func _openings_for(shape_type: int, is_vertical: bool) -> Array[Vector2i]:
	if shape_type == PipeSegment.ShapeType.CROSS:
		return DIRECTIONS.duplicate()
	if is_vertical:
		return [Vector2i.UP, Vector2i.DOWN]
	return [Vector2i.LEFT, Vector2i.RIGHT]


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * PIPE_TILE_SIZE) + Vector2.ONE * PIPE_TILE_SIZE * 0.5


func get_mouse_cell(camera: Camera2D) -> Vector2i:
	var mouse_position := camera.get_global_mouse_position()
	return Vector2i(floori(mouse_position.x / PIPE_TILE_SIZE), floori(mouse_position.y / PIPE_TILE_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return _cell_center(cell)


func _component_accepts_category(start_cell: Vector2i, category: int) -> bool:
	for member in get_network(start_cell):
		if member.category != PipeSegment.Category.GENERIC and member.category != category:
			return false
	for source in fluid_sources:
		var source_cell := Vector2i(source.get("cell", Vector2i.ZERO))
		var source_pipe := get_pipe(source_cell)
		if source_pipe == null or source_pipe not in get_network(start_cell):
			continue
		var source_category := int(source.get("category", PipeSegment.Category.GENERIC))
		if source_category != PipeSegment.Category.GENERIC and source_category != category:
			return false
	return true


func _cell_is_inside_buildable(cell: Vector2i) -> bool:
	for entry in BuildableRegistry.get_entries():
		if entry.get("kind", "") == "pipe":
			continue
		var node: Node = entry.get("node")
		if not is_instance_valid(node) or not node.has_method("get_occupied_power_cells"):
			continue
		if cell in node.get_occupied_power_cells():
			return true
	return false


func _cleanup_fluid_sources() -> void:
	for index in range(fluid_sources.size() - 1, -1, -1):
		if not is_instance_valid(fluid_sources[index].get("node")):
			fluid_sources.remove_at(index)


func reset_for_new_mission() -> void:
	pipes.clear()
	fluid_sources.clear()
	network_changed.emit()
