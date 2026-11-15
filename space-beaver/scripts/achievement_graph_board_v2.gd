extends CanvasLayer

## Cartographic contract archive. Tabs divide the large graph into readable maps
## while keeping prerequisites visible in the detail panel.

const CARD_SIZE := Vector2(156.0, 88.0)
const GRAPH_SIZE := Vector2(1_500.0, 620.0)
const ROCK_RESOURCE := preload("res://scripts/rock.gd")

const CATEGORIES := [
	{"id": "field", "label": "FIELD", "icon": "◈", "color": Color("e6a66d"), "description": "Samples, exploration, and contracts that need no infrastructure."},
	{"id": "habitat", "label": "BASE", "icon": "⌂", "color": Color("91dfa2"), "description": "Survival, air, water, power, and crops."},
	{"id": "science", "label": "RESEARCH", "icon": "⌬", "color": Color("c6a4ff"), "description": "Laboratories, reports, and high-value scientific contracts."},
	{"id": "return", "label": "RETURN", "icon": "▲", "color": Color("ffe07a"), "description": "From a possible biosignature to a complete manifest and launch to Earth."},
	{"id": "photos", "label": "PHOTOS", "icon": "▣", "color": Color("84dced"), "description": "Photo archive and visual transmissions to Earth."},
]

const CATEGORY_LAYOUTS := {
	"field": {
		"nodes": {
			"first_field_sample": Vector2(72, 126), "field_notes": Vector2(300, 126), "sample_satchel": Vector2(528, 126),
			"surface_catalog": Vector2(756, 52), "surface_anomaly": Vector2(756, 202),
			"first_horizon": Vector2(72, 406), "biome_survey": Vector2(300, 406), "long_range_survey": Vector2(528, 340), "exploration_suit": Vector2(756, 340), "polar_expedition": Vector2(528, 484),
			"perseverance_photo": Vector2(1_020, 126), "perseverance_report": Vector2(1_020, 276), "perseverance_repair": Vector2(1_020, 426),
		},
		"sections": [["SURFACE COLLECTION", Vector2(72, 52)], ["EXPLORATION", Vector2(72, 332)], ["PERSEVERANCE MISSION", Vector2(1_020, 52)]],
	},
	"habitat": {
		"nodes": {
			"first_base": Vector2(60, 276), "airlock_cycle": Vector2(290, 112), "ice_drill": Vector2(520, 112), "refill_bottle": Vector2(750, 112),
			"stable_grid": Vector2(290, 420), "greenhouse": Vector2(520, 420), "first_planting": Vector2(750, 354), "first_harvest": Vector2(980, 420),
			"genetic_modification": Vector2(1_190, 354), "genetic_replacement": Vector2(1_190, 480),
		},
		"sections": [["ACCESS AND WATER CYCLE", Vector2(290, 44)], ["HABITAT AND FOOD", Vector2(290, 350)], ["BIOENGINEERING", Vector2(1_190, 292)]],
	},
	"science": {
		"nodes": {
			"first_lab": Vector2(48, 294), "first_extraction": Vector2(270, 88), "first_report": Vector2(270, 294), "chain_of_custody": Vector2(492, 294),
			"xrd_fieldwork": Vector2(714, 78), "xrd_master": Vector2(936, 40),
			"raman_fieldwork": Vector2(714, 198), "raman_master": Vector2(936, 170),
			"icp_fieldwork": Vector2(714, 318), "icp_master": Vector2(936, 300),
			"rare_signal": Vector2(714, 458), "rare_constellation": Vector2(936, 456),
			"data_convoy": Vector2(714, 400), "earth_relay": Vector2(1_158, 344),
			"regional_atlas": Vector2(936, 534), "planetary_archive": Vector2(1_158, 520),
			"science_center": Vector2(1_158, 158), "martian_dividend": Vector2(1_360, 158),
		},
		"sections": [["FOUNDATION", Vector2(48, 224)], ["INSTRUMENTS", Vector2(714, 28)], ["TRANSMISSION", Vector2(714, 382)], ["DIRECTORATE", Vector2(1_158, 108)]],
	},
	"return": {
		"nodes": {
			"polar_drill": Vector2(36, 74), "primordial_ice": Vector2(252, 74), "deep_ice_study": Vector2(468, 74), "ancient_life": Vector2(684, 74), "life_relay": Vector2(900, 74), "life_sample_secured": Vector2(1_116, 74),
			"return_manifest": Vector2(144, 258), "sabatier_online": Vector2(410, 258), "rocket_fueled": Vector2(676, 258), "return_launch": Vector2(942, 258),
		},
		"sections": [["DISCOVERY AND CONTAINMENT", Vector2(36, 30)], ["RETURN PREPARATION", Vector2(144, 216)], ["REQUIRED SAMPLE CATALOG", Vector2(36, 382)]],
	},
	"photos": {
		"nodes": {
			"first_photo": Vector2(52, 276), "contact_sheet": Vector2(276, 276), "mars_postcard": Vector2(500, 52), "field_portrait": Vector2(500, 180),
			"biome_gallery": Vector2(500, 308), "night_sky": Vector2(500, 468), "rare_lens": Vector2(724, 180),
			"six_horizons": Vector2(724, 308), "dawn_ice": Vector2(948, 396), "polar_light": Vector2(1_172, 396),
			"outpost_portrait": Vector2(724, 52), "greenhouse_window": Vector2(948, 52), "lab_in_frame": Vector2(1_172, 52),
			"primordial_frost_photo": Vector2(1_172, 180), "life_witness_image": Vector2(1_360, 180),
		},
		"sections": [["FIELD SHOTS", Vector2(52, 206)], ["SCIENTIFIC OBSERVATIONS", Vector2(724, 28)], ["SKY AND POLES", Vector2(500, 398)]],
	},
}


