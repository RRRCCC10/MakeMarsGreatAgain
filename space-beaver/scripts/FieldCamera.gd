extends CanvasLayer

## Telecamera scientifica da campo. Non e' un oggetto decorativo: conserva
## gli scatti, identifica il soggetto inquadrato e lascia al giocatore la
## scelta esplicita di trasmettere ogni immagine alla Terra.

signal photo_taken(photo: Dictionary)
signal photo_transmitted(photo: Dictionary)

const CAMERA_ITEM_ID := "field_camera"
const MAX_ROLL_SIZE := 36
const PHOTO_DISTANCE := 78.0
const CAMERA_ICON_PATH := "res://assets/camera/field_camera.png"

const BIOME_NAMES := {
	0: "Pianura di atterraggio",
	1: "Regolite scura",
	2: "Cratere d'impatto",
	3: "Bordo della calotta",
	4: "Nucleo polare",
	5: "Altopiano basaltico",
}

var photo_roll: Array[Dictionary] = []
var next_photo_id := 1
var is_archive_open := false
var _camera_icon: Texture2D

var _root: Control
var _status_panel: PanelContainer
var _status: Label
var _hint: Label
var _flash: ColorRect
var _archive_overlay: ColorRect
var _archive_list: VBoxContainer
var _archive_summary: Label
var _notice: Label


func _ready() -> void:
	layer = 68
	_build_ui()


func _process(_delta: float) -> void:
	var active := _camera_is_equipped() and not _other_modal_is_open()
	if _status_panel != null:
		_status_panel.visible = active
	if active:
		_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_archive_open:
		if event.keycode in [KEY_C, KEY_ESCAPE]:
			close_archive()
			get_viewport().set_input_as_handled()
		return
	if not _camera_is_equipped() or _other_modal_is_open():
		return
	if event.keycode == KEY_P:
		take_photo()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_O:
		transmit_oldest_photo()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_C:
		open_archive()
		get_viewport().set_input_as_handled()


func reset_for_new_mission() -> void:
	photo_roll.clear()
	next_photo_id = 1
	is_archive_open = false
	if _archive_overlay != null:
		_archive_overlay.visible = false
	if _notice != null:
		_notice.visible = false


func take_photo() -> Dictionary:
	if not _camera_is_equipped() or _other_modal_is_open():
		return {}
	var photo := _build_photo_context()
	if photo.is_empty():
		return {}
	photo_roll.append(photo)
	while photo_roll.size() > MAX_ROLL_SIZE:
		photo_roll.pop_front()
	_show_flash()
	_capture_view_to_archive(int(photo.get("id", 0)))
	_show_notice("SCATTO %02d SALVATO · %s · premi O per inviarlo" % [int(photo.get("id", 0)), str(photo.get("subject", "Marte"))], Color("b6f3ff"))
	photo_taken.emit(photo.duplicate(true))
	_refresh_status()
	return photo.duplicate(true)


func transmit_oldest_photo() -> bool:
	if not _camera_is_equipped() or _other_modal_is_open():
		return false
	for photo in photo_roll:
		if bool(photo.get("sent", false)):
			continue
		photo["sent"] = true
		photo["sent_at_day"] = int(WorldClock.day)
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null and achievements.has_method("record_photo_transmission"):
			achievements.call("record_photo_transmission", photo.duplicate(true))
		_show_notice("TRASMISSIONE TERRA COMPLETATA · %s" % str(photo.get("subject", "Foto scientifica")), Color("9ff0aa"))
		photo_transmitted.emit(photo.duplicate(true))
		_refresh_status()
		if is_archive_open:
			_refresh_archive()
		return true
	_show_notice("RULLINO VUOTO · premi P per scattare una foto", Color("ffd878"))
	return false


func get_photo_count(sent_only: bool = false) -> int:
	if not sent_only:
		return photo_roll.size()
	var sent := 0
	for photo in photo_roll:
		if bool(photo.get("sent", false)):
			sent += 1
	return sent


func get_unsent_count() -> int:
	return get_photo_count(false) - get_photo_count(true)


func has_camera() -> bool:
	return Inventory.count_item(CAMERA_ITEM_ID) > 0


func _camera_is_equipped() -> bool:
	return str(Inventory.get_selected_item().get("id", "")) == CAMERA_ITEM_ID


func _other_modal_is_open() -> bool:
	return Inventory.is_open or Shop.is_open or BuildableRegistry.is_modal_open or AchievementManager.is_board_open


