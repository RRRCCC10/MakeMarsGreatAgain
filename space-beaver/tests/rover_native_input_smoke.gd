extends SceneTree


const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const ROVER_SCRIPT := preload("res://scripts/Rover.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Unable to load the main scene")
		return
	await process_frame
	await process_frame
	var player := current_scene.get_node("player") as Node2D
	var dome := DOME_SCRIPT.new() as BaseDome
	dome.setup("dome_medium", 1, false, {"rover_pad": true})
	current_scene.add_child(dome)
	dome.global_position = Vector2(12_000, 12_000)
	await process_frame
	var rover := ROVER_SCRIPT.new() as Rover
	current_scene.add_child(rover)
	rover.global_position = dome.call("_get_rover_parking_position")
	player.global_position = rover.global_position + Vector2(-38.0, 0.0)
	await physics_frame
	for candidate in get_nodes_in_group("rovers"):
		if bool(candidate.get("is_preview")):
			_fail("an invisible preview remained in the real rover group")
			return
	if not rover.can_board(player):
		_fail("the test position cannot board the rover")
		return
	var press_e := InputEventKey.new()
	press_e.keycode = KEY_NONE
	press_e.physical_keycode = KEY_E
	press_e.pressed = true
	var router := root.get_node_or_null("RoverInteraction")
	if router != null:
		router.set_process_input(false)
	Input.parse_input_event(press_e)
	await process_frame
	await physics_frame
	var release_e := InputEventKey.new()
	release_e.keycode = KEY_E
	release_e.physical_keycode = KEY_E
	release_e.pressed = false
	Input.parse_input_event(release_e)
	if router != null:
		router.set_process_input(true)
	if not bool(player.call("is_driving_rover")) or rover.driver != player:
		_fail("the native E event did not board the player")
		return
	rover.exit_rover()
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	rover.call("_on_boarding_click", get_root().get_viewport(), click_event, 0)
	if not bool(player.call("is_driving_rover")) or rover.driver != player:
		_fail("clicking the rover near the player did not board the player")
		return
	print("ROVER_NATIVE_INPUT_SMOKE_OK")
	quit(0)


func _fail(reason: String) -> void:
	push_error("ROVER_NATIVE_INPUT_SMOKE_FAIL: " + reason)
	quit(1)
