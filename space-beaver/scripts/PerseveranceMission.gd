extends Node

## Evento scientifico raro: Perseverance si guasta lontano dalla base e richiede
## una catena completa di documentazione prima della riparazione. Non è un
## semplice incidente casuale: foto, telemetria e sequenza di manutenzione
## raccontano tutti lo stesso recupero, senza costringere ad aspettare un
## secondo rover per completare gli obiettivi.

signal state_changed(new_state: int)
signal rover_broken(world_position: Vector2)
signal rover_repaired(world_position: Vector2)

enum State { WAITING, AWAIT_PHOTO, AWAIT_STUDY, REPORT_READY, REPORT_SIGNED, REPAIRING, REPAIRED }

const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const REPAIRED_TEXTURE := preload("res://assets/sprites/perseverance/perseverance_riparato_frontale_48x48.png")
const BROKEN_TEXTURE := preload("res://assets/sprites/perseverance/perseverance_rotto_frontale_48x48.png")
const TILE_SIZE := 16.0
const FIRST_BREAK_MIN_GAME_HOURS := 72.0
const FIRST_BREAK_MAX_GAME_HOURS := 96.0
const REPEAT_BREAK_MIN_GAME_HOURS := 7.0 * 24.0
const REPEAT_BREAK_MAX_GAME_HOURS := 10.0 * 24.0
const MAX_BREAK_DISTANCE_TILES := 500.0
const MIN_BREAK_DISTANCE_TILES := 140.0
const INTERACTION_DISTANCE := 88.0
## Il segnalatore serve a ritrovare il rover, non a coprire l'azione quando
## l'obiettivo è già davanti al giocatore.
const GUIDANCE_HIDE_DISTANCE_TILES := 15.0
const GUIDANCE_HIDE_DISTANCE := GUIDANCE_HIDE_DISTANCE_TILES * TILE_SIZE
## Dopo la riparazione Perseverance non deve restare per sempre nel mondo.
## Aspettiamo però che esca davvero dall'inquadratura, con un margine ampio,
## così non scompare mentre il giocatore gli è ancora vicino.
const REPAIRED_DESPAWN_VIEW_MARGIN_TILES := 12.0
const REPAIRED_DESPAWN_FALLBACK_DISTANCE_TILES := 64.0
const STUDY_SECONDS := 2.8
const REPAIR_KEYS := [KEY_W, KEY_D, KEY_S, KEY_A]
const REPAIR_KEY_LABELS := {KEY_W: "W", KEY_A: "A", KEY_S: "S", KEY_D: "D"}

var state := State.WAITING
var rover: Node2D
var rover_sprite: Sprite2D
var rover_prompt: Label
var _elapsed_game_hours := 0.0
var _next_break_at_game_hours := 0.0
var _study_elapsed := 0.0
var _repair_sequence: Array[int] = []
var _repair_index := 0
var _rng := RandomNumberGenerator.new()

var _arrow_layer: CanvasLayer
var _arrow: Label
var _report_layer: CanvasLayer
var _report_panel: PanelContainer
var _report_label: Label


func _ready() -> void:
	process_priority = -70
	_rng.randomize()
	_schedule_first_break()
	_build_guidance_ui()
	var camera := get_node_or_null("/root/FieldCamera")
	if camera != null and camera.has_signal("photo_transmitted"):
		camera.photo_transmitted.connect(_on_photo_transmitted)


func _process(delta: float) -> void:
	_elapsed_game_hours += WorldClock.get_game_hours_for_real_delta(delta)
	if state in [State.WAITING, State.REPAIRED] and _elapsed_game_hours >= _next_break_at_game_hours:
		_spawn_broken_rover()
	if state == State.REPAIRED and _repaired_rover_is_far_outside_view():
		_remove_rover()
	if state == State.AWAIT_STUDY:
		_process_damage_study(delta)
	_update_guidance()
	_update_rover_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _world_input_blocked():
		return
	if not _player_is_near_rover():
		return
	if state == State.REPORT_READY and event.keycode == KEY_F:
		_sign_report()
		get_viewport().set_input_as_handled()
		return
	if state == State.REPORT_SIGNED and event.keycode == KEY_R:
		_send_report_to_earth()
		get_viewport().set_input_as_handled()
		return
	if state == State.REPAIRING and event.keycode in REPAIR_KEYS:
		_accept_repair_key(event.keycode)
		get_viewport().set_input_as_handled()


