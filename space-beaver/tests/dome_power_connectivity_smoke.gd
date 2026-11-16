extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const RESEARCH_SCRIPT := preload("res://scripts/ResearchMachine.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Unable to load the main scene")
		_finish()
		return
	await process_frame
	await process_frame
	var grid := root.get_node("PowerGrid")
	var player := current_scene.get_node("player") as Node2D
	grid.reset_for_new_mission()
	player.global_position = Vector2(-8_000.0, -8_000.0)
	var dome := DOME_SCRIPT.new() as BaseDome
	dome.setup("dome_large", 1, false, {})
	current_scene.add_child(dome)
	dome.global_position = DOME_SCRIPT.world_position_for(Vector2i(620, 430))
	await process_frame
	await process_frame
	var research_cell := Vector2i(floori((dome.global_position.x - 8.0) / 16.0), floori((dome.global_position.y - 32.0) / 16.0))
	var lab := RESEARCH_SCRIPT.place(current_scene, "xrd_diffractometer", research_cell) as ResearchMachine
	_expect(lab != null, "Test assertion failed")
	if lab == null:
		_finish()
		return
	await process_frame
	var connector := dome.get_power_connection_cell()
	var panel = grid.place_device(current_scene, "solar_panel", connector + Vector2i(-20, 0))
	var transformer = grid.place_device(current_scene, "transformer", connector + Vector2i(-14, 0))
	var battery = grid.place_device(current_scene, "battery", connector + Vector2i(-7, 0))
	_expect(panel != null and transformer != null and battery != null, "Test assertion failed")
	if panel == null or transformer == null or battery == null:
		_finish()
		return
	for device in [panel, transformer, battery]:
		device.set_network_enabled(true)
	grid.rebuild_network()
	var clock := root.get_node("WorldClock")
	clock.running = true
	clock.set_game_hour(12.0)
	grid._update_energy(0.1)
	_expect(bool(grid.connection_ok.get(dome, false)), "Test assertion failed")
	_expect(bool(grid.connection_ok.get(lab, false)), "Test assertion failed")
	_expect(dome.powered and lab.powered, "Test assertion failed")
	clock.running = false
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DOME_POWER_CONNECTIVITY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DOME_POWER_CONNECTIVITY_SMOKE_FAIL: " + failure)
	quit(1)
