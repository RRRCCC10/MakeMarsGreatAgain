class_name DeliveryCapsule
extends StaticBody2D

enum State { DESCENDING, LANDED }

const LANDED_SOURCE := preload("res://assets/sprites/delivery-capsule/delivery-capsule-landed.jpg")
const BLINK_SOURCE := preload("res://assets/sprites/delivery-capsule/delivery-capsule-blink.jpg")
const PARACHUTE_SOURCE := preload("res://assets/sprites/delivery-capsule/delivery-capsule-landing.jpg")
const LANDED_FRAME_SIZE := Vector2i(32, 32)
const PARACHUTE_FRAME_SIZE := Vector2i(32, 64)
const DESCENT_SECONDS := 5.5
const INTERACTION_DISTANCE := 68.0
const BLINK_INTERVAL_SECONDS := 30.0
const BLINK_DURATION_SECONDS := 2.4

static var landed_texture: Texture2D
static var blink_texture: Texture2D
static var parachute_texture: Texture2D

var contents: Array[Dictionary] = []
var target_position := Vector2.ZERO
var start_position := Vector2.ZERO
var state := State.DESCENDING
var descent_elapsed := 0.0
var animation_elapsed := 0.0
var animation_frame := 0
var landed_elapsed := 0.0
var blink_remaining := 0.0
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var prompt: Label


func setup(order_contents: Array[Dictionary], landing_position: Vector2) -> void:
	contents = order_contents.duplicate(true)
	target_position = landing_position
	start_position = target_position + Vector2(0.0, -420.0)
	global_position = start_position


