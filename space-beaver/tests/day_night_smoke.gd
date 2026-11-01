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
	_expect(noon_color.get_luminance() > night_color.get_luminance(), "Il giorno deve essere piu' luminoso della notte")
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
	clock.set_game_hour(4.99)
	_expect(clock.get_phase_label() == "NOTTE", "04:59 deve essere NOTTE")
	_expect(is_zero_approx(clock.get_solar_factor()), "Il solare deve essere zero di notte")
	clock.set_game_hour(5.5)
	_expect(clock.get_phase_label() == "ALBA", "05:30 deve essere ALBA")
	_expect(is_zero_approx(clock.get_solar_factor()), "Il solare deve restare zero prima delle 06:00")
	clock.set_game_hour(6.0)
	_expect(clock.get_phase_label() == "GIORNO", "06:00 deve essere GIORNO")
	_expect(is_zero_approx(clock.get_solar_factor()), "La rampa solare deve partire da zero alle 06:00")
	clock.set_game_hour(6.5)
	_expect(clock.get_solar_factor() > 0.0 and clock.get_solar_factor() < 1.0, "Alle 06:30 il solare deve essere in rampa")
	clock.set_game_hour(12.0)
	_expect(is_equal_approx(clock.get_solar_factor(), 1.0), "A mezzogiorno il solare deve essere al 100%")
	clock.set_game_hour(17.5)
	_expect(clock.get_phase_label() == "TRAMONTO", "17:30 deve essere TRAMONTO")
	_expect(clock.get_solar_factor() > 0.0 and clock.get_solar_factor() < 1.0, "Alle 17:30 il solare deve essere in calo")
	clock.set_game_hour(18.0)
	_expect(clock.get_phase_label() == "NOTTE", "18:00 deve essere NOTTE")
	_expect(is_zero_approx(clock.get_solar_factor()), "Il solare deve essere zero dalle 18:00")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