func get_state_label() -> String:
	match state:
		State.WAITING:
			return "NESSUN SEGNALE PERSEVERANCE"
		State.AWAIT_PHOTO:
			return "FOTO E TRASMISSIONE RICHIESTE"
		State.AWAIT_STUDY:
			return "STUDIO DANNI RICHIESTO"
		State.REPORT_READY:
			return "RAPPORTO DA FIRMARE"
		State.REPORT_SIGNED:
			return "RAPPORTO DA SPEDIRE"
		State.REPAIRING:
			return "RIPARAZIONE IN CORSO"
		State.REPAIRED:
			return "PERSEVERANCE OPERATIVO"
	return "SCONOSCIUTO"


func get_next_break_in_game_hours() -> float:
	return maxf(0.0, _next_break_at_game_hours - _elapsed_game_hours)


func force_break_for_test(world_position: Vector2 = Vector2(320.0, 320.0)) -> void:
	if rover != null and is_instance_valid(rover):
		_remove_rover()
	_spawn_broken_rover(world_position)


func force_complete_photo_for_test() -> void:
	if state == State.AWAIT_PHOTO:
		_set_state(State.AWAIT_STUDY)


func reset_for_new_mission() -> void:
	_remove_rover()
	_elapsed_game_hours = 0.0
	_study_elapsed = 0.0
	_repair_sequence.clear()
	_repair_index = 0
	_set_state(State.WAITING)
	_schedule_first_break()
	if _report_panel != null:
		_report_panel.visible = false
	if _arrow != null:
		_arrow.visible = false


func _schedule_first_break() -> void:
	_next_break_at_game_hours = _elapsed_game_hours + _rng.randf_range(FIRST_BREAK_MIN_GAME_HOURS, FIRST_BREAK_MAX_GAME_HOURS)


func _schedule_repeat_break() -> void:
	_next_break_at_game_hours = _elapsed_game_hours + _rng.randf_range(REPEAT_BREAK_MIN_GAME_HOURS, REPEAT_BREAK_MAX_GAME_HOURS)


func _spawn_broken_rover(forced_position: Vector2 = Vector2.INF) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_remove_rover()
	var position := forced_position if forced_position != Vector2.INF else _choose_break_position()
	if position == Vector2.INF:
		return
	rover = Node2D.new()
	rover.name = "PerseveranceBroken"
	rover.global_position = position
	rover.z_index = 11
	rover.add_to_group("perseverance_rover")
	rover.add_to_group("mission_rovers")
	scene.add_child(rover)
	rover_sprite = Sprite2D.new()
	rover_sprite.name = "PerseveranceSprite"
	rover_sprite.texture = BROKEN_TEXTURE
	rover_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rover_sprite.z_index = 1
	rover.add_child(rover_sprite)
	var body := StaticBody2D.new()
	body.name = "PerseveranceCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(39.0, 27.0)
	collision.shape = shape
	collision.position = Vector2(0.0, 7.0)
	body.add_child(collision)
	rover.add_child(body)
	rover_prompt = Label.new()
	rover_prompt.name = "PerseverancePrompt"
	rover_prompt.position = Vector2(-128.0, -50.0)
	rover_prompt.size = Vector2(256.0, 42.0)
	rover_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rover_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rover_prompt.add_theme_font_override("font", UI_FONT)
	rover_prompt.add_theme_font_size_override("font_size", 12)
	rover_prompt.add_theme_color_override("font_color", Color("ffd783"))
	rover_prompt.add_theme_color_override("font_outline_color", Color("160b04"))
	rover_prompt.add_theme_constant_override("outline_size", 3)
	rover_prompt.visible = false
	rover.add_child(rover_prompt)
	var registry := get_node_or_null("/root/BuildableRegistry")
	if registry != null:
		registry.call("register_buildable", rover, "ROVER PERSEVERANCE", "mission_structure", _deny_rover_removal)
	_set_state(State.AWAIT_PHOTO)
	rover_broken.emit(position)


func _remove_rover() -> void:
	if rover == null or not is_instance_valid(rover):
		rover = null
		rover_sprite = null
		rover_prompt = null
		return
	var registry := get_node_or_null("/root/BuildableRegistry")
	if registry != null:
		registry.call("unregister_buildable", rover)
	rover.queue_free()
	rover = null
	rover_sprite = null
	rover_prompt = null


func _deny_rover_removal() -> bool:
	return false


func _on_photo_transmitted(photo: Dictionary) -> void:
	if state != State.AWAIT_PHOTO:
		return
	var tags: Array = photo.get("tags", [])
	if "perseverance" not in tags:
		return
	_record_achievement("perseverance_photo")
	_set_state(State.AWAIT_STUDY)


func _process_damage_study(delta: float) -> void:
	if not _player_is_near_rover() or not Input.is_key_pressed(KEY_E):
		_study_elapsed = 0.0
		return
	_study_elapsed = minf(STUDY_SECONDS, _study_elapsed + maxf(0.0, delta))
	if _study_elapsed >= STUDY_SECONDS:
		_create_damage_report()


