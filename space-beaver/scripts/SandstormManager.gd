extends Node

## Weather and sand are separated from each individual machine simulation.
## Registered targets decide how appearance and behavior change when they
## receive set_sand_accumulation(); this manager coordinates timing, alerts,
## hold-to-clean input, and increasingly severe faults.

signal storm_state_changed(new_state: int)
signal sand_level_changed(target: Node2D, level: int)

enum State { CALM, WARNING, ACTIVE }

const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const MIN_CALM_SECONDS := 600.0
const MAX_CALM_SECONDS := 1200.0
const WARNING_SECONDS := 45.0
const MIN_STORM_SECONDS := 75.0
const MAX_STORM_SECONDS := 120.0
const SAND_STEP_SECONDS := 36.0
# A storm has several chances to deposit sand, but not every target is hit.
# The third level remains possible only as a rare event: in practice, one or
# two accumulation levels per storm are the normal result.
const SAND_DEPOSIT_CHANCE := 0.72
const SAND_THIRD_LEVEL_CHANCE := 0.12
const CLEAN_DISTANCE := 94.0
const CLEAN_MODAL := &"sand_cleaning"
const OUTDOOR_DEBUFF_PROFILES := [
	{
		"label": "CUTTING GUSTS",
		"movement_multiplier": 0.94,
		"oxygen_multiplier": 1.15,
		"hunger_multiplier": 1.05,
		"thirst_multiplier": 1.15,
		"wind_chill_c": -4.0,
	},
	{
		"label": "DUST CLOUD",
		"movement_multiplier": 0.88,
		"oxygen_multiplier": 1.30,
		"hunger_multiplier": 1.10,
		"thirst_multiplier": 1.28,
		"wind_chill_c": -8.0,
	},
	{
		"label": "MARTIAN WHITEOUT",
		"movement_multiplier": 0.82,
		"oxygen_multiplier": 1.50,
		"hunger_multiplier": 1.18,
		"thirst_multiplier": 1.45,
		"wind_chill_c": -12.0,
	},
]

var state := State.CALM
var _elapsed_seconds := 0.0
var _state_remaining := 0.0
var _sand_step_elapsed := 0.0
var _storm_deposit_count := 0
var _targets: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _overlay_layer: CanvasLayer
var _overlay: SandstormOverlay
var _ui_layer: CanvasLayer
var _weather_panel: PanelContainer
var _weather_label: Label
var _clean_panel: PanelContainer
var _clean_label: Label

var _clean_target_key := ""
var _clean_player: Node2D
var _clean_elapsed := 0.0
var _clean_duration := 0.0
var _notice_text := ""
var _notice_until_seconds := 0.0
var _outdoor_debuff_profile: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_outdoor_debuff_profile = Dictionary(OUTDOOR_DEBUFF_PROFILES[0]).duplicate(true)
	_schedule_calm_period()
	call_deferred("_ensure_layers")


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_elapsed_seconds += delta
	_process_cleaning(delta)
	_state_remaining = maxf(0.0, _state_remaining - delta)
	match state:
		State.CALM:
			if _state_remaining <= 0.0:
				_start_warning()
		State.WARNING:
			if _state_remaining <= 0.0:
				_start_storm()
		State.ACTIVE:
			_sand_step_elapsed += delta
			while _sand_step_elapsed >= SAND_STEP_SECONDS:
				_sand_step_elapsed -= SAND_STEP_SECONDS
				_deposit_sand_once()
			if _state_remaining <= 0.0:
				_end_storm()
	_update_weather_ui()
	_update_overlay()


