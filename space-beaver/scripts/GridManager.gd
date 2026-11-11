extends Node

const TILE_SIZE: int = 64
var grid: Dictionary = {}

func get_mouse_grid_position(camera: Camera2D) -> Vector2i:
	var mouse_pos = camera.get_global_mouse_position()
	return Vector2i(
		floor(mouse_pos.x / TILE_SIZE),
		floor(mouse_pos.y / TILE_SIZE)
	)

func is_cell_empty(cell_pos: Vector2i) -> bool:
	return not grid.has(cell_pos)

func place_item(cell_pos: Vector2i, item_data) -> bool:
	if not is_cell_empty(cell_pos):
		return false
	var placement_rect := Rect2(Vector2(cell_pos * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and placement_rect.grow(12.0).has_point(player.global_position):
		return false
	for rock in get_tree().get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and placement_rect.grow(14.0).has_point((rock as Node2D).global_position):
			return false
	grid[cell_pos] = item_data
	return true

func remove_item(cell_pos: Vector2i) -> void:
	if grid.has(cell_pos):
		grid.erase(cell_pos)
