extends CanvasLayer

## Tavola in stile advancement: una radice, rami indipendenti e nodi
## connessi da linee. Il progresso di ogni nodo viene sempre mostrato, ma una
## ricompensa richiede che i suoi predecessori siano stati riscossi.

const CARD_SIZE := Vector2(130.0, 70.0)
const GRAPH_SIZE := Vector2(2_000.0, 550.0)

# Due contratti sul campo partono subito, senza rete o macchinari. Da qui il
# grafo si divide in sopravvivenza, habitat, laboratorio e biologia polare.
const GRAPH_POSITIONS := {
	# Contratti a piedi: due radici completamente indipendenti dalla base.
	"first_field_sample": Vector2(24.0, 30.0),
	"field_notes": Vector2(190.0, 30.0),
	"sample_satchel": Vector2(356.0, 30.0),
	"surface_catalog": Vector2(522.0, 30.0),
	"surface_anomaly": Vector2(522.0, 110.0),
	"first_horizon": Vector2(24.0, 210.0),
	"biome_survey": Vector2(190.0, 210.0),
	"long_range_survey": Vector2(356.0, 210.0),
	"polar_expedition": Vector2(522.0, 210.0),
	# Sopravvivenza e habitat.
	"first_base": Vector2(24.0, 400.0),
	"airlock_cycle": Vector2(190.0, 300.0),
	"ice_drill": Vector2(356.0, 300.0),
	"refill_bottle": Vector2(522.0, 300.0),
	"stable_grid": Vector2(190.0, 400.0),
	"greenhouse": Vector2(356.0, 400.0),
	"first_planting": Vector2(522.0, 400.0),
	"first_harvest": Vector2(688.0, 480.0),
	# Ricerca economica, dati rari e biologia polare.
	"first_lab": Vector2(688.0, 400.0),
	"first_extraction": Vector2(854.0, 300.0),
	"first_report": Vector2(854.0, 400.0),
	"chain_of_custody": Vector2(1_020.0, 400.0),
	"rare_signal": Vector2(1_020.0, 30.0),
	"regional_atlas": Vector2(1_186.0, 30.0),
	"planetary_archive": Vector2(1_352.0, 30.0),
	"rare_constellation": Vector2(1_518.0, 30.0),
	"polar_drill": Vector2(1_020.0, 110.0),
	"primordial_ice": Vector2(1_186.0, 110.0),
	"deep_ice_study": Vector2(1_352.0, 110.0),
	"ancient_life": Vector2(1_518.0, 110.0),
	"life_relay": Vector2(1_684.0, 110.0),
	"xrd_fieldwork": Vector2(1_186.0, 210.0),
	"xrd_master": Vector2(1_352.0, 210.0),
	"raman_fieldwork": Vector2(1_186.0, 300.0),
	"raman_master": Vector2(1_352.0, 300.0),
	"icp_fieldwork": Vector2(1_186.0, 400.0),
	"icp_master": Vector2(1_352.0, 400.0),
	"data_convoy": Vector2(1_186.0, 480.0),
	"earth_relay": Vector2(1_352.0, 480.0),
	"science_center": Vector2(1_684.0, 300.0),
	"martian_dividend": Vector2(1_850.0, 300.0),
}


class GraphLinks extends Control:
	var links: Array[Dictionary] = []

	func set_links(new_links: Array[Dictionary]) -> void:
		links = new_links
		queue_redraw()

	func _draw() -> void:
		for link in links:
			var from: Vector2 = link.get("from", Vector2.ZERO)
			var to: Vector2 = link.get("to", Vector2.ZERO)
			var color: Color = link.get("color", Color("3d4b55"))
			var direction := (to - from).normalized()
			if direction.length_squared() <= 0.001:
				continue
			var tip := to - direction * 18.0
			var normal := Vector2(-direction.y, direction.x)
			draw_line(from, tip, color, 3.0, true)
			draw_circle(from, 4.0, color)
			draw_colored_polygon(PackedVector2Array([to, tip + normal * 6.0, tip - normal * 6.0]), color)


