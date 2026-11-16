class_name ResearchMachine
extends Node2D

## Scientific instruments installed in any habitat dome. Each analysis consumes one
## rock sample and produces a report to transmit to Earth.

const TILE_SIZE := 16
const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const ROCK_RESOURCE := preload("res://scripts/rock.gd")
const INTERACTION_DISTANCE := 58.0
const ANIMATION_FRAME_SECONDS := 0.16
const REPORT_TRANSMISSION_SECONDS := 4.0
const MAX_UPGRADE_LEVEL := 5
const FINAL_UPGRADED_ANALYSIS_SECONDS := 40.0
const ANALYSIS_POWER_DEMAND_KW := 240.0
const ANCIENT_LIFE_REPORT_BONUS := 10_000_000_000
const UPGRADE_COSTS: Array[int] = [175_000_000, 250_000_000, 350_000_000, 500_000_000, 700_000_000]
const RESEARCH_TEXTURES := {
	"xrd": {
		"idle": preload("res://assets/sprites/research/xrd_idle.png"),
		"active": preload("res://assets/sprites/research/xrd_active.png"),
		"complete": preload("res://assets/sprites/research/xrd_complete.png"),
	},
	"raman": {
		"idle": preload("res://assets/sprites/research/raman_idle.png"),
		"active": preload("res://assets/sprites/research/raman_active.png"),
		"complete": preload("res://assets/sprites/research/raman_complete.png"),
	},
	"icp_ms": {
		"idle": preload("res://assets/sprites/research/icp_ms_idle.png"),
		"active": preload("res://assets/sprites/research/icp_ms_active.png"),
		"complete": preload("res://assets/sprites/research/icp_ms_complete.png"),
	},
}

const DEFINITIONS := {
	"xrd_diffractometer": {
		"name": "X-ray Diffractometer",
		"short_name": "XRD DIFFRACTOMETER",
		"size": Vector2i(32, 16),
		"seconds": 150.0,
		"reward": 1_000_000_000,
		"biosignature_chance": 0.20,
		"principle": "X-ray diffraction identifies the sample's crystalline phases from the geometry of its atomic lattice.",
	},
	"raman_spectrometer": {
		"name": "Raman Spectrometer",
		"short_name": "RAMAN SPECTROMETER",
		"size": Vector2i(32, 16),
		"seconds": 180.0,
		"reward": 1_300_000_000,
		"biosignature_chance": 0.35,
		"principle": "Laser Raman scattering reveals molecular bonds and mineral composition without destroying the sample.",
	},
	"icp_ms": {
		"name": "ICP-MS Spectrometer",
		"short_name": "ICP-MS",
		"size": Vector2i(48, 16),
		"seconds": 240.0,
		"reward": 1_900_000_000,
		"biosignature_chance": 0.55,
		"principle": "Inductively coupled plasma ionizes the sample; mass spectrometry measures its elements and their abundances.",
	},
}

enum State { IDLE, ANALYZING, COMPLETE }

var machine_id := ""
var is_preview := false
var placement_rotation := 0
var state := State.IDLE
var upgrade_level := 0
var network_enabled := true
var powered := false
var study_elapsed := 0.0
var report_elapsed := 0.0
var animation_elapsed := 0.0
var animation_frame := 0
var sample_name := ""
var sample_id := ""
var sample_biome := ""
var sample_rarity := ""
var sample_research_multiplier := 1.0
var sample_is_primordial_ice := false
var biosignature_chance := 0.0
var ancient_life_detected := false
var report_signed := false
var last_report_reward := 0
var sprite: Sprite2D
var physics_body: StaticBody2D
var interaction_label: Label
var _life_rng := RandomNumberGenerator.new()
var _sample_picker_layer: CanvasLayer
var _sample_picker_root: Control
var _sample_picker_rows: VBoxContainer
var _sample_picker_player: Node2D


func setup(new_machine_id: String, preview: bool = false, new_placement_rotation: int = 0) -> void:
	machine_id = new_machine_id
	is_preview = preview
	placement_rotation = posmod(new_placement_rotation, 4)
	if is_node_ready():
		_apply_placement_rotation()
		_refresh_visual()


