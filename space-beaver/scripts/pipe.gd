class_name PipeSegment
extends Node2D

enum ShapeType { STRAIGHT, CROSS }
enum Category { GENERIC, OXYGEN, WATER, HYDROGEN }

const PIPE_SHEET := preload("res://assets/sprites/machines/pipe-spritesheet.png")
const FRAME_SIZE := Vector2i(16, 16)

@onready var pipe_sprite: Sprite2D = $Sprite2D

var cell := Vector2i.ZERO
var shape_type := ShapeType.STRAIGHT
var is_vertical := false
var category := Category.GENERIC
var is_preview := false


func _ready() -> void:
	_refresh_visuals()


func setup(cell_pos: Vector2i, new_shape: int, vertical: bool, new_category: int = Category.GENERIC) -> void:
	var visuals_changed := shape_type != new_shape or is_vertical != vertical or category != new_category
	cell = cell_pos
	shape_type = new_shape
	is_vertical = vertical
	category = new_category
	if visuals_changed and is_node_ready():
		_refresh_visuals()


func set_category(new_category: int) -> void:
	if category == new_category:
		return
	category = new_category
	_refresh_visuals()


func get_openings() -> Array[Vector2i]:
	if shape_type == ShapeType.CROSS:
		return [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	if is_vertical:
		return [Vector2i.UP, Vector2i.DOWN]
	return [Vector2i.LEFT, Vector2i.RIGHT]


func has_opening(direction: Vector2i) -> bool:
	return direction in get_openings()


func contains_world_point(world_point: Vector2) -> bool:
	return Rect2(global_position - Vector2(FRAME_SIZE) * 0.5, Vector2(FRAME_SIZE)).has_point(world_point)


func _refresh_visuals() -> void:
	var atlas_position := Vector2i.ZERO
	match category:
		Category.OXYGEN:
			atlas_position = Vector2i(32, 0)
		Category.WATER:
			atlas_position = Vector2i(0, 16)
		Category.HYDROGEN:
			atlas_position = Vector2i(32, 16)
	# Ogni categoria occupa due frame consecutivi: dritto, poi croce.
	if shape_type == ShapeType.CROSS:
		atlas_position.x += FRAME_SIZE.x
	var texture := AtlasTexture.new()
	texture.atlas = PIPE_SHEET
	texture.region = Rect2(atlas_position, FRAME_SIZE)
	pipe_sprite.texture = texture
	pipe_sprite.rotation = PI * 0.5 if shape_type == ShapeType.STRAIGHT and is_vertical else 0.0