func _create_damage_report() -> void:
	_study_elapsed = 0.0
	_set_state(State.REPORT_READY)
	if _report_panel != null:
		_report_panel.visible = true
		_report_label.text = "PERSEVERANCE (NASA, 2021)\n\n• Periodo operativo: 18 febbraio-novembre 2026;\n• Causa della cessazione delle operazioni: il progressivo deterioramento delle ruote e dei motori di trazione, dovuto alla lunga esposizione al terreno marziano e all'usura dei componenti meccanici, compromette la capacità di movimento del rover, rendendolo definitivamente impossibilitato a proseguire le operazioni.\n• Condizione finale: rimarrebbe immobilizzato nel cratere Jezero, su Marte. Prima del guasto aveva percorso oltre 45,22 km (dato dell'11 ottobre 2026), superando il record di Opportunity.\n\nF · FIRMA RAPPORTO"


func _sign_report() -> void:
	if state != State.REPORT_READY:
		return
	_set_state(State.REPORT_SIGNED)
	if _report_label != null:
		_report_label.text = "RAPPORTO DANNI // FIRMATO\nPronto per il relay Terra.\n\nR · SPEDISCI RAPPORTO ALLA TERRA"


func _send_report_to_earth() -> void:
	if state != State.REPORT_SIGNED:
		return
	_record_achievement("perseverance_report")
	_repair_sequence = _make_repair_sequence()
	_repair_index = 0
	_set_state(State.REPAIRING)
	if _report_panel != null:
		_report_panel.visible = false


func _make_repair_sequence() -> Array[int]:
	var sequence: Array[int] = []
	for _index in range(5):
		sequence.append(REPAIR_KEYS[_rng.randi_range(0, REPAIR_KEYS.size() - 1)])
	return sequence


func _accept_repair_key(keycode: int) -> void:
	if _repair_sequence.is_empty():
		return
	if keycode != _repair_sequence[_repair_index]:
		_repair_index = 0
		return
	_repair_index += 1
	if _repair_index >= _repair_sequence.size():
		_finish_repair()


func _finish_repair() -> void:
	if rover_sprite != null:
		rover_sprite.texture = REPAIRED_TEXTURE
	_record_achievement("perseverance_repair")
	_set_state(State.REPAIRED)
	_schedule_repeat_break()
	rover_repaired.emit(rover.global_position if rover != null else Vector2.ZERO)


func _set_state(value: int) -> void:
	if state == value:
		return
	state = value
	state_changed.emit(state)


func _update_guidance() -> void:
	if _arrow == null:
		return
	var active := rover != null and is_instance_valid(rover) and state not in [State.WAITING, State.REPAIRED]
	_arrow.visible = active
	if not active:
		return
	var player := _player()
	if player == null:
		return
	var direction := rover.global_position - player.global_position
	if direction.length() <= GUIDANCE_HIDE_DISTANCE:
		_arrow.visible = false
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_arrow.position = viewport_size * 0.5 + direction.normalized() * minf(viewport_size.x, viewport_size.y) * 0.34
	_arrow.rotation = direction.angle() + PI * 0.5
	_arrow.text = "▲\nPERSEVERANCE"


func _repaired_rover_is_far_outside_view() -> bool:
	if rover == null or not is_instance_valid(rover):
		return false
	var player := _player()
	if player == null:
		return false
	var fallback_distance := REPAIRED_DESPAWN_FALLBACK_DISTANCE_TILES * TILE_SIZE
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return player.global_position.distance_to(rover.global_position) > fallback_distance
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom := camera.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return player.global_position.distance_to(rover.global_position) > fallback_distance
	var half_visible_world := viewport_size * 0.5 / zoom
	var visible_world := Rect2(camera.get_screen_center_position() - half_visible_world, half_visible_world * 2.0)
	var safe_margin := TILE_SIZE * REPAIRED_DESPAWN_VIEW_MARGIN_TILES
	return not visible_world.grow(safe_margin).has_point(rover.global_position)


func _update_rover_prompt() -> void:
	if rover_prompt == null:
		return
	rover_prompt.visible = _player_is_near_rover()
	if not rover_prompt.visible:
		return
	match state:
		State.AWAIT_PHOTO:
			rover_prompt.text = "PERSEVERANCE DANNEGGIATO\nEQUIPA CAMERA · P FOTO, O INVIA"
		State.AWAIT_STUDY:
			rover_prompt.text = "ANALISI DANNI · TIENI E  %d%%" % roundi(_study_elapsed / STUDY_SECONDS * 100.0)
		State.REPORT_READY:
			rover_prompt.text = "RAPPORTO PRONTO · F FIRMA"
		State.REPORT_SIGNED:
			rover_prompt.text = "RAPPORTO FIRMATO · R INVIA ALLA TERRA"
		State.REPAIRING:
			rover_prompt.text = "RIPARAZIONE · %s" % _repair_sequence_label()
		State.REPAIRED:
			rover_prompt.text = "PERSEVERANCE RIPARATO · TELEMETRIA STABILE"


