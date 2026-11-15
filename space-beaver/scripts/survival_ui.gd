extends CanvasLayer

const SEGMENT_COUNT := 10
const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const BACKGROUND_COLOR := Color("#151B25ee")
const TEXT_COLOR := Color("E0F8EE")
const HUNGER_COLOR := Color("E88F33")
const THIRST_COLOR := Color("4191b1")
const OXYGEN_COLOR := Color("8AC4E1")

var oxygen_segments: Array[ColorRect] = []
var hunger_segments: Array[ColorRect] = []
var thirst_segments: Array[ColorRect] = []
var oxygen_label: Label
var hunger_label: Label
var thirst_label: Label
var money_label: Label
var money_delta_label: Label
var _money_tween: Tween


func _ready() -> void:
	_build_ui()
	Oxygen.changed.connect(_set_oxygen)
	Hunger.changed.connect(_set_hunger)
	Hydration.changed.connect(_set_thirst)
	Economy.balance_changed.connect(_set_money)
	Economy.transaction_changed.connect(_on_money_transaction)
	_set_oxygen(Oxygen.oxygen, Oxygen.max_oxygen)
	_set_hunger(Hunger.hunger, Hunger.MAX_HUNGER)
	_set_thirst(Hydration.thirst, Hydration.MAX_THIRST)
	_set_money(Economy.balance)


func _build_ui() -> void:
	var root := Control.new()
	root.add_theme_font_override("font", UI_FONT)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var survival_panel := PanelContainer.new()
	survival_panel.anchor_left = 0.5
	survival_panel.anchor_right = 0.5
	survival_panel.anchor_top = 1.0
	survival_panel.anchor_bottom = 1.0
	survival_panel.offset_top = -160.0
	survival_panel.offset_bottom = -10.0
	survival_panel.offset_left = -350.0
	survival_panel.offset_right = 350.0
	survival_panel.add_theme_stylebox_override("panel", _panel_style(Color("00000000"), Color("00000000")))
	root.add_child(survival_panel)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 16)
	survival_panel.add_child(columns)

	var thirst_widgets := _add_meter(columns, "THIRST", THIRST_COLOR)
	thirst_segments = thirst_widgets["segments"]
	thirst_label = thirst_widgets["label"]
	var oxygen_widgets := _add_meter(columns, "OXYGEN", OXYGEN_COLOR)
	oxygen_segments = oxygen_widgets["segments"]
	oxygen_label = oxygen_widgets["label"]
	var hunger_widgets := _add_meter(columns, "HUNGER", HUNGER_COLOR)
	hunger_segments = hunger_widgets["segments"]
	hunger_label = hunger_widgets["label"]

	var money_panel := PanelContainer.new()
	money_panel.anchor_left = 1.0
	money_panel.anchor_right = 1.0
	money_panel.offset_left = -125.0
	money_panel.offset_top = 16.0
	money_panel.offset_right = -16.0
	money_panel.offset_bottom = 105.0
	money_panel.add_theme_stylebox_override("panel", _panel_style(BACKGROUND_COLOR, TEXT_COLOR))
	root.add_child(money_panel)

	var money_rows := VBoxContainer.new()
	money_rows.add_theme_constant_override("separation", 4)
	money_panel.add_child(money_rows)
	var budget_title := _make_label("$  BUDGET NASA", 14, TEXT_COLOR)
	money_rows.add_child(budget_title)
	money_label = _make_label("", 19, TEXT_COLOR)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_rows.add_child(money_label)

	money_delta_label = _make_label("", 12, Color("8ff1a9"))
	money_delta_label.anchor_left = 1.0
	money_delta_label.anchor_right = 1.0
	money_delta_label.offset_left = -220.0
	money_delta_label.offset_top = 105.0
	money_delta_label.offset_right = -16.0
	money_delta_label.offset_bottom = 127.0
	money_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_delta_label.visible = false
	root.add_child(money_delta_label)


func _add_meter(parent: HBoxContainer, title: String, color: Color) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var header := HBoxContainer.new()
	row.add_child(header)
	var name_label := _make_label(title, 12, TEXT_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := _make_label("100.0", 12, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _bar_frame_style(color.darkened(0.3)))
	row.add_child(frame)
	var blocks := HBoxContainer.new()
	blocks.add_theme_constant_override("separation", 1)
	frame.add_child(blocks)
	var segments: Array[ColorRect] = []
	for _index in SEGMENT_COUNT:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(21, 10)
		block.color = color
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blocks.add_child(block)
		segments.append(block)
	return {"segments": segments, "label": value_label, "color": color}


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("05090d"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel_style(background: Color, border: Color = TEXT_COLOR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _bar_frame_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = border_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _set_segments(segments: Array[ColorRect], current: float, maximum: float, color: Color) -> void:
	var filled := ceili(clampf(current / maximum, 0.0, 1.0) * SEGMENT_COUNT)
	for index in segments.size():
		segments[index].color = color if index < filled else color.darkened(0.3)


func _set_oxygen(current: float, maximum: float) -> void:
	_set_segments(oxygen_segments, current, maximum, OXYGEN_COLOR)
	oxygen_label.text = "%05.1f" % current


func _set_hunger(current: float, maximum: float) -> void:
	_set_segments(hunger_segments, current, maximum, HUNGER_COLOR)
	hunger_label.text = "%05.1f" % current


func _set_thirst(current: float, maximum: float) -> void:
	_set_segments(thirst_segments, current, maximum, THIRST_COLOR)
	thirst_label.text = "%05.1f" % current


func _set_money(current: int) -> void:
	money_label.text = Economy.format_money(current)


func _on_money_transaction(current: int, delta: int) -> void:
	_set_money(current)
	if delta == 0 or money_delta_label == null:
		return
	if _money_tween != null:
		_money_tween.kill()
	money_delta_label.text = ("+ " if delta > 0 else "− ") + Economy.format_money(absi(delta))
	money_delta_label.add_theme_color_override("font_color", Color("8ff1a9") if delta > 0 else Color("ff8b7d"))
	money_delta_label.modulate = Color.WHITE
	money_delta_label.visible = true
	money_delta_label.offset_top = 105.0
	money_delta_label.offset_bottom = 127.0
	_money_tween = create_tween()
	_money_tween.set_parallel(true)
	_money_tween.tween_property(money_delta_label, "offset_top", 73.0, 0.80).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_money_tween.tween_property(money_delta_label, "offset_bottom", 95.0, 0.80).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_money_tween.tween_property(money_delta_label, "modulate:a", 0.0, 0.65).set_delay(0.15)
	_money_tween.set_parallel(false)
	_money_tween.tween_callback(func() -> void:
		if is_instance_valid(money_delta_label):
			money_delta_label.visible = false
	)
