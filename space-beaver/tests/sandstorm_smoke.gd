extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var storms := root.get_node_or_null("SandstormManager")
	_expect(storms != null, "Test assertion failed")
	if storms == null or change_scene_to_file("res://Scenes/main.tscn") != OK:
		_finish()
		return
	await process_frame
	await process_frame
	var device_script := load("res://scripts/PowerDevice.gd")
	_expect(device_script != null, "Test assertion failed")
	if device_script == null:
		_finish()
		return
	var panel: Node2D = device_script.new() as Node2D
	panel.setup("solar_panel", Vector2i(80, 80), false)
	current_scene.add_child(panel)
	panel.global_position = Vector2(1288.0, 1288.0)
	await process_frame

	storms.call("force_storm_for_test")
	_expect(bool(storms.call("is_storm_active")), "Test assertion failed")
	_expect(is_equal_approx(float(storms.call("get_incident_rate_multiplier")), 2.5), "Test assertion failed")
	var player := current_scene.get_node("player") as Node2D
	player.global_position = Vector2(1288.0, 1288.0)
	var outdoor_effects: Dictionary = storms.call("get_active_outdoor_effects", player)
	_expect(bool(outdoor_effects.get("active", false)), "Test assertion failed")
	_expect(float(outdoor_effects.get("movement_multiplier", 1.0)) < 1.0, "Test assertion failed")
	_expect(float(outdoor_effects.get("oxygen_multiplier", 1.0)) > 1.0, "Test assertion failed")
	_expect(float(outdoor_effects.get("hunger_multiplier", 1.0)) > 1.0 and float(outdoor_effects.get("thirst_multiplier", 1.0)) > 1.0, "Test assertion failed")
	_expect(float(outdoor_effects.get("wind_chill_c", 0.0)) < 0.0, "Test assertion failed")
	var oxygen: Node = root.get_node("Oxygen")
	var hunger: Node = root.get_node("Hunger")
	var hydration: Node = root.get_node("Hydration")
	oxygen.oxygen = 100.0
	hunger.hunger = 100.0
	hydration.thirst = 100.0
	oxygen.call("_process", 1.0)
	hunger.call("_process", 1.0)
	hydration.call("_process", 1.0)
	_expect(float(oxygen.oxygen) < 99.7, "Test assertion failed")
	_expect(float(hunger.hunger) < 99.8 and float(hydration.thirst) < 99.7, "Test assertion failed")
	var shelter := BaseDome.new()
	shelter.setup("dome_small", 1, false)
	current_scene.add_child(shelter)
	shelter.global_position = Vector2(1448.0, 1288.0)
	await process_frame
	player.global_position = shelter.global_position
	var sheltered_effects: Dictionary = storms.call("get_active_outdoor_effects", player)
	_expect(not bool(sheltered_effects.get("active", true)), "Test assertion failed")
	_expect(is_equal_approx(float(sheltered_effects.get("movement_multiplier", 0.0)), 1.0), "Test assertion failed")
	var machine_panel := PanelContainer.new()
	machine_panel.name = "NearbyMachinePanel"
	machine_panel.add_to_group("machine_status_ui")
	machine_panel.visible = true
	current_scene.add_child(machine_panel)
	storms.call("_update_weather_ui")
	var weather_panel := storms.get("_weather_panel") as Control
	_expect(weather_panel != null and is_equal_approx(weather_panel.offset_left, 16.0) and is_equal_approx(weather_panel.offset_top, 282.0), "Test assertion failed")
	machine_panel.queue_free()
	shelter.queue_free()
	storms.call("force_deposit_for_test", panel)
	_expect(int(panel.call("get_sand_accumulation")) == 1, "Test assertion failed")
	_expect(is_equal_approx(float(panel.call("get_solar_output_multiplier")), 0.66), "Test assertion failed")
	_expect(bool(panel.call("toggle_solar_tarp")), "Test assertion failed")
	storms.call("force_deposit_for_test", panel)
	_expect(int(panel.call("get_sand_accumulation")) == 1, "Test assertion failed")
	_expect(is_equal_approx(float(panel.call("get_solar_output_multiplier")), 0.0), "Test assertion failed")
	panel.call("toggle_solar_tarp")
	panel.call("set_sand_accumulation", 3)
	_expect(is_equal_approx(float(panel.call("get_solar_output_multiplier")), 0.0), "Test assertion failed")

	panel.queue_free()
	storms.call("reset_for_new_mission")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SANDSTORM_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("SANDSTORM_SMOKE_FAIL: " + failure)
	quit(1)
