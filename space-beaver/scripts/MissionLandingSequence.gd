class_name MissionLandingSequence
extends Node2D

signal landing_completed

enum Phase { SPACE_FLIGHT, REVEAL_MARS, DESCENT, TOUCHDOWN, COMPLETE }

const ROCKET_SHEET := preload("res://assets/sprites/rocket/rocket-landing-spritesheet.png")
const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const ROCKET_PAD_TEXTURE := preload("res://assets/sprites/rocket/rocket-pad.png")
const ROCKET_PAD_SAND_TEXTURES := {
	1: preload("res://assets/sprites/rocket/sand/dirty/rocket-pad.png"),
	2: preload("res://assets/sprites/rocket/sand/covered/rocket-pad.png"),
	3: preload("res://assets/sprites/rocket/sand/buried/rocket-pad.png"),
}
const ROCKET_FRAME_SIZE := Vector2i(32, 64)
const ROCKET_COLUMNS := 10
const ROCKET_FRAME_COUNT := 30
const FLIGHT_FIRST_FRAME := ROCKET_FRAME_COUNT - 8
const FLIGHT_FRAME_COUNT := 8
const FLIGHT_FPS := 12.0
const SPACE_FLIGHT_DURATION := 1.35
const REVEAL_DURATION := 0.45
const DESCENT_DURATION := 2.10
const TOUCHDOWN_DURATION := 0.55
const LANDING_SITE_OFFSET := Vector2(-48.0, -20.0)
const LANDED_ROCKET_OFFSET := Vector2(0.0, -24.0)
const CELL_SIZE := 16

var landing_complete := false
var methane_kg := 0.0
const METHANE_CAPACITY_KG := 400.0
var phase := Phase.SPACE_FLIGHT
var phase_time := 0.0
var player: CharacterBody2D
var intro_layer: CanvasLayer
var intro_root: Control
var space_group: Control
var rocket_cinematic: Sprite2D
var caption: Label
var pad_sprite: Sprite2D
var landed_rocket: Sprite2D
var rocket_frames: Array[Texture2D] = []
var stars: Array[ColorRect] = []
var star_speeds: Array[float] = []
var gameplay_layer_visibility: Dictionary = {}
var sand_accumulation := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rocket_frames()
	player = get_parent().get_node_or_null("player") as CharacterBody2D
	if player == null:
		push_error("MissionLandingSequence: nodo player non trovato")
		set_process(false)
		return
	global_position = player.global_position + LANDING_SITE_OFFSET
	_create_landed_site()
	BuildableRegistry.register_buildable(self, "MODULO DI ATTERRAGGIO", "mission_structure", _deny_removal)
	var sandstorms := get_node_or_null("/root/SandstormManager")
	if sandstorms != null:
		sandstorms.call("register_target", self, "BASE DI ATTERRAGGIO")

	# I test headless non devono attendere la cinematica, ma verificano lo
	# stesso stato finale che il giocatore ottiene dopo l'atterraggio.
	if DisplayServer.get_name() == "headless":
		_complete_immediately()
		return

	player.visible = false
	_hide_gameplay_layers()
	_create_intro_overlay()
	get_tree().paused = true


func _process(delta: float) -> void:
	if landing_complete:
		return
	_hide_gameplay_layers()
	_update_stars(delta)
	phase_time += delta
	var viewport_size := get_viewport().get_visible_rect().size
	match phase:
		Phase.SPACE_FLIGHT:
			_update_space_flight(viewport_size)
		Phase.REVEAL_MARS:
			_update_mars_reveal(viewport_size)
		Phase.DESCENT:
			_update_descent(viewport_size)
		Phase.TOUCHDOWN:
			if phase_time >= TOUCHDOWN_DURATION:
				_finish_sequence()


func _update_space_flight(viewport_size: Vector2) -> void:
	var progress := clampf(phase_time / SPACE_FLIGHT_DURATION, 0.0, 1.0)
	var start := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.82)
	var finish := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.34)
	rocket_cinematic.position = start.lerp(finish, _smooth(progress))
	rocket_cinematic.position.x += sin(phase_time * 2.5) * 3.0
	_set_flight_frame()
	if progress >= 1.0:
		_set_phase(Phase.REVEAL_MARS, "INGRESSO ATMOSFERICO // ASSETTO NOMINALE")


func _update_mars_reveal(viewport_size: Vector2) -> void:
	var progress := clampf(phase_time / REVEAL_DURATION, 0.0, 1.0)
	space_group.modulate.a = 1.0 - _smooth(progress)
	var start := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.34)
	var finish := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.14)
	rocket_cinematic.position = start.lerp(finish, _smooth(progress))
	_set_flight_frame()
	if progress >= 1.0:
		space_group.visible = false
		_set_phase(Phase.DESCENT, "DISCESA PROPULSA // VELOCITA' CONTROLLATA")


