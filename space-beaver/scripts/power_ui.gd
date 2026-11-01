extends CanvasLayer

var status_label: Label
var time_label: Label
var production_label: Label
var solar_label: Label
var demand_label: Label
var battery_label: Label
var autonomy_label: Label


func _ready() -> void:
	_build_ui()
	PowerGrid.stats_changed.connect(_refresh)
	_refresh(PowerGrid.get_stats())


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -250.0
	panel.offset_top = 114.0
	panel.offset_right = -16.0
	panel.offset_bottom = 302.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	var title := _label(">> RETE ELETTRICA", 14, Color("ffe38a"))
	rows.add_child(title)
	status_label = _label("", 15, Color.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rows.add_child(status_label)
	time_label = _label("", 11, Color("b9c8ca"))
	production_label = _label("", 11, Color("6fe8a3"))
	solar_label = _label("", 11, Color("ffe38a"))
	demand_label = _label("", 11, Color("ffad66"))
	battery_label = _label("", 11, Color("69a7ff"))
	autonomy_label = _label("", 11, Color("b9c8ca"))
	rows.add_child(time_label)
	rows.add_child(production_label)
	rows.add_child(solar_label)
	rows.add_child(demand_label)
	rows.add_child(battery_label)
	rows.add_child(autonomy_label)


func _refresh(data: Dictionary) -> void:
	var status := str(data.get("status", "RETE INCOMPLETA"))
	status_label.text = status
	var status_color := Color("7fe39d")
	if status == "BLACKOUT":
		status_color = Color("ff655d")
	elif status in ["RETE INCOMPLETA", "RETE DISCONNESSA"]:
		status_color = Color("ffb45d")
	status_label.add_theme_color_override("font_color", status_color)
	var hour := float(data.get("hour", 0.0))
	var whole_hour := floori(hour)
	var minutes := floori((hour - whole_hour) * 60.0)
	time_label.text = "%s  %02d:%02d" % [str(data.get("phase", "NOTTE")), whole_hour, minutes]
	production_label.text = "PRODUZIONE  %d kW  (%d/%d pannelli)" % [roundi(data.get("production_kw", 0.0)), int(data.get("panels_connected", 0)), int(data.get("panels_total", 0))]
	solar_label.text = "LUCE SOLARE %d%%" % roundi(float(data.get("solar_factor", 0.0)) * 100.0)
	demand_label.text = "RICHIESTA   %d kW" % roundi(data.get("demand_kw", 0.0))
	battery_label.text = "BATTERIE RETE %d/%d kWh  [%d/%d]" % [
		roundi(data.get("connected_battery_kwh", 0.0)),
		roundi(data.get("connected_battery_capacity_kwh", 0.0)),
		int(data.get("batteries_connected", 0)),
		int(data.get("batteries_total", 0)),
	]
	var autonomy := float(data.get("battery_autonomy_hours", -1.0))
	autonomy_label.text = "AUTONOMIA   STABILE" if autonomy < 0.0 else "AUTONOMIA   %.1f h" % autonomy


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("05090d"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101820")
	style.border_color = Color("dfbd52")
	style.set_border_width_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
