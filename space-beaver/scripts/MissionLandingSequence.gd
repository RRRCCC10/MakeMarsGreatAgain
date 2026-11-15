class_name MissionLandingSequence
extends Node2D

signal landing_completed

enum Phase { SPACE_FLIGHT, REVEAL_MARS, DESCENT, TOUCHDOWN, COMPLETE }

const ROCKET_SHEET := preload("res://assets/sprites/rocket/rocket-landing-spritesheet.png")
const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const ROCK_RESOURCE := preload("res://scripts/rock.gd")
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
const MANIFEST_INTERACTION_DISTANCE := 92.0
const RETURN_LAUNCH_DURATION := 4.2
const ALIEN_LIFE_SAMPLE_ITEM_ID := "alien_life_sample"

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
var loaded_return_samples: Dictionary = {}
var sabatier_qualified := false
var return_launch_in_progress := false
var return_launch_finished := false
var manifest_layer: CanvasLayer
var manifest_root: Control
var manifest_status: Label
var manifest_list: RichTextLabel
var manifest_scroll: ScrollContainer
var manifest_message: Label
var manifest_load_button: Button
var manifest_launch_button: Button
var world_manifest_prompt: Label
var return_launch_layer: CanvasLayer
var return_launch_root: Control
var return_launch_sprite: Sprite2D
var return_launch_caption: Label
var return_launch_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rocket_frames()
	player = get_parent().get_node_or_null("player") as CharacterBody2D
	if player == null:
		push_error("MissionLandingSequence: player node not found")
		set_process(false)
		return
	global_position = player.global_position + LANDING_SITE_OFFSET
	_create_landed_site()
	_create_return_manifest_ui()
	_create_world_manifest_prompt()
	BuildableRegistry.register_buildable(self, "LANDING MODULE", "mission_structure", _deny_removal)
	var sandstorms := get_node_or_null("/root/SandstormManager")
	if sandstorms != null:
		sandstorms.call("register_target", self, "LANDING SITE")

	# Headless tests skip the cinematic but validate the same final state a
	# player reaches after touchdown.
	if DisplayServer.get_name() == "headless":
		_complete_immediately()
		return

	player.visible = false
	_hide_gameplay_layers()
	_create_intro_overlay()
	get_tree().paused = true


func is_active() -> bool:
	return not landing_complete


func _process(delta: float) -> void:
	if return_launch_in_progress:
		_update_return_launch(delta)
		return
	if landing_complete:
		_update_world_manifest_prompt()
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
		_set_phase(Phase.REVEAL_MARS, "ATMOSPHERIC ENTRY // NOMINAL ATTITUDE")


func _update_mars_reveal(viewport_size: Vector2) -> void:
	var progress := clampf(phase_time / REVEAL_DURATION, 0.0, 1.0)
	space_group.modulate.a = 1.0 - _smooth(progress)
	var start := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.34)
	var finish := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.14)
	rocket_cinematic.position = start.lerp(finish, _smooth(progress))
	_set_flight_frame()
	if progress >= 1.0:
		space_group.visible = false
		_set_phase(Phase.DESCENT, "POWERED DESCENT // CONTROLLED SPEED")


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
	_set_phase(Phase.TOUCHDOWN, "TOUCHDOWN CONFIRMED // MARS MISSION ACTIVE")


func _finish_sequence() -> void:
	phase = Phase.COMPLETE
	landing_complete = true
	player.visible = true
	_restore_gameplay_layers()
	get_tree().paused = false
	if intro_layer != null:
		intro_layer.queue_free()
	landing_completed.emit()
	set_process(true)


