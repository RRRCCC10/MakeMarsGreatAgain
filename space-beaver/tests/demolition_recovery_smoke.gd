extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")

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
	var inventory := root.get_node("Inventory")
	inventory.reset_for_new_mission()
	var player := current_scene.get_node("player") as Node2D
	player.global_position = Vector2(-4_000.0, -4_000.0)
	var dome := DOME_SCRIPT.new() as BaseDome
	dome.setup("dome_medium", 1, false, {"lead_shielding": true})
	current_scene.add_child(dome)
	dome.global_position = Vector2(700.0 * 16.0 + 8.0, 430.0 * 16.0 + 8.0)
	await process_frame
	await process_frame
	var rover := Node2D.new()
	rover.name = "RoverDaConservare"
	dome.add_child(rover)
	rover.add_to_group("rovers")
	rover.position = Vector2(22.0, -14.0)
	var rover_position := rover.global_position
	_expect(bool(dome.call("_destroy")), "Test assertion failed")
	_expect(inventory.count_item("dome_medium") == 1, "Test assertion failed")
	await process_frame
	_expect(is_instance_valid(rover) and rover.get_parent() == current_scene, "Test assertion failed")
	_expect(is_instance_valid(rover) and rover.global_position.distance_to(rover_position) < 0.01, "Test assertion failed")
	if is_instance_valid(rover):
		rover.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DEMOLITION_RECOVERY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DEMOLITION_RECOVERY_SMOKE_FAIL: " + failure)
	quit(1)
