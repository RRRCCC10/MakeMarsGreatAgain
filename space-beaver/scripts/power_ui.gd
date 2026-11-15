extends CanvasLayer

## Electrical distribution center.
##
## Replaces the old permanent HUD with one operational page. Read flows and
## enable or disable every grid element here. UIState blocks the world while
## the page is open.

const PAGE_MODAL_ID := &"power_network"
const REFRESH_INTERVAL := 0.20
const UI_FONT := preload("res://assets/fonts/font-regular.ttf")

var _root: Control
var _network_status: Label
var _network_note: Label
var _metrics: Dictionary = {}
var _device_rows: VBoxContainer
var _device_count: Label
var _notice: Label
var _device_row_by_id: Dictionary = {}
var _empty_state: Label
var _refresh_elapsed := 0.0


func _ready() -> void:
	layer = 82
	_build_ui()
	var power_grid := _power_grid()
	if power_grid != null and power_grid.has_signal("stats_changed"):
		power_grid.connect("stats_changed", _on_stats_changed)
	if power_grid != null and power_grid.has_signal("routing_failed"):
		power_grid.connect("routing_failed", _on_routing_failed)
	_refresh()


func _process(delta: float) -> void:
	if _root == null or not _root.visible:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_L:
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func toggle() -> bool:
	if _root.visible:
		close()
		return false
	return open()


func open() -> bool:
	if _root.visible:
		return true
	if not _try_open_modal():
		return false
	_notice.text = ""
	_root.visible = true
	_refresh_elapsed = REFRESH_INTERVAL
	_refresh()
	return true


