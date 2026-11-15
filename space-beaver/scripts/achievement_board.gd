extends CanvasLayer

## Horizontal mission board. Every milestone shows its progress, while each
## reward visually and logically unlocks the next one.

const CARD_SIZE := Vector2(172.0, 190.0)

var _root: Control
var _route: HBoxContainer
var _detail: Label
var _hint: Label
var _notification: Label
var _claimable_cards: Array[Control] = []
var _time := 0.0


func _ready() -> void:
	layer = 30
	_build_ui()
	AchievementManager.achievement_updated.connect(_on_achievement_updated)
	AchievementManager.achievement_claimable.connect(_on_achievement_claimable)
	AchievementManager.achievement_claimed.connect(_on_achievement_claimed)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_time += delta
	var pulse := 0.84 + (sin(_time * 5.5) + 1.0) * 0.08
	for card in _claimable_cards:
		if is_instance_valid(card):
			card.modulate = Color(1.0, pulse, 0.62 + pulse * 0.18, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_J:
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.keycode in [KEY_ESCAPE, KEY_B]:
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _root.visible:
		close()
	else:
		open()


func open() -> void:
	_root.visible = true
	AchievementManager.is_board_open = true
	_rebuild_route()


func close() -> void:
	_root.visible = false
	AchievementManager.is_board_open = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AchievementBoardRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.028, 0.045, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 26.0
	panel.offset_top = 24.0
	panel.offset_right = -26.0
	panel.offset_bottom = -24.0
	panel.add_theme_stylebox_override("panel", _box(Color("111d29"), Color("4ba7cb"), 2, 10))
	_root.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 22)
	margins.add_theme_constant_override("margin_right", 22)
	margins.add_theme_constant_override("margin_top", 16)
	margins.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margins.add_child(content)

	var title := Label.new()
	title.text = "// OBJECTIVE BOARD //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffe37b"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "The line advances from left to right: complete and claim a milestone to make the next one available."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("c0d1db"))
	content.add_child(subtitle)

	var line := ColorRect.new()
	line.color = Color("456170")
	line.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(line)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, 226.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_route = HBoxContainer.new()
	_route.name = "MissionRoute"
	_route.add_theme_constant_override("separation", 8)
	_route.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(_route)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.custom_minimum_size = Vector2(0.0, 48.0)
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", Color("d7e8ef"))
	content.add_child(_detail)
	_hint = Label.new()
	_hint.text = "J · close board     |     Click a glowing milestone to claim its reward"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color("87cdef"))
	content.add_child(_hint)

	_notification = Label.new()
	_notification.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notification.offset_left = -430.0
	_notification.offset_top = 10.0
	_notification.offset_right = -12.0
	_notification.offset_bottom = 54.0
	_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notification.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification.add_theme_font_size_override("font_size", 12)
	_notification.add_theme_color_override("font_color", Color("fff3a2"))
	_notification.add_theme_color_override("font_outline_color", Color("071017"))
	_notification.add_theme_constant_override("outline_size", 4)
	_notification.visible = false
	# The message remains visible even while the board is closed, immediately
	# informing the player that a milestone glows and can be claimed with J.
	add_child(_notification)


func _rebuild_route() -> void:
	if _route == null:
		return
	for child in _route.get_children():
		child.queue_free()
	_claimable_cards.clear()
	var definitions := AchievementManager.get_ordered_definitions()
	for index in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		var card := _make_card(definition)
		_route.add_child(card)
		if index < definitions.size() - 1:
			_route.add_child(_make_connector(str(definition.get("id", ""))))
	if not definitions.is_empty():
		_show_detail(str(definitions[0].get("id", "")))


func _make_connector(previous_id: String) -> Control:
	var connector := Label.new()
	connector.custom_minimum_size = Vector2(54.0, 190.0)
	connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	connector.text = "━━━━▶"
	connector.add_theme_font_size_override("font_size", 14)
	connector.add_theme_color_override("font_color", Color("73d8aa") if AchievementManager.is_claimed(previous_id) else Color("4c5b66"))
	return connector


