extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const BACKGROUND_COLOR := Color("#151B25ee")
const TEXT_COLOR := Color("E0F8EE")
const HUNGER_COLOR := Color("E88F33")
const THIRST_COLOR := Color("4191b1")
const OXYGEN_COLOR := Color("8AC4E1")

var rate_label: Label
var dose_label: Label
var condition_label: Label
var suit_label: Label
var alert_panel: PanelContainer
var alert_title: Label
var alert_detail: Label


func _ready() -> void:
	layer = 46
	_build_ui()
	Radiation.changed.connect(_refresh)
	SuitSystem.equipped_changed.connect(_on_suit_changed)
	_refresh(Radiation.get_data())


func _build_ui() -> void:
	var root := Control.new()
	root.add_theme_font_override("font", UI_FONT)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(274, 112)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	rows.add_child(_label("DOSIMETRO PERSONALE", 13, TEXT_COLOR))
	rate_label = _label("", 12, THIRST_COLOR)
	rows.add_child(rate_label)
	dose_label = _label("", 11, TEXT_COLOR)
	rows.add_child(dose_label)
	condition_label = _label("", 11, OXYGEN_COLOR)
	rows.add_child(condition_label)
	suit_label = _label("", 10, Color("a9c9d4"))
	suit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(suit_label)
	alert_panel = PanelContainer.new()
	alert_panel.anchor_left = 0.5
	alert_panel.anchor_right = 0.5
	alert_panel.offset_left = -255
	alert_panel.offset_right = 255
	alert_panel.offset_top = 16
	alert_panel.offset_bottom = 83
	root.add_child(alert_panel)
	var alert_rows := VBoxContainer.new()
	alert_rows.add_theme_constant_override("separation", 2)
	alert_panel.add_child(alert_rows)
	alert_title = _label("", 15, Color.WHITE)
	alert_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_rows.add_child(alert_title)
	alert_detail = _label("", 11, Color("eef2ef"))
	alert_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_rows.add_child(alert_detail)


func _refresh(data: Dictionary) -> void:
	rate_label.text = "RATE  %.3f mSv/h" % float(data["received_rate_msv_h"])
	dose_label.text = "DOSE  acuta %.1f  ·  missione %.1f mSv" % [float(data["acute_dose_msv"]), float(data["cumulative_dose_msv"])]
	condition_label.text = "STATO  " + str(data["condition"])
	condition_label.add_theme_color_override("font_color", _condition_color(float(data["acute_dose_msv"])))
	_on_suit_changed(SuitSystem.equipped_suit_id, SuitSystem.get_equipped_definition())
	var state := int(data["state"])
	alert_panel.visible = state != Radiation.EventState.QUIET
	if not alert_panel.visible:
		return
	var color: Color = data["event_color"]
	alert_panel.add_theme_stylebox_override("panel", _panel_style())
	alert_title.add_theme_color_override("font_color", color)
	var time_text := _format_game_time(float(data["time_remaining_hours"]))
	if state == Radiation.EventState.WARNING:
		alert_title.text = "⚠  ALLERTA: %s" % str(data["event_label"])
		alert_detail.text = "Arrivo tra %s  ·  prepara il rientro in un rifugio schermato" % time_text
	else:
		alert_title.text = "⚠  %s IN CORSO" % str(data["event_label"])
		alert_detail.text = "Fine stimata %s  ·  esposizione esterna %.1f mSv/h" % [time_text, float(data["received_rate_msv_h"])]


func _on_suit_changed(_suit_id: String, definition: Dictionary) -> void:
	suit_label.text = "%s  ·  SOL %d%%  COS %d%%  TERM %+.0f°C" % [
		str(definition.get("short_name", "EVA")),
		roundi(float(definition.get("solar_protection", 0.0)) * 100.0),
		roundi(float(definition.get("cosmic_protection", 0.0)) * 100.0),
		float(definition.get("cold_tolerance_c", -68.0)),
	]


func _format_game_time(hours: float) -> String:
	var total_minutes := maxi(0, roundi(hours * 60.0))
	return "%02d:%02d" % [floori(total_minutes / 60.0), total_minutes % 60]


func _condition_color(dose: float) -> Color:
	if dose < 500.0:
		return OXYGEN_COLOR
	if dose < 1000.0:
		return Color("F6BC5D")
	if dose < 2000.0:
		return HUNGER_COLOR
	return Color("ef6cff")


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("04070a"))
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