func close() -> void:
	if _root == null or not _root.visible:
		_close_modal()
		return
	_root.visible = false
	_close_modal()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PowerNetworkRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_font_override("font", UI_FONT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color("03080dee")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "PowerNetworkPanel"
	panel.anchor_left = 0.045
	panel.anchor_top = 0.045
	panel.anchor_right = 0.955
	panel.anchor_bottom = 0.955
	panel.add_theme_stylebox_override("panel", _box(Color("0d1b24"), Color("4fc0e8"), 3, 10))
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
	var title := _label("ELECTRICAL DISTRIBUTION CENTER", 22, Color("ffe07c"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_outline_color", Color("03070a"))
	title.add_theme_constant_override("outline_size", 3)
	title_row.add_child(title)
	var close_hint := _label("L / ESC · CLOSE", 12, Color("9edcf2"))
	close_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(close_hint)

	var subtitle := _label("Only grid-connected elements appear here. Use a button to enable or disable an element.", 12, Color("bacbd2"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)

	var overview := PanelContainer.new()
	overview.add_theme_stylebox_override("panel", _box(Color("0a141b"), Color("315869"), 1, 6))
	content.add_child(overview)
	var overview_rows := VBoxContainer.new()
	overview_rows.add_theme_constant_override("separation", 6)
	overview.add_child(overview_rows)
	_network_status = _label("", 17, Color("dceff2"))
	overview_rows.add_child(_network_status)
	_network_note = _label("", 11, Color("93b2bf"))
	overview_rows.add_child(_network_note)
	var metric_grid := GridContainer.new()
	metric_grid.columns = 5
	metric_grid.add_theme_constant_override("h_separation", 7)
	metric_grid.add_theme_constant_override("v_separation", 7)
	overview_rows.add_child(metric_grid)
	_metrics["production"] = _make_metric(metric_grid, "PRODUCTION", Color("71e6a4"))
	_metrics["demand"] = _make_metric(metric_grid, "DEMAND", Color("ffb46b"))
	_metrics["battery"] = _make_metric(metric_grid, "RESERVE", Color("79aaff"))
	_metrics["solar"] = _make_metric(metric_grid, "SUN", Color("ffe38b"))
	_metrics["autonomy"] = _make_metric(metric_grid, "AUTONOMY", Color("91c8db"))

	var devices_header := HBoxContainer.new()
	content.add_child(devices_header)
	var devices_title := _label("GRID ELEMENTS", 14, Color("7ee5ff"))
	devices_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	devices_header.add_child(devices_title)
	_device_count = _label("", 11, Color("9eb6bf"))
	_device_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	devices_header.add_child(_device_count)

	var table_header := _label("GRID ELEMENTS · each card has its own control", 10, Color("77929c"))
	content.add_child(table_header)

	var scroll := ScrollContainer.new()
	scroll.name = "PowerNetworkDeviceScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 290)
	content.add_child(scroll)
	_device_rows = VBoxContainer.new()
	_device_rows.name = "PowerNetworkDeviceRows"
	_device_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_device_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_device_rows)

	_notice = _label("", 11, Color("a7eecc"))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.custom_minimum_size = Vector2(0, 18)
	content.add_child(_notice)
	var footer := _label("GREEN operational · YELLOW awaiting power or no cable · RED disconnected · L / ESC closes", 10, Color("78959f"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)


func _make_metric(parent: Control, title: String, color: Color) -> Label:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(135, 54)
	frame.add_theme_stylebox_override("panel", _box(Color("111f28"), color.darkened(0.36), 1, 5))
	parent.add_child(frame)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(column)
	var title_label := _label(title, 9, color)
	column.add_child(title_label)
	var value := _label("—", 14, Color("e5eff2"))
	column.add_child(value)
	return value


func _on_stats_changed(_data: Dictionary) -> void:
	if _root != null and _root.visible:
		_refresh()


func _on_routing_failed(_device: Node, message: String) -> void:
	if _notice == null:
		return
	_notice.text = message
	_notice.add_theme_color_override("font_color", Color("ff776d"))


func _refresh() -> void:
	if _network_status == null:
		return
	var power_grid := _power_grid()
	if power_grid == null:
		_network_status.text = "GRID UNAVAILABLE"
		_network_note.text = "The power-grid controller has not initialized."
		return
	var stats: Dictionary = power_grid.call("get_stats")
	var status := str(stats.get("status", "GRID INCOMPLETE"))
	_network_status.text = "GRID STATUS · " + status
	_network_status.add_theme_color_override("font_color", _status_color(status))
	var hour := float(stats.get("hour", 0.0))
	_network_note.text = "%s · %02d:%02d · %d pannelli collegati su %d · %d batterie collegate su %d" % [
		str(stats.get("phase", "OPERATIONS")),
		floori(hour),
		floori((hour - floorf(hour)) * 60.0),
		int(stats.get("panels_connected", 0)),
		int(stats.get("panels_total", 0)),
		int(stats.get("batteries_connected", 0)),
		int(stats.get("batteries_total", 0)),
	]
	_metrics["production"].text = "%d kW" % roundi(float(stats.get("production_kw", 0.0)))
	_metrics["demand"].text = "%d kW" % roundi(float(stats.get("demand_kw", 0.0)))
	_metrics["battery"].text = "%d / %d kWh" % [roundi(float(stats.get("connected_battery_kwh", 0.0))), roundi(float(stats.get("connected_battery_capacity_kwh", 0.0)))]
	_metrics["solar"].text = "%d%% light" % roundi(float(stats.get("solar_factor", 0.0)) * 100.0)
	var autonomy := float(stats.get("battery_autonomy_hours", -1.0))
	_metrics["autonomy"].text = "STABLE" if autonomy < 0.0 else "%.1f h" % autonomy
	_rebuild_device_rows(Array(power_grid.call("get_network_devices")))


func _rebuild_device_rows(devices: Array) -> void:
	_device_count.text = "%d devices detected" % devices.size()
	if devices.is_empty():
		for key in _device_row_by_id.keys():
			var old_row := _device_row_by_id[key] as Control
			if old_row != null and is_instance_valid(old_row):
				old_row.queue_free()
		_device_row_by_id.clear()
		if _empty_state == null or not is_instance_valid(_empty_state):
			_empty_state = _label("No electrical element built. Buy and place a panel, transformer, or device to power.", 13, Color("9db5bd"))
			_empty_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_empty_state.custom_minimum_size = Vector2(0, 72)
			_device_rows.add_child(_empty_state)
		return
	if _empty_state != null and is_instance_valid(_empty_state):
		_empty_state.queue_free()
		_empty_state = null
	var seen_ids: Dictionary = {}
	for entry_variant in devices:
		var entry: Dictionary = entry_variant
		var device := entry.get("node") as Node
		if device == null or not is_instance_valid(device):
			continue
		var key := str(device.get_instance_id())
		seen_ids[key] = true
		var row := _device_row_by_id.get(key) as Control
		if row == null or not is_instance_valid(row):
			row = _make_device_row(entry)
			row.set_meta("device_key", key)
			_device_rows.add_child(row)
			_device_row_by_id[key] = row
		_update_device_row(row, entry)
	for key in _device_row_by_id.keys().duplicate():
		if seen_ids.has(key):
			continue
		var row := _device_row_by_id[key] as Control
		if row != null and is_instance_valid(row):
			row.queue_free()
		_device_row_by_id.erase(key)


func _make_device_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 92)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 8)
	margins.add_theme_constant_override("margin_right", 8)
	margins.add_theme_constant_override("margin_top", 6)
	margins.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margins.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var role_badge := _label("", 9, Color("c3d4d9"))
	role_badge.custom_minimum_size = Vector2(112, 22)
	role_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(role_badge)
	var name := _label("", 14, Color("eaf3f4"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name)
	var button := Button.new()
	button.custom_minimum_size = Vector2(148, 34)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_toggle_device.bind(entry.get("node") as Node))
	header.add_child(button)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	column.add_child(status_row)
	var state := _label("", 11, Color("eaf3f4"))
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(state)
	var power_label := _label("", 10, Color("c3d4d9"))
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(power_label)
	var detail := _label("", 10, Color("91aab3"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	row.set_meta("role_badge", role_badge)
	row.set_meta("name_label", name)
	row.set_meta("state_label", state)
	row.set_meta("power_label", power_label)
	row.set_meta("detail_label", detail)
	row.set_meta("toggle_button", button)
	return row


func _update_device_row(row: Control, entry: Dictionary) -> void:
	if row == null or not is_instance_valid(row):
		return
	var enabled := bool(entry.get("enabled", false))
	var connected := bool(entry.get("connected", false))
	var role := str(entry.get("role", "ELEMENT"))
	var state_text := str(entry.get("status", ""))
	var role_badge := row.get_meta("role_badge") as Label
	var name := row.get_meta("name_label") as Label
	var state := row.get_meta("state_label") as Label
	var power_label := row.get_meta("power_label") as Label
	var detail := row.get_meta("detail_label") as Label
	var button := row.get_meta("toggle_button") as Button
	if role_badge != null:
		role_badge.text = role
		role_badge.add_theme_color_override("font_color", _role_color(role))
	if name != null:
		name.text = str(entry.get("name", "ELEMENT"))
	if state != null:
		state.text = state_text
		state.add_theme_color_override("font_color", _status_color(state_text))
	if power_label != null:
		power_label.text = _power_text(role, float(entry.get("power_kw", 0.0)), enabled, connected)
	if detail != null:
		detail.text = str(entry.get("detail", ""))
	if button != null:
		button.text = "DISCONNECT" if enabled else "CONNECT"
		button.tooltip_text = "Disconnect this element from the grid" if enabled else "Enable this element"
		button.disabled = not bool(entry.get("can_toggle", false))
		button.add_theme_stylebox_override("normal", _button_style(Color("a9444f") if enabled else Color("39785f")))
		button.add_theme_stylebox_override("hover", _button_style(Color("d95a66") if enabled else Color("55ad83")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("8d3440") if enabled else Color("2c604b")))
		button.add_theme_stylebox_override("disabled", _button_style(Color("39474d")))
	row.add_theme_stylebox_override("panel", _box(Color("111f28"), _status_color(state_text).darkened(0.28), 1, 5))


func _toggle_device(device: Node, requested_enabled: Variant = null) -> void:
	var power_grid := _power_grid()
	if power_grid == null or not is_instance_valid(device):
		return
	var should_enable := not bool(device.call("is_network_enabled")) if device.has_method("is_network_enabled") else true
	if requested_enabled != null:
		should_enable = bool(requested_enabled)
	if bool(power_grid.call("set_device_network_enabled", device, should_enable)):
		_notice.text = ("CONNECTED · " if should_enable else "DISCONNECTED · ") + _device_name(device)
		_notice.add_theme_color_override("font_color", Color("a7eecc"))
	else:
		_notice.text = "THIS ELEMENT DOES NOT SUPPORT MANUAL CONTROL"
	_refresh_elapsed = REFRESH_INTERVAL
	_refresh()


func _power_text(role: String, value: float, enabled: bool, connected: bool) -> String:
	if not enabled:
		return "no flow · disabled"
	if not connected:
		return "no flow · cable absent"
	match role:
		"GENERATION":
			return "%.0f kW available" % value
		"STORAGE":
			return "%.0f kWh stored" % value
		"CONSUMPTION":
			return "%.0f kW requested" % value
	return "grid bridge"


func _device_name(device: Node) -> String:
	if device != null and is_instance_valid(device) and device.has_method("get_display_name"):
		return str(device.call("get_display_name")).to_upper()
	return str(device.name).to_upper() if device != null and is_instance_valid(device) else "ELEMENT"


func _power_grid() -> Node:
	return get_node_or_null("/root/PowerGrid")


func _try_open_modal() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state == null or bool(ui_state.call("try_open_modal", PAGE_MODAL_ID))


func _close_modal() -> void:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", PAGE_MODAL_ID)


func _status_color(status: String) -> Color:
	if status in ["OPERATIONAL", "GRID ACTIVE", "CHARGING", "DIRECT GRID", "BATTERY"]:
		return Color("78e9aa")
	if status in ["CONNECTED · AWAITING POWER", "AWAITING LIGHT", "GRID INCOMPLETE", "CABLE NOT CONNECTED"]:
		return Color("ffd278")
	return Color("f16d70")


func _role_color(role: String) -> Color:
	match role:
		"GENERATION": return Color("78e9aa")
		"CONVERSION": return Color("7ed8f4")
		"STORAGE": return Color("82aaff")
		"CONSUMPTION": return Color("ffb56f")
	return Color("c3d4d9")


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("03080c"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := _box(color.darkened(0.52), color, 1, 4)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
