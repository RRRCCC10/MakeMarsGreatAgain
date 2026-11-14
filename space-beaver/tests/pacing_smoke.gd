extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var player := get_first_node_in_group("player") as CharacterBody2D
	_expect(player != null, "La scena principale deve avere un player")
	if player != null:
		_expect(is_equal_approx(float(player.get("SPEED")), 64.0), "Il player deve usare la velocità di progetto di 64 px/s")
		player.collision_mask = 0
		player.global_position = Vector2.ZERO
		var start_position := player.global_position
		Input.action_press("move_right")
		for _frame in 60:
			await physics_frame
		Input.action_release("move_right")
		var travelled := player.global_position.distance_to(start_position)
		_expect(travelled > 57.0 and travelled < 71.0, "Un secondo di fisica deve spostare il player di circa 64 px, indipendentemente dagli FPS")

	var clock := root.get_node_or_null("WorldClock")
	var hunger := root.get_node_or_null("Hunger")
	var hydration := root.get_node_or_null("Hydration")
	_expect(clock != null and hunger != null and hydration != null, "I manager di ritmo devono essere autoload disponibili")
	if clock != null and hunger != null and hydration != null:
		clock.call("reset_for_new_mission")
		_expect(is_equal_approx(float(clock.call("get_game_hours_for_real_delta", 1.0)), 0.05), "Il clock deve avanzare 0,05 ore di gioco per secondo reale")
		_expect(is_equal_approx(float(clock.call("get_game_hours_for_real_delta", 480.0)), 24.0), "Un sol deve durare 8 minuti reali")
		hunger.call("reset_for_new_mission")
		hydration.call("reset_for_new_mission")
		hunger.call("_process", 10.0)
		hydration.call("_process", 10.0)
		_expect(is_equal_approx(float(hunger.get("hunger")), 98.0), "La fame deve perdere 0,20 al secondo reale")
		_expect(is_equal_approx(float(hydration.get("thirst")), 97.0), "La sete deve perdere 0,30 al secondo reale")

	var power_device_script := load("res://scripts/PowerDevice.gd")
	_expect(power_device_script != null, "PowerDevice deve caricarsi dopo gli autoload")
	if power_device_script == null:
		_finish()
		return
	var drill: Node2D = power_device_script.new() as Node2D
	drill.setup("ice_drill", Vector2i(80, 80), false)
	current_scene.add_child(drill)
	drill.set_power_state(true)
	drill._process(20.0)
	_expect(is_equal_approx(drill.water_extracted_liters, 40.0), "La trivella deve produrre 40 L per ora di gioco, quindi 40 L in 20 secondi reali")
	drill.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	Input.action_release("move_right")
	if failures.is_empty():
		print("PACING_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("PACING_SMOKE_FAIL: " + failure)
	quit(1)
