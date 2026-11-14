extends Node

## Incidenti rari delle infrastrutture. Il manager possiede sia lo stato del
## guasto, sia la riparazione: gli oggetti restano responsabili di spegnere il
## loro comportamento quando ricevono set_incident_faulted().

signal incident_started(target: Node2D, target_id: String, display_name: String)
signal incident_repaired(target: Node2D, target_id: String, display_name: String)

const MIN_OPERATIONAL_SECONDS := 120.0
const INCIDENT_CHECK_SECONDS := 30.0
# Vita media di 20 ore reali per ogni singolo oggetto: una base grande vede
# comunque un incidente solo all'incirca ogni ora, non una pioggia di guasti.
const INCIDENT_RATE_PER_SECOND := 1.0 / 72_000.0
const REPAIR_DISTANCE := 94.0
const REPAIR_MODAL := &"incident_repair"
const REPAIR_KEYS: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D]
const REPAIR_KEY_LABELS := {
	KEY_W: "W",
	KEY_A: "A",
	KEY_S: "S",
	KEY_D: "D",
}

var _targets: Dictionary = {}
var _elapsed_seconds := 0.0
var _incident_check_elapsed := 0.0
var _active_target_key := ""
var _repair_target_key := ""
var _repair_sequence: Array[int] = []
var _repair_progress := 0
var _repair_feedback := ""
var _random_incidents_enabled := true
var _rng := RandomNumberGenerator.new()

var _ui_layer: CanvasLayer
var _notification_panel: PanelContainer
var _notification_label: Label
var _notification_until_seconds := 0.0
var _repair_panel: PanelContainer
var _repair_label: Label


func _ready() -> void:
	_rng.randomize()
	call_deferred("_ensure_ui")


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_elapsed_seconds += delta
	_update_fault_indicators()
	if _notification_panel != null and _notification_panel.visible and _elapsed_seconds >= _notification_until_seconds:
		_notification_panel.visible = false
	if not _active_target_key.is_empty() or not _random_incidents_enabled:
		return
	_incident_check_elapsed += delta
	while _incident_check_elapsed >= INCIDENT_CHECK_SECONDS:
		_incident_check_elapsed -= INCIDENT_CHECK_SECONDS
		_roll_for_incident()
		if not _active_target_key.is_empty():
			break


func register_target(target: Node2D, target_id: String, display_name: String, rate_multiplier: float = 1.0) -> void:
	if target == null or not is_instance_valid(target) or target_id.is_empty():
		return
	var key := _target_key(target, target_id)
	_targets[key] = {
		"node": target,
		"target_id": target_id,
		"display_name": display_name,
		"rate_multiplier": maxf(0.0, rate_multiplier),
		"available_after": _elapsed_seconds + MIN_OPERATIONAL_SECONDS,
		"indicator": null,
	}


func unregister_target(target: Node, target_id: String = "") -> void:
	if target == null:
		return
	for key_variant in _targets.keys().duplicate():
		var key := str(key_variant)
		var data: Dictionary = _targets[key]
		if data.get("node") != target:
			continue
		if not target_id.is_empty() and str(data.get("target_id", "")) != target_id:
			continue
		_clear_indicator(data)
		_targets.erase(key)
		if _active_target_key == key:
			_active_target_key = ""
		if _repair_target_key == key:
			_finish_repair(false)


func force_incident(target: Node2D, target_id: String = "") -> bool:
	if target == null or not is_instance_valid(target):
		return false
	for key_variant in _targets.keys():
		var key := str(key_variant)
		var data: Dictionary = _targets[key]
		if data.get("node") == target and (target_id.is_empty() or str(data.get("target_id", "")) == target_id):
			return _trigger_incident(key, data, true)
	return false


func begin_nearby_repair(player: Node2D) -> bool:
	if player == null or _active_target_key.is_empty() or not _targets.has(_active_target_key):
		return false
	if not _repair_target_key.is_empty():
		return true
	var data: Dictionary = _targets[_active_target_key]
	var target := data.get("node") as Node2D
	if target == null or not is_instance_valid(target):
		return false
	if player.global_position.distance_to(_repair_position(target, str(data.get("target_id", "")))) > REPAIR_DISTANCE:
		return false
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and not bool(ui_state.call("try_open_modal", REPAIR_MODAL)):
		return false
	_repair_target_key = _active_target_key
	_repair_sequence.clear()
	for _index in _rng.randi_range(3, 7):
		_repair_sequence.append(REPAIR_KEYS[_rng.randi_range(0, REPAIR_KEYS.size() - 1)])
	_repair_progress = 0
	_repair_feedback = "Ricalibra i controlli nell'ordine mostrato."
	_show_repair_panel()
	return true


