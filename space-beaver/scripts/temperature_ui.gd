extends CanvasLayer

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
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 326)
	panel.custom_minimum_size = Vector2(274, 126)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("70c9ea")))
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	rows.add_child(_label("// GESTIONE TERMICA EVA //", 13, Color("e3f1ee")))
	ambient_label = _label("", 11, Color("9fc7d5"))
	rows.add_child(ambient_label)
	core_label = _label("", 15, Color("7fe3ba"))
	rows.add_child(core_label)
	status_label = _label("", 11, Color("7fe3ba"))
	rows.add_child(status_label)
	effects_label = _label("", 10, Color("b9c8ca"))
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(effects_label)


func _refresh(data: Dictionary) -> void:
	var ambient := float(data.get("ambient_temperature_c", 0.0))
	var effective := float(data.get("effective_temperature_c", ambient))
	var core := float(data.get("core_temperature_c", 37.0))
	var sheltered := bool(data.get("is_sheltered", false))
	var shelter_suffix := "  ·  %s +%d°C" % [str(data.get("shelter_name", "RIFUGIO")), roundi(float(data.get("shelter_bonus_c", 0.0)))] if sheltered else "  ·  ESPOSTO"
	ambient_label.text = "ESTERNO  %+.0f°C  ·  %s%s" % [ambient, str(data.get("biome_name", "MARTE")), shelter_suffix]
	core_label.text = "CORE  %.1f°C    EVA FINO A %+.0f°C" % [core, float(data.get("suit_tolerance_c", -65.0))]
	var color: Color = data.get("condition_color", Color.WHITE)
	status_label.text = "STATO  " + str(data.get("condition", "TERMICO STABILE"))
	status_label.add_theme_color_override("font_color", color)
	core_label.add_theme_color_override("font_color", color)
	var move_percent := roundi(float(data.get("movement_multiplier", 1.0)) * 100.0)
	var oxygen_percent := roundi(float(data.get("oxygen_multiplier", 1.0)) * 100.0)
	effects_label.text = "EFFETTI  movimento %d%%  ·  consumo O₂ %d%%  ·  carico freddo %.0f°C" % [move_percent, oxygen_percent, float(data.get("cold_gap_c", 0.0))]


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("04070a"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101820ed")
	style.border_color = border
	style.set_border_width_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
