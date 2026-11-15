extends Node

signal changed(data: Dictionary)
signal event_warning(data: Dictionary)
signal event_started(data: Dictionary)
signal event_ended

enum EventState { QUIET, WARNING, ACTIVE }

const GCR_AMBIENT_RATE_MSV_H := 0.03
const ACUTE_HALF_LIFE_HOURS := 24.0
const WARNING_HOURS := 1.5
const EXTREME_EVENTS_ENABLED := false
const FIRST_EVENT_MIN_HOURS := 72.0
const FIRST_EVENT_MAX_HOURS := 96.0
const REPEAT_EVENT_MIN_HOURS := 72.0
const REPEAT_EVENT_MAX_HOURS := 120.0
const EVENT_DEFINITIONS := {
	"minor": {
		"label": "PICCO SOLARE MINORE",
		"duration_hours": 2.5,
		"unshielded_total_msv": 120.0,
		"color": Color("ffd36a"),
	},
	"major": {
		"label": "PICCO SOLARE MAGGIORE",
		"duration_hours": 4.0,
		"unshielded_total_msv": 600.0,
		"color": Color("ff8d62"),
	},
	"extreme": {
		"label": "TEMPESTA SOLARE ESTREMA",
		"duration_hours": 6.0,
		"unshielded_total_msv": 1500.0,
		"color": Color("ef6cff"),
	},
}

var event_state := EventState.QUIET
var current_event_id := ""
var event_elapsed_hours := 0.0
var event_time_remaining_hours := 0.0
var time_to_next_event_hours := 0.0
var current_ambient_rate_msv_h := GCR_AMBIENT_RATE_MSV_H
var current_received_rate_msv_h := 0.0
var acute_dose_msv := 0.0
var cumulative_dose_msv := 0.0
var solar_dose_msv := 0.0
var cosmic_dose_msv := 0.0
var events_completed := 0
var _ui_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_priority = -50
	_rng.seed = Time.get_ticks_usec()
	reset_for_new_mission()


func _process(delta: float) -> void:
	var game_hours := WorldClock.get_game_hours_for_real_delta(delta)
	if game_hours <= 0.0:
		return
	acute_dose_msv *= pow(0.5, game_hours / ACUTE_HALF_LIFE_HOURS)
	var dome_cosmic_protection := _get_dome_radiation_protection("get_cosmic_radiation_protection")
	var dome_solar_protection := _get_dome_radiation_protection("get_solar_radiation_protection")
	var cosmic_rate := GCR_AMBIENT_RATE_MSV_H * (1.0 - SuitSystem.get_cosmic_protection()) * (1.0 - dome_cosmic_protection)
	var solar_ambient_rate := 0.0
	if event_state == EventState.QUIET:
		time_to_next_event_hours -= game_hours
		if time_to_next_event_hours <= 0.0:
			_begin_warning(_choose_next_event())
	elif event_state == EventState.WARNING:
		event_time_remaining_hours = maxf(0.0, event_time_remaining_hours - game_hours)
		if event_time_remaining_hours <= 0.0:
			_begin_active_event()
	elif event_state == EventState.ACTIVE:
		var definition: Dictionary = EVENT_DEFINITIONS[current_event_id]
		var duration := float(definition["duration_hours"])
		var progress := clampf(event_elapsed_hours / duration, 0.0, 1.0)
		# Curva morbida con media circa 1: il centro dell'evento e' il picco.
		var intensity_shape := 0.25 + 1.1781 * sin(PI * progress)
		solar_ambient_rate = float(definition["unshielded_total_msv"]) / duration * intensity_shape
		var received_solar_rate := solar_ambient_rate * (1.0 - SuitSystem.get_solar_protection()) * (1.0 - dome_solar_protection)
		var solar_step := received_solar_rate * game_hours
		solar_dose_msv += solar_step
		acute_dose_msv += solar_step
		cumulative_dose_msv += solar_step
		event_elapsed_hours += game_hours
		event_time_remaining_hours = maxf(0.0, duration - event_elapsed_hours)
		if event_elapsed_hours >= duration:
			_end_active_event()
	var cosmic_step := cosmic_rate * game_hours
	cosmic_dose_msv += cosmic_step
	acute_dose_msv += cosmic_step
	cumulative_dose_msv += cosmic_step
	current_ambient_rate_msv_h = GCR_AMBIENT_RATE_MSV_H + solar_ambient_rate
	current_received_rate_msv_h = cosmic_rate + solar_ambient_rate * (1.0 - SuitSystem.get_solar_protection()) * (1.0 - dome_solar_protection)
	_ui_timer += delta
	if _ui_timer >= 0.10:
		_ui_timer = 0.0
		changed.emit(get_data())


