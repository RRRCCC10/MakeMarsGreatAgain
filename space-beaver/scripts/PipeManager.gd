extends Node

signal network_changed

const PIPE_SCENE := preload("res://Scenes/pipe.tscn")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PIPE_TILE_SIZE := 16
const PIPE_COST := 100_000_000

var pipes: Dictionary = {}
var fluid_sources: Array[Dictionary] = []
var fluid_inputs: Array[Dictionary] = []


func can_place_pipe(cell: Vector2i, shape_type: int, is_vertical: bool) -> bool:
	if pipes.has(cell):
		return false
	if _cell_is_inside_buildable(cell):
		return false
	if not Economy.can_afford(PIPE_COST):
		return false
	var orientation := _orientation_for_port(cell, shape_type, is_vertical)
	var categories := _neighbor_categories(cell, shape_type, orientation)
	# Non si possono unire accidentalmente due reti con fluidi incompatibili.
	return categories.size() <= 1


func place_pipe(parent: Node, cell: Vector2i, shape_type: int, is_vertical: bool) -> PipeSegment:
	if not can_place_pipe(cell, shape_type, is_vertical):
		return null
	if not Economy.spend(PIPE_COST):
		return null
	var pipe := PIPE_SCENE.instantiate() as PipeSegment
	pipe.setup(cell, shape_type, _orientation_for_port(cell, shape_type, is_vertical))
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
	# Una macchina puo' esporre piu' uscite (per esempio H₂ e O₂): sostituiamo
	# soltanto l'eventuale porta gia' registrata nella stessa cella.
	for index in range(fluid_sources.size() - 1, -1, -1):
		var registered: Node = fluid_sources[index].get("node")
		var registered_cell := Vector2i(fluid_sources[index].get("cell", Vector2i.ZERO))
		if not is_instance_valid(registered) or (registered == source and registered_cell == output_cell):
			fluid_sources.remove_at(index)
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


func register_fluid_input(sink: Node2D, input_cell: Vector2i, category: int, required_opening: Vector2i) -> void:
	for index in range(fluid_inputs.size() - 1, -1, -1):
		var registered: Node = fluid_inputs[index].get("node")
		var registered_cell := Vector2i(fluid_inputs[index].get("cell", Vector2i.ZERO))
		if not is_instance_valid(registered) or (registered == sink and registered_cell == input_cell):
			fluid_inputs.remove_at(index)
	fluid_inputs.append({"node": sink, "cell": input_cell, "category": category, "required_opening": required_opening})
	var pipe := get_pipe(input_cell)
	if pipe != null:
		# Le porte d'ingresso sono laterali: corregge i raccordi a croce creati
		# dalla vecchia regola che trasformava automaticamente ogni tubo in croce.
		var vertical := required_opening == Vector2i.UP or required_opening == Vector2i.DOWN
		pipe.setup(input_cell, PipeSegment.ShapeType.STRAIGHT, vertical, pipe.category)
		if pipe.has_opening(required_opening) and _component_accepts_category(input_cell, category):
			_recalculate_component(input_cell)
	network_changed.emit()


func unregister_fluid_source(source: Node, emit_change: bool = true) -> void:
	for index in range(fluid_sources.size() - 1, -1, -1):
		var registered: Node = fluid_sources[index].get("node")
		if not is_instance_valid(registered) or registered == source:
			fluid_sources.remove_at(index)
	for index in range(fluid_inputs.size() - 1, -1, -1):
		var registered: Node = fluid_inputs[index].get("node")
		if not is_instance_valid(registered) or registered == source:
			fluid_inputs.remove_at(index)
	if emit_change:
		network_changed.emit()


func can_attach_fluid_source(output_cell: Vector2i, category: int, required_opening: Vector2i = Vector2i.LEFT) -> bool:
	var pipe := get_pipe(output_cell)
	if pipe == null:
		return true
	return pipe.has_opening(required_opening) and _component_accepts_category(output_cell, category)


func is_source_connected(source: Node, category: int = -1) -> bool:
	_cleanup_fluid_sources()
	for definition in fluid_sources:
		if definition.get("node") != source:
			continue
		if category >= 0 and int(definition.get("category", PipeSegment.Category.GENERIC)) != category:
			continue
		var cell := Vector2i(definition.get("cell", Vector2i.ZERO))
		var required_opening := Vector2i(definition.get("required_opening", Vector2i.LEFT))
		var source_category := int(definition.get("category", PipeSegment.Category.GENERIC))
		var pipe := get_pipe(cell)
		return pipe != null and pipe.has_opening(required_opening) and pipe.category == source_category
	return false


