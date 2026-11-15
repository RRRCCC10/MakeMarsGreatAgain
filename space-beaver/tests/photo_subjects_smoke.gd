extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const GREENHOUSE_SCRIPT := preload("res://scripts/Greenhouse.gd")

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
	var player := current_scene.get_node("player") as Node2D
	var camera := root.get_node("FieldCamera")
	var achievements := root.get_node("AchievementManager")
	var inventory := root.get_node("Inventory")
	var test_position := Vector2(14_000.0, 14_000.0)
	player.global_position = test_position
	
	achievements.call("reset_for_new_mission")
	achievements.call("record", "first_base")
	achievements.call("record", "first_photo")
	var dome := DOME_SCRIPT.new() as BaseDome
	dome.setup("dome_small", 1, false, {})
	current_scene.add_child(dome)
	dome.global_position = test_position + Vector2(80.0, 0.0)
	await process_frame
	var dome_photo: Dictionary = camera.call("_build_photo_context")
	_expect("base" in Array(dome_photo.get("tags", [])), "Test assertion failed")
	achievements.call("record_photo_transmission", dome_photo)
	_expect(int(achievements.call("get_progress", "outpost_portrait")) == 1, "Test assertion failed")
	dome.queue_free()
	await process_frame

	achievements.call("record", "greenhouse")
	var greenhouse := GREENHOUSE_SCRIPT.new() as Greenhouse
	greenhouse.setup_greenhouse(1, false)
	current_scene.add_child(greenhouse)
	greenhouse.global_position = test_position + Vector2(90.0, 0.0)
	await process_frame
	var greenhouse_photo: Dictionary = camera.call("_build_photo_context")
	_expect("greenhouse" in Array(greenhouse_photo.get("tags", [])), "Test assertion failed")
	achievements.call("record_photo_transmission", greenhouse_photo)
	_expect(int(achievements.call("get_progress", "greenhouse_window")) == 1, "Test assertion failed")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PHOTO_SUBJECTS_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("PHOTO_SUBJECTS_SMOKE_FAIL: " + failure)
	quit(1)