static func get_definition(new_machine_id: String) -> Dictionary:
	return DEFINITIONS.get(new_machine_id, {}).duplicate(true)


static func get_icon_texture(machine_id_value: String) -> Texture2D:
	return _texture_for_state(machine_id_value, State.IDLE)


static func _texture_for_state(machine_id_value: String, machine_state: State) -> Texture2D:
	var state_key := "idle"
	if machine_state == State.ANALYZING:
		state_key = "active"
	elif machine_state == State.COMPLETE:
		state_key = "complete"
	# Use imported project resources rather than runtime ImageTextures. The latter
	# may be invalidated on some renderers, leaving both the world sprite and UI
	# thumbnails fully transparent despite the PNG file being present.
	var machine_textures: Dictionary = RESEARCH_TEXTURES.get(_asset_prefix_for(machine_id_value), {})
	return machine_textures.get(state_key, null) as Texture2D


static func _asset_prefix_for(machine_id_value: String) -> String:
	match machine_id_value:
		"xrd_diffractometer":
			return "xrd"
		"raman_spectrometer":
			return "raman"
		"icp_ms":
			return "icp_ms"
	return "xrd"


static func rotated_size_for(machine_id_value: String, new_placement_rotation: int = 0) -> Vector2i:
	var size: Vector2i = get_definition(machine_id_value).get("size", Vector2i(TILE_SIZE, TILE_SIZE))
	return Vector2i(size.y, size.x) if posmod(new_placement_rotation, 2) == 1 else size


static func world_position_for(machine_id_value: String, cell: Vector2i, new_placement_rotation: int = 0) -> Vector2:
	var size := rotated_size_for(machine_id_value, new_placement_rotation)
	return Vector2(cell * TILE_SIZE) + Vector2(float(size.x) * 0.5, float(size.y) * 0.5)


static func footprint_rect_for(machine_id_value: String, world_position: Vector2, new_placement_rotation: int = 0) -> Rect2:
	var size := rotated_size_for(machine_id_value, new_placement_rotation)
	var dimensions := Vector2(size)
	return Rect2(world_position - dimensions * 0.5, dimensions)


static func can_place_at(machine_id_value: String, world_position: Vector2, new_placement_rotation: int = 0) -> bool:
	if not DEFINITIONS.has(machine_id_value):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var footprint := footprint_rect_for(machine_id_value, world_position, new_placement_rotation)
	var host_dome: Node2D
	for dome in tree.get_nodes_in_group("base_domes"):
		# All habitat domes are valid technical rooms. The greenhouse uses the same
		# dome infrastructure, but laboratory machines must not occupy its beds.
		if not dome is Node2D or dome.is_in_group("greenhouses"):
			continue
		var dome_node := dome as Node2D
		if _footprint_is_inside_dome(footprint, dome_node):
			host_dome = dome_node
			break
	if host_dome == null:
		return false
	var player := tree.get_first_node_in_group("player") as Node2D
	if player != null and footprint.grow(12.0).has_point(player.global_position):
		return false
	for rock in tree.get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and footprint.grow(13.0).has_point((rock as Node2D).global_position):
			return false
	var registry := tree.root.get_node_or_null("BuildableRegistry")
	if registry == null:
		return true
	for entry in registry.call("get_entries"):
		var other := entry.get("node") as Node2D
		if other == null or not is_instance_valid(other) or other == host_dome:
			continue
		if other.has_method("get_footprint_rect") and footprint.intersects(other.call("get_footprint_rect")):
			return false
		if other.has_method("contains_world_point"):
			for point in _footprint_samples(footprint):
				if bool(other.call("contains_world_point", point)):
					return false
	return true


static func _footprint_is_inside_dome(footprint: Rect2, dome: Node2D) -> bool:
	if not dome.has_method("contains_world_point"):
		return false
	for point in _footprint_samples(footprint):
		if not bool(dome.call("contains_world_point", point)):
			return false
	return true