func _repair_sequence_label() -> String:
	var parts := PackedStringArray()
	for index in _repair_sequence.size():
		var keycode := _repair_sequence[index]
		parts.append(str(REPAIR_KEY_LABELS.get(keycode, "?")) if index >= _repair_index else "✓")
	return " ".join(parts)


func _player_is_near_rover() -> bool:
	var player := _player()
	return player != null and rover != null and is_instance_valid(rover) and player.global_position.distance_to(rover.global_position) <= INTERACTION_DISTANCE


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _choose_break_position() -> Vector2:
	for _attempt in range(56):
		var distance := _rng.randf_range(MIN_BREAK_DISTANCE_TILES, MAX_BREAK_DISTANCE_TILES) * TILE_SIZE
		var candidate := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * distance
		candidate = Vector2(roundi(candidate.x / TILE_SIZE) * TILE_SIZE, roundi(candidate.y / TILE_SIZE) * TILE_SIZE)
		if _position_is_clear(candidate):
			return candidate
	return Vector2.INF


func _position_is_clear(position: Vector2) -> bool:
	var map_provider := get_tree().get_first_node_in_group("world_map_provider")
	if map_provider != null and map_provider.has_method("is_world_position_inside") and not bool(map_provider.call("is_world_position_inside", position, 30.0)):
		return false
	var player := _player()
	if player != null and player.global_position.distance_to(position) < 96.0:
		return false
	for rock in get_tree().get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and (rock as Node2D).global_position.distance_to(position) < 56.0:
			return false
	for entry_variant in BuildableRegistry.get_entries():
		var entry: Dictionary = entry_variant
		var node := entry.get("node") as Node2D
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(position) < 56.0:
			return false
		if node.has_method("contains_world_point"):
			for offset in [Vector2.ZERO, Vector2(-20.0, -14.0), Vector2(20.0, -14.0), Vector2(-20.0, 14.0), Vector2(20.0, 14.0)]:
				if bool(node.call("contains_world_point", position + offset)):
					return false
	return true


func _build_guidance_ui() -> void:
	_arrow_layer = CanvasLayer.new()
	_arrow_layer.name = "PerseveranceGuidance"
	_arrow_layer.layer = 116
	get_tree().root.call_deferred("add_child", _arrow_layer)
	_arrow = Label.new()
	_arrow.anchor_left = 0.5
	_arrow.anchor_top = 0.5
	_arrow.size = Vector2(122.0, 44.0)
	_arrow.pivot_offset = _arrow.size * 0.5
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow.add_theme_font_override("font", UI_FONT)
	_arrow.add_theme_font_size_override("font_size", 12)
	_arrow.add_theme_color_override("font_color", Color("ffe38a"))
	_arrow.add_theme_color_override("font_outline_color", Color("1c1006"))
	_arrow.add_theme_constant_override("outline_size", 4)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	_arrow_layer.add_child(_arrow)
	_report_layer = CanvasLayer.new()
	_report_layer.name = "PerseveranceReportLayer"
	_report_layer.layer = 118
	get_tree().root.call_deferred("add_child", _report_layer)
	_report_panel = PanelContainer.new()
	_report_panel.anchor_left = 0.5
	_report_panel.anchor_top = 0.5
	_report_panel.anchor_right = 0.5
	_report_panel.anchor_bottom = 0.5
	_report_panel.offset_left = -430.0
	_report_panel.offset_top = -245.0
	_report_panel.offset_right = 430.0
	_report_panel.offset_bottom = 245.0
	_report_panel.add_theme_stylebox_override("panel", _report_style())
	_report_panel.visible = false
	_report_layer.add_child(_report_panel)
	_report_label = Label.new()
	_report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_label.add_theme_font_override("font", UI_FONT)
	_report_label.add_theme_font_size_override("font_size", 13)
	_report_label.add_theme_color_override("font_color", Color("d9eef0"))
	_report_label.add_theme_color_override("font_outline_color", Color("061014"))
	_report_label.add_theme_constant_override("outline_size", 2)
	_report_panel.add_child(_report_label)


func _report_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b161beF")
	style.border_color = Color("e2b45f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _record_achievement(achievement_id: String) -> void:
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("record"):
		achievements.call("record", achievement_id)


func _world_input_blocked() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state != null and bool(ui_state.call("blocks_world_actions"))
