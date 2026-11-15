extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const PIPE_SCENE := preload("res://Scenes/pipe.tscn")


class FakeOxygenSource:
	extends Node2D
	var oxygen_flow_kg := 10.0

	func get_fluid_output_available_for_category(category: int) -> float:
		return oxygen_flow_kg if category == PipeSegment.Category.OXYGEN else 0.0

	func consume_fluid_resource_for_category(category: int, amount: float) -> float:
		if category != PipeSegment.Category.OXYGEN:
			return 0.0
		var supplied := minf(amount, oxygen_flow_kg)
		oxygen_flow_kg -= supplied
		return supplied

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var shop: Node = root.get_node("Shop")
	var pipe_manager: Node = root.get_node("PipeManager")
	for size_id in ["dome_small", "dome_medium", "dome_large"]:
		var definition: Dictionary = shop.call("get_definition", size_id)
		_expect(not definition.is_empty() and bool(definition.get("placeable", false)), "Test assertion failed")
		_expect(str(definition.get("category", "")) == "habitats", "Test assertion failed")
	_expect(shop.call("get_definition", "rover").is_empty(), "Test assertion failed")
	var shop_ui: Node = current_scene.get_node("ShopUI")
	shop.toggle()
	await process_frame
	var shop_tabs := shop_ui.get("catalog_view") as TabContainer
	_expect(shop_tabs != null and shop_tabs.get_tab_count() == 4, "Test assertion failed")
	if shop_tabs != null:
		_expect(shop_tabs.get_tab_title(0) == "SUITS", "Test assertion failed")
		_expect(not shop_tabs.get_tab_title(0).contains("VEICOLI"), "Test assertion failed")
	shop_ui.call("_select_or_purchase", "dome_small")
	await process_frame
	_expect(bool(shop_ui.get("dome_config_view").visible), "Test assertion failed")
	_expect(shop_ui.get("dome_config_image").texture == DOME_SCRIPT.EXTERIOR_TEXTURES["dome_small"], "Test assertion failed")
	_expect(bool(shop_ui.get("dome_rover_pad_checkbox").disabled), "Test assertion failed")
	shop_ui.call("_close_dome_config")
	var shop_viewport_size := root.get_viewport().get_visible_rect().size
	var shop_panel := shop_ui.get_child(0).get_child(0).get_child(0) as PanelContainer
	_expect(shop_panel != null and shop_panel.size.y <= shop_viewport_size.y, "Test assertion failed")
	_expect(shop_tabs != null and shop_tabs.visible and shop_tabs.size.y <= shop_viewport_size.y, "Test assertion failed")
	shop.close()

	var player := current_scene.get_node("player") as Node2D
	var original_player_position := player.global_position
	var preview := DOME_SCRIPT.new() as BaseDome
	preview.setup("dome_small", 1, true)
	current_scene.add_child(preview)
	preview.global_position = Vector2.ZERO
	await process_frame
	_expect(preview.get_node("DomeSprite").texture == DOME_SCRIPT.EXTERIOR_TEXTURES["dome_small"], "Test assertion failed")
	_expect(int(preview.get_node("DomeSprite").z_index) >= 0, "Test assertion failed")
	_expect(not preview.is_in_group("base_domes") and not preview.is_in_group("pressurized_interiors"), "Test assertion failed")
	preview.queue_free()
	for direction in 4:
		var oriented_preview := DOME_SCRIPT.new() as BaseDome
		oriented_preview.setup("dome_small", direction, true)
		current_scene.add_child(oriented_preview)
		var direction_name: String = DOME_SCRIPT.DIRECTION_NAMES[direction]
		var expected_sheet: Texture2D = DOME_SCRIPT.DOOR_CLOSE_SHEETS[direction_name]
		var outer_visual := oriented_preview.get_node("OuterDoor") as Sprite2D
		var oriented_frame := outer_visual.texture as AtlasTexture
		_expect(oriented_frame != null and oriented_frame.atlas == expected_sheet, "Test assertion failed")
		_expect(oriented_preview.get_node("AirlockCorridor").texture != null, "Test assertion failed")
		oriented_preview.queue_free()

	var dome_cell := Vector2i(620, 430)
	var dome_target := DOME_SCRIPT.world_position_for(dome_cell)
	player.global_position = dome_target
	_expect(not DOME_SCRIPT.can_place_at(dome_target, "dome_small", {}, 1), "Test assertion failed")
	player.global_position = original_player_position
	var blocking_rock := Node2D.new()
	blocking_rock.add_to_group("collectible_rocks")
	blocking_rock.global_position = dome_target
	current_scene.add_child(blocking_rock)
	_expect(not DOME_SCRIPT.can_place_at(dome_target, "dome_small", {}, 1), "Test assertion failed")
	blocking_rock.free()
	await process_frame
	_expect(DOME_SCRIPT.can_place_at(dome_target, "dome_small", {}, 1), "Test assertion failed")
	var dome := DOME_SCRIPT.place(current_scene, "dome_small", dome_cell, 1) as BaseDome
	_expect(dome != null, "Test assertion failed")
	if dome == null:
		_finish()
		return
	await process_frame
	_expect(dome.is_in_group("pressurized_interiors"), "Test assertion failed")
	var registered_oxygen_port := false
	for input_port in pipe_manager.get("fluid_inputs"):
		if input_port.get("node") == dome and int(input_port.get("category", -1)) == PipeSegment.Category.OXYGEN:
			registered_oxygen_port = true
	_expect(registered_oxygen_port, "Test assertion failed")
	_expect(dome.get_oxygen_input_cell() == Vector2i(floori((dome.global_position.x + dome.get_radius() + 8.0) / 16.0), floori(dome.global_position.y / 16.0)), "Test assertion failed")
	_expect(not DOME_SCRIPT.can_place_at(dome.global_position, "dome_small"), "Test assertion failed")
	_expect(dome.contains_world_point(dome.global_position), "Test assertion failed")
	var boundary := dome.get_node_or_null("DomeAndCorridorCollision") as StaticBody2D
	_expect(boundary != null and boundary.get_child_count() >= 60, "Test assertion failed")
	var outer_frame := dome.get_node("OuterDoor").texture as AtlasTexture
	var corridor_frame := dome.get_node("AirlockCorridor").texture as AtlasTexture
	var door_depth := outer_frame.region.size.y
	_expect(is_equal_approx(dome.get_node("AirlockCorridor").position.length() - corridor_frame.region.size.y * 0.5, dome.get_radius()), "Test assertion failed")
	_expect(is_equal_approx(dome.get_node("OuterDoor").position.length() + door_depth * 0.5, dome.get_radius() + corridor_frame.region.size.y), "Test assertion failed")
	_expect(not dome.is_in_corridor(dome.global_position + Vector2(0.0, dome.get_radius() + 16.0) + Vector2(30.0, 0.0)), "Test assertion failed")

	var temperature: Node = root.get_node("Temperature")
	var shelter: Dictionary = temperature.call("_get_shelter_at", dome.global_position)
	_expect(float(shelter.get("bonus_c", 0.0)) > 0.0 and float(shelter.get("bonus_c", 0.0)) < 45.0, "Test assertion failed")
	dome.set_powered(true)
	shelter = temperature.call("_get_shelter_at", dome.global_position)
	_expect(float(shelter.get("bonus_c", 0.0)) >= 45.0, "Test assertion failed")
	dome.set_powered(false)
	var oxygen: Node = root.get_node("Oxygen")
	var oxygen_connector := dome.get_node_or_null("OxygenPipeAttachment") as Sprite2D
	_expect(oxygen_connector != null and oxygen_connector.texture is AtlasTexture, "Test assertion failed")
	_expect(dome.get_node_or_null("HeaterPowerPortMarker") == null, "Test assertion failed")
	if oxygen_connector != null and oxygen_connector.texture is AtlasTexture:
		var connector_frame := oxygen_connector.texture as AtlasTexture
		_expect(connector_frame.atlas == preload("res://assets/sprites/machines/pipe-spritesheet.png") and connector_frame.region == Rect2(32.0, 0.0, 16.0, 16.0), "Test assertion failed")
	_expect(not dome.is_oxygen_connected(), "Test assertion failed")
	var saved_player_mask: int = player.collision_mask
	player.collision_mask = 1
	player.global_position = dome.get_corridor_center_position()
	_expect(not bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	player.global_position = dome.get_outer_door_position() + Vector2.DOWN * 26.0
	_expect(not bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	Input.action_press("move_up")
	for _frame in 8:
		await physics_frame
	Input.action_release("move_up")
	_expect((player.global_position - dome.global_position).y > dome.get_radius() + 24.0, "Test assertion failed")
	_expect(bool(dome.call("handle_airlock_key", player, KEY_E)), "Test assertion failed")
	_expect(not bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	await _wait_door()
	_expect(dome.is_door_open("outer"), "Test assertion failed")
	_expect(bool(dome.get_node("DomeAndCorridorCollision/OuterGate").disabled), "Test assertion failed")
	Input.action_press("move_up")
	for _frame in 48:
		await physics_frame
	Input.action_release("move_up")
	await process_frame
	await _wait_door()
	_expect((player.global_position - dome.global_position).y <= dome.get_radius() + 8.0, "Test assertion failed")
	_expect(not dome.is_door_open("outer"), "Test assertion failed")
	player.global_position = dome.get_corridor_center_position()
	Input.action_press("move_left")
	for _frame in 8:
		await physics_frame
	Input.action_release("move_left")
	_expect(absf(player.global_position.x - dome.global_position.x) < 10.0, "Test assertion failed")
	player.global_position = dome.get_corridor_center_position() - Vector2.DOWN * 10.0
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("outer"), "Test assertion failed")
	player.collision_mask = saved_player_mask
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	_expect(dome.is_sequence_active(), "Test assertion failed")
	_expect(not player.is_physics_processing(), "Test assertion failed")
	_expect(str(dome.call("get_prompt_for_player", player)).contains("WASD"), "Test assertion failed")
	_complete_sequence(dome, player)
	_expect(dome.is_sequence_complete(), "Test assertion failed")
	_expect(player.is_physics_processing(), "Test assertion failed")
	player.global_position = dome.get_inner_door_position()
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	await _wait_door()
	_expect(dome.is_door_open("inner"), "Test assertion failed")
	player.global_position = dome.global_position + Vector2.DOWN * (dome.get_radius() - 25.0)
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("inner"), "Test assertion failed")
	_expect(dome.contains_world_point(player.global_position), "Test assertion failed")
	player.global_position = dome.get_outer_door_position() + Vector2.DOWN * 26.0
	dome.oxygen_reserve = BaseDome.INITIAL_OXYGEN_UNITS
	var reserve_before_passive := dome.oxygen_reserve
	dome.call("_update_oxygen_reserve", 5.0)
	_expect(is_equal_approx(float(dome.oxygen_reserve), reserve_before_passive - BaseDome.OXYGEN_PASSIVE_LOSS_PER_SECOND * 5.0), "Test assertion failed")
	player.global_position = dome.global_position
	_expect(is_equal_approx(dome.get_oxygen_loss_rate(), BaseDome.OXYGEN_PASSIVE_LOSS_PER_SECOND + BaseDome.OXYGEN_OCCUPANT_LOSS_PER_SECOND), "Test assertion failed")
	var reserve_before_occupied := dome.oxygen_reserve
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(is_equal_approx(float(dome.oxygen_reserve), reserve_before_occupied - dome.get_oxygen_loss_rate() * 0.25), "Test assertion failed")
	oxygen.oxygen = 20.0
	oxygen.call("_process", 0.25)
	_expect(is_equal_approx(float(oxygen.oxygen), float(oxygen.max_oxygen)), "Test assertion failed")
	dome.oxygen_reserve = 0.0
	oxygen.oxygen = 20.0
	oxygen.call("_process", 0.25)
	_expect(float(oxygen.oxygen) < 20.0, "Test assertion failed")
	dome.oxygen_reserve = BaseDome.INITIAL_OXYGEN_UNITS
	dome.call("_process", 0.0)
	_expect(dome.get_node("DomeSprite").texture == DOME_SCRIPT.INTERIOR_TEXTURES["dome_small"], "Test assertion failed")

	player.global_position = dome.global_position + Vector2.DOWN * (dome.get_radius() - 25.0)
	_expect(bool(dome.call("handle_airlock_key", player, KEY_E)), "Test assertion failed")
	await _wait_door()
	player.global_position = dome.get_corridor_center_position()
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("inner"), "Test assertion failed")
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	_complete_sequence(dome, player)
	_expect(dome.is_sequence_complete(), "Test assertion failed")
	player.global_position = dome.get_outer_door_position()
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "Test assertion failed")
	await _wait_door()
	player.global_position = dome.get_outer_door_position() + Vector2.DOWN * 26.0
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("outer"), "Test assertion failed")
	oxygen.call("_process", 0.25)
	_expect(float(oxygen.oxygen) < float(oxygen.max_oxygen), "Test assertion failed")
	var port_cell: Vector2i = dome.get_oxygen_input_cell()
	var source_cell := port_cell + Vector2i.RIGHT
	var electrolyzer := FakeOxygenSource.new()
	current_scene.add_child(electrolyzer)
	var port_pipe := PIPE_SCENE.instantiate() as PipeSegment
	port_pipe.setup(port_cell, PipeSegment.ShapeType.STRAIGHT, false, PipeSegment.Category.OXYGEN)
	current_scene.add_child(port_pipe)
	port_pipe.global_position = pipe_manager.call("cell_to_world", port_cell)
	var source_pipe := PIPE_SCENE.instantiate() as PipeSegment
	source_pipe.setup(source_cell, PipeSegment.ShapeType.STRAIGHT, false, PipeSegment.Category.OXYGEN)
	current_scene.add_child(source_pipe)
	source_pipe.global_position = pipe_manager.call("cell_to_world", source_cell)
	var registered_pipes: Dictionary = pipe_manager.get("pipes")
	registered_pipes[port_cell] = port_pipe
	registered_pipes[source_cell] = source_pipe
	pipe_manager.call("register_fluid_source", electrolyzer, source_cell, PipeSegment.Category.OXYGEN, Vector2i.RIGHT)
	_expect(dome.is_oxygen_connected(), "Test assertion failed")
	player.global_position = dome.global_position
	dome.oxygen_reserve = 0.0
	electrolyzer.oxygen_flow_kg = 0.0
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(is_equal_approx(float(dome.oxygen_reserve), 0.0), "Test assertion failed")
	electrolyzer.oxygen_flow_kg = 10.0
	dome.oxygen_reserve = 179.2
	var reserve_before_recharge := dome.oxygen_reserve
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(float(dome.oxygen_reserve) > reserve_before_recharge, "Test assertion failed")
	dome.oxygen_reserve = 0.0
	oxygen.oxygen = 20.0
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(electrolyzer.oxygen_flow_kg < 10.0, "Test assertion failed")
	oxygen.call("_process", 0.25)
	_expect(is_equal_approx(float(oxygen.oxygen), float(oxygen.max_oxygen)), "Test assertion failed")
	_expect(dome.oxygen_reserve > 0.0, "Test assertion failed")
	_expect(bool(dome.call("handle_oxygen_port_right_click", oxygen_connector.global_position)), "Test assertion failed")
	_expect(str(dome.get("_dome_status_label").text).contains("Estimated endurance at current use") and str(dome.get("_dome_status_label").text).contains("Source(s)"), "Test assertion failed")
	pipe_manager.call("unregister_fluid_source", electrolyzer)
	registered_pipes.erase(port_cell)
	registered_pipes.erase(source_cell)
	port_pipe.queue_free()
	source_pipe.queue_free()
	electrolyzer.queue_free()

	root.get_node("Economy").call("reset_for_new_mission")
	_expect(bool(shop.call("purchase", "dome_small")), "Test assertion failed")
	_expect(int(root.get_node("DeliveryManager").call("count_uncollected", "dome_small")) > 0, "Test assertion failed")
	root.get_node("Economy").call("reset_for_new_mission")
	var configured_options := {"lead_shielding": true, "hydrogen_shielding": true, "rover_pad": true}
	_expect(int(shop.call("get_dome_total_price", "dome_medium", configured_options)) == 3_850_000_000, "Test assertion failed")
	shop.toggle()
	await process_frame
	shop_ui.call("_select_or_purchase", "dome_medium")
	await process_frame
	shop_ui.get("dome_lead_checkbox").button_pressed = true
	shop_ui.get("dome_hydrogen_checkbox").button_pressed = true
	shop_ui.get("dome_rover_pad_checkbox").button_pressed = true
	shop_ui.call("_refresh_dome_config_price")
	_expect(str(shop_ui.get("dome_config_total").text).contains(str(root.get_node("Economy").call("format_money", 3_850_000_000))), "Test assertion failed")
	shop_ui.call("_confirm_dome_purchase")
	var queued_configuration: Dictionary = {}
	for queued_item in root.get_node("DeliveryManager").get("pending_order").values():
		if str(queued_item.get("id", "")) == "dome_medium":
			queued_configuration = queued_item.get("configuration", {})
	_expect(queued_configuration == configured_options, "Test assertion failed")
	shop.close()
	var configured_capsule := DeliveryCapsule.new()
	configured_capsule.setup([{"id": "dome_medium", "name": "Configured Medium Dome", "count": 1, "placeable": true, "configuration": configured_options}], Vector2(11_000, 11_000))
	current_scene.add_child(configured_capsule)
	configured_capsule.set("state", DeliveryCapsule.State.LANDED)
	_expect(bool(configured_capsule.call("collect_all")), "Test assertion failed")
	var inventory: Node = root.get_node("Inventory")
	var delivered_configuration: Dictionary = {}
	for item in inventory.get("backpack"):
		if str(item.get("id", "")) == "dome_medium":
			delivered_configuration = item.get("configuration", {})
	_expect(delivered_configuration == configured_options, "Test assertion failed")
	var configured_dome := DOME_SCRIPT.new() as BaseDome
	configured_dome.setup("dome_medium", 1, false, configured_options)
	current_scene.add_child(configured_dome)
	configured_dome.global_position = Vector2(12_000, 12_000)
	await process_frame
	_expect(configured_dome.has_rover_charging_pad() and configured_dome.get_node_or_null("RoverChargingPad") != null, "Test assertion failed")
	var pad_area := configured_dome.get_node_or_null("RoverPadInteractionArea") as Area2D
	_expect(pad_area != null and pad_area.get_node_or_null("RoverPadHitbox") is CollisionShape2D, "Test assertion failed")
	var pad_body := configured_dome.get_node_or_null("RoverPadBody") as StaticBody2D
	_expect(pad_body != null and pad_body.get_node_or_null("RoverPadCollision") is CollisionShape2D and pad_body.collision_layer == 2, "Test assertion failed")
	player.global_position = configured_dome.global_position
	_expect(is_equal_approx(configured_dome.get_cosmic_radiation_protection(), 1.0 - 0.92 * 0.65), "Test assertion failed")
	_expect(is_equal_approx(configured_dome.get_solar_radiation_protection(), 1.0 - 0.75 * 0.88), "Test assertion failed")
	var radiation: Node = root.get_node("Radiation")
	_expect(is_equal_approx(float(radiation.call("_get_dome_radiation_protection", "get_cosmic_radiation_protection")), configured_dome.get_cosmic_radiation_protection()), "Test assertion failed")
	_expect(is_equal_approx(float(radiation.call("_get_dome_radiation_protection", "get_solar_radiation_protection")), configured_dome.get_solar_radiation_protection()), "Test assertion failed")
	player.global_position = configured_dome.get_rover_pad_position()
	for existing_rover in get_nodes_in_group("rovers"):
		existing_rover.queue_free()
	await process_frame
	root.get_node("Economy").call("add_funds", 5_000_000_000)
	var funds_before_rover_purchase := int(root.get_node("Economy").get("balance"))
	_expect(bool(configured_dome.call("_player_is_at_rover_pad", player)), "Test assertion failed")
	_expect(bool(configured_dome.call("handle_airlock_key", player, KEY_E)), "Test assertion failed")
	_expect(BaseDome.ROVER_PURCHASE_COST > BaseDome.ROVER_RECALL_COST, "Test assertion failed")
	_expect(int(root.get_node("Economy").get("balance")) == funds_before_rover_purchase - BaseDome.ROVER_PURCHASE_COST, "Test assertion failed")
	var rovers: Array = get_nodes_in_group("rovers")
	var base_rover := rovers.back() as Rover if not rovers.is_empty() else null
	await process_frame
	_expect(base_rover != null and configured_dome.is_rover_on_charging_pad(base_rover), "Test assertion failed")
	if base_rover != null:
		base_rover.facing_index = 3
		base_rover.sprite.visible = false
		configured_dome.call("_update_rover_pad_status")
		_expect(base_rover.z_index > int(configured_dome.get_node("RoverChargingPad").z_index), "Test assertion failed")
		_expect(base_rover.facing_index == 0 and base_rover.sprite.visible, "Test assertion failed")
		_expect(bool(configured_dome.get_node("RoverPadStatus").visible), "Test assertion failed")
		_expect(not bool(configured_dome.call("_handle_rover_pad_action", player)), "Test assertion failed")
		var board_event := InputEventKey.new()
		board_event.keycode = KEY_E
		board_event.pressed = true
		player.call("_input", board_event)
		_expect(bool(player.call("is_driving_rover")), "Test assertion failed")
		if bool(player.call("is_driving_rover")):
			base_rover.call("exit_rover")
	if base_rover != null:
		base_rover.battery_energy_kwh = 10.0
		configured_dome.set_powered(true)
		root.get_node("PowerGrid").get("connection_ok")[configured_dome] = true
		_expect(is_equal_approx(float(configured_dome.call("get_rover_pad_charge_rate_kw")), BaseDome.ROVER_PAD_CHARGE_KW), "Test assertion failed")
		base_rover.call("_charge_from_solar", 10.0)
		_expect(float(base_rover.battery_energy_kwh) > 10.0, "Test assertion failed")
		base_rover.global_position += Vector2(300.0, 0.0)
		player.global_position = configured_dome.get_rover_pad_position()
		var funds_before_recall := int(root.get_node("Economy").get("balance"))
		_expect(bool(configured_dome.call("handle_airlock_key", player, KEY_E)), "Test assertion failed")
		_expect(configured_dome.is_rover_on_charging_pad(base_rover), "Test assertion failed")
		_expect(int(root.get_node("Economy").get("balance")) == funds_before_recall - BaseDome.ROVER_RECALL_COST, "Test assertion failed")
	_finish()


func _complete_sequence(dome: BaseDome, player: Node2D) -> void:
	var keys: Array[int] = dome.get_sequence_keys()
	for keycode in keys:
		_expect(bool(dome.call("handle_airlock_key", player, keycode)), "Test assertion failed")


func _wait_door() -> void:
	await create_timer(0.55).timeout
	await process_frame


func _finish() -> void:
	if failures.is_empty():
		print("BASE_DOME_SMOKE_OK")
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
