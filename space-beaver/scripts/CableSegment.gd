class_name CableSegment
extends Node2D

const CABLE_SHEET := preload("res://assets/sprites/machines/energy-pipe-spritesheet.png")
const FRAME_SIZE := Vector2i(16, 16)

var cell := Vector2i.ZERO
var openings: Array[Vector2i] = []
var sprite: Sprite2D


func setup(new_cell: Vector2i, new_openings: Array[Vector2i]) -> void:
	cell = new_cell
	openings = new_openings.duplicate()
	if is_node_ready():
		_refresh_visual()


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	z_index = 0
	_refresh_visual()


func _refresh_visual() -> void:
	if sprite == null:
		return
	var frame := Vector2i.ZERO
	var rotation_steps := 0
	var unique := _unique_openings()
	match unique.size():
		4:
			frame = Vector2i(0, 1)
		3:
			frame = Vector2i(1, 1) # Base: sinistra, destra, basso.
			var missing := _missing_direction(unique)
			rotation_steps = _direction_rotation_from_up(missing)
		2:
			if (-unique[0]) == unique[1]:
				frame = Vector2i(0, 0) if Vector2i.LEFT in unique else Vector2i(1, 0)
			else:
				frame = Vector2i(0, 2) # Base: alto + sinistra.
				rotation_steps = _corner_rotation(unique)
		1:
			frame = Vector2i(0, 0) if unique[0].x != 0 else Vector2i(1, 0)
		_:
			frame = Vector2i(0, 0)
	var texture := AtlasTexture.new()
	texture.atlas = CABLE_SHEET
	texture.region = Rect2(frame * FRAME_SIZE, FRAME_SIZE)
	sprite.texture = texture
	sprite.rotation = rotation_steps * PI * 0.5


func _unique_openings() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in openings:
		if direction not in result:
			result.append(direction)
	return result


func _missing_direction(current: Array[Vector2i]) -> Vector2i:
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if direction not in current:
			return direction
	return Vector2i.UP


func _direction_rotation_from_up(direction: Vector2i) -> int:
	match direction:
		Vector2i.RIGHT:
			return 1
		Vector2i.DOWN:
			return 2
		Vector2i.LEFT:
			return 3
	return 0


func _corner_rotation(current: Array[Vector2i]) -> int:
	if Vector2i.UP in current and Vector2i.LEFT in current:
		return 0
	if Vector2i.UP in current and Vector2i.RIGHT in current:
		return 1
	if Vector2i.RIGHT in current and Vector2i.DOWN in current:
		return 2
	return 3
