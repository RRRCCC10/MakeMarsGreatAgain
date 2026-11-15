extends CanvasLayer

## Notifica non bloccante per i traguardi appena completati. I nodi della
## rete possono raggiungere il proprio target prima dei prerequisiti: in quel
## caso la schermata celebra comunque il risultato, ma non promette una
## ricompensa riscattabile fino a quando la catena non e' stata completata.

const DISPLAY_SECONDS := 4.5

var _root: Control
var _card: PanelContainer
var _eyebrow: Label
var _icon: Label
var _title: Label
var _description: Label
var _reward: Label
var _hint: Label
var _queue: Array[Dictionary] = []
var _showing := false
var _display_generation := 0


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	AchievementManager.achievement_reached.connect(_on_achievement_reached)


func _on_achievement_reached(achievement_id: String, claimable_now: bool) -> void:
	# La tavola e' gia' la vista dettagliata degli obiettivi: non sovrapponiamo
	# una seconda interfaccia mentre il giocatore la sta consultando.
	if AchievementManager.is_board_open:
		return
	var definition := AchievementManager.get_definition(achievement_id)
	if definition.is_empty():
		return
	_queue.append({"id": achievement_id, "claimable": claimable_now})
	if not _showing:
		_show_next()


func _input(event: InputEvent) -> void:
	if not _showing or _root == null or not _root.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_current()
		get_viewport().set_input_as_handled()


func _dismiss_current() -> void:
	if not _showing:
		return
	_display_generation += 1
	_showing = false
	_root.visible = false
	if not _queue.is_empty():
		_queue.pop_front()
	if not _queue.is_empty():
		call_deferred("_show_next")


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var generation := _display_generation
	var entry: Dictionary = _queue.front()
	var definition := AchievementManager.get_definition(str(entry.get("id", "")))
	var color: Color = definition.get("color", Color("ffd36a"))
	var claimable_now := bool(entry.get("claimable", false))
	var reward: Dictionary = definition.get("reward", {})
	_card.add_theme_stylebox_override("panel", _card_style(color))
	_eyebrow.add_theme_color_override("font_color", color)
	_icon.text = str(definition.get("icon", "✦"))
	_icon.add_theme_color_override("font_color", color)
	_title.text = str(definition.get("title", "OBIETTIVO RAGGIUNTO"))
	_description.text = str(definition.get("description", ""))
	_reward.text = "RICOMPENSA  " + str(reward.get("label", "Pronta per il riscatto"))
	_hint.text = "J  ·  Apri la tavola e riscatta la ricompensa" if claimable_now else "PROGRESSO SALVATO  ·  completa prima i prerequisiti della rete"
	_hint.add_theme_color_override("font_color", Color("ffe178") if claimable_now else Color("b7c4cb"))
	_root.visible = true
	_card.modulate = Color(1, 1, 1, 0)
	_card.scale = Vector2(0.88, 0.88)
	var appear := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(_card, "modulate:a", 1.0, 0.20)
	appear.parallel().tween_property(_card, "scale", Vector2.ONE, 0.28)
	await get_tree().create_timer(DISPLAY_SECONDS, true).timeout
	if generation != _display_generation or not _showing:
		return
	var vanish := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	vanish.tween_property(_card, "modulate:a", 0.0, 0.20)
	vanish.parallel().tween_property(_card, "scale", Vector2(0.96, 0.96), 0.20)
	await vanish.finished
	if generation != _display_generation or not _showing:
		return
	_root.visible = false
	_queue.pop_front()
	_showing = false
	_show_next()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AchievementSuccessRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 20)
	safe_area.add_theme_constant_override("margin_right", 20)
	safe_area.add_theme_constant_override("margin_top", 40)
	_root.add_child(safe_area)
	var alignment := CenterContainer.new()
	alignment.anchor_top = 0.0
	alignment.anchor_bottom = 0.0
	alignment.offset_bottom = 170.0
	safe_area.add_child(alignment)
	_card = PanelContainer.new()
	_card.name = "AchievementSuccessCard"
	_card.custom_minimum_size = Vector2(440, 150)
	_card.pivot_offset = Vector2(220, 75)
	alignment.add_child(_card)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 15)
	margins.add_theme_constant_override("margin_right", 15)
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_bottom", 10)
	_card.add_child(margins)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	margins.add_child(rows)
	_eyebrow = _label("// TRAGUARDO RAGGIUNTO //", 12, Color("ffd36a"))
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_eyebrow)
	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 10)
	rows.add_child(main_row)
	_icon = _label("✦", 34, Color("ffd36a"))
	_icon.custom_minimum_size = Vector2(42, 46)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_vertical_center(_icon)
	main_row.add_child(_icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	main_row.add_child(copy)
	_title = _label("", 19, Color("f4f7ef"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_title)
	_description = _label("", 11, Color("c5d2d7"))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_description)
	_reward = _label("", 11, Color("a9e8ba"))
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_reward)
	_hint = _label("", 10, Color("b7c4cb"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_hint)


func icon_vertical_center(label: Label) -> void:
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("030609"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d1822f5")
	style.border_color = color
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style