class MissionMapBackdrop extends Control:
	var accent := Color("64c6df")

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("09151d"))
		var grid_color := Color(accent, 0.12)
		for x in range(0, int(size.x) + 1, 32):
			draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		for y in range(0, int(size.y) + 1, 32):
			draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		for index in 72:
			var point := Vector2(fposmod(float(index * 137 + 31), size.x), fposmod(float(index * 71 + 17), size.y))
			var radius := 1.0 + float(index % 3) * 0.45
			draw_circle(point, radius, Color(accent, 0.13 + float(index % 4) * 0.03))
		var orbital_center := Vector2(size.x * 0.54, size.y * 0.48)
		for radius in [150.0, 270.0, 410.0]:
			draw_arc(orbital_center, radius, -0.65, 2.35, 48, Color(accent, 0.08), 1.0, true)


class GraphLinks extends Control:
	var links: Array[Dictionary] = []

	func set_links(new_links: Array[Dictionary]) -> void:
		links = new_links
		queue_redraw()

	func _draw() -> void:
		for link in links:
			var from: Vector2 = link.get("from", Vector2.ZERO)
			var to: Vector2 = link.get("to", Vector2.ZERO)
			var color: Color = link.get("color", Color("38515d"))
			var direction := (to - from).normalized()
			if direction.length_squared() <= 0.001:
				continue
			var tip := to - direction * 18.0
			var normal := Vector2(-direction.y, direction.x)
			draw_line(from, tip, color, 3.0, true)
			draw_circle(from, 4.0, color)
			draw_colored_polygon(PackedVector2Array([to, tip + normal * 6.0, tip - normal * 6.0]), color)


var _root: Control
var _graph: Control
var _scroll: ScrollContainer
var _detail_title: Label
var _detail_body: Label
var _detail_status: Label
var _notification: Label
var _tab_buttons: Dictionary = {}
var _claimable_cards: Array[Control] = []
var _hidden_layers: Array[Dictionary] = []
var _selected_category := "field"
var _time := 0.0
var _is_panning := false
var _pan_pointer := Vector2.ZERO


