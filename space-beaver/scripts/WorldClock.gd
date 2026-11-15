extends Node

signal minute_changed(hour: int, minute: int, sol: int)
signal phase_changed(phase: int, phase_label: String)

enum Phase { NIGHT, DAWN, DAY, DUSK }

## A Martian sol lasts 24 h 39 m 35 terrestrial seconds. By convention the
## local clock divides it into 24 Martian hours, so each lasts ~61 m 39.8 s.
## The game remains compressed to eight real minutes per Sol: nomenclature and
## scientific reference change, not survival pacing.
const HOURS_PER_SOL := 24.0
const HOURS_PER_DAY := HOURS_PER_SOL # compatibility with pre-existing systems
const MARS_SOL_EARTH_SECONDS := 88_775.244
const MARS_HOUR_EARTH_MINUTES := MARS_SOL_EARTH_SECONDS / HOURS_PER_SOL / 60.0
const LOCAL_SOLAR_TIME_LABEL := "LMST"
const DEFAULT_GAME_HOURS_PER_REAL_SECOND := 0.05

var game_hour := 8.0
var sol := 1
## Technical alias for older saves and scripts: new interface and data always
## expose the correct name, `sol`.
var day: int:
	get:
		return sol
	set(value):
		sol = maxi(1, value)
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
	if total_hours >= HOURS_PER_SOL:
		sol += floori(total_hours / HOURS_PER_SOL)
	game_hour = fmod(total_hours, HOURS_PER_SOL)
	_emit_clock_state(false)


func set_game_hour(value: float) -> void:
	game_hour = fposmod(value, HOURS_PER_SOL)
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
			return "DAWN"
		Phase.DAY:
			return "DAY"
		Phase.DUSK:
			return "DUSK"
	return "NIGHT"


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
		"mars_hour": game_hour,
		"whole_hour": whole_hour,
		"minute": minute,
		"sol": sol,
		"day": sol, # compatibility with existing photo archives
		"phase": get_phase(),
		"phase_label": get_phase_label(),
		"solar_factor": get_solar_factor(),
		"artificial_light_factor": get_artificial_light_factor(),
	}


func format_local_solar_time(use_am_pm: bool = true) -> String:
	var data := get_time_data()
	var hour_24 := clampi(int(data.get("whole_hour", 0)), 0, 23)
	var minute := clampi(int(data.get("minute", 0)), 0, 59)
	if not use_am_pm:
		return "%02d:%02d %s" % [hour_24, minute, LOCAL_SOLAR_TIME_LABEL]
	var suffix := "AM" if hour_24 < 12 else "PM"
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%02d:%02d %s %s" % [hour_12, minute, suffix, LOCAL_SOLAR_TIME_LABEL]


func get_mars_hour_earth_minutes() -> float:
	return MARS_HOUR_EARTH_MINUTES


func _emit_clock_state(force: bool) -> void:
	var phase := get_phase()
	if force or phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase, get_phase_label(phase))
	var minute_of_sol := floori(game_hour * 60.0) % 1440
	if force or minute_of_sol != _last_minute:
		_last_minute = minute_of_sol
		minute_changed.emit(minute_of_sol / 60, minute_of_sol % 60, sol)


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	var amount := clampf((value - edge_start) / (edge_end - edge_start), 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)


func reset_for_new_mission() -> void:
	game_hour = 8.0
	sol = 1
	time_scale = 1.0
	running = true
	_last_minute = -1
	_last_phase = -1
	_emit_clock_state(true)
