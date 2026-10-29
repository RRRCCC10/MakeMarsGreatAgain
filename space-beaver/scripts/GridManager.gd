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
	grid[cell_pos] = item_data
	return true

func remove_item(cell_pos: Vector2i) -> void:
	if grid.has(cell_pos):
		grid.erase(cell_pos)