func _build_photo_context() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return {}
	var source_id := _source_at(player.global_position)
	var phase := WorldClock.get_phase_label()
	var tags: Array[String] = ["panorama", "source_%d" % source_id, "phase_%s" % phase.to_lower()]
	var subject: String = str(BIOME_NAMES.get(source_id, "Orizzonte marziano"))
	var rock := _nearest_group_node("collectible_rocks", player.global_position)
	if rock != null and rock.has_method("resource_definition"):
		var definition: Dictionary = rock.call("resource_definition")
		subject = str(definition.get("name", "Campione geologico"))
		tags.append("rock")
		if str(definition.get("rarity", "common")) in ["rare", "ultra_rare"]:
			tags.append("rare_rock")
	var structure := _nearest_photo_structure(player.global_position)
	if structure != null:
		if structure.is_in_group("greenhouses"):
			subject = "Serra nel paesaggio marziano"
			tags.append("greenhouse")
		elif structure.is_in_group("base_domes"):
			subject = "Avamposto umano su Marte"
			tags.append("base")
		elif structure.is_in_group("research_machines"):
			subject = "Laboratorio di superficie"
			tags.append("laboratory")
		elif structure.is_in_group("rovers"):
			subject = "Rover esplorativo"
			tags.append("rover")
	if Inventory.count_item("rock_ghiaccio_profondo_primordiale") > 0:
		tags.append("primordial_ice")
		if subject == BIOME_NAMES.get(source_id, "Orizzonte marziano"):
			subject = "Custodia di ghiaccio profondo"
	if AchievementManager.is_reached("ancient_life") and "laboratory" in tags:
		tags.append("life_evidence")
	if source_id in [3, 4] and WorldClock.get_phase() == WorldClock.Phase.DAWN:
		tags.append("dawn_ice")
	if WorldClock.get_phase() == WorldClock.Phase.NIGHT:
		tags.append("night_sky")
	if source_id == 4:
		tags.append("polar")
	return {
		"id": next_photo_id,
		"subject": subject,
		"source_id": source_id,
		"biome": BIOME_NAMES.get(source_id, "Zona inesplorata"),
		"phase": phase,
		"day": int(WorldClock.day),
		"tags": tags,
		"sent": false,
	}


func _source_at(world_position: Vector2) -> int:
	var map_provider := get_tree().get_first_node_in_group("world_map_provider")
	if map_provider == null or not map_provider.has_method("world_to_cell") or not map_provider.has_method("get_source_id"):
		return -1
	var cell: Vector2i = map_provider.call("world_to_cell", world_position)
	return int(map_provider.call("get_source_id", cell))


func _nearest_group_node(group_name: String, point: Vector2) -> Node2D:
	var closest: Node2D
	var closest_distance := PHOTO_DISTANCE
	for candidate in get_tree().get_nodes_in_group(group_name):
		if not candidate is Node2D:
			continue
		var node := candidate as Node2D
		var distance := point.distance_to(node.global_position)
		if distance <= closest_distance:
			closest = node
			closest_distance = distance
	return closest


func _nearest_photo_structure(point: Vector2) -> Node2D:
	for group_name in ["greenhouses", "research_machines", "base_domes", "rovers"]:
		var node := _nearest_group_node(group_name, point)
		if node != null:
			return node
	return null


func _capture_view_to_archive(photo_id: int) -> void:
	# L'immagine completa viene conservata localmente oltre ai metadati usati dal
	# contratto. Aspettiamo due frame e nascondiamo temporaneamente i soli HUD
	# della fotocamera: nell'archivio finisce il panorama, non il lampo bianco o
	# il testo di conferma dello scatto.
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var status_was_visible := _status_panel.visible
	var notice_was_visible := _notice.visible
	_status_panel.visible = false
	_notice.visible = false
	_flash.color.a = 0.0
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var image := get_viewport().get_texture().get_image()
	_status_panel.visible = status_was_visible
	_notice.visible = notice_was_visible
	if image == null or image.is_empty():
		return
	var folder := "user://mission_photos"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file_path := "%s/sol_%02d_scatt_%03d.png" % [folder, int(WorldClock.day), photo_id]
	if image.save_png(file_path) == OK:
		for photo in photo_roll:
			if int(photo.get("id", -1)) == photo_id:
				photo["archive_path"] = file_path
				break


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "FieldCameraUI"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_status_panel = PanelContainer.new()
	_status_panel.name = "ResponsiveCameraStatus"
	_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_panel.anchor_left = 0.62
	_status_panel.anchor_right = 1.0
	_status_panel.offset_left = 0.0
	_status_panel.offset_top = 16.0
	_status_panel.offset_right = -16.0
	_status_panel.offset_bottom = 108.0
	_status_panel.add_theme_stylebox_override("panel", _box(Color("091720e8"), Color("67cde5"), 2, 5))
	_root.add_child(_status_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_status_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _get_camera_icon()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(38.0, 0.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("d9f7ff"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_status)
	_hint = Label.new()
	_hint.text = "P · SCATTA     O · TERRA     C · ARCHIVIO"
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color("91cfe1"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_hint)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.82, 0.97, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_notice = Label.new()
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.anchor_left = 0.25
	_notice.anchor_right = 0.75
	_notice.offset_top = 26.0
	_notice.offset_bottom = 68.0
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_font_size_override("font_size", 13)
	_notice.add_theme_color_override("font_outline_color", Color("03080c"))
	_notice.add_theme_constant_override("outline_size", 4)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_root.add_child(_notice)

	_build_archive_ui()


func _build_archive_ui() -> void:
	_archive_overlay = ColorRect.new()
	_archive_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_archive_overlay.color = Color("02080ddd")
	_archive_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_archive_overlay.visible = false
	_root.add_child(_archive_overlay)
	var panel := PanelContainer.new()
	panel.name = "ResponsiveCameraArchive"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.08
	panel.anchor_top = 0.08
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.92
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.add_theme_stylebox_override("panel", _box(Color("0a1720"), Color("65cce8"), 2, 7))
	_archive_overlay.add_child(panel)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 18)
	margins.add_theme_constant_override("margin_right", 18)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margins.add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := Label.new()
	title.text = "// ARCHIVIO FOTOGRAFICO MISSIONE //"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("b8efff"))
	title_row.add_child(title)
	var close := Button.new()
	close.text = "[ C / ESC · CHIUDI ]"
	close.custom_minimum_size = Vector2(150, 32)
	close.pressed.connect(close_archive)
	title_row.add_child(close)
	_archive_summary = Label.new()
	_archive_summary.add_theme_font_size_override("font_size", 12)
	_archive_summary.add_theme_color_override("font_color", Color("d1e2e7"))
	layout.add_child(_archive_summary)
	var divider := HSeparator.new()
	layout.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 200.0)
	layout.add_child(scroll)
	_archive_list = VBoxContainer.new()
	_archive_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archive_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_archive_list)