func _ready() -> void:
	layer = 100
	_build_ui()
	AchievementManager.achievement_updated.connect(_on_achievement_updated)
	AchievementManager.achievement_claimable.connect(_on_achievement_claimable)
	AchievementManager.achievement_claimed.connect(_on_achievement_claimed)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_time += delta
	var pulse := 0.82 + (sin(_time * 6.0) + 1.0) * 0.09
	for card in _claimable_cards:
		if is_instance_valid(card):
			card.modulate = Color(1.0, pulse, 0.58 + pulse * 0.22, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_J:
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _root.visible:
		close()
	else:
		open()


func open() -> void:
	if _root.visible:
		return
	if not _try_open_ui_modal():
		return
	_hide_external_ui()
	_notification.visible = false
	_root.visible = true
	AchievementManager.is_board_open = true
	_select_category(_selected_category)


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	AchievementManager.is_board_open = false
	_close_ui_modal()
	_restore_external_ui()


func _try_open_ui_modal() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state == null or bool(ui_state.call("try_open_modal", &"achievements"))


func _close_ui_modal() -> void:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", &"achievements")


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AchievementBoardRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color("03070c")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 14.0
	panel.offset_top = 14.0
	panel.offset_right = -14.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", _box(Color("0d1a23"), Color("3e94b8"), 2, 10))
	_root.add_child(panel)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 18)
	margins.add_theme_constant_override("margin_right", 18)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margins.add_child(content)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "CONTRACT ARCHIVE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f2d672"))
	title.add_theme_color_override("font_outline_color", Color("05090d"))
	title.add_theme_constant_override("outline_size", 3)
	title_row.add_child(title)
	var close_label := Label.new()
	close_label.text = "J / ESC  ·  CLOSE"
	close_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_label.add_theme_font_size_override("font_size", 12)
	close_label.add_theme_color_override("font_color", Color("a5dcef"))
	title_row.add_child(close_label)
	var subtitle := Label.new()
	subtitle.text = "Select a dossier: contracts always progress, but rewards follow the authorization chain."
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("b7c8d0"))
	content.add_child(subtitle)
	var tabs := HBoxContainer.new()
	tabs.name = "AchievementCategoryTabs"
	tabs.add_theme_constant_override("separation", 7)
	content.add_child(tabs)
	for category in CATEGORIES:
		var category_id := str(category["id"])
		var button := Button.new()
		button.name = "Tab_" + category_id
		button.text = "%s  %s" % [str(category["icon"]), str(category["label"])]
		button.custom_minimum_size = Vector2(142, 34)
		button.tooltip_text = str(category["description"])
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_select_category.bind(category_id))
		tabs.add_child(button)
		_tab_buttons[category_id] = button
	var map_frame := PanelContainer.new()
	map_frame.name = "MissionMapFrame"
	map_frame.custom_minimum_size = Vector2(0, 300)
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", _box(Color("071018"), Color("305f73"), 2, 7))
	content.add_child(map_frame)
	var map_margins := MarginContainer.new()
	map_margins.add_theme_constant_override("margin_left", 8)
	map_margins.add_theme_constant_override("margin_right", 8)
	map_margins.add_theme_constant_override("margin_top", 8)
	map_margins.add_theme_constant_override("margin_bottom", 8)
	map_frame.add_child(map_margins)
	_scroll = ScrollContainer.new()
	_scroll.name = "AchievementGraphScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.gui_input.connect(_on_scroll_gui_input)
	map_margins.add_child(_scroll)
	_graph = Control.new()
	_graph.name = "MissionGraph"
	_graph.custom_minimum_size = GRAPH_SIZE
	_graph.size = GRAPH_SIZE
	_graph.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_graph)
	var detail_frame := PanelContainer.new()
	detail_frame.name = "AchievementDetailFrame"
	detail_frame.custom_minimum_size = Vector2(0, 92)
	detail_frame.add_theme_stylebox_override("panel", _box(Color("111d25"), Color("345d70"), 1, 6))
	content.add_child(detail_frame)
	var detail_margins := MarginContainer.new()
	detail_margins.add_theme_constant_override("margin_left", 12)
	detail_margins.add_theme_constant_override("margin_right", 12)
	detail_margins.add_theme_constant_override("margin_top", 7)
	detail_margins.add_theme_constant_override("margin_bottom", 7)
	detail_frame.add_child(detail_margins)
	var detail_rows := VBoxContainer.new()
	detail_rows.add_theme_constant_override("separation", 2)
	detail_margins.add_child(detail_rows)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 13)
	_detail_title.add_theme_color_override("font_color", Color("f1f6f4"))
	detail_rows.add_child(_detail_title)
	_detail_body = Label.new()
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_theme_font_size_override("font_size", 11)
	_detail_body.add_theme_color_override("font_color", Color("b9cbd1"))
	detail_rows.add_child(_detail_body)
	_detail_status = Label.new()
	_detail_status.add_theme_font_size_override("font_size", 10)
	detail_rows.add_child(_detail_status)
	var controls := Label.new()
	controls.text = "LEGEND  ◼ locked   ◇ in progress   ✦ reward ready   ✓ claimed     ·     MIDDLE MOUSE  drag map     ·     LEFT-CLICK  details / claim"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 10)
	controls.add_theme_color_override("font_color", Color("7fa2b0"))
	content.add_child(controls)
	_notification = Label.new()
	_notification.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notification.offset_left = -450.0
	_notification.offset_top = 22.0
	_notification.offset_right = -30.0
	_notification.offset_bottom = 62.0
	_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notification.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification.add_theme_font_size_override("font_size", 12)
	_notification.add_theme_color_override("font_color", Color("fff3a2"))
	_notification.add_theme_color_override("font_outline_color", Color("071017"))
	_notification.add_theme_constant_override("outline_size", 4)
	_notification.visible = false
	add_child(_notification)


