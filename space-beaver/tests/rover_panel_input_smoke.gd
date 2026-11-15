extends SceneTree


const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const ROVER_SCRIPT := preload("res://scripts/Rover.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("impossibile caricare la scena principale")
		return
	await process_frame
	await process_frame
	var player := current_scene.get_node("player") as Node2D
	var rover := ROVER_SCRIPT.new() as Rover
	current_scene.add_child(rover)
	rover.global_position = Vector2(12_000, 12_000)
	player.global_position = rover.global_position + Vector2(240.0, 0.0)
	await physics_frame
	_send_physical_key(KEY_F)
	await process_frame
	if rover.panel_state != Rover.PanelState.CLOSED:
		_fail("A distant rover opened its panels with F")
		return

	player.global_position = rover.global_position + Vector2(-36.0, 0.0)
	_send_physical_key(KEY_F)
	await process_frame
	if rover.panel_state == Rover.PanelState.CLOSED:
		_fail("F near the rover did not open its panels")
		return
	rover.panel_state = Rover.PanelState.CLOSED
	rover.animation_elapsed = 0.0

	var dome := DOME_SCRIPT.new() as BaseDome
	dome.setup("dome_medium", 1, false, {})
	current_scene.add_child(dome)
	dome.global_position = Vector2(13_000, 12_000)
	player.global_position = dome.get_corridor_center_position()
	dome.set("_airlock_path", "enter")
	dome.set("_first_door_crossed", true)
	dome.set("_outer_door_open", false)
	dome.set("_inner_door_open", false)
	await physics_frame
	_send_physical_key(KEY_F)
	await process_frame
	if not dome.is_sequence_active():
		_fail("F non ha raggiunto la sequenza della camera d'aria con rover lontano")
		return
	if rover.panel_state != Rover.PanelState.CLOSED:
		_fail("F della camera d'aria ha alterato i pannelli del rover remoto")
		return
	print("ROVER_PANEL_INPUT_SMOKE_OK")
	quit(0)


func _send_physical_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_NONE
	event.physical_keycode = keycode
	event.pressed = true
	get_root().get_viewport().push_input(event)


func _fail(reason: String) -> void:
	push_error("ROVER_PANEL_INPUT_SMOKE_FAIL: " + reason)
	quit(1)