func _make_card(definition: Dictionary) -> Control:
	var achievement_id := str(definition.get("id", ""))
	var status := AchievementManager.get_status(achievement_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.tooltip_text = str(definition.get("description", ""))
	var border_color := Color("394955")
	var fill_color := Color("17212a")
	if status == "locked":
		border_color = Color("7f3137")
		fill_color = Color("1d1b20")
	elif status == "available":
		border_color = Color("6e7d86")
		fill_color = Color("263039")
	elif status == "claimed":
		border_color = Color(definition.get("color", Color.WHITE))
		fill_color = Color("20313a")
	else:
		border_color = Color("ffe379")
		fill_color = Color("3a3420")
		_claimable_cards.append(card)
	card.add_theme_stylebox_override("panel", _box(fill_color, border_color, 2, 5))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_pressed(achievement_id)
	)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(0.0, 7.0)
	stripe.color = Color("d84d55") if status == "locked" else (Color("ffd95f") if status == "claimable" else (Color(definition.get("color", Color.WHITE)) if status == "claimed" else Color("7b8790")))
	stack.add_child(stripe)
	var icon := Label.new()
	icon.text = str(definition.get("icon", "•"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(0.0, 40.0)
	icon.add_theme_font_size_override("font_size", 29)
	icon.add_theme_color_override("font_color", Color("6c7880") if status in ["locked", "available"] else Color(definition.get("color", Color.WHITE)))
	stack.add_child(icon)
	var title := Label.new()
	title.text = str(definition.get("title", "OBJECTIVE"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0.0, 32.0)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("e6eff2") if status != "locked" else Color("a57b7f"))
	stack.add_child(title)
	var progress := Label.new()
	progress.text = "PROGRESS %d / %d" % [AchievementManager.get_progress(achievement_id), AchievementManager.get_target(achievement_id)]
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 10)
	progress.add_theme_color_override("font_color", Color("a7c4cf"))
	stack.add_child(progress)
	var state := Label.new()
	state.text = _status_text(achievement_id, status)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.custom_minimum_size = Vector2(0.0, 29.0)
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", Color("ffe47b") if status == "claimable" else Color("bcc8cd"))
	stack.add_child(state)
	return card


func _status_text(achievement_id: String, status: String) -> String:
	if status == "locked":
		return "▰ LOCKED"
	if status == "available":
		return "IN PROGRESS"
	if status == "claimable":
		return "✦ CLAIM ✦"
	var reward: Dictionary = AchievementManager.get_definition(achievement_id).get("reward", {})
	return "✓ " + str(reward.get("label", "CLAIMED"))


func _on_card_pressed(achievement_id: String) -> void:
	if AchievementManager.is_claimable(achievement_id):
		AchievementManager.claim(achievement_id)
		_rebuild_route()
	else:
		_show_detail(achievement_id)


func _show_detail(achievement_id: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	if definition.is_empty():
		return
	var status := AchievementManager.get_status(achievement_id)
	var reward: Dictionary = definition.get("reward", {})
	var text := "%s — %s\nReward: %s" % [str(definition.get("title", "")), str(definition.get("description", "")), str(reward.get("label", "none"))]
	if status == "locked":
		text += "\nComplete and claim the previous milestone to unlock this reward. Progress remains recorded."
	elif status == "available":
		text += "\nAvailable: complete the objective to make the reward claimable."
	elif status == "claimable":
		text += "\nREADY: click the glowing milestone to claim it and unlock the next one."
	else:
		text += "\nReward already claimed."
	_detail.text = text


func _on_achievement_updated(_achievement_id: String) -> void:
	if _root.visible:
		_rebuild_route()


func _on_achievement_claimable(achievement_id: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	_show_notification("OBJECTIVE READY · %s · press J" % str(definition.get("title", "")))


func _on_achievement_claimed(achievement_id: String, reward_label: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	_show_notification("REWARD CLAIMED · %s · %s" % [str(definition.get("title", "")), reward_label])


func _show_notification(message: String) -> void:
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
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 8.0
	return box
