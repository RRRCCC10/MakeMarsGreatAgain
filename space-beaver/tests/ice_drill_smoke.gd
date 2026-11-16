extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var power_grid: Node = root.get_node("PowerGrid")
	var pipe_manager: Node = root.get_node("PipeManager")
	var clock: Node = root.get_node("WorldClock")
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Unable to load the main scene: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var main_scene: Node = current_scene
	var panel = power_grid.place_device(main_scene, "solar_panel", Vector2i(-8, 6))
	var transformer = power_grid.place_device(main_scene, "transformer", Vector2i(-2, 6))
	var battery = power_grid.place_device(main_scene, "battery", Vector2i(4, 6))
	var drill = power_grid.place_device(main_scene, "ice_drill", Vector2i(10, 6))
	_expect(drill != null, "Test assertion failed")
	if drill == null:
		_finish()
		return
	_expect(not panel.is_network_enabled() and not transformer.is_network_enabled() and not battery.is_network_enabled() and not drill.is_network_enabled(), "Test assertion failed")
	panel.set_network_enabled(true)
	transformer.set_network_enabled(true)
	battery.set_network_enabled(true)
	drill.set_network_enabled(true)
	var output_cell := Vector2i(12, 6)
	var pipe = pipe_manager.place_pipe(main_scene, output_cell, 0, false)
	_expect(pipe != null, "Test assertion failed")
	_expect(pipe != null and pipe.category == 2, "Test assertion failed")
	_expect(pipe_manager.is_source_connected(drill), "Test assertion failed")

	clock.running = true
	clock.time_scale = 1.0
	clock.set_game_hour(12.0)
	power_grid.battery_energy_kwh = 100.0
	power_grid.rebuild_network()
	power_grid._update_energy(1.0)
	_expect(is_equal_approx(power_grid.demand_kw, 60.0), "Test assertion failed")
	_expect(drill.powered, "Test assertion failed")
	var frame_before: int = int(drill.animation_frame)
	drill._process(20.0)
	_expect(drill.animation_frame != frame_before, "Test assertion failed")
	_expect(drill.water_extracted_liters >= 79.9, "Test assertion failed")
	_expect(drill.water_transported_liters >= 79.9, "Test assertion failed")
	var specs: Dictionary = drill.get_machine_specs()
	_expect(str(specs.get("title", "")).contains("ICE EXTRACTION DRILL"), "Test assertion failed")
	var registry: Node = root.get_node("BuildableRegistry")
	var builder: Node = main_scene.get_node("player/Node")
	var player: Node2D = main_scene.get_node("player")
	player.global_position = drill.global_position
	builder.call("_update_nearby_machine_ui")
	_expect(builder.nearby_machine == drill, "Test assertion failed")
	_expect(builder.nearby_machine_root.visible, "Test assertion failed")
	builder.call("_toggle_nearby_network")
	_expect(not drill.is_network_enabled(), "Test assertion failed")
	_expect(not bool(power_grid.connection_ok.get(drill, false)), "Test assertion failed")
	builder.call("_toggle_nearby_network")
	_expect(drill.is_network_enabled(), "Test assertion failed")
	_expect(bool(power_grid.connection_ok.get(drill, false)), "Test assertion failed")
	power_grid._update_energy(0.0)
	var inventory: Node = root.get_node("Inventory")
	inventory.call("select_hotbar", 3)
	var bottle: Dictionary = inventory.call("get_selected_item")
	bottle["liters"] = 0.3
	builder.call("_update_nearby_machine_ui")
	_expect(not builder.nearby_machine_root.visible, "Test assertion failed")
	var inventory_ui: Node = main_scene.get_node_or_null("InventoryUI")
	if inventory_ui != null:
		inventory_ui.call("_process", 0.0)
		_expect(str(inventory_ui.pickup_label.text).begins_with("E · REFILL WATER BOTTLE"), "Test assertion failed")
	else:
		_expect(false, "Test assertion failed")
	var water_before_refill := float(drill.water_storage_liters)
	var refill_event := InputEventKey.new()
	refill_event.keycode = KEY_E
	refill_event.pressed = true
	player.call("_unhandled_input", refill_event)
	_expect(is_equal_approx(float(bottle.get("liters", 0.0)), 2.0), "Test assertion failed")
	_expect(float(drill.water_storage_liters) < water_before_refill, "Test assertion failed")
	bottle["liters"] = 0.3
	drill.set_network_enabled(false)
	var reserve_before_unpowered_refill := float(drill.water_storage_liters)
	_expect(str(drill.get_bottle_refill_prompt()).begins_with("E · REFILL WATER BOTTLE"), "Test assertion failed")
	_expect(drill.try_refill_selected_bottle(player), "Test assertion failed")
	_expect(is_equal_approx(float(bottle.get("liters", 0.0)), 2.0) and float(drill.water_storage_liters) < reserve_before_unpowered_refill, "Test assertion failed")
	var drill_entry: Dictionary = registry.find_at(drill.global_position)
	builder.call("_show_machine_info", drill_entry)
	_expect(registry.is_modal_open, "Test assertion failed")
	_expect(builder.machine_info_root.visible, "Test assertion failed")
	_expect(builder.machine_title.text.contains("ICE EXTRACTION DRILL"), "Test assertion failed")
	builder.call("_close_machine_info")
	clock.running = false
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("ICE_DRILL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		var stack := get_stack()
		var line := int(stack[1].get("line", -1)) if stack.size() > 1 else -1
		failures.append("%s at line %d" % [message, line])