func _update_descent(viewport_size: Vector2) -> void:
	var progress := clampf(phase_time / DESCENT_DURATION, 0.0, 1.0)
	var start := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.14)
	var finish := _get_touchdown_screen_position(viewport_size)
	rocket_cinematic.position = start.lerp(finish, _smooth(progress))
	rocket_cinematic.scale = Vector2.ONE * lerpf(1.72, 2.0, _smooth(progress))
	var reverse_frame := clampi(
		ROCKET_FRAME_COUNT - 1 - floori(progress * float(ROCKET_FRAME_COUNT - 1)),
		0,
		ROCKET_FRAME_COUNT - 1
	)
	rocket_cinematic.texture = rocket_frames[reverse_frame]
	if progress >= 1.0:
		_begin_touchdown()


func _begin_touchdown() -> void:
	pad_sprite.visible = true
	landed_rocket.visible = true
	rocket_cinematic.visible = false
	_set_phase(Phase.TOUCHDOWN, "CONTATTO CONFERMATO // MISSIONE MARTE ATTIVA")


func _finish_sequence() -> void:
	phase = Phase.COMPLETE
	landing_complete = true
	player.visible = true
	_restore_gameplay_layers()
	get_tree().paused = false
	if intro_layer != null:
		intro_layer.queue_free()
	landing_completed.emit()
	set_process(false)


func _complete_immediately() -> void:
	pad_sprite.visible = true
	landed_rocket.visible = true
	player.visible = true
	phase = Phase.COMPLETE
	landing_complete = true
	landing_completed.emit()
	set_process(false)


func _create_landed_site() -> void:
	pad_sprite = Sprite2D.new()
	pad_sprite.name = "RocketPad"
	pad_sprite.texture = ROCKET_PAD_TEXTURE
	pad_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pad_sprite.z_index = 0
	pad_sprite.visible = false
	add_child(pad_sprite)

	landed_rocket = Sprite2D.new()
	landed_rocket.name = "LandedRocket"
	landed_rocket.texture = rocket_frames[0]
	landed_rocket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	landed_rocket.position = LANDED_ROCKET_OFFSET
	landed_rocket.z_index = 2
	landed_rocket.visible = false
	add_child(landed_rocket)

	# La collisione occupa solo la base: il giocatore puo' passare dietro
	# alla parte alta del razzo, come per gli altri macchinari verticali.
	var body := StaticBody2D.new()
	body.name = "LandingSiteCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50.0, 22.0)
	collision.shape = shape
	collision.position = Vector2(0.0, 12.0)
	body.add_child(collision)
	add_child(body)