func _complete_immediately() -> void:
	pad_sprite.visible = true
	landed_rocket.visible = true
	player.visible = true
	phase = Phase.COMPLETE
	landing_complete = true
	landing_completed.emit()
	set_process(true)


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

	# Collision occupies only the base, allowing the player to pass behind the
	# upper rocket section like other tall machines.
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
	caption.text = "MARS TRANSIT // PROPULSION ACTIVE"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", UI_FONT)
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color("dcecff"))
	caption.add_theme_color_override("font_outline_color", Color("02040a"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(caption)


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
	_record_fuel_ready_if_needed()
	# The Sabatier can refuel while the player keeps the manifest open, so the
	# propellant counter must remain live.
	_refresh_return_manifest()
	return loaded


func register_sabatier_operation(machine: Node) -> void:
	if sabatier_qualified or machine == null or not is_instance_valid(machine):
		return
	# This call happens only after the Sabatier consumed H₂ and transferred CH₄
	# to the rocket, certifying correct placement, cable, and pipe connection.
	sabatier_qualified = true
	AchievementManager.record("sabatier_online")
	_record_fuel_ready_if_needed()
	_refresh_return_manifest()


func get_return_manifest_catalog() -> Array[Dictionary]:
	return ROCK_RESOURCE.get_return_mission_catalog()


func get_return_readiness() -> Dictionary:
	var catalog := get_return_manifest_catalog()
	var loaded_geology := 0
	for definition in catalog:
		if bool(loaded_return_samples.get(str(definition.get("item_id", "")), false)):
			loaded_geology += 1
	var life_loaded := bool(loaded_return_samples.get(ALIEN_LIFE_SAMPLE_ITEM_ID, false))
	return {
		"geology_loaded": loaded_geology,
		"geology_total": catalog.size(),
		"life_loaded": life_loaded,
		"sabatier_qualified": sabatier_qualified,
		"methane_kg": methane_kg,
		"methane_capacity_kg": METHANE_CAPACITY_KG,
		"ready": _has_full_return_manifest() and sabatier_qualified and methane_kg >= METHANE_CAPACITY_KG - 0.001,
	}


func try_open_return_manifest(requesting_player: Node2D) -> bool:
	if not landing_complete or return_launch_in_progress or return_launch_finished:
		return false
	if requesting_player == null or requesting_player.global_position.distance_to(global_position + LANDED_ROCKET_OFFSET) > MANIFEST_INTERACTION_DISTANCE:
		return false
	if manifest_root != null and manifest_root.visible:
		return true
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and not bool(ui_state.call("try_open_modal", &"rocket_manifest")):
		return false
	_refresh_return_manifest()
	manifest_root.visible = true
	return true


func _close_return_manifest() -> void:
	if manifest_root != null:
		manifest_root.visible = false
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", &"rocket_manifest")


func _load_available_return_samples() -> void:
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null:
		return
	var loaded_now := 0
	for definition in get_return_manifest_catalog():
		var item_id := str(definition.get("item_id", ""))
		if item_id.is_empty() or bool(loaded_return_samples.get(item_id, false)):
			continue
		if bool(inventory.call("consume_item", item_id, 1)):
			loaded_return_samples[item_id] = true
			loaded_now += 1
	if not bool(loaded_return_samples.get(ALIEN_LIFE_SAMPLE_ITEM_ID, false)) and bool(inventory.call("consume_item", ALIEN_LIFE_SAMPLE_ITEM_ID, 1)):
		loaded_return_samples[ALIEN_LIFE_SAMPLE_ITEM_ID] = true
		loaded_now += 1
	if _has_full_return_manifest():
		AchievementManager.record("return_manifest")
		manifest_message.text = "MANIFEST COMPLETE · every sample is sealed aboard."
	elif loaded_now > 0:
		manifest_message.text = "%d samples sealed. The manifest highlights what is still missing." % loaded_now
	else:
		manifest_message.text = "No required samples in the backpack: explore the biomes listed in the manifest."
	_refresh_return_manifest()


func _has_full_return_manifest() -> bool:
	for definition in get_return_manifest_catalog():
		if not bool(loaded_return_samples.get(str(definition.get("item_id", "")), false)):
			return false
	return bool(loaded_return_samples.get(ALIEN_LIFE_SAMPLE_ITEM_ID, false))


func _record_fuel_ready_if_needed() -> void:
	if sabatier_qualified and methane_kg >= METHANE_CAPACITY_KG - 0.001:
		AchievementManager.record("rocket_fueled")


func _try_launch_return() -> void:
	if return_launch_in_progress or return_launch_finished:
		return
	if not _has_full_return_manifest():
		manifest_message.text = "LAUNCH BLOCKED · at least one manifest sample is missing."
		return
	if not sabatier_qualified:
		manifest_message.text = "LAUNCH BLOCKED · the Sabatier must produce methane with power and H₂ connected."
		return
	if methane_kg < METHANE_CAPACITY_KG - 0.001:
		manifest_message.text = "LAUNCH BLOCKED · fuel %.1f / %.0f kg." % [methane_kg, METHANE_CAPACITY_KG]
		return
	AchievementManager.record("return_launch")
	_close_return_manifest()
	return_launch_in_progress = true
	return_launch_elapsed = 0.0
	if landed_rocket != null:
		landed_rocket.visible = false
	_create_return_launch_overlay()


func _create_world_manifest_prompt() -> void:
	world_manifest_prompt = Label.new()
	world_manifest_prompt.name = "ReturnManifestPrompt"
	world_manifest_prompt.position = Vector2(-116.0, -86.0)
	world_manifest_prompt.size = Vector2(232.0, 28.0)
	world_manifest_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_manifest_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_manifest_prompt.add_theme_font_override("font", UI_FONT)
	world_manifest_prompt.add_theme_font_size_override("font_size", 11)
	world_manifest_prompt.add_theme_color_override("font_color", Color("fff1a3"))
	world_manifest_prompt.add_theme_color_override("font_outline_color", Color("071015"))
	world_manifest_prompt.add_theme_constant_override("outline_size", 3)
	world_manifest_prompt.z_index = 20
	world_manifest_prompt.visible = false
	add_child(world_manifest_prompt)


func _update_world_manifest_prompt() -> void:
	if world_manifest_prompt == null:
		return
	var nearby := player != null and player.global_position.distance_to(global_position + LANDED_ROCKET_OFFSET) <= MANIFEST_INTERACTION_DISTANCE
	world_manifest_prompt.visible = nearby and manifest_root != null and not manifest_root.visible and not return_launch_finished
	if world_manifest_prompt.visible:
		var readiness := get_return_readiness()
		world_manifest_prompt.text = "E  ·  ROCKET MANIFEST\n%d/%d SAMPLES" % [int(readiness["geology_loaded"]) + int(bool(readiness["life_loaded"])), int(readiness["geology_total"]) + 1]


func _create_return_manifest_ui() -> void:
	manifest_layer = CanvasLayer.new()
	manifest_layer.name = "RocketManifestLayer"
	manifest_layer.layer = 130
	add_child(manifest_layer)
	manifest_root = Control.new()
	manifest_root.name = "RocketManifestRoot"
	manifest_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	manifest_root.add_theme_font_override("font", UI_FONT)
	manifest_root.visible = false
	manifest_root.mouse_filter = Control.MOUSE_FILTER_STOP
	manifest_layer.add_child(manifest_root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.018, 0.025, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	manifest_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450.0
	panel.offset_top = -300.0
	panel.offset_right = 450.0
	panel.offset_bottom = 300.0
	panel.add_theme_stylebox_override("panel", _return_panel_style(Color("78d6ed")))
	manifest_root.add_child(panel)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 18)
	margins.add_theme_constant_override("margin_right", 18)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margins.add_child(content)
	var title := Label.new()
	title.text = "// EARTH RETURN MANIFEST //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("ffe380"))
	content.add_child(title)
	manifest_status = Label.new()
	manifest_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	manifest_status.add_theme_font_size_override("font_size", 13)
	manifest_status.add_theme_color_override("font_color", Color("c9e9ee"))
	content.add_child(manifest_status)
	var note := Label.new()
	note.text = "Load one unit of each sample. Loaded samples remain sealed in the rocket."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("a9c2cb"))
	content.add_child(note)
	manifest_scroll = ScrollContainer.new()
	manifest_scroll.custom_minimum_size = Vector2(0, 350)
	manifest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	manifest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	manifest_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	manifest_scroll.add_theme_stylebox_override("panel", _return_panel_style(Color("315f70"), Color("07121a")))
	content.add_child(manifest_scroll)
	manifest_list = RichTextLabel.new()
	manifest_list.bbcode_enabled = true
	manifest_list.fit_content = false
	manifest_list.scroll_active = false
	# The ScrollContainer needs a child taller than its viewport before it can
	# expose a scrollbar. The height is calculated again whenever the manifest
	# text changes below.
	manifest_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	manifest_list.custom_minimum_size = Vector2(840, 0)
	manifest_list.add_theme_font_override("normal_font", UI_FONT)
	manifest_list.add_theme_font_size_override("normal_font_size", 12)
	manifest_list.add_theme_color_override("default_color", Color("c9d8dc"))
	manifest_scroll.add_child(manifest_list)
	manifest_message = Label.new()
	manifest_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	manifest_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	manifest_message.add_theme_font_size_override("font_size", 11)
	manifest_message.add_theme_color_override("font_color", Color("ffe07a"))
	content.add_child(manifest_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	manifest_load_button = _return_button("LOAD AVAILABLE SAMPLES", Color("2f6571"))
	manifest_load_button.pressed.connect(_load_available_return_samples)
	actions.add_child(manifest_load_button)
	manifest_launch_button = _return_button("LAUNCH ROCKET", Color("6f4730"))
	manifest_launch_button.pressed.connect(_try_launch_return)
	actions.add_child(manifest_launch_button)
	var close_button := _return_button("ESC · CLOSE", Color("334550"))
	close_button.pressed.connect(_close_return_manifest)
	actions.add_child(close_button)


func _refresh_return_manifest() -> void:
	if manifest_list == null or manifest_status == null:
		return
	var readiness := get_return_readiness()
	var lines := PackedStringArray()
	lines.append("[color=#8ee9f3][b]GEOLOGICAL SAMPLES  %d / %d[/b][/color]" % [int(readiness["geology_loaded"]), int(readiness["geology_total"])])
	for definition in get_return_manifest_catalog():
		var item_id := str(definition.get("item_id", ""))
		var loaded := bool(loaded_return_samples.get(item_id, false))
		var mark := "[color=#74e5a2]✓ LOADED[/color]" if loaded else "[color=#ffb86b]○ MISSING[/color]"
		lines.append("%s  [b]%s[/b]  —  %s  —  rarity: %s" % [mark, str(definition.get("name", "Sample")), str(definition.get("biome", "Unknown biome")), _rarity_label(str(definition.get("rarity", "common")))])
	var life_loaded := bool(readiness["life_loaded"])
	lines.append("")
	lines.append("[color=#80ffcf][b]BIOLOGICAL SAMPLE[/b][/color]")
	lines.append("%s  Alien life sample — deep-ice laboratory" % [("[color=#74e5a2]✓ LOADED[/color]" if life_loaded else "[color=#ffb86b]○ MISSING[/color]")])
	lines.append("")
	lines.append("[color=#ffe380][b]PROPULSION[/b][/color]")
	lines.append("%s  Sabatier: placement, power, and H₂ verified" % [("[color=#74e5a2]✓ READY[/color]" if sabatier_qualified else "[color=#ffb86b]○ CONNECT AND START[/color]")])
	lines.append("%s  Methane: %.1f / %.0f kg" % [("[color=#74e5a2]✓ FULL[/color]" if methane_kg >= METHANE_CAPACITY_KG - 0.001 else "[color=#ffb86b]○ FILLING[/color]"), methane_kg, METHANE_CAPACITY_KG])
	manifest_list.text = "\n".join(lines)
	# RichTextLabel itself does not grow when fit_content is disabled, so make
	# the content explicitly taller than the 350 px viewport for long lists.
	manifest_list.custom_minimum_size = Vector2(840, maxf(350.0, 28.0 + float(lines.size()) * 20.0))
	manifest_status.text = "MANIFEST  %d / %d   ·   PROPULSION %s   ·   FUEL %.0f / %.0f kg" % [int(readiness["geology_loaded"]) + int(life_loaded), int(readiness["geology_total"]) + 1, "READY" if sabatier_qualified else "PENDING VERIFICATION", methane_kg, METHANE_CAPACITY_KG]
	manifest_launch_button.disabled = not bool(readiness["ready"])
	manifest_load_button.disabled = _has_full_return_manifest()
	if manifest_message.text.is_empty():
		manifest_message.text = "Complete the manifest, produce methane with the Sabatier, then launch the rocket."


func _rarity_label(rarity: String) -> String:
	match rarity:
		"rare": return "RARE"
		"ultra_rare": return "ULTRA-RARE"
		_: return "COMMON"


func _return_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 38)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _return_panel_style(color, color.lightened(0.22)))
	button.add_theme_stylebox_override("hover", _return_panel_style(color.lightened(0.12), Color("fff0a2")))
	return button


