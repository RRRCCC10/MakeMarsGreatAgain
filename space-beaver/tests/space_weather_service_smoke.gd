extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		push_error("Impossibile caricare la scena principale")
		quit(1)
		return
	await process_frame
	await process_frame
	var weather: Node = root.get_node("SpaceWeatherService")
	var radiation: Node = root.get_node("Radiation")
	weather.call("set_live_fetch_enabled_for_test", false)
	weather.call("ingest_wsa_enlil_for_test", [
		{
			"simulationID": "WSA-ENLIL/major-mars",
			"cmeInputs": [{"speed": 1500.0}],
			"impactList": [{"location": "Mars", "arrivalTime": "2026-11-10T12:00Z"}],
		},
		{
			"simulationID": "WSA-ENLIL/minor-mars",
			"speed": 450.0,
			"impactList": [{"location": "Mars", "arrivalTime": "2026-11-11T12:00Z", "isGlancingBlow": true}],
		},
		{
			"simulationID": "WSA-ENLIL/earth-only",
			"speed": 3100.0,
			"impactList": [{"location": "Earth", "arrivalTime": "2026-11-09T12:00Z"}],
		},
	])
	_expect(int(weather.call("get_candidate_count")) == 2, "Solo gli impatti previsti su Marte devono entrare nel pool")
	_expect(str(weather.call("choose_event_profile", "major", 0, 4)) == "minor", "Il primo evento deve restare minore anche con DONKI")
	_expect(str(weather.call("choose_event_profile", "minor", 1, 2)) == "minor", "Nessun evento DONKI deve entrare prima del SOL 3")
	_expect(str(weather.call("choose_event_profile", "minor", 1, 4)) == "major", "Un impatto marziano veloce deve selezionare il profilo maggiore")
	_expect(str(weather.call("choose_event_profile", "major", 2, 4)) == "minor", "Un impatto radente deve selezionare il profilo minore")
	_expect(str(weather.call("choose_event_profile", "major", 3, 4)) == "major", "Esauriti i dati DONKI, deve restare il fallback del gioco")

	var stats: Dictionary = weather.call("get_schedule_statistics")
	_expect(is_equal_approx(float(stats.get("first_event_min_hours", 0.0)), 72.0), "Il tutorial deve avere almeno 3 SOL senza eventi")
	_expect(is_equal_approx(float(stats.get("first_event_max_hours", 0.0)), 96.0), "Il primo evento deve arrivare entro 4 SOL")
	_expect(is_equal_approx(float(stats.get("repeat_quiet_mean_sols", 0.0)), 4.0), "L'attesa media tra eventi deve restare di 4 SOL")
	_expect(float(stats.get("expected_events_per_30_sols", 0.0)) > 7.0 and float(stats.get("expected_events_per_30_sols", 0.0)) < 7.3, "La frequenza media deve restare regolare, non continua ne' rara")

	radiation.call("reset_for_new_mission")
	_expect(float(radiation.time_to_next_event_hours) >= 72.0 and float(radiation.time_to_next_event_hours) <= 96.0, "Radiation deve rispettare la finestra protetta iniziale")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SPACE_WEATHER_SERVICE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