func _create_intro_overlay() -> void:
	intro_layer = CanvasLayer.new()
	intro_layer.name = "LandingCinematic"
	intro_layer.layer = 500
	intro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(intro_layer)

	intro_root = Control.new()
	intro_root.name = "CinematicRoot"
	intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_root.process_mode = Node.PROCESS_MODE_ALWAYS
	intro_layer.add_child(intro_root)

	space_group = Control.new()
	space_group.name = "SpaceBackdrop"
	space_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	space_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(space_group)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("030711")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space_group.add_child(backdrop)
	_create_stars()

	rocket_cinematic = Sprite2D.new()
	rocket_cinematic.name = "Rocket"
	rocket_cinematic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rocket_cinematic.scale = Vector2.ONE * 1.72
	rocket_cinematic.texture = rocket_frames[FLIGHT_FIRST_FRAME]
	intro_root.add_child(rocket_cinematic)

	caption = Label.new()
	caption.name = "FlightStatus"
	caption.anchor_left = 0.0
	caption.anchor_top = 1.0
	caption.anchor_right = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -62.0
	caption.offset_bottom = -26.0
	caption.text = "TRANSITO MARTE // PROPULSIONE ATTIVA"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", UI_FONT)
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color("dcecff"))
	caption.add_theme_color_override("font_outline_color", Color("02040a"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(caption)
	_create_camera_tutorial()


func _create_camera_tutorial() -> void:
	# È l'unica GUI visibile durante il viaggio: spiega la telecamera prima che
	# HUD e pannelli operativi vengano ripristinati al termine dell'atterraggio.
	var panel := PanelContainer.new()
	panel.name = "CameraTutorial"
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -354.0
	panel.offset_top = 22.0
	panel.offset_right = -22.0
	panel.offset_bottom = 148.0
	panel.add_theme_stylebox_override("panel", _camera_tutorial_style())
	intro_root.add_child(panel)
	var label := Label.new()
	label.text = "TELECAMERA SCIENTIFICA\nCompleta SACCA CAMPIONI per riceverla.\nQuando è equipaggiata:\nP · scatta     O · invia alla Terra     C · archivio"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("c9f3ff"))
	label.add_theme_color_override("font_outline_color", Color("031116"))
	label.add_theme_constant_override("outline_size", 2)
	panel.add_child(label)


func _camera_tutorial_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("071820e8")
	style.border_color = Color("65cce8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _create_stars() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for index in range(56):
		var star := ColorRect.new()
		var pixel_size := 1.0 + float(index % 3 == 0)
		star.size = Vector2.ONE * pixel_size
		star.position = Vector2(
			fposmod(float(index * 83 + 29), maxf(1.0, viewport_size.x)),
			fposmod(float(index * 47 + 13), maxf(1.0, viewport_size.y))
		)
		star.color = Color(0.68, 0.82, 1.0, 0.55 + float(index % 4) * 0.1)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space_group.add_child(star)
		stars.append(star)
		star_speeds.append(42.0 + float(index % 7) * 14.0)


func _update_stars(delta: float) -> void:
	if space_group == null or not space_group.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for index in stars.size():
		var star := stars[index]
		star.position.y += star_speeds[index] * delta
		if star.position.y > viewport_size.y + 4.0:
			star.position.y = -4.0


func _hide_gameplay_layers() -> void:
	for child in get_parent().get_children():
		if not child is CanvasLayer:
			continue
		var layer := child as CanvasLayer
		if not gameplay_layer_visibility.has(layer):
			gameplay_layer_visibility[layer] = layer.visible
		layer.visible = false


func _restore_gameplay_layers() -> void:
	for layer_variant in gameplay_layer_visibility.keys():
		var layer := layer_variant as CanvasLayer
		if is_instance_valid(layer):
			layer.visible = bool(gameplay_layer_visibility[layer_variant])
	gameplay_layer_visibility.clear()


func _build_rocket_frames() -> void:
	for index in range(ROCKET_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = ROCKET_SHEET
		frame.region = Rect2(
			Vector2i(index % ROCKET_COLUMNS, index / ROCKET_COLUMNS) * ROCKET_FRAME_SIZE,
			ROCKET_FRAME_SIZE
		)
		rocket_frames.append(frame)


func _set_flight_frame() -> void:
	var frame_offset := int(floor(phase_time * FLIGHT_FPS)) % FLIGHT_FRAME_COUNT
	rocket_cinematic.texture = rocket_frames[FLIGHT_FIRST_FRAME + frame_offset]


func _set_phase(new_phase: int, status_text: String) -> void:
	phase = new_phase
	phase_time = 0.0
	if caption != null:
		caption.text = status_text


func _get_touchdown_screen_position(viewport_size: Vector2) -> Vector2:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var camera_zoom := camera.zoom if camera != null else Vector2.ONE
	var rocket_world_position := global_position + LANDED_ROCKET_OFFSET
	return viewport_size * 0.5 + (rocket_world_position - player.global_position) * camera_zoom


func get_occupied_power_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var min_cell := Vector2i(
		floori((global_position.x - 32.0) / CELL_SIZE),
		floori((global_position.y - 32.0) / CELL_SIZE)
	)
	var max_cell := Vector2i(
		floori((global_position.x + 31.0) / CELL_SIZE),
		floori((global_position.y + 31.0) / CELL_SIZE)
	)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			result.append(Vector2i(x, y))
	return result


func get_methane_capacity_kg() -> float:
	return METHANE_CAPACITY_KG


func load_methane_kg(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var loaded := minf(amount, maxf(0.0, METHANE_CAPACITY_KG - methane_kg))
	methane_kg += loaded
	return loaded


func contains_world_point(world_point: Vector2) -> bool:
	return Rect2(global_position - Vector2(32.0, 32.0), Vector2(64.0, 64.0)).has_point(world_point)


func get_thermal_shelter_bonus_c() -> float:
	# Il modulo di atterraggio non e' ancora un habitat completo, ma offre
	# pareti e schermature sufficienti a ridurre in parte la perdita di calore.
	return 18.0


func get_sand_accumulation() -> int:
	return sand_accumulation


func set_sand_accumulation(level: int) -> void:
	sand_accumulation = clampi(level, 0, 3)
	if pad_sprite != null:
		pad_sprite.texture = ROCKET_PAD_SAND_TEXTURES.get(sand_accumulation, ROCKET_PAD_TEXTURE)


func get_sand_clean_position() -> Vector2:
	return global_position


func _deny_removal() -> bool:
	return false


func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _exit_tree() -> void:
	BuildableRegistry.unregister_buildable(self)
	var sandstorms := get_node_or_null("/root/SandstormManager")
	if sandstorms != null:
		sandstorms.call("unregister_target", self)
	if not landing_complete and get_tree() != null:
		get_tree().paused = false