func get_data() -> Dictionary:
	var definition: Dictionary = EVENT_DEFINITIONS.get(current_event_id, {})
	return {
		"state": event_state,
		"event_id": current_event_id,
		"event_label": str(definition.get("label", "FONDO COSMICO NOMINALE")),
		"event_color": definition.get("color", Color("6fc9e8")),
		"time_remaining_hours": event_time_remaining_hours,
		"ambient_rate_msv_h": current_ambient_rate_msv_h,
		"received_rate_msv_h": current_received_rate_msv_h,
		"acute_dose_msv": acute_dose_msv,
		"cumulative_dose_msv": cumulative_dose_msv,
		"solar_dose_msv": solar_dose_msv,
		"cosmic_dose_msv": cosmic_dose_msv,
		"condition": get_condition_label(),
		"movement_multiplier": get_movement_multiplier(),
	}


func _get_dome_radiation_protection(method_name: String) -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return 0.0
	for dome in get_tree().get_nodes_in_group("pressurized_interiors"):
		if is_instance_valid(dome) and dome.has_method("contains_world_point") and bool(dome.call("contains_world_point", player.global_position)) and dome.has_method(method_name):
			return clampf(float(dome.call(method_name)), 0.0, 0.95)
	return 0.0


func get_condition_label() -> String:
	if acute_dose_msv < 500.0:
		return "NOMINALE"
	if acute_dose_msv < 1000.0:
		return "AFFATICAMENTO LIEVE"
	if acute_dose_msv < 2000.0:
		return "NAUSEA E DEBOLEZZA"
	if acute_dose_msv < 4000.0:
		return "ESPOSIZIONE CRITICA"
	return "DANNO RADIOLOGICO IRREVERSIBILE"


func get_movement_multiplier() -> float:
	if acute_dose_msv < 500.0:
		return 1.0
	if acute_dose_msv < 1000.0:
		return 0.95
	if acute_dose_msv < 2000.0:
		return 0.90
	return 0.80


func is_lethal() -> bool:
	return acute_dose_msv >= 4000.0


func force_event(event_id: String, skip_warning: bool = false) -> bool:
	if not EVENT_DEFINITIONS.has(event_id):
		return false
	current_event_id = event_id
	if skip_warning:
		_begin_active_event()
	else:
		_begin_warning(event_id)
	return true


func reset_for_new_mission() -> void:
	event_state = EventState.QUIET
	current_event_id = ""
	event_elapsed_hours = 0.0
	event_time_remaining_hours = 0.0
	# Tre o quattro Sol protetti: nessun feed esterno puo' interrompere il tutorial.
	time_to_next_event_hours = _rng.randf_range(FIRST_EVENT_MIN_HOURS, FIRST_EVENT_MAX_HOURS)
	current_ambient_rate_msv_h = GCR_AMBIENT_RATE_MSV_H
	current_received_rate_msv_h = GCR_AMBIENT_RATE_MSV_H * (1.0 - SuitSystem.get_cosmic_protection())
	acute_dose_msv = 0.0
	cumulative_dose_msv = 0.0
	solar_dose_msv = 0.0
	cosmic_dose_msv = 0.0
	events_completed = 0
	_ui_timer = 0.0
	changed.emit(get_data())


func _choose_next_event() -> String:
	var fallback_profile := "minor"
	if events_completed == 0:
		fallback_profile = "minor"
	else:
		var roll := _rng.randf()
		if roll < 0.65:
			fallback_profile = "minor"
		elif roll < 0.95 or not EXTREME_EVENTS_ENABLED:
			fallback_profile = "major"
		else:
			fallback_profile = "extreme"
	if SpaceWeatherService != null and SpaceWeatherService.has_method("choose_event_profile"):
		return str(SpaceWeatherService.choose_event_profile(fallback_profile, events_completed, WorldClock.sol))
	return fallback_profile


func _begin_warning(event_id: String) -> void:
	current_event_id = event_id
	event_state = EventState.WARNING
	event_elapsed_hours = 0.0
	event_time_remaining_hours = WARNING_HOURS
	event_warning.emit(get_data())
	changed.emit(get_data())


func _begin_active_event() -> void:
	if current_event_id.is_empty():
		current_event_id = "minor"
	event_state = EventState.ACTIVE
	event_elapsed_hours = 0.0
	event_time_remaining_hours = float(EVENT_DEFINITIONS[current_event_id]["duration_hours"])
	event_started.emit(get_data())
	changed.emit(get_data())


func _end_active_event() -> void:
	events_completed += 1
	event_state = EventState.QUIET
	current_event_id = ""
	event_elapsed_hours = 0.0
	event_time_remaining_hours = 0.0
	time_to_next_event_hours = _rng.randf_range(REPEAT_EVENT_MIN_HOURS, REPEAT_EVENT_MAX_HOURS)
	event_ended.emit()
	changed.emit(get_data())