var _root: Control
var _graph: Control
var _detail: Label
var _notification: Label
var _claimable_cards: Array[Control] = []
var _hidden_layers: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	# Sopra ogni HUD: la tavola è una schermata dedicata, non un pannello sopra
	# le barre di sopravvivenza o le finestre del mondo.
	layer = 100
	_build_ui()
	AchievementManager.achievement_updated.connect(_on_achievement_updated)
	AchievementManager.achievement_claimable.connect(_on_achievement_claimable)
	AchievementManager.achievement_claimed.connect(_on_achievement_claimed)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_time += delta
	var pulse := 0.82 + (sin(_time * 6.0) + 1.0) * 0.09
	for card in _claimable_cards:
		if is_instance_valid(card):
			card.modulate = Color(1.0, pulse, 0.58 + pulse * 0.22, 1.0)


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
	if _root.visible:
		return
	_hide_external_ui()
	_notification.visible = false
	_root.visible = true
	AchievementManager.is_board_open = true
	_rebuild_graph()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	AchievementManager.is_board_open = false
	_restore_external_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AchievementBoardRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color("061018")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = -12.0
	panel.add_theme_stylebox_override("panel", _box(Color("0d1923"), Color("4ba7cb"), 2, 9))
	_root.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 16)
	margins.add_theme_constant_override("margin_right", 16)
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margins.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "// RETE DEI CONTRATTI DI MISSIONE //"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ffe37b"))
	title_row.add_child(title)
	var close_label := Label.new()
	close_label.text = "J / ESC · CHIUDI"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_label.add_theme_font_size_override("font_size", 12)
	close_label.add_theme_color_override("font_color", Color("91cfe9"))
	title_row.add_child(close_label)

	var subtitle := Label.new()
	subtitle.text = "La ricerca è il motore economico della prima metà della missione: ogni rapporto paga, ogni contratto paga molto di più. Le frecce indicano i prerequisiti."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("c0d1db"))
	content.add_child(subtitle)

	var legend := Label.new()
	legend.text = "ROSSO: BLOCCATO   ·   GRIGIO: IN CORSO   ·   COLORE: RISCOSSO   ·   ORO PULSANTE: RISCATTA"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 9)
	legend.add_theme_color_override("font_color", Color("9ab6c2"))
	content.add_child(legend)

	var divider := ColorRect.new()
	divider.color = Color("3e5d6d")
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "AchievementGraphScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0.0, 460.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_graph = Control.new()
	_graph.name = "MissionGraph"
	_graph.custom_minimum_size = GRAPH_SIZE
	_graph.size = GRAPH_SIZE
	scroll.add_child(_graph)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.custom_minimum_size = Vector2(0.0, 36.0)
	_detail.add_theme_font_size_override("font_size", 11)
	_detail.add_theme_color_override("font_color", Color("d7e8ef"))
	content.add_child(_detail)

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
	add_child(_notification)


func _rebuild_graph() -> void:
	if _graph == null:
		return
	for child in _graph.get_children():
		child.queue_free()
	_claimable_cards.clear()

	var background := ColorRect.new()
	background.name = "GraphBackground"
	background.color = Color("101e29")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.position = Vector2.ZERO
	background.size = GRAPH_SIZE
	_graph.add_child(background)
	_add_branch_lane(Rect2(10.0, 10.0, 680.0, 160.0), Color("3a2b22"))
	_add_branch_lane(Rect2(10.0, 190.0, 680.0, 90.0), Color("153442"))
	_add_branch_lane(Rect2(10.0, 285.0, 840.0, 260.0), Color("1d392e"))
	_add_branch_lane(Rect2(670.0, 10.0, 1_310.0, 535.0), Color("27233a"))
	_add_branch_lane(Rect2(990.0, 10.0, 860.0, 170.0), Color("183b45"))
	_add_branch_lane(Rect2(1_160.0, 190.0, 400.0, 350.0), Color("2c2841"))
	_add_branch_label("CONTRATTI A PIEDI  /  RACCOLTA", Vector2(18.0, 13.0), Color("efc68e"))
	_add_branch_label("ESPLORAZIONE  /  MAPPA", Vector2(18.0, 193.0), Color("81d8ff"))
	_add_branch_label("SOPRAVVIVENZA  /  HABITAT", Vector2(18.0, 288.0), Color("9ce66f"))
	_add_branch_label("RICERCA  /  CONTRATTI TERRA", Vector2(682.0, 13.0), Color("d4b6ff"))
	_add_branch_label("CRIOSFERA  /  VITA ANTICA", Vector2(998.0, 13.0), Color("a8f3ff"))
	_add_branch_label("STRUMENTI  /  BREVETTI", Vector2(1_168.0, 193.0), Color("d48cff"))

	var definitions := AchievementManager.get_ordered_definitions()
	var links := GraphLinks.new()
	links.name = "GraphLinks"
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.position = Vector2.ZERO
	links.size = GRAPH_SIZE
	links.set_links(_build_links(definitions))
	_graph.add_child(links)
	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		if not GRAPH_POSITIONS.has(achievement_id):
			continue
		var card := _make_card(definition)
		card.name = "AchievementNode_" + achievement_id
		card.position = GRAPH_POSITIONS[achievement_id]
		_graph.add_child(card)
	_show_detail("first_base")