func _select_category(category_id: String) -> void:
	if not CATEGORY_LAYOUTS.has(category_id):
		return
	_selected_category = category_id
	for id_variant in _tab_buttons:
		var button := _tab_buttons[id_variant] as Button
		var category := _category_definition(str(id_variant))
		var color: Color = category.get("color", Color.WHITE)
		var is_active := str(id_variant) == category_id
		button.add_theme_stylebox_override("normal", _tab_style(color, is_active))
		button.add_theme_stylebox_override("hover", _tab_style(color.lightened(0.12), true))
		button.add_theme_stylebox_override("pressed", _tab_style(color.darkened(0.08), true))
		button.add_theme_color_override("font_color", Color("061016") if is_active else Color("c1d0d5"))
	_rebuild_graph()
	if _scroll != null:
		_scroll.scroll_horizontal = 0
		_scroll.scroll_vertical = 0


func _rebuild_graph() -> void:
	if _graph == null:
		return
	for child in _graph.get_children():
		child.queue_free()
	_claimable_cards.clear()
	var category := _category_definition(_selected_category)
	var backdrop := MissionMapBackdrop.new()
	backdrop.name = "GraphBackground"
	backdrop.accent = Color(category.get("color", Color("64c6df")))
	backdrop.position = Vector2.ZERO
	backdrop.size = GRAPH_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(backdrop)
	var layout: Dictionary = CATEGORY_LAYOUTS[_selected_category]
	for section in layout.get("sections", []):
		_add_section_label(str(section[0]), Vector2(section[1]), Color(category.get("color", Color.WHITE)))
	var definitions := AchievementManager.get_ordered_definitions()
	var links := GraphLinks.new()
	links.name = "GraphLinks"
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.position = Vector2.ZERO
	links.size = GRAPH_SIZE
	links.set_links(_build_links(definitions, layout.get("nodes", {})))
	_graph.add_child(links)
	var positions: Dictionary = layout.get("nodes", {})
	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		if not positions.has(achievement_id):
			continue
		var card := _make_card(definition, Color(category.get("color", Color.WHITE)))
		card.name = "AchievementNode_" + achievement_id
		card.position = Vector2(positions[achievement_id])
		_graph.add_child(card)
	if _selected_category == "return":
		_add_return_catalog_panel()
	var initial_id := _first_category_node(positions)
	if not initial_id.is_empty():
		_show_detail(initial_id)