static func _footprint_samples(footprint: Rect2) -> Array[Vector2]:
	var inset := Vector2(1.0, 1.0)
	return [
		footprint.get_center(),
		footprint.position + inset,
		Vector2(footprint.end.x, footprint.position.y) - inset,
		Vector2(footprint.position.x, footprint.end.y) + Vector2(1.0, -1.0),
		footprint.end - inset,
	]


static func place(parent: Node, new_machine_id: String, cell: Vector2i, new_placement_rotation: int = 0) -> Node2D:
	var target := world_position_for(new_machine_id, cell, new_placement_rotation)
	if not can_place_at(new_machine_id, target, new_placement_rotation):
		return null
	var machine := ResearchMachine.new()
	machine.setup(new_machine_id, false, new_placement_rotation)
	parent.add_child(machine)
	machine.global_position = target
	var achievements := parent.get_node_or_null("/root/AchievementManager")
	if achievements != null:
		achievements.call("record", "first_lab")
	return machine


func _ready() -> void:
	z_index = 3
	_life_rng.randomize()
	sprite = Sprite2D.new()
	sprite.name = "ResearchSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_apply_placement_rotation()
	_refresh_visual()
	if is_preview:
		return
	add_to_group("research_machines")
	_setup_collision()
	_setup_interaction_label()
	_build_sample_picker_ui()
	var registry := get_node_or_null("/root/BuildableRegistry")
	if registry != null:
		registry.call("register_buildable", self, get_display_name(), "research", Callable(self, "pickup"))
	call_deferred("_register_power_consumer")


func _exit_tree() -> void:
	if _sample_picker_layer != null and is_instance_valid(_sample_picker_layer):
		var ui_state := get_node_or_null("/root/UIState")
		if ui_state != null:
			ui_state.call("close_modal", &"research_sample_picker")
		_sample_picker_layer.queue_free()
	if not is_preview:
		var power_grid := get_node_or_null("/root/PowerGrid")
		if power_grid != null:
			power_grid.call("unregister_consumer", self)
		var registry := get_node_or_null("/root/BuildableRegistry")
		if registry != null:
			registry.call("unregister_buildable", self)


func _process(delta: float) -> void:
	if is_preview:
		return
	if state == State.ANALYZING:
		# High-precision laboratories work only with an active grid: while analyzing,
		# they demand 240 kW, more than two solar panels provide individually.
		if powered:
			study_elapsed = minf(get_analysis_seconds(), study_elapsed + maxf(delta, 0.0))
		if study_elapsed >= get_analysis_seconds():
			state = State.COMPLETE
			report_elapsed = 0.0
			animation_elapsed = 0.0
			animation_frame = 0
			_refresh_visual()
			_register_power_consumer()
	elif state == State.COMPLETE:
		_animation_step(delta)
	_update_interaction_label()
	if state == State.ANALYZING:
		if powered:
			_animation_step(delta)


func _unhandled_input(event: InputEvent) -> void:
	# The sample picker is the laboratory's own modal window. Escape must close it
	# even when UIState blocks the player.
	if _sample_picker_root == null or not _sample_picker_root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_sample_picker()
		get_viewport().set_input_as_handled()


func _animation_step(delta: float) -> void:
	animation_elapsed += delta
	if animation_elapsed < ANIMATION_FRAME_SECONDS:
		return
	animation_elapsed = 0.0
	animation_frame = (animation_frame + 1) % 4
	_refresh_visual()


func _setup_collision() -> void:
	physics_body = StaticBody2D.new()
	physics_body.name = "ResearchMachineCollision"
	physics_body.collision_layer = 1
	physics_body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = get_footprint_rect().size
	collision.shape = shape
	physics_body.add_child(collision)
	add_child(physics_body)


