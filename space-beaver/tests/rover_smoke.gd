extends SceneTree

const ROVER_SCRIPT := preload("res://scripts/Rover.gd")
const ROCK_SCENE := preload("res://Scenes/rock.tscn")
const DRIVER_RIGHT_SHEET := preload("res://assets/sprites/rover/rover_driver_right.png")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var player := current_scene.get_node("player") as Node2D
	var map_ui: Node = current_scene.get_node("WorldMapUI")
	var inventory: Node = root.get_node("Inventory")
	var rover := ROVER_SCRIPT.place(current_scene, Vector2i(600, 400)) as Rover
	_expect(rover != null, "Test assertion failed")
	if rover == null:
		_finish()
		return
	await process_frame
	_expect(rover.is_in_group("rovers"), "Test assertion failed")
	var registry: Node = root.get_node("BuildableRegistry")
	_expect(registry.call("find_at", rover.global_position).get("node") == rover, "Test assertion failed")
	_expect(map_ui.call("get_structure_map_markers").any(func(marker): return marker.get("node") == rover), "Test assertion failed")
	var shop: Node = root.get_node("Shop")
	_expect(shop.call("get_definition", "rover").is_empty() and not bool(shop.call("purchase", "rover")), "Test assertion failed")

	player.global_position = rover.global_position + Vector2(20.0, 0.0)
	_expect(rover.can_board(player), "Test assertion failed")
	_expect(rover.board(player), "Test assertion failed")
	_expect(player.call("is_driving_rover"), "Test assertion failed")
	_expect(not rover.toggle_panels(), "Test assertion failed")
	var rock := ROCK_SCENE.instantiate() as Node2D
	current_scene.add_child(rock)
	rock.global_position = rover.global_position + Vector2(40.0, 0.0)
	await process_frame
	var rock_body := rock.get_node("StaticBody2D") as StaticBody2D
	_expect(rock_body.collision_layer == 2 and (rover.collision_mask & 2) == 0, "Test assertion failed")
	var position_before_drive := rover.global_position
	Input.action_press("move_right")
	rover.call("_physics_process", 0.20)
	Input.action_release("move_right")
	_expect(rover.global_position.x > position_before_drive.x + 8.0, "Test assertion failed")
	var rover_frame := rover.sprite.texture as AtlasTexture
	_expect(rover_frame != null and rover_frame.atlas == DRIVER_RIGHT_SHEET, "Test assertion failed")
	var inventory_before_pickup: int = int(inventory.call("count_item", "rock_red_regolith"))
	var pickup_event := InputEventKey.new()
	pickup_event.keycode = KEY_E
	pickup_event.pressed = true
	player.call("_unhandled_input", pickup_event)
	_expect(int(inventory.call("count_item", "rock_red_regolith")) == inventory_before_pickup, "Test assertion failed")
	var battery_before_drive := rover.battery_energy_kwh
	rover.call("_consume_driving_energy", 20.0)
	_expect(rover.battery_energy_kwh < battery_before_drive, "Test assertion failed")
	_expect(rover.exit_rover(), "Test assertion failed")
	_expect(not player.call("is_driving_rover"), "Test assertion failed")

	root.get_node("WorldClock").call("set_game_hour", 12.0)
	var battery_before_charge := rover.battery_energy_kwh
	_expect(rover.toggle_panels(), "Test assertion failed")
	rover.call("_update_panel_animation", 0.0)
	var panel_frame := rover.sprite.texture as AtlasTexture
	_expect(panel_frame != null and panel_frame.region.size == Vector2(80.0, 32.0), "Test assertion failed")
	rover.call("_update_panel_animation", 1.0)
	_expect(rover.is_panels_open(), "Test assertion failed")
	rover.call("_charge_from_solar", 20.0)
	_expect(rover.battery_energy_kwh > battery_before_charge, "Test assertion failed")
	rover.toggle_panels()
	rover.call("_update_panel_animation", 1.0)
	_expect(not rover.is_panels_open(), "Test assertion failed")
	_expect(rover.get_machine_specs().get("title", "").contains("ROVER"), "Test assertion failed")
	rover.battery_energy_kwh = 31.25
	_expect(rover.pickup(), "Test assertion failed")
	await process_frame
	var rover_backpack_index := -1
	for index in inventory.backpack.size():
		if str(inventory.backpack[index].get("id", "")) == "rover":
			rover_backpack_index = index
			break
	_expect(rover_backpack_index >= 0, "Test assertion failed")
	if rover_backpack_index >= 0:
		inventory.call("select_backpack", rover_backpack_index)
		inventory.call("move_selected_to_hotbar", 1)
		inventory.call("select_hotbar", 1)
		var stored_battery := float(inventory.call("peek_selected_rover_battery"))
		_expect(is_equal_approx(stored_battery, 31.25), "Test assertion failed")
		var redeployed := ROVER_SCRIPT.place(current_scene, Vector2i(700, 400), stored_battery) as Rover
		_expect(redeployed != null and is_equal_approx(redeployed.battery_energy_kwh, 31.25), "Test assertion failed")
		if redeployed != null:
			inventory.call("consume_selected_item")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ROVER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
