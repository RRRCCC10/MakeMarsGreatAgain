extends SceneTree


const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const ROVER_SCRIPT := preload("res://scripts/Rover.gd")


class FakeStockMachine:
	extends Node
	var taken := false

	func get_stock_items() -> Array:
		return [{"name": "Test output", "count": 1}]

	func take_stock_item(_index: int) -> Dictionary:
		taken = true
		return {"name": "Test output", "count": 1}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		push_error("ROVER_DOCK_INPUT_SMOKE_FAIL: Unable to load the main scene")
		quit(1)
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
	var stock_machine := FakeStockMachine.new()
	current_scene.add_child(stock_machine)
	var machine_handler := player.get_node("Node")
	machine_handler.set("nearby_machine", stock_machine)
	var press_e := InputEventKey.new()
	press_e.keycode = KEY_E
	press_e.pressed = true
	get_root().get_viewport().push_input(press_e)
	await process_frame
	if not bool(player.call("is_driving_rover")) or rover.driver != player:
		push_error("ROVER_DOCK_INPUT_SMOKE_FAIL: E did not board the player onto the docked rover")
		quit(1)
		return
	if stock_machine.taken:
		push_error("ROVER_DOCK_INPUT_SMOKE_FAIL: a nearby machine intercepted E before the rover")
		quit(1)
		return
	print("ROVER_DOCK_INPUT_SMOKE_OK")
	quit()