func consume_connected_resource(input_cell: Vector2i, opening_toward_machine: Vector2i, category: int, amount: float) -> float:
	"""Preleva fluido da una sorgente raggiunta dalla rete del tubo in ingresso."""
	if amount <= 0.0:
		return 0.0
	var input_pipe := get_pipe(input_cell)
	if input_pipe == null or input_pipe.category != category or not input_pipe.has_opening(opening_toward_machine):
		return 0.0
	var network := get_network(input_cell)
	for definition in fluid_sources:
		if int(definition.get("category", PipeSegment.Category.GENERIC)) != category:
			continue
		var source_node := definition.get("node") as Node
		if not is_instance_valid(source_node) or (not source_node.has_method("consume_fluid_resource") and not source_node.has_method("consume_fluid_resource_for_category")):
			continue
		var source_cell := Vector2i(definition.get("cell", Vector2i.ZERO))
		var source_pipe := get_pipe(source_cell)
		var source_opening := Vector2i(definition.get("required_opening", Vector2i.LEFT))
		if source_pipe == null or source_pipe not in network or not source_pipe.has_opening(source_opening):
			continue
		var supplied := 0.0
		if source_node.has_method("consume_fluid_resource_for_category"):
			supplied = maxf(0.0, float(source_node.call("consume_fluid_resource_for_category", category, amount)))
		else:
			supplied = maxf(0.0, float(source_node.call("consume_fluid_resource", amount)))
		if supplied > 0.0:
			return supplied
	return 0.0


func is_input_connected(input_cell: Vector2i, opening_toward_machine: Vector2i, category: int) -> bool:
	return not get_connected_source_nodes(input_cell, opening_toward_machine, category).is_empty()


func get_connected_source_nodes(input_cell: Vector2i, opening_toward_machine: Vector2i, category: int) -> Array[Node]:
	var result: Array[Node] = []
	var input_pipe := get_pipe(input_cell)
	if input_pipe == null or input_pipe.category != category or not input_pipe.has_opening(opening_toward_machine):
		return result
	var network := get_network(input_cell)
	for definition in fluid_sources:
		if int(definition.get("category", PipeSegment.Category.GENERIC)) != category:
			continue
		var source_node := definition.get("node") as Node
		var source_cell := Vector2i(definition.get("cell", Vector2i.ZERO))
		var source_pipe := get_pipe(source_cell)
		var source_opening := Vector2i(definition.get("required_opening", Vector2i.LEFT))
		if is_instance_valid(source_node) and (source_node.has_method("consume_fluid_resource") or source_node.has_method("consume_fluid_resource_for_category")) and source_pipe != null and source_pipe in network and source_pipe.has_opening(source_opening):
			result.append(source_node)
	return result


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
	if inherited_category == PipeSegment.Category.GENERIC:
		for input_port in fluid_inputs:
			var input_cell := Vector2i(input_port.get("cell", Vector2i.ZERO))
			var input_pipe := get_pipe(input_cell)
			if input_pipe == null or input_pipe not in component:
				continue
			var required_opening := Vector2i(input_port.get("required_opening", Vector2i.LEFT))
			if input_pipe.has_opening(required_opening):
				inherited_category = int(input_port.get("category", PipeSegment.Category.GENERIC))
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
	for input_port in fluid_inputs:
		if Vector2i(input_port.get("cell", Vector2i.ZERO)) != cell:
			continue
		var required_opening := Vector2i(input_port.get("required_opening", Vector2i.LEFT))
		if required_opening in candidate_openings:
			categories[int(input_port.get("category", PipeSegment.Category.GENERIC))] = true
	for direction in candidate_openings:
		var neighbor := get_pipe(cell + direction)
		if neighbor == null or not neighbor.has_opening(-direction):
			continue
		if neighbor.category != PipeSegment.Category.GENERIC:
			categories[neighbor.category] = true
	return categories


func _orientation_for_port(cell: Vector2i, shape_type: int, is_vertical: bool) -> bool:
	if shape_type == PipeSegment.ShapeType.CROSS:
		return is_vertical
	for port in fluid_sources + fluid_inputs:
		if Vector2i(port.get("cell", Vector2i.ZERO)) != cell:
			continue
		var direction := Vector2i(port.get("required_opening", Vector2i.ZERO))
		if direction == Vector2i.UP or direction == Vector2i.DOWN:
			return true
		if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
			return false
	return is_vertical


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
	fluid_inputs.clear()
	network_changed.emit()