func register_target(target: Node2D, display_name: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	_targets[_target_key(target)] = {
		"node": target,
		"display_name": display_name,
	}


func unregister_target(target: Node) -> void:
	if target == null:
		return
	var key := _target_key(target)
	_targets.erase(key)
	if _clean_target_key == key:
		_finish_cleaning(false)


func get_incident_rate_multiplier() -> float:
	# Wind-driven dust enters joints and makes ordinary faults more likely;
	# solar panels also have their own irreversible failure rule.
	return 2.5 if state == State.ACTIVE else 1.0


func is_storm_active() -> bool:
	return state == State.ACTIVE


func is_player_exposed_to_storm(player: Node2D) -> bool:
	if state != State.ACTIVE or player == null or not is_instance_valid(player):
		return false
	for dome in get_tree().get_nodes_in_group("pressurized_interiors"):
		if is_instance_valid(dome) and dome.has_method("contains_world_point") and bool(dome.call("contains_world_point", player.global_position)):
			return false
	return true


func get_outdoor_movement_multiplier(player: Node2D) -> float:
	return _outdoor_multiplier("movement_multiplier", player)


func get_outdoor_oxygen_multiplier(player: Node2D) -> float:
	return _outdoor_multiplier("oxygen_multiplier", player)


func get_outdoor_hunger_multiplier(player: Node2D) -> float:
	return _outdoor_multiplier("hunger_multiplier", player)


func get_outdoor_thirst_multiplier(player: Node2D) -> float:
	return _outdoor_multiplier("thirst_multiplier", player)


func get_outdoor_wind_chill_c(player: Node2D) -> float:
	return float(_outdoor_debuff_profile.get("wind_chill_c", 0.0)) if is_player_exposed_to_storm(player) else 0.0


func get_outdoor_debuff_label(player: Node2D) -> String:
	return str(_outdoor_debuff_profile.get("label", "STORM")) if is_player_exposed_to_storm(player) else "CLEAR"


func get_active_outdoor_effects(player: Node2D) -> Dictionary:
	return {
		"active": is_player_exposed_to_storm(player),
		"movement_multiplier": get_outdoor_movement_multiplier(player),
		"oxygen_multiplier": get_outdoor_oxygen_multiplier(player),
		"hunger_multiplier": get_outdoor_hunger_multiplier(player),
		"thirst_multiplier": get_outdoor_thirst_multiplier(player),
		"wind_chill_c": get_outdoor_wind_chill_c(player),
	}


func _outdoor_multiplier(key: String, player: Node2D) -> float:
	return float(_outdoor_debuff_profile.get(key, 1.0)) if is_player_exposed_to_storm(player) else 1.0


func get_state_label() -> String:
	match state:
		State.WARNING:
			return "STORM APPROACHING"
		State.ACTIVE:
			return "SANDSTORM ACTIVE"
	return "WEATHER STABLE"


func get_remaining_seconds() -> float:
	return _state_remaining


func begin_nearby_cleaning(player: Node2D, preferred_target: Node2D = null) -> bool:
	if player == null or not is_instance_valid(player) or not _clean_target_key.is_empty():
		return false
	if _player_inside_pressurized_dome(player):
		return false
	var closest_key := ""
	var closest_distance := CLEAN_DISTANCE
	for key_variant in _targets.keys().duplicate():
		var key := str(key_variant)
		var data: Dictionary = _targets[key]
		var target := data.get("node") as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			_targets.erase(key)
			continue
		var level := _sand_level(target)
		if level <= 0 or not _can_clean(target):
			continue
		var distance := player.global_position.distance_to(_clean_position(target))
		if preferred_target != null and target != preferred_target:
			continue
		if distance <= closest_distance:
			closest_key = key
			closest_distance = distance
	if closest_key.is_empty():
		return false
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and not bool(ui_state.call("try_open_modal", CLEAN_MODAL)):
		return false
	var data: Dictionary = _targets[closest_key]
	var target := data.get("node") as Node2D
	_clean_target_key = closest_key
	_clean_player = player
	_clean_elapsed = 0.0
	_clean_duration = _clean_duration_for_level(_sand_level(target))
	_show_clean_panel()
	return true


func toggle_nearby_solar_tarp(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player) or not _clean_target_key.is_empty():
		return false
	if _player_inside_pressurized_dome(player):
		return false
	var closest: Node2D
	var closest_distance := CLEAN_DISTANCE
	for data_variant in _targets.values():
		var data: Dictionary = data_variant
		var target := data.get("node") as Node2D
		if target == null or not is_instance_valid(target) or not target.has_method("can_toggle_solar_tarp"):
			continue
		var distance := player.global_position.distance_to(_clean_position(target))
		if distance <= closest_distance:
			closest = target
			closest_distance = distance
	if closest == null or not bool(closest.call("can_toggle_solar_tarp")):
		return false
	var covered := bool(closest.call("toggle_solar_tarp"))
	_show_notice("TARP %s\n%s" % ["INSTALLED" if covered else "REMOVED", "The panel is protected from sand." if covered else "The panel can generate power again."])
	return true


func get_nearby_sand_prompt(player: Node2D) -> String:
	if player == null or not is_instance_valid(player):
		return ""
	if _player_inside_pressurized_dome(player):
		return ""
	var closest: Node2D
	var closest_distance := CLEAN_DISTANCE
	for data_variant in _targets.values():
		var data: Dictionary = data_variant
		var target := data.get("node") as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var distance := player.global_position.distance_to(_clean_position(target))
		if distance <= closest_distance:
			closest = target
			closest_distance = distance
	if closest == null:
		return ""
	if closest.has_method("is_solar_destroyed") and bool(closest.call("is_solar_destroyed")):
		return "PANEL DESTROYED · remove it and purchase a new one"
	if closest.has_method("is_solar_tarped") and bool(closest.call("is_solar_tarped")):
		return "T · REMOVE PANEL TARP"
	if closest.has_method("can_toggle_solar_tarp") and bool(closest.call("can_toggle_solar_tarp")):
		return "T · INSTALL PROTECTIVE TARP"
	var level := _sand_level(closest)
	if level > 0:
		return "HOLD E · CLEAN (%s)" % _sand_label(level)
	return ""


func force_storm_for_test() -> void:
	_start_storm()


func force_deposit_for_test(target: Node2D) -> void:
	if target == null:
		return
	_deposit_on_target(target)


func show_notification(message: String) -> void:
	_show_notice(message)


func reset_for_new_mission() -> void:
	for data_variant in _targets.values():
		var data: Dictionary = data_variant
		var target := data.get("node") as Node2D
		if target != null and is_instance_valid(target) and target.has_method("set_sand_accumulation"):
			target.call("set_sand_accumulation", 0)
	_targets.clear()
	_finish_cleaning(false)
	state = State.CALM
	_sand_step_elapsed = 0.0
	_storm_deposit_count = 0
	_outdoor_debuff_profile = Dictionary(OUTDOOR_DEBUFF_PROFILES[0]).duplicate(true)
	_schedule_calm_period()
	if _weather_panel != null:
		_weather_panel.visible = false
	_update_overlay()


func _schedule_calm_period() -> void:
	_state_remaining = _rng.randf_range(MIN_CALM_SECONDS, MAX_CALM_SECONDS)


func _start_warning() -> void:
	state = State.WARNING
	_state_remaining = WARNING_SECONDS
	storm_state_changed.emit(state)
	_show_notice("WEATHER ALERT\nA sandstorm will reach the base shortly. Protect panels with T.")


func _start_storm() -> void:
	state = State.ACTIVE
	_state_remaining = _rng.randf_range(MIN_STORM_SECONDS, MAX_STORM_SECONDS)
	_sand_step_elapsed = 0.0
	_storm_deposit_count = 0
	_outdoor_debuff_profile = Dictionary(OUTDOOR_DEBUFF_PROFILES[_rng.randi_range(0, OUTDOOR_DEBUFF_PROFILES.size() - 1)]).duplicate(true)
	storm_state_changed.emit(state)
	_show_notice("SANDSTORM\nOutdoors: %s. Return inside or consume more resources." % str(_outdoor_debuff_profile.get("label", "STRONG WIND")))


func _end_storm() -> void:
	state = State.CALM
	_sand_step_elapsed = 0.0
	_storm_deposit_count = 0
	_schedule_calm_period()
	storm_state_changed.emit(state)
	_show_notice("STORM PASSED\nSand remaining on machines must be removed by hand.")


func _deposit_sand_once() -> void:
	var deposit_chance := 1.0 if _storm_deposit_count == 0 else (SAND_THIRD_LEVEL_CHANCE if _storm_deposit_count >= 2 else SAND_DEPOSIT_CHANCE)
	if _rng.randf() > deposit_chance:
		return
	_storm_deposit_count += 1
	for key_variant in _targets.keys().duplicate():
		var key := str(key_variant)
		var data: Dictionary = _targets[key]
		var target := data.get("node") as Node2D
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			_targets.erase(key)
			continue
		_deposit_on_target(target)


func _deposit_on_target(target: Node2D) -> void:
	if target.has_method("is_sand_protected") and bool(target.call("is_sand_protected")):
		return
	var old_level := _sand_level(target)
	if old_level >= 3:
		# IncidentManager keeps only one active fault to avoid overwhelming the
		# player. A buried target retries on later steps once the former incident
		# has been resolved.
		if target.has_method("on_sand_buried"):
			target.call("on_sand_buried")
		return
	var new_level := old_level + 1
	if target.has_method("set_sand_accumulation"):
		target.call("set_sand_accumulation", new_level)
		sand_level_changed.emit(target, new_level)
	if new_level >= 3 and target.has_method("on_sand_buried"):
		target.call("on_sand_buried")


func _process_cleaning(delta: float) -> void:
	if _clean_target_key.is_empty():
		return
	if not _targets.has(_clean_target_key):
		_finish_cleaning(false)
		return
	var data: Dictionary = _targets[_clean_target_key]
	var target := data.get("node") as Node2D
	if target == null or not is_instance_valid(target) or _clean_player == null or not is_instance_valid(_clean_player):
		_finish_cleaning(false)
		return
	if not Input.is_key_pressed(KEY_E) or _clean_player.global_position.distance_to(_clean_position(target)) > CLEAN_DISTANCE:
		_finish_cleaning(false)
		return
	_clean_elapsed += delta
	_show_clean_panel()
	if _clean_elapsed < _clean_duration:
		return
	var level := _sand_level(target)
	if level > 0 and target.has_method("set_sand_accumulation"):
		# One complete cleaning removes all accumulated sand instead of requiring
		# the player to repeat E once for every level.
		target.call("set_sand_accumulation", 0)
		sand_level_changed.emit(target, 0)
	_show_notice("SAND REMOVED\n%s: CLEAN" % str(data.get("display_name", "MACHINE")))
	_finish_cleaning(true)


func _finish_cleaning(_success: bool) -> void:
	_clean_target_key = ""
	_clean_player = null
	_clean_elapsed = 0.0
	_clean_duration = 0.0
	if _clean_panel != null:
		_clean_panel.visible = false
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", CLEAN_MODAL)


func _sand_level(target: Node2D) -> int:
	return clampi(int(target.call("get_sand_accumulation")), 0, 3) if target.has_method("get_sand_accumulation") else 0


func _can_clean(target: Node2D) -> bool:
	return bool(target.call("can_clean_sand")) if target.has_method("can_clean_sand") else true


func _clean_position(target: Node2D) -> Vector2:
	return Vector2(target.call("get_sand_clean_position")) if target.has_method("get_sand_clean_position") else target.global_position


func _clean_duration_for_level(level: int) -> float:
	return 1.5 + float(clampi(level, 1, 3)) * 1.5


func _player_inside_pressurized_dome(player: Node2D) -> bool:
	for dome in get_tree().get_nodes_in_group("pressurized_interiors"):
		if not is_instance_valid(dome) or not dome.has_method("contains_world_point"):
			continue
		if bool(dome.call("contains_world_point", player.global_position)) and (not dome.has_method("is_in_corridor") or not bool(dome.call("is_in_corridor", player.global_position))):
			return true
	return false


func _sand_label(level: int) -> String:
	match level:
		1:
			return "DIRTY"
		2:
			return "COVERED"
		3:
			return "BURIED"
	return "CLEAN"


func _target_key(target: Node) -> String:
	return str(target.get_instance_id())


func _ensure_layers() -> void:
	if _overlay_layer == null or not is_instance_valid(_overlay_layer):
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "SandstormOverlayLayer"
		_overlay_layer.layer = 30
		get_tree().root.add_child(_overlay_layer)
		_overlay = SandstormOverlay.new()
		_overlay.name = "FlyingSand"
		_overlay_layer.add_child(_overlay)
	if _ui_layer == null or not is_instance_valid(_ui_layer):
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "SandstormUILayer"
		_ui_layer.layer = 115
		get_tree().root.add_child(_ui_layer)
		_weather_panel = _make_panel(Color("b85c2f"))
		_weather_panel.name = "SandstormWeatherPanel"
		_weather_panel.visible = false
		_ui_layer.add_child(_weather_panel)
		_weather_label = _make_label(15, Color("ffe2bd"))
		_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weather_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_weather_panel.add_child(_weather_label)
		_clean_panel = _make_panel(Color("d88a3b"))
		_clean_panel.anchor_left = 0.5
		_clean_panel.anchor_right = 0.5
		_clean_panel.anchor_top = 0.5
		_clean_panel.anchor_bottom = 0.5
		_clean_panel.offset_left = -290.0
		_clean_panel.offset_right = 290.0
		_clean_panel.offset_top = -70.0
		_clean_panel.offset_bottom = 70.0
		_clean_panel.visible = false
		_ui_layer.add_child(_clean_panel)
		_clean_label = _make_label(19, Color("fff1da"))
		_clean_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_clean_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_clean_panel.add_child(_clean_label)
	_update_weather_panel_position()
	_update_overlay()


func _make_panel(border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.035, 0.012, 0.91)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("210b03"))
	label.add_theme_constant_override("outline_size", 3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _update_weather_ui() -> void:
	if _weather_panel == null or _weather_label == null:
		return
	_update_weather_panel_position()
	if _elapsed_seconds < _notice_until_seconds and not _notice_text.is_empty():
		_weather_panel.visible = true
		_weather_label.text = _notice_text
		return
	if state == State.CALM:
		_weather_panel.visible = false
		return
	_weather_panel.visible = true
	var seconds := ceili(_state_remaining)
	if state == State.WARNING:
		_weather_label.text = "⚠ STORM APPROACHING  ·  %ds\nInstall solar-panel tarps: T" % seconds
	else:
		_weather_label.text = "SANDSTORM ACTIVE  ·  %ds\nOutdoors: %s · increased EVA consumption" % [seconds, str(_outdoor_debuff_profile.get("label", "STRONG WIND"))]


func _update_weather_panel_position() -> void:
	if _weather_panel == null:
		return
	# The machine panel lives in a CanvasLayer separate from the main scene, so
	# the group stays reliable even when the HUD is rebuilt.
	var machine_panel: Control
	for candidate in get_tree().get_nodes_in_group("machine_status_ui"):
		if candidate is Control and is_instance_valid(candidate) and candidate.visible:
			machine_panel = candidate as Control
			break
	if machine_panel != null and machine_panel.visible:
		# The machine panel occupies the top center; place the alert beneath the
		# EVA systems, where it remains readable without covering useful data.
		_weather_panel.anchor_left = 0.0
		_weather_panel.anchor_right = 0.0
		_weather_panel.anchor_top = 0.0
		_weather_panel.anchor_bottom = 0.0
		_weather_panel.offset_left = 16.0
		_weather_panel.offset_right = 386.0
		# The supplied GUI layout places temperature at 141..267 px: stay below
		# that panel without covering either the machine card or EVA data.
		_weather_panel.offset_top = 282.0
		_weather_panel.offset_bottom = 374.0
	else:
		_weather_panel.anchor_left = 0.5
		_weather_panel.anchor_right = 0.5
		_weather_panel.anchor_top = 0.0
		_weather_panel.anchor_bottom = 0.0
		_weather_panel.offset_left = -265.0
		_weather_panel.offset_right = 265.0
		_weather_panel.offset_top = 18.0
		_weather_panel.offset_bottom = 100.0


func _update_overlay() -> void:
	if _overlay == null:
		return
	var intensity := 0.0
	if state == State.WARNING:
		intensity = 0.12
	elif state == State.ACTIVE:
		intensity = 0.72 + sin(_elapsed_seconds * 2.2) * 0.12
	_overlay.set_intensity(intensity)


func _show_notice(message: String) -> void:
	_ensure_layers()
	_notice_text = message
	_notice_until_seconds = _elapsed_seconds + 5.0
	if _weather_label != null:
		_weather_panel.visible = true
		_weather_label.text = message


func _show_clean_panel() -> void:
	_ensure_layers()
	if _clean_panel == null or _clean_label == null or not _targets.has(_clean_target_key):
		return
	var data: Dictionary = _targets[_clean_target_key]
	var target := data.get("node") as Node2D
	var level := _sand_level(target)
	var percent := roundi(clampf(_clean_elapsed / maxf(0.01, _clean_duration), 0.0, 1.0) * 100.0)
	_clean_label.text = "SPOLVERATURA · %s\n\nTIENI PREMUTO E  ·  %d%%\n%s" % [str(data.get("display_name", "MACCHINARIO")), percent, _sand_label(level)]
	_clean_panel.visible = true