func _setup_interaction_label() -> void:
	interaction_label = Label.new()
	interaction_label.name = "ResearchPrompt"
	interaction_label.position = Vector2(-86.0, -35.0)
	interaction_label.size = Vector2(172.0, 28.0)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_label.add_theme_font_size_override("font_size", 10)
	interaction_label.add_theme_color_override("font_color", Color("dff7ff"))
	interaction_label.add_theme_color_override("font_outline_color", Color("071118"))
	interaction_label.add_theme_constant_override("outline_size", 3)
	add_child(interaction_label)


func _build_sample_picker_ui() -> void:
	_sample_picker_layer = CanvasLayer.new()
	_sample_picker_layer.name = "ResearchSamplePickerLayer"
	_sample_picker_layer.layer = 125
	get_tree().current_scene.add_child(_sample_picker_layer)
	_sample_picker_root = Control.new()
	_sample_picker_root.name = "ResearchSamplePicker"
	_sample_picker_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sample_picker_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_sample_picker_root.focus_mode = Control.FOCUS_ALL
	_sample_picker_root.gui_input.connect(_on_sample_picker_gui_input)
	_sample_picker_root.visible = false
	_sample_picker_layer.add_child(_sample_picker_root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02070acc")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_sample_picker_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360.0
	panel.offset_right = 360.0
	panel.offset_top = -245.0
	panel.offset_bottom = 245.0
	panel.add_theme_font_override("font", UI_FONT)
	panel.add_theme_stylebox_override("panel", _sample_picker_panel_style())
	_sample_picker_root.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	panel.add_child(contents)
	var title := _picker_label("// SELECT SAMPLE FOR ANALYSIS //", 17, Color("ffe38a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(title)
	var hint := _picker_label("You have multiple rocks: choose the stack the laboratory will consume.", 11, Color("b8d0d6"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680.0, 360.0)
	contents.add_child(scroll)
	_sample_picker_rows = VBoxContainer.new()
	_sample_picker_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_picker_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_sample_picker_rows)
	var close := Button.new()
	close.text = "[ CANCEL · ESC ]"
	close.custom_minimum_size = Vector2(220.0, 34.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_override("font", UI_FONT)
	close.pressed.connect(_close_sample_picker)
	contents.add_child(close)


func _open_sample_picker(player: Node2D, choices: Array) -> void:
	if _sample_picker_root == null or _sample_picker_rows == null:
		return
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and not bool(ui_state.call("try_open_modal", &"research_sample_picker")):
		return
	_sample_picker_player = player
	for child in _sample_picker_rows.get_children():
		child.queue_free()
	for choice_variant in choices:
		var choice: Dictionary = choice_variant
		var item_id := str(choice.get("id", ""))
		var definition: Dictionary = ROCK_RESOURCE.definition_for_item_id(item_id)
		var rarity := str(definition.get("rarity", "common"))
		var rarity_label := "ULTRA RARE" if rarity == "ultra_rare" else ("RARE" if rarity == "rare" else "COMMON")
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(660.0, 58.0)
		button.add_theme_stylebox_override("normal", _sample_picker_button_style(Color("12232d"), Color("477786")))
		button.add_theme_stylebox_override("hover", _sample_picker_button_style(Color("214653"), Color("8ee7f2")))
		button.add_theme_stylebox_override("pressed", _sample_picker_button_style(Color("315f6d"), Color("ffe38a")))
		button.pressed.connect(_select_sample.bind(item_id))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12.0
		row.offset_right = -12.0
		row.offset_top = 6.0
		row.offset_bottom = -6.0
		row.add_theme_constant_override("separation", 12)
		button.add_child(row)
		var icon := TextureRect.new()
		icon.texture = ROCK_RESOURCE.get_icon_texture_for_item_id(item_id)
		icon.custom_minimum_size = Vector2(42.0, 42.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var text := _picker_label("%s  ×%d\n%s · %s · research value ×%.2f" % [str(choice.get("name", "Rock")).to_upper(), int(choice.get("count", 0)), str(definition.get("biome", "unknown origin")), rarity_label, float(definition.get("research_multiplier", 1.0))], 12, Color("dcecef"))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)
		_sample_picker_rows.add_child(button)
	_sample_picker_root.visible = true
	_sample_picker_root.grab_focus()


func _select_sample(item_id: String) -> void:
	var player := _sample_picker_player
	_close_sample_picker()
	if player == null or not is_instance_valid(player):
		return
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not inventory.has_method("take_rock_sample"):
		return
	var sample: Dictionary = inventory.call("take_rock_sample", item_id)
	if not sample.is_empty():
		_start_analysis(sample)


func _close_sample_picker() -> void:
	if _sample_picker_root != null:
		_sample_picker_root.visible = false
	_sample_picker_player = null
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", &"research_sample_picker")


func _on_sample_picker_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_sample_picker()
		_sample_picker_root.accept_event()


func _picker_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("02070a"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _sample_picker_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1720f5")
	style.border_color = Color("6ed2e6")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _sample_picker_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _update_interaction_label() -> void:
	if interaction_label == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var nearby := player != null and player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE
	interaction_label.visible = nearby and not _is_modal_ui_open()
	if interaction_label.visible:
		interaction_label.text = get_prompt_for_player(player)


func get_display_name() -> String:
	return str(get_definition(machine_id).get("name", "Scientific Laboratory"))


func get_footprint_rect() -> Rect2:
	return footprint_rect_for(machine_id, global_position, placement_rotation)


func contains_world_point(world_position: Vector2) -> bool:
	return get_footprint_rect().grow(4.0).has_point(world_position)


func get_occupied_power_cells() -> Array[Vector2i]:
	var rect := get_footprint_rect()
	var cells: Array[Vector2i] = []
	var min_cell := Vector2i(floori(rect.position.x / TILE_SIZE), floori(rect.position.y / TILE_SIZE))
	var max_cell := Vector2i(floori((rect.end.x - 0.1) / TILE_SIZE), floori((rect.end.y - 0.1) / TILE_SIZE))
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func get_analysis_seconds() -> float:
	var base_seconds := float(get_definition(machine_id).get("seconds", 180.0))
	return lerpf(base_seconds, FINAL_UPGRADED_ANALYSIS_SECONDS, float(upgrade_level) / float(MAX_UPGRADE_LEVEL))


func get_base_analysis_seconds() -> float:
	return float(get_definition(machine_id).get("seconds", 180.0))


func get_power_connection_cell() -> Vector2i:
	# Laboratories sit inside habitat domes, where cables must not cross floors or
	# walls. They use their host dome's exterior electrical connector, while their
	# power demand remains separate.
	var host_dome := _get_host_base_dome()
	if host_dome != null and host_dome.has_method("get_power_connection_cell"):
		return Vector2i(host_dome.call("get_power_connection_cell"))
	var footprint := get_footprint_rect()
	return Vector2i(floori((footprint.position.x - TILE_SIZE * 0.5) / TILE_SIZE), floori(global_position.y / TILE_SIZE))


func get_power_attach_direction() -> Vector2i:
	var host_dome := _get_host_base_dome()
	if host_dome != null and host_dome.has_method("get_power_attach_direction"):
		return Vector2i(host_dome.call("get_power_attach_direction"))
	return Vector2i.RIGHT


func get_power_demand_kw() -> float:
	return ANALYSIS_POWER_DEMAND_KW if state == State.ANALYZING else 0.0


func set_network_enabled(value: bool) -> void:
	if is_preview or network_enabled == value:
		return
	network_enabled = value
	if not network_enabled:
		set_powered(false)
	_register_power_consumer()


func is_network_enabled() -> bool:
	return network_enabled


func set_powered(value: bool) -> void:
	powered = value and network_enabled


func get_power_connection_label() -> String:
	if not network_enabled:
		return "GRID DISABLED"
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid == null:
		return "GRID UNAVAILABLE"
	return "CONNECTED TO GRID" if bool(power_grid.get("connection_ok").get(self, false)) else "POWER CABLE NOT CONNECTED"


func get_reward() -> int:
	# After delivery, the UI and callers can still ask for the report's value. Keep
	# it instead of losing it when the sample resets during the transition to IDLE.
	if state == State.IDLE and sample_id.is_empty() and last_report_reward > 0:
		return last_report_reward
	var multiplier := 1.0
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("get_research_reward_multiplier"):
		multiplier = float(achievements.call("get_research_reward_multiplier", machine_id, sample_rarity))
	# Research value belongs to the sample, not only the machine: a rare discovery
	# extracted in a remote biome produces a more valuable report.
	var reward := roundi(float(get_definition(machine_id).get("reward", 0)) * sample_research_multiplier * multiplier)
	if sample_is_primordial_ice and ancient_life_detected:
		reward += ANCIENT_LIFE_REPORT_BONUS
	return reward


func get_biosignature_chance() -> float:
	return float(get_definition(machine_id).get("biosignature_chance", 0.20)) if sample_is_primordial_ice else 0.0


func get_remaining_seconds() -> float:
	return maxf(0.0, get_analysis_seconds() - study_elapsed)


func get_prompt_for_player(_player: Node2D) -> String:
	if state == State.ANALYZING:
		var analysis_status := "%s · analysis %s" % [str(get_definition(machine_id).get("short_name", "RESEARCH")), _format_time(get_remaining_seconds())]
		if sample_is_primordial_ice:
			analysis_status += "\nGAME MODEL · compatible signal %.0f%%" % (biosignature_chance * 100.0)
		return analysis_status if powered else analysis_status + "\nPAUSED · CONNECT 240 kW"
	if state == State.COMPLETE:
		var report_header := "COMPATIBLE SIGNAL DETECTED" if sample_is_primordial_ice and ancient_life_detected else "REPORT READY"
		if not report_signed:
			return "%s · SIGNATURE REQUIRED\nE · SIGN REPORT · %s" % [report_header, _format_money(get_reward())]
		return "%s · REPORT SIGNED\nE · SEND TO EARTH · %s" % [report_header, _format_money(get_reward())]
	if upgrade_level >= MAX_UPGRADE_LEVEL:
		return "E · ANALYZE A ROCK\nMAXIMUM UPGRADE · 40 s"
	var inventory := get_node_or_null("/root/Inventory")
	var upgrade_line := "U · UPGRADE %d→%d · %s" % [upgrade_level, upgrade_level + 1, _format_money(get_next_upgrade_cost())]
	if inventory != null:
		var available_sample: Dictionary = inventory.call("get_first_rock_sample")
		if not available_sample.is_empty():
			return "E · ANALYZE A ROCK\n" + upgrade_line
	return "BRING A ROCK TO THE LABORATORY\n" + upgrade_line


func try_interact(player: Node2D) -> bool:
	if is_preview or player == null or player.global_position.distance_to(global_position) > INTERACTION_DISTANCE:
		return false
	if state == State.COMPLETE:
		if not report_signed:
			report_signed = true
			_update_interaction_label()
			return true
		_deliver_report()
		return true
	if state != State.IDLE:
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null:
		return false
	var choices: Array = inventory.call("get_rock_sample_choices") if inventory.has_method("get_rock_sample_choices") else []
	if choices.is_empty():
		return false
	if choices.size() > 1:
		_open_sample_picker(player, choices)
		return true
	var sample: Dictionary = inventory.call("take_rock_sample", str(choices[0].get("id", ""))) if inventory.has_method("take_rock_sample") else inventory.call("take_first_rock_sample")
	return _start_analysis(sample)


func _start_analysis(sample: Dictionary) -> bool:
	if sample.is_empty():
		return false
	sample_id = str(sample.get("id", ""))
	sample_name = str(sample.get("name", "Rock"))
	var sample_definition: Dictionary = ROCK_RESOURCE.definition_for_item_id(sample_id)
	sample_biome = str(sample_definition.get("biome", "Uncatalogued origin"))
	sample_rarity = str(sample_definition.get("rarity", "common"))
	sample_research_multiplier = maxf(0.1, float(sample_definition.get("research_multiplier", 1.0)))
	sample_is_primordial_ice = bool(sample_definition.get("deep_ice", false))
	biosignature_chance = get_biosignature_chance()
	ancient_life_detected = sample_is_primordial_ice and _life_rng.randf() < biosignature_chance
	if sample_is_primordial_ice:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null and achievements.has_method("record_deep_ice_study"):
			achievements.call("record_deep_ice_study")
	state = State.ANALYZING
	study_elapsed = 0.0
	report_signed = false
	animation_elapsed = 0.0
	animation_frame = 0
	_refresh_visual()
	_register_power_consumer()
	return true


func get_next_upgrade_cost() -> int:
	if upgrade_level < 0 or upgrade_level >= MAX_UPGRADE_LEVEL:
		return 0
	return UPGRADE_COSTS[upgrade_level]


func try_upgrade(player: Node2D) -> bool:
	if is_preview or player == null or player.global_position.distance_to(global_position) > INTERACTION_DISTANCE:
		return false
	# Do not change calibration in the middle of an experiment already underway.
	if state != State.IDLE or upgrade_level >= MAX_UPGRADE_LEVEL:
		return false
	var economy := get_node_or_null("/root/Economy")
	var cost := get_next_upgrade_cost()
	if economy == null or cost <= 0 or not bool(economy.call("spend", cost)):
		return false
	upgrade_level += 1
	if upgrade_level >= MAX_UPGRADE_LEVEL:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			match machine_id:
				"xrd_diffractometer":
					achievements.call("record", "xrd_master")
				"raman_spectrometer":
					achievements.call("record", "raman_master")
				"icp_ms":
					achievements.call("record", "icp_master")
	return true


func _deliver_report() -> void:
	if state != State.COMPLETE:
		return
	var report_reward := get_reward()
	var economy := get_node_or_null("/root/Economy")
	if economy != null:
		economy.call("add_funds", report_reward)
	last_report_reward = report_reward
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null:
		# A report is more than a sale: it advances scientific campaigns in the
		# objective board (biomes, rarities, instruments, and transmissions).
		if achievements.has_method("record_research_report"):
			achievements.call("record_research_report", machine_id, sample_id, sample_biome, sample_rarity)
		else:
			achievements.call("record", "first_report")
		if ancient_life_detected and achievements.has_method("record_ancient_life_discovery"):
			achievements.call("record_ancient_life_discovery")
	state = State.IDLE
	study_elapsed = 0.0
	report_elapsed = 0.0
	report_signed = false
	animation_elapsed = 0.0
	animation_frame = 0
	sample_id = ""
	sample_name = ""
	sample_biome = ""
	sample_rarity = ""
	sample_research_multiplier = 1.0
	sample_is_primordial_ice = false
	biosignature_chance = 0.0
	ancient_life_detected = false
	_refresh_visual()
	_register_power_consumer()


func pickup() -> bool:
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not bool(inventory.call("add_item", machine_id, get_display_name(), 1, true)):
		return false
	# Dismantling a laboratory interrupts its analysis or report, but must always
	# be possible: the player cannot become stuck with a machine inside a dome.
	state = State.IDLE
	report_signed = false
	study_elapsed = 0.0
	report_elapsed = 0.0
	queue_free()
	return true


func get_machine_specs() -> Dictionary:
	var status := "READY FOR ANALYSIS"
	var detail := "awaiting a sample"
	var color := Color("8cd9ff")
	if state == State.ANALYZING:
		status = "ANALYSIS IN PROGRESS" if powered else "ANALYSIS PAUSED · GRID UNAVAILABLE"
		detail = "%s · %s · %s · %s remaining" % [sample_name, sample_biome, _rarity_label(), _format_time(get_remaining_seconds())]
		if sample_is_primordial_ice:
			detail += " · compatible signal (model) %.0f%%" % (biosignature_chance * 100.0)
		color = Color("ffe38a")
	elif state == State.COMPLETE:
		status = "COMPATIBLE SIGNAL DETECTED" if ancient_life_detected else "REPORT READY"
		detail = "%s · %s · %s · %s · %s" % [sample_name, sample_biome, _rarity_label(), "sign report" if not report_signed else "ready to send", _format_money(get_reward())]
		color = Color("7fffd4") if ancient_life_detected else Color("72eda0")
	var research_multiplier := 1.0
	var contracts := "awaiting first report"
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null:
		if achievements.has_method("get_research_reward_multiplier"):
			research_multiplier = float(achievements.call("get_research_reward_multiplier", machine_id, sample_rarity))
		if achievements.has_method("get_research_contract_summary"):
			contracts = str(achievements.call("get_research_contract_summary", machine_id))
	return {
		"title": get_display_name().to_upper(),
		"category": "SCIENTIFIC RESEARCH · HABITAT DOME",
		"status": status,
		"status_color": color,
		"principle": str(get_definition(machine_id).get("principle", "")),
		"specs": ["Sample: %s" % detail, "Sample value: ×%.2f · contracts: ×%.2f" % [sample_research_multiplier, research_multiplier], "Compatible signal (game model): %s" % ("DETECTED · bonus %s" % _format_money(ANCIENT_LIFE_REPORT_BONUS) if ancient_life_detected else ("chance %.0f%%" % (biosignature_chance * 100.0) if sample_is_primordial_ice else "not applicable")), "Earth contracts: %s" % contracts, "Upgrade: level %d/%d" % [upgrade_level, MAX_UPGRADE_LEVEL], "Analysis duration: %s (base %s, maximum upgrade: 0:40)" % [_format_time(get_analysis_seconds()), _format_time(get_base_analysis_seconds())], "Next upgrade: %s" % ("MAXIMUM" if upgrade_level >= MAX_UPGRADE_LEVEL else _format_money(get_next_upgrade_cost())), "Analysis demand: %.0f kW" % ANALYSIS_POWER_DEMAND_KW, "Grid: %s" % get_power_connection_label(), "Report reward: %s" % _format_money(get_reward()), "E: rock / report · U: upgrade"],
	}


func _rarity_label() -> String:
	if sample_rarity == "ultra_rare":
		return "ULTRA RARE"
	return "RARE" if sample_rarity == "rare" else "COMMON"


func _refresh_visual() -> void:
	if sprite == null:
		return
	var definition := get_definition(machine_id)
	if definition.is_empty():
		return
	if state == State.IDLE:
		sprite.texture = _texture_for_state(machine_id, State.IDLE)
		return
	var sheet := _texture_for_state(machine_id, state)
	if sheet == null:
		return
	var footprint_size: Vector2i = definition.get("size", Vector2i(TILE_SIZE, TILE_SIZE))
	var frame_width := footprint_size.x
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(animation_frame * frame_width, 0.0, frame_width, TILE_SIZE)
	sprite.texture = frame


func _apply_placement_rotation() -> void:
	rotation = float(placement_rotation) * PI * 0.5


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _format_money(amount: int) -> String:
	var economy := get_node_or_null("/root/Economy")
	if economy != null and economy.has_method("format_money"):
		return str(economy.call("format_money", amount))
	return "$ %d" % amount


func _is_modal_ui_open() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and bool(ui_state.call("blocks_world_actions")):
		return true
	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and bool(inventory.get("is_open")):
		return true
	var shop := get_node_or_null("/root/Shop")
	if shop != null and bool(shop.get("is_open")):
		return true
	var registry := get_node_or_null("/root/BuildableRegistry")
	return registry != null and bool(registry.get("is_modal_open"))


func _register_power_consumer() -> void:
	if is_preview or not is_inside_tree():
		return
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("register_consumer", self, get_power_connection_cell(), get_power_demand_kw(), get_power_attach_direction())


func _get_host_base_dome() -> Node2D:
	if not is_inside_tree():
		return null
	for dome in get_tree().get_nodes_in_group("base_domes"):
		if dome is Node2D and not dome.is_in_group("greenhouses") and dome.has_method("contains_world_point"):
			if bool(dome.call("contains_world_point", global_position)):
				return dome as Node2D
	return null
