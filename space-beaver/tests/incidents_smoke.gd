extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var incidents := root.get_node_or_null("IncidentManager")
	if incidents == null:
		_fail("IncidentManager deve essere registrato come autoload")
		_finish()
		return
	incidents.call("set_random_incidents_enabled_for_test", false)
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var player := get_first_node_in_group("player") as Node2D
	_expect(player != null, "Test assertion failed")
	if player == null:
		_finish()
		return
	var power_device_script := load("res://scripts/PowerDevice.gd")
	var base_dome_script := load("res://scripts/BaseDome.gd")
	var research_machine_script := load("res://scripts/ResearchMachine.gd")
	_expect(power_device_script != null and base_dome_script != null and research_machine_script != null, "Test assertion failed")
	if power_device_script == null or base_dome_script == null or research_machine_script == null:
		_finish()
		return
	var device: Node2D = power_device_script.new() as Node2D
	device.setup("solar_panel", Vector2i(56, 56), false)
	current_scene.add_child(device)
	device.global_position = Vector2(904.0, 904.0)
	await process_frame
	_expect(bool(incidents.call("force_incident", device, "machine")), "Test assertion failed")
	_expect(not bool(device.call("is_incident_operational")), "Test assertion failed")
	_expect(device.get_node_or_null("IncidentWarning") != null, "Test assertion failed")
	player.global_position = device.global_position
	_expect(bool(incidents.call("begin_nearby_repair", player)), "Test assertion failed")
	var sequence: Array = incidents.call("get_repair_sequence_for_test")
	_expect(sequence.size() >= 3 and sequence.size() <= 7, "Test assertion failed")
	for keycode in sequence:
		incidents.call("handle_repair_key", keycode)
	_expect(bool(device.call("is_incident_operational")), "Test assertion failed")
	var warning := device.get_node_or_null("IncidentWarning") as CanvasItem
	_expect(warning == null or not warning.visible, "Test assertion failed")

	var dome: Node2D = base_dome_script.new() as Node2D
	dome.setup("dome_small", 1, false)
	current_scene.add_child(dome)
	dome.global_position = Vector2(1200.0, 904.0)
	await process_frame
	_expect(bool(incidents.call("force_incident", dome, "outer_door")), "Test assertion failed")
	_expect(bool(dome.call("is_incident_faulted", "outer_door")), "Test assertion failed")
	player.global_position = dome.call("get_outer_door_position")
	_expect(bool(incidents.call("begin_nearby_repair", player)), "Test assertion failed")
	for keycode in Array(incidents.call("get_repair_sequence_for_test")):
		incidents.call("handle_repair_key", keycode)
	_expect(not bool(dome.call("is_incident_faulted", "outer_door")), "Test assertion failed")

	var lab: Node2D = research_machine_script.new() as Node2D
	lab.setup("xrd_diffractometer", true)
	current_scene.add_child(lab)
	await process_frame
	_expect(not bool(incidents.call("force_incident", lab, "machine")), "Test assertion failed")
	lab.queue_free()
	device.queue_free()
	dome.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	var incidents := root.get_node_or_null("IncidentManager")
	if incidents != null:
		incidents.call("reset_for_new_mission")
		incidents.call("set_random_incidents_enabled_for_test", true)
	if failures.is_empty():
		print("INCIDENTS_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("INCIDENTS_SMOKE_FAIL: " + failure)
	quit(1)
