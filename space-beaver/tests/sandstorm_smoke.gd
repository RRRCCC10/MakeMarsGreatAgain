extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var storms := root.get_node_or_null("SandstormManager")
	_expect(storms != null, "SandstormManager deve essere un autoload")
	if storms == null or change_scene_to_file("res://Scenes/main.tscn") != OK:
		_finish()
		return
	await process_frame
	await process_frame
	var device_script := load("res://scripts/PowerDevice.gd")
	_expect(device_script != null, "PowerDevice deve caricarsi dopo gli autoload")
	if device_script == null:
		_finish()
		return
	var panel: Node2D = device_script.new() as Node2D
	panel.setup("solar_panel", Vector2i(80, 80), false)
	current_scene.add_child(panel)
	panel.global_position = Vector2(1288.0, 1288.0)
	await process_frame

	storms.call("force_storm_for_test")
	_expect(bool(storms.call("is_storm_active")), "Una tempesta deve poter iniziare sia con il clock diurno sia notturno")
	_expect(is_equal_approx(float(storms.call("get_incident_rate_multiplier")), 7.0), "La tempesta deve aumentare il rischio di guasto")
	storms.call("force_deposit_for_test", panel)
	_expect(int(panel.call("get_sand_accumulation")) == 1, "La tempesta deve sporcare il pannello al primo accumulo")
	_expect(is_equal_approx(float(panel.call("get_solar_output_multiplier")), 0.66), "Un pannello sporco deve produrre meno energia")
	_expect(bool(panel.call("toggle_solar_tarp")), "T deve poter installare il telo protettivo")
	storms.call("force_deposit_for_test", panel)
	_expect(int(panel.call("get_sand_accumulation")) == 1, "Il telo deve impedire nuovo accumulo di sabbia")
	_expect(is_equal_approx(float(panel.call("get_solar_output_multiplier")), 0.0), "Il telo deve sospendere la produzione mentre protegge il pannello")
	panel.call("toggle_solar_tarp")
	panel.call("set_sand_accumulation", 3)
	_expect(is_equal_approx(float(panel.call("get_solar_output_multiplier")), 0.0), "Un pannello sepolto deve fermare la produzione")

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
