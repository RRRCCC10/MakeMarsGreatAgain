extends Node

signal minute_changed(hour: int, minute: int, day: int)
signal phase_changed(phase: int, phase_label: String)

enum Phase { NIGHT, DAWN, DAY, DUSK }

const HOURS_PER_DAY := 24.0
const DEFAULT_GAME_HOURS_PER_REAL_SECOND := 0.05

var game_hour := 8.0
var day := 1
var time_scale := 1.0
var running := true

var _last_minute := -1
var _last_phase := -1


func _ready() -> void:
	process_priority = -100
	_emit_clock_state(true)


func _process(delta: float) -> void:
	var advanced_hours := get_game_hours_for_real_delta(delta)
	if advanced_hours <= 0.0:
		return
	var total_hours := game_hour + advanced_hours
	if total_hours >= HOURS_PER_DAY:
		day += floori(total_hours / HOURS_PER_DAY)
	game_hour = fmod(total_hours, HOURS_PER_DAY)
	_emit_clock_state(false)


func set_game_hour(value: float) -> void:
	game_hour = fposmod(value, HOURS_PER_DAY)
	_emit_clock_state(true)


func set_time_scale(value: float) -> void:
	time_scale = maxf(0.0, value)


func get_game_hours_for_real_delta(delta: float) -> float:
	if not running:
		return 0.0
	return maxf(0.0, delta) * DEFAULT_GAME_HOURS_PER_REAL_SECOND * time_scale


func is_day() -> bool:
	return game_hour >= 6.0 and game_hour < 18.0


func get_phase() -> int:
	if game_hour >= 5.0 and game_hour < 6.0:
		return Phase.DAWN
	if game_hour >= 6.0 and game_hour < 17.0:
		return Phase.DAY
	if game_hour >= 17.0 and game_hour < 18.0:
		return Phase.DUSK
	return Phase.NIGHT


func get_phase_label(phase: int = -1) -> String:
	var resolved_phase := get_phase() if phase < 0 else phase
	match resolved_phase:
		Phase.DAWN:
			return "ALBA"
		Phase.DAY:
			return "GIORNO"
		Phase.DUSK:
			return "TRAMONTO"
	return "NOTTE"


func get_phase_progress() -> float:
	match get_phase():
		Phase.DAWN:
			return clampf(game_hour - 5.0, 0.0, 1.0)
		Phase.DAY:
			return clampf((game_hour - 6.0) / 11.0, 0.0, 1.0)
		Phase.DUSK:
			return clampf(game_hour - 17.0, 0.0, 1.0)
	var night_hour := game_hour - 18.0 if game_hour >= 18.0 else game_hour + 6.0
	return clampf(night_hour / 11.0, 0.0, 1.0)


func get_solar_factor() -> float:
	if game_hour < 6.0 or game_hour >= 18.0:
		return 0.0
	if game_hour < 7.0:
		return _smoothstep(6.0, 7.0, game_hour)
	if game_hour < 17.0:
		return 1.0
	return 1.0 - _smoothstep(17.0, 18.0, game_hour)


func get_artificial_light_factor() -> float:
	if game_hour >= 18.0 or game_hour < 5.0:
		return 1.0
	if game_hour < 6.0:
		return 1.0 - _smoothstep(5.0, 6.0, game_hour)
	if game_hour >= 17.0:
		return _smoothstep(17.0, 18.0, game_hour)
	return 0.0


func get_time_data() -> Dictionary:
	var whole_hour := floori(game_hour)
	var minute := floori((game_hour - whole_hour) * 60.0)
	return {
		"hour": game_hour,
		"whole_hour": whole_hour,
		"minute": minute,
		"day": day,
		"phase": get_phase(),
		"phase_label": get_phase_label(),
		"solar_factor": get_solar_factor(),
		"artificial_light_factor": get_artificial_light_factor(),
	}


func _emit_clock_state(force: bool) -> void:
	var phase := get_phase()
	if force or phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase, get_phase_label(phase))
	var minute_of_day := floori(game_hour * 60.0) % 1440
	if force or minute_of_day != _last_minute:
		_last_minute = minute_of_day
		minute_changed.emit(minute_of_day / 60, minute_of_day % 60, day)


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	var amount := clampf((value - edge_start) / (edge_end - edge_start), 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)


func reset_for_new_mission() -> void:
	game_hour = 8.0
	day = 1
	time_scale = 1.0
	running = true
	_last_minute = -1
	_last_phase = -1
	_emit_clock_state(true)
