extends CharacterBody2D

const SPEED := 190.0
const PICKUP_DISTANCE := 70.0
const FRAME_SIZE := Vector2i(32, 32)
const PLAYER_SHEET := preload("res://sprites/player-spritesheet.png")
const MIN_CAMERA_ZOOM := 0.35
const MAX_CAMERA_ZOOM := 3.0
const ZOOM_FACTOR := 1.18

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var facing := "down"


func _ready() -> void:
	add_to_group("player")
	animated_sprite.sprite_frames = _make_sprite_frames()
	animated_sprite.play("idle_down")
	SuitSystem.equipped_changed.connect(_on_suit_equipped)
	_on_suit_equipped(SuitSystem.equipped_suit_id, SuitSystem.get_equipped_definition())


func _physics_process(_delta: float) -> void:
	if Inventory.is_open or Shop.is_open or BuildableRegistry.is_modal_open:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED * SuitSystem.get_movement_multiplier() * Radiation.get_movement_multiplier() * Temperature.get_movement_multiplier()
	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0.0 else "left"
		else:
			facing = "down" if direction.y > 0.0 else "up"
	var animation_name := ("walk_" if direction != Vector2.ZERO else "idle_") + facing
	animated_sprite.flip_h = false
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _make_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# Riga 1: idle. Righe 2-5: basso, alto, sinistra, destra.
	_add_animation(frames, "idle_down", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "idle_up", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "idle_left", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "idle_right", 0, [0, 1, 2, 3, 4], 3.0)
	_add_animation(frames, "walk_down", 1, [0, 1, 2, 3, 4], 8.0)
	_add_animation(frames, "walk_up", 2, [0, 1, 2, 3, 4], 8.0)
	_add_animation(frames, "walk_left", 3, [0, 1, 2, 3, 4], 8.0)
	_add_animation(frames, "walk_right", 4, [0, 1, 2, 3, 4], 8.0)
	return frames


func _add_animation(frames: SpriteFrames, name: String, row: int, columns: Array, speed: float) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, speed)
	frames.set_animation_loop(name, true)
	for column in columns:
		var frame := AtlasTexture.new()
		frame.atlas = PLAYER_SHEET
		frame.region = Rect2(Vector2i(column, row) * FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(name, frame)


func nearest_rock() -> Node2D:
	var closest: Node2D = null
	var closest_distance := PICKUP_DISTANCE
	for rock in get_tree().get_nodes_in_group("collectible_rocks"):
		if not rock is Node2D:
			continue
		var distance := global_position.distance_to(rock.global_position)
		if distance < closest_distance:
			closest = rock
			closest_distance = distance
	return closest


func nearest_delivery_capsule() -> Node:
	var closest: Node = null
	var closest_distance := PICKUP_DISTANCE
	for capsule in get_tree().get_nodes_in_group("delivery_capsules"):
		if not capsule is Node2D or not capsule.has_method("is_landed") or not bool(capsule.call("is_landed")):
			continue
		var distance := global_position.distance_to(capsule.global_position)
		if distance < closest_distance:
			closest = capsule
			closest_distance = distance
	return closest


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var map_ui := get_tree().get_first_node_in_group("world_map_ui")
		if map_ui != null and map_ui.has_method("handle_mouse_wheel") and bool(map_ui.call("handle_mouse_wheel", event)):
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom(camera.zoom.x * ZOOM_FACTOR)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom(camera.zoom.x / ZOOM_FACTOR)
			get_viewport().set_input_as_handled()
			return
	if not Inventory.is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var capsule := nearest_delivery_capsule()
		if capsule != null:
			capsule.call("collect_all")
			get_viewport().set_input_as_handled()
			return
		var rock := nearest_rock()
		if rock != null and rock.has_method("collect") and bool(rock.call("collect")):
			get_viewport().set_input_as_handled()


func _set_camera_zoom(value: float) -> void:
	var clamped := clampf(value, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	camera.zoom = Vector2.ONE * clamped


func _on_suit_equipped(_suit_id: String, definition: Dictionary) -> void:
	animated_sprite.self_modulate = definition.get("tint", Color.WHITE)