func open_archive() -> void:
	if _other_modal_is_open() or is_archive_open:
		return
	is_archive_open = true
	_archive_overlay.visible = true
	_refresh_archive()


func close_archive() -> void:
	is_archive_open = false
	if _archive_overlay != null:
		_archive_overlay.visible = false


func _refresh_status() -> void:
	if _status == null:
		return
	var unsent := get_unsent_count()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var biome := "AREA SCONOSCIUTA"
	if player != null:
		biome = str(BIOME_NAMES.get(_source_at(player.global_position), biome)).to_upper()
	_status.text = "TELECAMERA SCIENTIFICA · %s\nRULLINO %d/%d · %d DA TRASMETTERE" % [biome, photo_roll.size(), MAX_ROLL_SIZE, unsent]


func _refresh_archive() -> void:
	if _archive_list == null:
		return
	for child in _archive_list.get_children():
		child.queue_free()
	_archive_summary.text = "%d SCATTI · %d INVIATI · ogni invio sblocca i contratti fotografici senza richiedere energia." % [photo_roll.size(), get_photo_count(true)]
	if photo_roll.is_empty():
		var empty := Label.new()
		empty.text = "Nessuno scatto nel rullino. Equipa la telecamera e premi P davanti a un panorama, roccia o struttura."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color("a8bdc5"))
		_archive_list.add_child(empty)
		return
	for photo in photo_roll:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0.0, 62.0)
		card.add_theme_stylebox_override("panel", _box(Color("132631"), Color("77d9ed") if bool(photo.get("sent", false)) else Color("e8b95b"), 1, 4))
		_archive_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var index := Label.new()
		index.text = "#%02d" % int(photo.get("id", 0))
		index.custom_minimum_size = Vector2(48.0, 0.0)
		index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		index.add_theme_font_size_override("font_size", 15)
		index.add_theme_color_override("font_color", Color("a5eaff"))
		row.add_child(index)
		var text := Label.new()
		text.text = "%s\n%s · SOL %d · %s" % [str(photo.get("subject", "Foto scientifica")), str(photo.get("biome", "Marte")), int(photo.get("day", 1)), str(photo.get("phase", "GIORNO"))]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 12)
		text.add_theme_color_override("font_color", Color("d9e8eb"))
		row.add_child(text)
		var state := Label.new()
		state.text = "INVIATA" if bool(photo.get("sent", false)) else "NEL RULLINO"
		state.custom_minimum_size = Vector2(116.0, 0.0)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state.add_theme_font_size_override("font_size", 11)
		state.add_theme_color_override("font_color", Color("8ff1b1") if bool(photo.get("sent", false)) else Color("ffd778"))
		row.add_child(state)


func _show_flash() -> void:
	_flash.color = Color(0.82, 0.97, 1.0, 0.80)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.20)


func _show_notice(message: String, color: Color) -> void:
	_notice.text = message
	_notice.add_theme_color_override("font_color", color)
	_notice.visible = true
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_notice):
			_notice.visible = false
	)


func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 9.0
	box.content_margin_right = 9.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _get_camera_icon() -> Texture2D:
	if _camera_icon != null:
		return _camera_icon
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(CAMERA_ICON_PATH))
	if image == null or image.is_empty():
		push_error("Impossibile caricare lo sprite della telecamera: %s" % CAMERA_ICON_PATH)
		return null
	_camera_icon = ImageTexture.create_from_image(image)
	return _camera_icon
