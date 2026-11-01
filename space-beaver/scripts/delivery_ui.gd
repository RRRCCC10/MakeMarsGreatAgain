extends CanvasLayer

var panel: PanelContainer
var title_label: Label
var detail_label: Label


func _ready() -> void:
	layer = 44
	_build_ui()
	DeliveryManager.order_changed.connect(_refresh)
	DeliveryManager.capsule_dispatched.connect(_on_capsule_event)
	DeliveryManager.capsule_landed.connect(_on_capsule_event)
	DeliveryManager.capsule_emptied.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -230.0
	panel.offset_right = 230.0
	panel.offset_top = 92.0
	panel.offset_bottom = 152.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	panel.add_child(rows)
	title_label = _label("", 14, Color("ffe38a"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title_label)
	detail_label = _label("", 11, Color("d5e6e7"))
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rows.add_child(detail_label)


func _refresh() -> void:
	var status := DeliveryManager.get_delivery_status()
	if bool(status["pending"]):
		panel.visible = true
		title_label.text = "ORDINE IN PREPARAZIONE  ·  %.1f s" % float(status["seconds"])
		detail_label.text = str(status["pending_summary"])
	elif int(status["descending"]) > 0:
		panel.visible = true
		title_label.text = "CAPSULA DI RIFORNIMENTO IN DISCESA"
		detail_label.text = "Allontanati dalla zona di atterraggio"
	elif int(status["landed"]) > 0:
		panel.visible = true
		title_label.text = "RIFORNIMENTO ATTERRATO"
		detail_label.text = "Avvicinati alla capsula e premi E"
	else:
		panel.visible = false


func _on_capsule_event(_capsule: Node) -> void:
	_refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("03070a"))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a22e8")
	style.border_color = Color("d4aa4f")
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

