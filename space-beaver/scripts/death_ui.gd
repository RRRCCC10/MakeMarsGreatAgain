extends CanvasLayer

var overlay: ColorRect
var code_label: Label
var title_label: Label
var message_label: Label
var epilogue_label: Label
var accent: ColorRect
var restart_button: Button


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameState.mission_failed.connect(_show_death)
	overlay.visible = GameState.has_failed


func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color("030609f2")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_top = -235
	panel.offset_right = 350
	panel.offset_bottom = 235
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 15)
	panel.add_child(rows)
	var header := _label("// RAPPORTO FINALE DI MISSIONE //", 13, Color("84949a"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(header)
	code_label = _label("", 18, Color.WHITE)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(code_label)
	accent = ColorRect.new()
	accent.custom_minimum_size = Vector2(520, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(accent)
	title_label = _label("", 25, Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title_label)
	message_label = _label("", 14, Color("d6dfdf"))
	message_label.custom_minimum_size = Vector2(590, 108)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rows.add_child(message_label)
	epilogue_label = _label("", 13, Color("aab6b8"))
	epilogue_label.custom_minimum_size = Vector2(590, 50)
	epilogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epilogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(epilogue_label)
	restart_button = Button.new()
	restart_button.text = "[ RICOMINCIA LA MISSIONE DA ZERO ]"
	restart_button.custom_minimum_size = Vector2(390, 48)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.add_theme_font_size_override("font_size", 15)
	restart_button.add_theme_stylebox_override("normal", _button_style(Color("27353c")))
	restart_button.add_theme_stylebox_override("hover", _button_style(Color("3d535c")))
	restart_button.add_theme_stylebox_override("pressed", _button_style(Color("182126")))
	restart_button.pressed.connect(GameState.restart_from_scratch)
	rows.add_child(restart_button)
	var warning := _label("ATTENZIONE: inventario, strutture, budget e progressi verranno azzerati.", 11, Color("d17c72"))
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(warning)
	overlay.visible = false


func _show_death(data: Dictionary) -> void:
	var color: Color = data.get("color", Color.WHITE)
	code_label.text = str(data.get("code", "MISSION // END"))
	code_label.add_theme_color_override("font_color", color)
	title_label.text = str(data.get("title", "MISSIONE TERMINATA"))
	title_label.add_theme_color_override("font_color", color)
	message_label.text = str(data.get("message", ""))
	epilogue_label.text = str(data.get("epilogue", ""))
	accent.color = color
	overlay.visible = true
	restart_button.grab_focus()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("000000"))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10171deb")
	style.border_color = Color("5b6e75")
	style.set_border_width_all(4)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c4d1d2")
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
