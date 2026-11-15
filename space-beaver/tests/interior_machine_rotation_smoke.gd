extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const RESEARCH_SCRIPT := preload("res://scripts/ResearchMachine.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var achievements := root.get_node_or_null("AchievementManager")
	if achievements != null:
		achievements.call("set_persistence_enabled_for_test", false)
	var player := current_scene.get_node("player") as Node2D
	var power_grid := root.get_node_or_null("PowerGrid")
	var dome := DOME_SCRIPT.place(current_scene, "dome_large", Vector2i(620, 430), 1) as BaseDome
	_expect(dome != null, "Test assertion failed")
	if dome == null:
		_finish()
		return
	await process_frame
	player.global_position = dome.global_position + Vector2(300.0, 0.0)
	var center_cell := Vector2i(floori(dome.global_position.x / 16.0), floori(dome.global_position.y / 16.0))
	var lab_cell := center_cell + Vector2i(-3, -2)
	var lab_position := RESEARCH_SCRIPT.world_position_for("xrd_diffractometer", lab_cell, 1)
	_expect(RESEARCH_SCRIPT.can_place_at("xrd_diffractometer", lab_position, 1), "Test assertion failed")
	var lab := RESEARCH_SCRIPT.place(current_scene, "xrd_diffractometer", lab_cell, 1) as ResearchMachine
	_expect(lab != null and lab.placement_rotation == 1 and is_equal_approx(lab.rotation, PI * 0.5), "Test assertion failed")
	_expect(lab != null and lab.get_footprint_rect().size == Vector2(16.0, 32.0), "Test assertion failed")
	var process_cell := center_cell + Vector2i(4, -2)
	_expect(power_grid != null and bool(power_grid.call("can_place_process_machine", "electrolyzer", process_cell, 1)), "Test assertion failed")
	var process_machine = power_grid.call("place_process_machine", current_scene, "electrolyzer", process_cell, 1) if power_grid != null else null
	_expect(process_machine != null and int(process_machine.get("placement_rotation")) == 1 and is_equal_approx(float(process_machine.get("rotation")), PI * 0.5), "Test assertion failed")
	_expect(process_machine != null and Vector2i(process_machine.call("get_water_input_cell")) != process_cell + Vector2i.LEFT + Vector2i.DOWN, "Test assertion failed")
	var drill_cell := center_cell + Vector2i(8, 3)
	_expect(power_grid != null and bool(power_grid.call("can_place_device", "ice_drill", drill_cell, 1)), "Test assertion failed")
	var drill = power_grid.call("place_device", current_scene, "ice_drill", drill_cell, 1) if power_grid != null else null
	_expect(drill != null and int(drill.get("placement_rotation")) == 1 and is_equal_approx(float(drill.get("rotation")), PI * 0.5), "Test assertion failed")
	_expect(drill != null and Vector2i(drill.call("get_fluid_output_cell")) != drill_cell + Vector2i(2, 0), "Test assertion failed")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("INTERIOR_MACHINE_ROTATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("INTERIOR_MACHINE_ROTATION_SMOKE_FAIL: " + failure)
	quit(1)