func handle_repair_key(keycode: int) -> bool:
	if _repair_target_key.is_empty():
		return false
	if keycode == KEY_ESCAPE:
		_finish_repair(false)
		return true
	if keycode not in REPAIR_KEYS:
		return true
	if _repair_progress < _repair_sequence.size() and keycode == _repair_sequence[_repair_progress]:
		_repair_progress += 1
		_repair_feedback = "Segnale corretto."
		if _repair_progress >= _repair_sequence.size():
			_finish_repair(true)
			return true
	else:
		_repair_progress = 0
		_repair_feedback = "Sequenza errata: riparti dall'inizio."
	_show_repair_panel()
	return true


func get_active_incident() -> Dictionary:
	if _active_target_key.is_empty() or not _targets.has(_active_target_key):
		return {}
	return _targets[_active_target_key].duplicate()


func get_repair_sequence_for_test() -> Array[int]:
	return _repair_sequence.duplicate()


func set_random_incidents_enabled_for_test(enabled: bool) -> void:
	_random_incidents_enabled = enabled


func reset_for_new_mission() -> void:
	for data_variant in _targets.values():
		var data: Dictionary = data_variant
		var target := data.get("node") as Node2D
		if target != null and is_instance_valid(target) and target.has_method("set_incident_faulted"):
			target.call("set_incident_faulted", str(data.get("target_id", "")), false)
		_clear_indicator(data)
	_targets.clear()
	_active_target_key = ""
	_incident_check_elapsed = 0.0
	_finish_repair(false)
	if _notification_panel != null:
		_notification_panel.visible = false


func _roll_for_incident() -> void:
	for key_variant in _targets.keys().duplicate():
		var key := str(key_variant)
		if not _targets.has(key):
			continue
		var data: Dictionary = _targets[key]
		var target := data.get("node") as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			_clear_indicator(data)
			_targets.erase(key)
			continue
		if _elapsed_seconds < float(data.get("available_after", 0.0)) or _is_faulted(target, str(data.get("target_id", ""))):
			continue
		if target.has_method("can_receive_incident") and not bool(target.call("can_receive_incident", str(data.get("target_id", "")))):
			continue
		var storm_multiplier := 1.0
		var sandstorm_manager := get_node_or_null("/root/SandstormManager")
		if sandstorm_manager != null and sandstorm_manager.has_method("get_incident_rate_multiplier"):
			storm_multiplier = float(sandstorm_manager.call("get_incident_rate_multiplier"))
		var rate := INCIDENT_RATE_PER_SECOND * float(data.get("rate_multiplier", 1.0)) * storm_multiplier
		var chance := 1.0 - exp(-rate * INCIDENT_CHECK_SECONDS)
		if _rng.randf() < chance:
			_trigger_incident(key, data, false)
			return


func _trigger_incident(key: String, data: Dictionary, force: bool) -> bool:
	if not _active_target_key.is_empty():
		return false
	var target := data.get("node") as Node2D
	if target == null or not is_instance_valid(target) or not target.has_method("set_incident_faulted"):
		return false
	var target_id := str(data.get("target_id", ""))
	if not force and target.has_method("can_receive_incident") and not bool(target.call("can_receive_incident", target_id)):
		return false
	target.call("set_incident_faulted", target_id, true)
	_active_target_key = key
	_targets[key] = data
	_create_indicator(data)
	_show_notification("⚠ INCIDENTE: %s\nGUASTO RILEVATO · avvicinati e premi E per riparare" % str(data.get("display_name", "MACCHINARIO")))
	incident_started.emit(target, target_id, str(data.get("display_name", "MACCHINARIO")))
	return true


func _finish_repair(success: bool) -> void:
	var repaired_data: Dictionary = {}
	if success and not _repair_target_key.is_empty() and _targets.has(_repair_target_key):
		repaired_data = _targets[_repair_target_key]
		var target := repaired_data.get("node") as Node2D
		if target != null and is_instance_valid(target) and target.has_method("set_incident_faulted"):
			target.call("set_incident_faulted", str(repaired_data.get("target_id", "")), false)
		_clear_indicator(repaired_data)
		_active_target_key = ""
	_repair_target_key = ""
	_repair_sequence.clear()
	_repair_progress = 0
	_repair_feedback = ""
	if _repair_panel != null:
		_repair_panel.visible = false
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", REPAIR_MODAL)
	if success:
		_show_notification("RIPARAZIONE COMPLETATA\n%s è di nuovo operativo." % str(repaired_data.get("display_name", "MACCHINARIO")))
		var target := repaired_data.get("node") as Node2D
		if target != null and is_instance_valid(target):
			incident_repaired.emit(target, str(repaired_data.get("target_id", "")), str(repaired_data.get("display_name", "MACCHINARIO")))


func _is_faulted(target: Node2D, target_id: String) -> bool:
	return bool(target.call("is_incident_faulted", target_id)) if target.has_method("is_incident_faulted") else false