func _add_branch_label(text: String, position_value: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = "// " + text + " //"
	label.position = position_value
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(label)


func _add_branch_lane(rect: Rect2, color: Color) -> void:
	var lane := ColorRect.new()
	lane.color = color
	lane.position = rect.position
	lane.size = rect.size
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(lane)


func _build_links(definitions: Array) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for definition in definitions:
		var child_id := str(definition.get("id", ""))
		if not GRAPH_POSITIONS.has(child_id):
			continue
		for parent_id in AchievementManager.get_prerequisites(child_id):
			if not GRAPH_POSITIONS.has(parent_id):
				continue
			links.append({
				"from": Vector2(GRAPH_POSITIONS[parent_id]) + CARD_SIZE * 0.5,
				"to": Vector2(GRAPH_POSITIONS[child_id]) + CARD_SIZE * 0.5,
				"color": _link_color(parent_id),
			})
	return links


func _link_color(parent_id: String) -> Color:
	if AchievementManager.is_claimed(parent_id):
		return Color("64d2b4")
	return Color("334450")


func _make_card(definition: Dictionary) -> Control:
	var achievement_id := str(definition.get("id", ""))
	var status := AchievementManager.get_status(achievement_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.tooltip_text = str(definition.get("description", ""))
	var border_color := Color("394955")
	var fill_color := Color("17212a")
	if status == "locked":
		border_color = Color("7f3137")
		fill_color = Color("1d1b20")
	elif status == "available":
		border_color = Color("697780")
		fill_color = Color("28313a")
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
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(0.0, 4.0)
	stripe.color = _stripe_color(definition, status)
	stack.add_child(stripe)
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	var icon := Label.new()
	icon.text = str(definition.get("icon", "•"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(28.0, 0.0)
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color("6c7880") if status in ["locked", "available"] else Color(definition.get("color", Color.WHITE)))
	body.add_child(icon)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	body.add_child(copy)
	var title := Label.new()
	title.text = str(definition.get("title", "OBIETTIVO"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0.0, 26.0)
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color("e6eff2") if status != "locked" else Color("a57b7f"))
	copy.add_child(title)
	var state := Label.new()
	state.text = "%d/%d · %s" % [AchievementManager.get_progress(achievement_id), AchievementManager.get_target(achievement_id), _status_text(achievement_id, status)]
	state.custom_minimum_size = Vector2(0.0, 14.0)
	state.add_theme_font_size_override("font_size", 8)
	state.add_theme_color_override("font_color", Color("ffe47b") if status == "claimable" else Color("bcc8cd"))
	copy.add_child(state)
	return card


func _stripe_color(definition: Dictionary, status: String) -> Color:
	if status == "locked":
		return Color("d84d55")
	if status == "available":
		return Color("7b8790")
	if status == "claimable":
		return Color("ffd95f")
	return Color(definition.get("color", Color.WHITE))


func _status_text(achievement_id: String, status: String) -> String:
	if status == "locked":
		return "BLOCCATO"
	if status == "available":
		return "IN CORSO"
	if status == "claimable":
		return "✦ RISCATTA ✦"
	return "✓ RISCOSSO"


func _on_card_pressed(achievement_id: String) -> void:
	if AchievementManager.is_claimable(achievement_id):
		AchievementManager.claim(achievement_id)
		_rebuild_graph()
	else:
		_show_detail(achievement_id)


func _show_detail(achievement_id: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	if definition.is_empty() or _detail == null:
		return
	var status := AchievementManager.get_status(achievement_id)
	var reward: Dictionary = definition.get("reward", {})
	var text := "%s — %s\nRicompensa: %s" % [str(definition.get("title", "")), str(definition.get("description", "")), str(reward.get("label", "nessuna"))]
	if status == "locked":
		var prerequisites := AchievementManager.get_prerequisites(achievement_id)
		var names: Array[String] = []
		for prerequisite_id in prerequisites:
			names.append(str(AchievementManager.get_definition(prerequisite_id).get("title", prerequisite_id)))
		text += "\nRiscatta prima: " + ", ".join(names) + ". Il progresso è già salvato."
	elif status == "available":
		text += "\nDisponibile: completa l'obiettivo per rendere la ricompensa riscattabile."
	elif status == "claimable":
		text += "\nPRONTA: clicca il nodo luccicante per riscuotere e sbloccare i successivi."
	else:
		text += "\nRicompensa già riscossa."
	_detail.text = text


func _hide_external_ui() -> void:
	_hidden_layers.clear()
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_collect_external_canvas_layers(scene_root)


func _collect_external_canvas_layers(node: Node) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is CanvasLayer:
			var canvas_layer := child as CanvasLayer
			_hidden_layers.append({"layer": canvas_layer, "visible": canvas_layer.visible})
			canvas_layer.visible = false
		_collect_external_canvas_layers(child)


func _restore_external_ui() -> void:
	for entry in _hidden_layers:
		var canvas_layer := entry.get("layer") as CanvasLayer
		if is_instance_valid(canvas_layer):
			canvas_layer.visible = bool(entry.get("visible", true))
	_hidden_layers.clear()


func _on_achievement_updated(_achievement_id: String) -> void:
	if _root.visible:
		_rebuild_graph()


func _on_achievement_claimable(achievement_id: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	_show_notification("OBIETTIVO PRONTO · %s · premi J" % str(definition.get("title", "")))


func _on_achievement_claimed(achievement_id: String, reward_label: String) -> void:
	var definition := AchievementManager.get_definition(achievement_id)
	_show_notification("RICOMPENSA RISCOSSA · %s · %s" % [str(definition.get("title", "")), reward_label])


func _show_notification(message: String) -> void:
	if _root.visible:
		return
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
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 6.0
	return box
