extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock_script := load("res://scripts/WorldClock.gd")
	var clock: Node = clock_script.new()
	root.add_child(clock)
	await process_frame
	_check_clock(clock)
	var environment_script := load("res://scripts/DayNightController.gd")
	var environment: Node = environment_script.new()
	var night_color: Color = environment.get_ambient_color_for_hour(0.0)
	var noon_color: Color = environment.get_ambient_color_for_hour(12.0)
	_expect(noon_color.get_luminance() > night_color.get_luminance(), "Test assertion failed")
	environment.free()
	clock.queue_free()
	await process_frame
	if failures.is_empty():
		print("DAY_NIGHT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_clock(clock: Node) -> void:
	clock.reset_for_new_mission()
	var starting_time: Dictionary = clock.get_time_data()
	_expect(int(starting_time.get("sol", 0)) == 1, "Test assertion failed")
	_expect(is_equal_approx(float(clock.get_mars_hour_earth_minutes()), 61.649475), "Test assertion failed")
	_expect(str(clock.format_local_solar_time()).ends_with("LMST"), "Test assertion failed")
	clock.set_game_hour(23.99)
	clock._process(0.3)
	var next_sol_time: Dictionary = clock.get_time_data()
	_expect(int(next_sol_time.get("sol", 0)) == 2, "Test assertion failed")
	clock.set_game_hour(4.99)
	_expect(clock.get_phase_label() == "NIGHT", "Test assertion failed")
	_expect(is_zero_approx(clock.get_solar_factor()), "Test assertion failed")
	clock.set_game_hour(5.5)
	_expect(clock.get_phase_label() == "DAWN", "Test assertion failed")
	_expect(is_zero_approx(clock.get_solar_factor()), "Test assertion failed")
	clock.set_game_hour(6.0)
	_expect(clock.get_phase_label() == "DAY", "Test assertion failed")
	_expect(is_zero_approx(clock.get_solar_factor()), "Test assertion failed")
	clock.set_game_hour(6.5)
	_expect(clock.get_solar_factor() > 0.0 and clock.get_solar_factor() < 1.0, "Test assertion failed")
	clock.set_game_hour(12.0)
	_expect(is_equal_approx(clock.get_solar_factor(), 1.0), "Test assertion failed")
	clock.set_game_hour(17.5)
	_expect(clock.get_phase_label() == "DUSK", "Test assertion failed")
	_expect(clock.get_solar_factor() > 0.0 and clock.get_solar_factor() < 1.0, "Test assertion failed")
	clock.set_game_hour(18.0)
	_expect(clock.get_phase_label() == "NIGHT", "Test assertion failed")
	_expect(is_zero_approx(clock.get_solar_factor()), "Test assertion failed")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