func _repair_position(target: Node2D, target_id: String) -> Vector2:
	return Vector2(target.call("get_incident_repair_position", target_id)) if target.has_method("get_incident_repair_position") else target.global_position


func _target_key(target: Node, target_id: String) -> String:
	return "%d:%s" % [target.get_instance_id(), target_id]


func _create_indicator(data: Dictionary) -> void:
	var target := data.get("node") as Node2D
	if target == null or not is_instance_valid(target):
		return
	_clear_indicator(data)
	var marker := Node2D.new()
	marker.name = "IncidentWarning"
	marker.position = target.to_local(_repair_position(target, str(data.get("target_id", ""))))
	marker.z_as_relative = false
	marker.z_index = 200
	var ring := Line2D.new()
	ring.name = "FaultGlow"
	ring.points = PackedVector2Array([Vector2(-24, 0), Vector2(0, -16), Vector2(24, 0), Vector2(0, 16)])
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.08, 0.04, 0.92)
	marker.add_child(ring)
	var label := Label.new()
	label.name = "FaultLabel"
	label.text = "GUASTO"
	label.position = Vector2(-38.0, -37.0)
	label.size = Vector2(76.0, 18.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("ff6258"))
	label.add_theme_color_override("font_outline_color", Color("290408"))
	label.add_theme_constant_override("outline_size", 3)
	marker.add_child(label)
	target.add_child(marker)
	data["indicator"] = marker


func _clear_indicator(data: Dictionary) -> void:
	var marker := data.get("indicator") as Node
	if marker != null and is_instance_valid(marker):
		marker.visible = false
		marker.queue_free()
	data["indicator"] = null


func _update_fault_indicators() -> void:
	var alpha := 0.45 + 0.55 * (0.5 + 0.5 * sin(_elapsed_seconds * 8.0))
	for data_variant in _targets.values():
		var data: Dictionary = data_variant
		var marker := data.get("indicator") as Node2D
		if marker == null or not is_instance_valid(marker):
			continue
		var ring := marker.get_node_or_null("FaultGlow") as Line2D
		if ring != null:
			ring.default_color = Color(1.0, 0.08, 0.04, alpha)


func _ensure_ui() -> void:
	if _ui_layer != null and is_instance_valid(_ui_layer):
		return
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "IncidentLayer"
	_ui_layer.layer = 110
	get_tree().root.add_child(_ui_layer)
	_notification_panel = _make_panel()
	_notification_panel.anchor_left = 0.5
	_notification_panel.anchor_right = 0.5
	_notification_panel.anchor_top = 0.035
	_notification_panel.anchor_bottom = 0.035
	_notification_panel.offset_left = -280.0
	_notification_panel.offset_right = 280.0
	_notification_panel.offset_top = 0.0
	_notification_panel.offset_bottom = 62.0
	_notification_panel.visible = false
	_ui_layer.add_child(_notification_panel)
	_notification_label = _make_label(16, Color("ffd1cd"))
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification_panel.add_child(_notification_label)
	_repair_panel = _make_panel()
	_repair_panel.anchor_left = 0.5
	_repair_panel.anchor_right = 0.5
	_repair_panel.anchor_top = 0.5
	_repair_panel.anchor_bottom = 0.5
	_repair_panel.offset_left = -310.0
	_repair_panel.offset_right = 310.0
	_repair_panel.offset_top = -86.0
	_repair_panel.offset_bottom = 86.0
	_repair_panel.visible = false
	_ui_layer.add_child(_repair_panel)
	_repair_label = _make_label(20, Color("fff0e8"))
	_repair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_repair_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repair_panel.add_child(_repair_label)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.015, 0.02, 0.94)
	style.border_color = Color("ff5148")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("180204"))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _show_notification(message: String) -> void:
	_ensure_ui()
	_notification_label.text = message
	_notification_panel.visible = true
	_notification_until_seconds = _elapsed_seconds + 8.0


func show_notification(message: String) -> void:
	_show_notification(message)


func _show_repair_panel() -> void:
	_ensure_ui()
	var parts := PackedStringArray()
	for index in _repair_sequence.size():
		var label := str(REPAIR_KEY_LABELS.get(_repair_sequence[index], "?"))
		parts.append("[%s]" % label if index == _repair_progress else label)
	var target_label := "MACCHINARIO"
	if _targets.has(_repair_target_key):
		target_label = str((_targets[_repair_target_key] as Dictionary).get("display_name", target_label))
	_repair_label.text = "RIPARAZIONE · %s\n\n%s\n\n%d/%d  ·  %s\nEsc annulla" % [target_label, "  →  ".join(parts), _repair_progress, _repair_sequence.size(), _repair_feedback]
	_repair_panel.visible = true
