extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var temperature: Node = root.get_node("Temperature")
	var suits: Node = root.get_node("SuitSystem")
	var clock: Node = root.get_node("WorldClock")
	var game_state: Node = root.get_node("GameState")
	var player := current_scene.get_node("player") as Node2D
	var landing := current_scene.get_node("LandingSequence") as Node2D

	_expect(current_scene.get_node_or_null("TemperatureUI") != null, "La scena deve mostrare il pannello termico EVA")
	clock.call("set_game_hour", 12.0)
	var equatorial_day := float(temperature.call("get_surface_temperature_for_source", 0))
	clock.call("set_game_hour", 1.0)
	var equatorial_night := float(temperature.call("get_surface_temperature_for_source", 0))
	var polar_night := float(temperature.call("get_surface_temperature_for_source", 4))
	_expect(equatorial_day > equatorial_night + 45.0, "La pianura marziana deve raffreddarsi nettamente di notte")
	_expect(polar_night < equatorial_night - 30.0, "Il ghiaccio polare deve essere molto piu' freddo della base")
	_expect(float(suits.call("get_cold_tolerance_c")) <= -68.0, "La tuta standard deve offrire protezione termica di base")

	temperature.call("reset_for_new_mission")
	temperature.call("_apply_thermal_step", 12.0, -115.0, 0.0)
	var exposed_core := float(temperature.core_temperature_c)
	_expect(exposed_core < 34.0, "Una notte polare esposta deve causare ipotermia concreta")
	_expect(float(temperature.call("get_movement_multiplier")) < 1.0, "Il freddo deve ridurre la mobilita' prima di essere letale")
	_expect(float(temperature.call("get_oxygen_consumption_multiplier")) > 1.0, "Il freddo deve aumentare il consumo di ossigeno")

	temperature.call("reset_for_new_mission")
	temperature.call("_apply_thermal_step", 12.0, -115.0, 18.0)
	_expect(float(temperature.core_temperature_c) > exposed_core, "Un rifugio deve ridurre la perdita termica anche senza riscaldamento completo")

	player.global_position = landing.global_position
	var shelter_environment: Dictionary = temperature.call("_resolve_environment")
	_expect(float(shelter_environment.get("shelter_bonus_c", 0.0)) > 0.0, "Il modulo di atterraggio deve fornire una protezione termica minima")

	suits.call("acquire_suit", "suit_storm")
	_expect(suits.call("equip", "suit_storm"), "La tuta Storm deve poter essere equipaggiata")
	_expect(float(suits.call("get_cold_tolerance_c")) <= -110.0, "La tuta Storm deve offrire la protezione dal freddo piu' alta")
	temperature.call("reset_for_new_mission")
	temperature.call("_apply_thermal_step", 12.0, -115.0, 0.0)
	_expect(float(temperature.core_temperature_c) > exposed_core + 2.0, "La tuta migliore deve mitigare in modo misurabile la notte polare")

	temperature.core_temperature_c = 28.0
	_expect(bool(temperature.call("is_lethal")), "Una temperatura corporea di 28°C deve essere letale")
	var death_data: Dictionary = game_state.call("_get_death_data", "cold")
	_expect(str(death_data.get("title", "")).contains("IPOTERMIA"), "Deve esistere un finale custom per il freddo")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TEMPERATURE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
