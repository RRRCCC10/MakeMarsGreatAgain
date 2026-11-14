extends CanvasLayer

const SEGMENT_COUNT := 10
const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const EMPTY_SEGMENT := Color("26313c")
const PANEL_COLOR := Color("101820")
const PANEL_BORDER := Color("8aa7b8")

var oxygen_segments: Array[ColorRect] = []
var hunger_segments: Array[ColorRect] = []
var thirst_segments: Array[ColorRect] = []
var oxygen_label: Label
var hunger_label: Label
var thirst_label: Label
var money_label: Label


func _ready() -> void:
	_build_ui()
	Oxygen.changed.connect(_set_oxygen)
	Hunger.changed.connect(_set_hunger)
	Hydration.changed.connect(_set_thirst)
	Economy.balance_changed.connect(_set_money)
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
	survival_panel.position = Vector2(16, 16)
	survival_panel.custom_minimum_size = Vector2(274, 177)
	survival_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(survival_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	survival_panel.add_child(rows)
	var title := _make_label("// SISTEMI EVA //", 15, Color("e3f1ee"))
	rows.add_child(title)

	var oxygen_widgets := _add_meter(rows, "O2  OSSIGENO", Color("50c8f4"))
	oxygen_segments = oxygen_widgets["segments"]
	oxygen_label = oxygen_widgets["label"]
	var hunger_widgets := _add_meter(rows, "FD  FAME", Color("f2a33c"))
	hunger_segments = hunger_widgets["segments"]
	hunger_label = hunger_widgets["label"]
	var thirst_widgets := _add_meter(rows, "H2O SETE", Color("4389f5"))
	thirst_segments = thirst_widgets["segments"]
	thirst_label = thirst_widgets["label"]

	var money_panel := PanelContainer.new()
	money_panel.anchor_left = 1.0
	money_panel.anchor_right = 1.0
	money_panel.offset_left = -250.0
	money_panel.offset_top = 16.0
	money_panel.offset_right = -16.0
	money_panel.offset_bottom = 80.0
	money_panel.add_theme_stylebox_override("panel", _panel_style(Color("111a1f"), Color("dfbd52")))
	root.add_child(money_panel)

	var money_rows := VBoxContainer.new()
	money_rows.add_theme_constant_override("separation", 4)
	money_panel.add_child(money_rows)
	var budget_title := _make_label("$  BUDGET NASA", 14, Color("ffe38a"))
	money_rows.add_child(budget_title)
	money_label = _make_label("", 19, Color("fff2b5"))
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_rows.add_child(money_label)


func _add_meter(parent: VBoxContainer, title: String, color: Color) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var header := HBoxContainer.new()
	row.add_child(header)
	var name_label := _make_label(title, 12, Color("dce8e6"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := _make_label("100.0", 12, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _bar_frame_style())
	row.add_child(frame)
	var blocks := HBoxContainer.new()
	blocks.add_theme_constant_override("separation", 2)
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


func _panel_style(background: Color = PANEL_COLOR, border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _bar_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("070d12")
	style.border_color = Color("4c626e")
	style.set_border_width_all(2)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _set_segments(segments: Array[ColorRect], current: float, maximum: float, color: Color) -> void:
	var filled := ceili(clampf(current / maximum, 0.0, 1.0) * SEGMENT_COUNT)
	for index in segments.size():
		segments[index].color = color if index < filled else EMPTY_SEGMENT


func _set_oxygen(current: float, maximum: float) -> void:
	_set_segments(oxygen_segments, current, maximum, Color("50c8f4"))
	oxygen_label.text = "%05.1f" % current


func _set_hunger(current: float, maximum: float) -> void:
	_set_segments(hunger_segments, current, maximum, Color("f2a33c"))
	hunger_label.text = "%05.1f" % current


func _set_thirst(current: float, maximum: float) -> void:
	_set_segments(thirst_segments, current, maximum, Color("4389f5"))
	thirst_label.text = "%05.1f" % current


func _set_money(current: int) -> void:
	money_label.text = Economy.format_money(current)