func _add_section_label(text: String, position_value: Vector2, color: Color) -> void:
	var label := Label.new()
	label.name = "MapSection_" + text.replace(" ", "_")
	label.text = "// " + text + " //"
	label.position = position_value
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color.lightened(0.06))
	label.add_theme_color_override("font_outline_color", Color("02070a"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(label)


func _add_return_catalog_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "ReturnSampleCatalog"
	panel.position = Vector2(36, 408)
	panel.size = Vector2(1_420, 184)
	panel.add_theme_stylebox_override("panel", _box(Color("0c1a21"), Color("6d9aad"), 1, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(panel)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 10)
	margins.add_theme_constant_override("margin_right", 10)
	margins.add_theme_constant_override("margin_top", 7)
	margins.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margins)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	margins.add_child(grid)
	for definition in ROCK_RESOURCE.get_return_mission_catalog():
		var item := Label.new()
		item.custom_minimum_size = Vector2(448, 17)
		item.text = "%s · %s · %s" % [str(definition.get("name", "Sample")), str(definition.get("biome", "Biome")), _catalog_rarity(str(definition.get("rarity", "common")))]
		item.add_theme_font_size_override("font_size", 9)
		item.add_theme_color_override("font_color", Color("c7d9df"))
		grid.add_child(item)
	var life_item := Label.new()
	life_item.custom_minimum_size = Vector2(448, 17)
	life_item.text = "Alien life sample · deep-ice laboratory · UNIQUE"
	life_item.add_theme_font_size_override("font_size", 9)
	life_item.add_theme_color_override("font_color", Color("80ffcf"))
	grid.add_child(life_item)


func _catalog_rarity(rarity: String) -> String:
	if rarity == "ultra_rare":
		return "ULTRA-RARE"
	if rarity == "rare":
		return "RARE"
	return "COMMON"


func _build_links(definitions: Array, positions: Dictionary) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for definition in definitions:
		var child_id := str(definition.get("id", ""))
		if not positions.has(child_id):
			continue
		for parent_id in AchievementManager.get_prerequisites(child_id):
			if not positions.has(parent_id):
				continue
			links.append({"from": Vector2(positions[parent_id]) + CARD_SIZE * 0.5, "to": Vector2(positions[child_id]) + CARD_SIZE * 0.5, "color": _link_color(parent_id)})
	return links


func _link_color(parent_id: String) -> Color:
	return Color("67d4b5") if AchievementManager.is_claimed(parent_id) else Color("36515e")


func _make_card(definition: Dictionary, category_color: Color) -> Control:
	var achievement_id := str(definition.get("id", ""))
	var status := AchievementManager.get_status(achievement_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.tooltip_text = str(definition.get("description", ""))
	var border_color := Color("51646e")
	var fill_color := Color("12222c")
	if status == "locked":
		border_color = Color("b2444e")
		fill_color = Color("20191e")
	elif status == "available":
		border_color = Color("61757e")
		fill_color = Color("1b2a32")
	elif status == "claimed":
		border_color = Color(definition.get("color", category_color))
		fill_color = Color("173138")
	else:
		border_color = Color("ffe17a")
		fill_color = Color("3b3420")
		_claimable_cards.append(card)
	card.add_theme_stylebox_override("panel", _box(fill_color, border_color, 2, 6))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_pressed(achievement_id)
	)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(0, 4)
	stripe.color = _stripe_color(definition, status)
	stack.add_child(stripe)
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(34, 0)
	icon_frame.add_theme_stylebox_override("panel", _box(Color("0b151c"), _stripe_color(definition, status), 1, 4))
	body.add_child(icon_frame)
	var icon := Label.new()
	icon.text = str(definition.get("icon", "•"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color("75848a") if status in ["locked", "available"] else Color(definition.get("color", category_color)))
	icon_frame.add_child(icon)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	body.add_child(copy)
	var title := Label.new()
	title.text = str(definition.get("title", "OBJECTIVE"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0, 25)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("e6eff2") if status != "locked" else Color("bc8589"))
	copy.add_child(title)
	var state := Label.new()
	state.text = "%d / %d   %s" % [AchievementManager.get_progress(achievement_id), AchievementManager.get_target(achievement_id), _status_text(status)]
	state.add_theme_font_size_override("font_size", 8)
	state.add_theme_color_override("font_color", Color("ffe47b") if status == "claimable" else Color("b8c6cb"))
	copy.add_child(state)
	var progress := ProgressBar.new()
	progress.value = float(AchievementManager.get_progress(achievement_id)) / float(maxi(1, AchievementManager.get_target(achievement_id))) * 100.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 5)
	progress.add_theme_stylebox_override("background", _box(Color("071015"), Color("314550"), 1, 2))
	progress.add_theme_stylebox_override("fill", _box(_stripe_color(definition, status), _stripe_color(definition, status), 0, 2))
	copy.add_child(progress)
	return card


func _stripe_color(definition: Dictionary, status: String) -> Color:
	if status == "locked":
		return Color("d84d55")
	if status == "available":
		return Color("80919a")
	if status == "claimable":
		return Color("ffd95f")
	return Color(definition.get("color", Color.WHITE))


func _status_text(status: String) -> String:
	match status:
		"locked": return "LOCKED"
		"available": return "IN PROGRESS"
		"claimable": return "✦ CLAIM"
	return "✓ CLAIMED"


func _on_card_pressed(achievement_id: String) -> void:
	if AchievementManager.is_claimable(achievement_id):
		AchievementManager.claim(achievement_id)
		_rebuild_graph()
	else:
		_show_detail(achievement_id)


func _show_detail(achievement_id: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	if definition.is_empty() or _detail_title == null:
		return
	var status := AchievementManager.get_status(achievement_id)
	var reward: Dictionary = definition.get("reward", {})
	_detail_title.text = "%s  ·  %s" % [str(definition.get("icon", "◈")), str(definition.get("title", ""))]
	_detail_body.text = "%s\nReward: %s" % [str(definition.get("description", "")), str(reward.get("label", "none"))]
	var text := ""
	if status == "locked":
		var names: Array[String] = []
		for prerequisite_id in AchievementManager.get_prerequisites(achievement_id):
			names.append(str(AchievementManager.get_definition(prerequisite_id).get("title", prerequisite_id)))
		text = "LOCKED  ·  Claim first: " + ", ".join(names) + ". Progress remains recorded."
	elif status == "available":
		text = "IN PROGRESS  ·  Complete the requirement to make the reward available."
	elif status == "claimable":
		text = "✦ REWARD READY  ·  Click this badge again to claim it and authorize the next ones."
	else:
		text = "✓ CLAIMED  ·  The contract has authorized its dependent nodes."
	_detail_status.text = text
	_detail_status.add_theme_color_override("font_color", Color("ffe17a") if status == "claimable" else Color("a9c8d1"))


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_panning = event.pressed
		_pan_pointer = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_panning:
		var pan_delta: Vector2 = event.position - _pan_pointer
		_scroll.scroll_horizontal = maxi(0, _scroll.scroll_horizontal - roundi(pan_delta.x))
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - roundi(pan_delta.y))
		_pan_pointer = event.position
		get_viewport().set_input_as_handled()


func _category_definition(category_id: String) -> Dictionary:
	for category in CATEGORIES:
		if str(category.get("id", "")) == category_id:
			return category
	return {}


func _first_category_node(positions: Dictionary) -> String:
	for definition in AchievementManager.get_ordered_definitions():
		var achievement_id := str(definition.get("id", ""))
		if positions.has(achievement_id):
			return achievement_id
	return ""


func _hide_external_ui() -> void:
	_hidden_layers.clear()
	var scene_root := get_tree().current_scene
	if scene_root != null:
		_collect_external_canvas_layers(scene_root)


func _collect_external_canvas_layers(node: Node) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is CanvasLayer:
			var canvas_layer := child as CanvasLayer
			_hidden_layers.append({"layer": canvas_layer, "visible": canvas_layer.visible})
			canvas_layer.visible = false
		_collect_external_canvas_layers(child)


func _restore_external_ui() -> void:
	for entry in _hidden_layers:
		var canvas_layer := entry.get("layer") as CanvasLayer
		if is_instance_valid(canvas_layer):
			canvas_layer.visible = bool(entry.get("visible", true))
	_hidden_layers.clear()


func _on_achievement_updated(_achievement_id: String) -> void:
	if _root.visible:
		_rebuild_graph()


func _on_achievement_claimable(achievement_id: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	_show_notification("OBJECTIVE READY · %s · press J" % str(definition.get("title", "")))


func _on_achievement_claimed(achievement_id: String, reward_label: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	_show_notification("REWARD CLAIMED · %s · %s" % [str(definition.get("title", "")), reward_label])


func _show_notification(message: String) -> void:
	if _root.visible:
		return
	_notification.text = message
	_notification.visible = true
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_notification):
			_notification.visible = false
	)


func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box


func _tab_style(color: Color, active: bool) -> StyleBoxFlat:
	var fill := Color("13232d") if not active else color
	var style := _box(fill, color, 2 if active else 1, 5)
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style