func _return_panel_style(border: Color, fill: Color = Color("10202a")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _create_return_launch_overlay() -> void:
	return_launch_layer = CanvasLayer.new()
	return_launch_layer.name = "ReturnLaunchCinematic"
	return_launch_layer.layer = 500
	return_launch_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(return_launch_layer)
	return_launch_root = Control.new()
	return_launch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return_launch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_launch_layer.add_child(return_launch_root)
	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.color = Color("28140f")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_launch_root.add_child(sky)
	return_launch_sprite = Sprite2D.new()
	return_launch_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return_launch_sprite.scale = Vector2.ONE * 2.7
	return_launch_sprite.texture = rocket_frames[FLIGHT_FIRST_FRAME]
	return_launch_root.add_child(return_launch_sprite)
	return_launch_caption = Label.new()
	return_launch_caption.anchor_left = 0.0
	return_launch_caption.anchor_top = 0.82
	return_launch_caption.anchor_right = 1.0
	return_launch_caption.anchor_bottom = 0.82
	return_launch_caption.offset_top = -26.0
	return_launch_caption.offset_bottom = 26.0
	return_launch_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_launch_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return_launch_caption.text = "LAUNCH CONFIRMED // SAMPLES EN ROUTE TO EARTH"
	return_launch_caption.add_theme_font_override("font", UI_FONT)
	return_launch_caption.add_theme_font_size_override("font_size", 16)
	return_launch_caption.add_theme_color_override("font_color", Color("fff0a2"))
	return_launch_caption.add_theme_color_override("font_outline_color", Color("020308"))
	return_launch_caption.add_theme_constant_override("outline_size", 4)
	return_launch_root.add_child(return_launch_caption)


func _update_return_launch(delta: float) -> void:
	if return_launch_sprite == null:
		return
	return_launch_elapsed += delta
	var viewport := get_viewport().get_visible_rect().size
	var progress := clampf(return_launch_elapsed / RETURN_LAUNCH_DURATION, 0.0, 1.0)
	return_launch_sprite.position = Vector2(viewport.x * 0.5, lerpf(viewport.y * 0.78, -110.0, _smooth(progress)))
	var frame_offset := int(floor(return_launch_elapsed * FLIGHT_FPS)) % FLIGHT_FRAME_COUNT
	return_launch_sprite.texture = rocket_frames[FLIGHT_FIRST_FRAME + frame_offset]
	return_launch_sprite.scale = Vector2.ONE * lerpf(2.7, 1.25, progress)
	if progress >= 1.0:
		return_launch_in_progress = false
		return_launch_finished = true
		return_launch_sprite.visible = false
		return_launch_caption.anchor_top = 0.5
		return_launch_caption.anchor_bottom = 0.5
		return_launch_caption.offset_top = -46.0
		return_launch_caption.offset_bottom = 46.0
		return_launch_caption.text = "MISSION COMPLETE\nMARS SAMPLES ARE TRAVELING TO EARTH"


func _unhandled_input(event: InputEvent) -> void:
	if manifest_root == null or not manifest_root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_return_manifest()
		get_viewport().set_input_as_handled()


func contains_world_point(world_point: Vector2) -> bool:
	return Rect2(global_position - Vector2(32.0, 32.0), Vector2(64.0, 64.0)).has_point(world_point)


func get_thermal_shelter_bonus_c() -> float:
	# The landing module is not a complete habitat yet, but its walls and
	# shielding partly reduce heat loss.
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