func _ready() -> void:
	add_to_group("delivery_capsules")
	_ensure_transparent_textures()
	z_index = 4
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26.0, 20.0)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0.0, 5.0)
	collision_shape.disabled = true
	add_child(collision_shape)
	prompt = Label.new()
	prompt.position = Vector2(-76.0, -48.0)
	prompt.size = Vector2(152.0, 38.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", Color("ffe38a"))
	prompt.add_theme_color_override("font_outline_color", Color("071016"))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.visible = false
	add_child(prompt)
	_refresh_parachute_frame()


func _process(delta: float) -> void:
	if state == State.DESCENDING:
		_process_descent(delta)
		return
	_process_landed(delta)


func _process_descent(delta: float) -> void:
	descent_elapsed += delta
	animation_elapsed += delta
	if animation_elapsed >= 0.14:
		animation_elapsed = 0.0
		animation_frame = (animation_frame + 1) % 4
		_refresh_parachute_frame()
	var progress := clampf(descent_elapsed / DESCENT_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.4)
	global_position = start_position.lerp(target_position, eased)
	global_position.x += sin(progress * TAU * 2.0) * (1.0 - progress) * 10.0
	if progress >= 1.0:
		_land()


func _land() -> void:
	state = State.LANDED
	global_position = target_position
	animation_frame = 0
	sprite.position = Vector2.ZERO
	sprite.texture = landed_texture
	prompt.position.y = -48.0
	collision_shape.set_deferred("disabled", false)
	var manager := get_node_or_null("/root/DeliveryManager")
	if manager != null:
		manager.call("notify_capsule_landed", self)


func _process_landed(delta: float) -> void:
	landed_elapsed += delta
	if blink_remaining > 0.0:
		blink_remaining = maxf(0.0, blink_remaining - delta)
		animation_elapsed += delta
		if animation_elapsed >= 0.14:
			animation_elapsed = 0.0
			animation_frame = (animation_frame + 1) % 4
			_refresh_blink_frame()
		if blink_remaining <= 0.0:
			sprite.texture = landed_texture
			animation_frame = 0
	elif landed_elapsed >= BLINK_INTERVAL_SECONDS:
		landed_elapsed = 0.0
		blink_remaining = BLINK_DURATION_SECONDS
		animation_elapsed = 0.0
		animation_frame = 0
		_refresh_blink_frame()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var nearby := player != null and player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE
	prompt.visible = nearby
	if nearby:
		prompt.text = "E  ·  RITIRA ORDINE\n%s" % get_contents_summary()


func collect_all() -> bool:
	if state != State.LANDED:
		return false
	var collected_any := false
	for index in range(contents.size() - 1, -1, -1):
		var item := contents[index]
		var remaining := int(item.get("count", 0))
		var inventory := get_node_or_null("/root/Inventory")
		while remaining > 0:
			if inventory == null or not bool(inventory.call("add_item", str(item.get("id", "")), str(item.get("name", "Oggetto")), 1, bool(item.get("placeable", true)), item.get("configuration", {}))):
				break
			remaining -= 1
			collected_any = true
		item["count"] = remaining
		if remaining <= 0:
			contents.remove_at(index)
	if contents.is_empty():
		var manager := get_node_or_null("/root/DeliveryManager")
		if manager != null:
			manager.call("notify_capsule_emptied", self)
		queue_free()
	else:
		prompt.text = "INVENTARIO PIENO\n%s" % get_contents_summary()
	return collected_any


func is_landed() -> bool:
	return state == State.LANDED


func get_map_marker_world_position() -> Vector2:
	# Durante la discesa la carta mostra il punto previsto di atterraggio,
	# non la posizione temporanea del paracadute fuori dallo schermo.
	return target_position if state == State.DESCENDING else global_position


func get_total_item_count() -> int:
	var total := 0
	for item in contents:
		total += int(item.get("count", 0))
	return total


func get_contents_summary() -> String:
	var parts := PackedStringArray()
	for item in contents:
		parts.append("%s x%d" % [str(item.get("name", "Oggetto")), int(item.get("count", 0))])
	return "  ·  ".join(parts)


func _refresh_parachute_frame() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = parachute_texture
	atlas.region = Rect2(Vector2i(animation_frame, 0) * PARACHUTE_FRAME_SIZE, PARACHUTE_FRAME_SIZE)
	sprite.texture = atlas
	sprite.position = Vector2(0.0, -16.0)


func _refresh_blink_frame() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = blink_texture
	atlas.region = Rect2(Vector2i(animation_frame, 0) * LANDED_FRAME_SIZE, LANDED_FRAME_SIZE)
	sprite.texture = atlas


static func _ensure_transparent_textures() -> void:
	if landed_texture == null:
		landed_texture = _make_background_transparent(LANDED_SOURCE, LANDED_FRAME_SIZE)
		blink_texture = _make_background_transparent(BLINK_SOURCE, LANDED_FRAME_SIZE)
		parachute_texture = _make_background_transparent(PARACHUTE_SOURCE, PARACHUTE_FRAME_SIZE)


static func _make_background_transparent(source: Texture2D, frame_size: Vector2i) -> Texture2D:
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var columns := image.get_width() / frame_size.x
	var rows := image.get_height() / frame_size.y
	for frame_y in rows:
		for frame_x in columns:
			_clear_frame_background(image, Rect2i(Vector2i(frame_x, frame_y) * frame_size, frame_size))
	return ImageTexture.create_from_image(image)


static func _clear_frame_background(image: Image, frame: Rect2i) -> void:
	var pending: Array[Vector2i] = []
	var visited: Dictionary = {}
	for x in range(frame.position.x, frame.end.x):
		pending.append(Vector2i(x, frame.position.y))
		pending.append(Vector2i(x, frame.end.y - 1))
	for y in range(frame.position.y, frame.end.y):
		pending.append(Vector2i(frame.position.x, y))
		pending.append(Vector2i(frame.end.x - 1, y))
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		if visited.has(point) or not frame.has_point(point):
			continue
		visited[point] = true
		var color := image.get_pixelv(point)
		if not _is_jpeg_background(color):
			continue
		color.a = 0.0
		image.set_pixelv(point, color)
		pending.append(point + Vector2i.UP)
		pending.append(point + Vector2i.RIGHT)
		pending.append(point + Vector2i.DOWN)
		pending.append(point + Vector2i.LEFT)


static func _is_jpeg_background(color: Color) -> bool:
	var minimum := minf(color.r, minf(color.g, color.b))
	var maximum := maxf(color.r, maxf(color.g, color.b))
	return minimum > 0.88 and maximum - minimum < 0.10
