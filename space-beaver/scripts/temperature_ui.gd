extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const BACKGROUND_COLOR := Color("#151B25ee")
const TEXT_COLOR := Color("E0F8EE")
const HUNGER_COLOR := Color("E88F33")
const THIRST_COLOR := Color("4191b1")
const OXYGEN_COLOR := Color("8AC4E1")

var ambient_label: Label
var core_label: Label
var status_label: Label
var effects_label: Label


func _ready() -> void:
	layer = 46
	_build_ui()
	Temperature.changed.connect(_refresh)
	_refresh(Temperature.get_data())


func _build_ui() -> void:
	var root := Control.new()
	root.add_theme_font_override("font", UI_FONT)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 141)
	panel.custom_minimum_size = Vector2(274, 126)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	rows.add_child(_label("EVA THERMAL MANAGEMENT", 13, TEXT_COLOR))
	ambient_label = _label("", 12, Color("9fc7d5"))
	rows.add_child(ambient_label)
	core_label = _label("", 12, OXYGEN_COLOR)
	rows.add_child(core_label)
	status_label = _label("", 14, OXYGEN_COLOR)
	rows.add_child(status_label)
	effects_label = _label("", 10, TEXT_COLOR)
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(effects_label)


func _refresh(data: Dictionary) -> void:
	var ambient := float(data.get("ambient_temperature_c", 0.0))
	var effective := float(data.get("effective_temperature_c", ambient))
	var core := float(data.get("core_temperature_c", 37.0))
	var sheltered := bool(data.get("is_sheltered", false))
	var shelter_suffix := "  ·  %s +%d°C" % [str(data.get("shelter_name", "SHELTER")), roundi(float(data.get("shelter_bonus_c", 0.0)))] if sheltered else "  ·  EXPOSED"
	ambient_label.text = "OUTSIDE  %+.0f°C  ·  %s%s" % [ambient, str(data.get("biome_name", "MARS")), shelter_suffix]
	core_label.text = "CORE  %.1f°C    EVA RATED TO %+.0f°C" % [core, float(data.get("suit_tolerance_c", -65.0))]
	var color: Color = data.get("condition_color", Color.WHITE)
	status_label.text = "STATUS  " + str(data.get("condition", "THERMALLY STABLE"))
	status_label.add_theme_color_override("font_color", color)
	core_label.add_theme_color_override("font_color", color)
	var move_percent := roundi(float(data.get("movement_multiplier", 1.0)) * 100.0)
	var oxygen_percent := roundi(float(data.get("oxygen_multiplier", 1.0)) * 100.0)
	effects_label.text = "EFFECTS  movement %d%%  ·  O₂ use %d%%  ·  cold load %.0f°C" % [move_percent, oxygen_percent, float(data.get("cold_gap_c", 0.0))]


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", BACKGROUND_COLOR)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
