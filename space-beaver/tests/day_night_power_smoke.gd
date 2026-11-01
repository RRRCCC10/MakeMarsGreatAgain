extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock: Node = root.get_node("WorldClock")
	var power_grid: Node = root.get_node("PowerGrid")
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Impossibile caricare la scena principale: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var main_scene: Node = current_scene
	var panel = power_grid.place_device(main_scene, "solar_panel", Vector2i(-8, 6))
	var transformer = power_grid.place_device(main_scene, "transformer", Vector2i(-2, 6))
	var battery = power_grid.place_device(main_scene, "battery", Vector2i(4, 6))
	panel.set_network_enabled(true)
	transformer.set_network_enabled(true)
	battery.set_network_enabled(true)
	var consumer := Node2D.new()
	consumer.position = Vector2(136.0, 104.0)
	main_scene.add_child(consumer)
	power_grid.register_consumer(consumer, Vector2i(8, 6), 50.0, Vector2i.LEFT)
	power_grid.rebuild_network()

	clock.running = true
	clock.time_scale = 1.0
	clock.set_game_hour(12.0)
	power_grid.battery_energy_kwh = 0.0
	power_grid._update_energy(20.0)
	_expect(is_equal_approx(power_grid.production_kw, 100.0), "A mezzogiorno un pannello collegato deve produrre 100 kW")
	_expect(is_equal_approx(power_grid.demand_kw, 50.0), "Il consumatore collegato deve richiedere 50 kW")
	_expect(is_equal_approx(power_grid.battery_energy_kwh, 50.0), "In un'ora il surplus di 50 kW deve caricare 50 kWh")

	clock.set_game_hour(0.0)
	power_grid.battery_energy_kwh = 100.0
	power_grid._update_energy(20.0)
	_expect(is_zero_approx(power_grid.production_kw), "Di notte la produzione solare deve essere zero")
	_expect(is_equal_approx(power_grid.battery_energy_kwh, 50.0), "In un'ora notturna il carico di 50 kW deve consumare 50 kWh")
	_expect(power_grid.network_powered, "La batteria deve mantenere alimentata la rete di notte")
	_expect(power_grid.network_status == "BATTERIA", "La UI deve indicare l'alimentazione da batteria")

	clock.running = false
	if failures.is_empty():
		print("DAY_NIGHT_POWER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
