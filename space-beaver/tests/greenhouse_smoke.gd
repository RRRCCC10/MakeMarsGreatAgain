extends SceneTree

const GREENHOUSE_SCRIPT := preload("res://scripts/Greenhouse.gd")
const PIPE_SCENE := preload("res://Scenes/pipe.tscn")
const TRANSPARENCY := preload("res://scripts/TextureTransparency.gd")
const GREENHOUSE_SOURCE := preload("res://assets/sprites/greenhouse/greenhouse_base.jpg")
const POTATO_SOURCE := preload("res://assets/sprites/greenhouse/potato_first_cycle.jpg")


class FakeWaterSource:
	extends Node2D
	var available_liters := 10_000.0

	func consume_fluid_resource_for_category(category: int, amount: float) -> float:
		if category != PipeSegment.Category.WATER:
			return 0.0
		var supplied := minf(maxf(0.0, amount), available_liters)
		available_liters -= supplied
		return supplied

	func get_fluid_output_available_for_category(category: int) -> float:
		return available_liters if category == PipeSegment.Category.WATER else 0.0

	func get_display_name() -> String:
		return "Test water source"


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
	var player := current_scene.get_node("player") as Node2D
	var inventory := root.get_node("Inventory")
	var shop_ui := current_scene.get_node("ShopUI")
	var inventory_ui := current_scene.get_node("InventoryUI")
	var greenhouse := GREENHOUSE_SCRIPT.new() as Greenhouse
	greenhouse.setup_greenhouse(1, false)
	current_scene.add_child(greenhouse)
	greenhouse.global_position = Greenhouse.world_position_for(Vector2i(875, 875))
	await process_frame
	await process_frame

	_expect(greenhouse.is_in_group("base_domes") and greenhouse.is_in_group("pressurized_interiors"), "Test assertion failed")
	_expect(greenhouse.get_node_or_null("GreenhouseBase") is Sprite2D and greenhouse.get_node_or_null("GreenhouseGlass") is Sprite2D, "Test assertion failed")
	var floor_sprite := greenhouse.get_node("GreenhouseBase") as Sprite2D
	var first_bed := greenhouse.get_node("PotatoBed0") as Sprite2D
	var first_crop := greenhouse.get_node("PotatoPlant00") as Sprite2D
	_expect(floor_sprite.z_index == 0 and first_bed.z_index == 0 and first_crop.z_index == 0 and player.z_index > 0, "Test assertion failed")
	_expect((TRANSPARENCY.without_white_background(GREENHOUSE_SOURCE).get_image().get_pixel(0, 0).a) <= 0.01 and (TRANSPARENCY.without_white_background(POTATO_SOURCE).get_image().get_pixel(0, 0).a) <= 0.01, "Test assertion failed")
	_expect(floor_sprite.texture.get_image().get_pixel(80, 80).a >= 0.99, "Test assertion failed")
	_expect(first_bed.texture.get_image().get_pixel(16, 32).a >= 0.99, "Test assertion failed")
	var glass_sprite := greenhouse.get_node("GreenhouseGlass") as Sprite2D
	_expect(glass_sprite.texture.get_image().get_pixel(80, 80).a >= 0.99, "Test assertion failed")
	for item_id in ["greenhouse", "potato_seeds"]:
		var shop_icon: Texture2D = shop_ui.call("_texture_for_item", item_id)
		var inventory_icon: Texture2D = inventory_ui.call("_item_icon", {"id": item_id})
		_expect(shop_icon.get_image().get_pixel(0, 0).a <= 0.01 and inventory_icon.get_image().get_pixel(0, 0).a <= 0.01, "Test assertion failed")
	_expect(greenhouse.get_node_or_null("DomeAndCorridorCollision") is StaticBody2D, "Test assertion failed")
	var beds_collision := greenhouse.get_node_or_null("GreenhouseBedCollision") as StaticBody2D
	_expect(beds_collision != null and beds_collision.get_child_count() == 2, "Test assertion failed")
	_expect(greenhouse.get_node_or_null("WaterPipeAttachment") is Sprite2D and greenhouse.get_water_input_cell().x < floori(greenhouse.global_position.x / 16.0), "Test assertion failed")
	_expect(is_equal_approx((greenhouse.get_node("WaterPipeAttachment") as Sprite2D).position.x, -greenhouse.get_radius()), "Test assertion failed")
	_expect(greenhouse.get_water_input_cell() not in greenhouse.get_occupied_power_cells(), "Test assertion failed")
	_expect(greenhouse.get_node_or_null("PotatoPlant15") is Sprite2D, "Test assertion failed")
	_expect(greenhouse.contains_world_point(greenhouse.global_position + Vector2(69.0, 0.0)) and not greenhouse.contains_world_point(greenhouse.global_position + Vector2(72.0, 0.0)), "Test assertion failed")
	_expect(is_equal_approx(greenhouse.get_node("AirlockCorridor").position.y, 96.0) and is_equal_approx(greenhouse.get_node("OuterDoor").position.y, 104.0) and is_equal_approx(greenhouse.get_node("InnerDoor").position.y, 72.0), "Test assertion failed")
	player.global_position = greenhouse.get_outer_door_position() + Vector2.DOWN * 26.0
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "Test assertion failed")
	await _wait_door()
	player.global_position = greenhouse.global_position + Vector2.DOWN * (greenhouse.get_radius() + 8.0)
	await process_frame
	await _wait_door()
	_expect(not greenhouse.is_door_open("outer"), "Test assertion failed")
	_expect(greenhouse.handle_airlock_key(player, KEY_F), "Test assertion failed")
	_complete_sequence(greenhouse, player)
	player.global_position = greenhouse.get_inner_door_position()
	_expect(greenhouse.handle_airlock_key(player, KEY_F), "Test assertion failed")
	await _wait_door()
	player.global_position = greenhouse.global_position
	await process_frame
	await _wait_door()
	_expect(greenhouse.contains_world_point(player.global_position) and not greenhouse.is_door_open("inner"), "Test assertion failed")

	var glass := greenhouse.get_node("GreenhouseGlass") as Sprite2D
	player.global_position = greenhouse.global_position + Vector2(300.0, 0.0)
	greenhouse.call("_update_interior_art")
	var exterior_alpha := glass.modulate.a
	player.global_position = greenhouse.global_position
	greenhouse.call("_update_interior_art")
	_expect(glass.modulate.a < exterior_alpha and glass.modulate.a <= 0.23, "Test assertion failed")

	var pipe_manager := root.get_node("PipeManager")
	var input_cell := greenhouse.get_water_input_cell()
	var source_cell := input_cell + Vector2i.LEFT
	_expect(bool(pipe_manager.call("can_place_pipe", input_cell, PipeSegment.ShapeType.STRAIGHT, false)), "Test assertion failed")
	var input_pipe := PIPE_SCENE.instantiate() as PipeSegment
	input_pipe.setup(input_cell, PipeSegment.ShapeType.STRAIGHT, false, PipeSegment.Category.GENERIC)
	current_scene.add_child(input_pipe)
	input_pipe.global_position = pipe_manager.call("cell_to_world", input_cell)
	var source_pipe := PIPE_SCENE.instantiate() as PipeSegment
	source_pipe.setup(source_cell, PipeSegment.ShapeType.STRAIGHT, false, PipeSegment.Category.GENERIC)
	current_scene.add_child(source_pipe)
	source_pipe.global_position = pipe_manager.call("cell_to_world", source_cell)
	var pipes: Dictionary = pipe_manager.get("pipes")
	pipes[input_cell] = input_pipe
	pipes[source_cell] = source_pipe
	_expect(greenhouse.is_water_connected() and not greenhouse.has_water_source(), "Test assertion failed")
	var source := FakeWaterSource.new()
	current_scene.add_child(source)
	pipe_manager.call("register_fluid_source", source, source_cell, PipeSegment.Category.WATER, Vector2i.LEFT)
	_expect(greenhouse.is_water_connected() and greenhouse.has_water_source() and input_pipe.category == PipeSegment.Category.WATER and source_pipe.category == PipeSegment.Category.WATER, "Test assertion failed")
	_expect(int(root.get_node("PowerGrid").get("consumers").filter(func(entry): return entry.get("node") == greenhouse).size()) == 1, "Test assertion failed")
	_expect(not greenhouse.is_network_enabled() and not greenhouse.powered, "Test assertion failed")
	greenhouse.set_network_enabled(false)
	root.get_node("PowerGrid").call("rebuild_network")
	_expect(not greenhouse.is_network_enabled() and greenhouse.get_connection_label() == "GREENHOUSE NETWORK DISABLED" and not greenhouse.powered, "Test assertion failed")
	greenhouse.set_network_enabled(true)
	root.get_node("PowerGrid").call("rebuild_network")
	_expect(greenhouse.is_network_enabled(), "Test assertion failed")

	_expect(bool(inventory.call("add_item", "potato_seeds", "Semi di patate (lotto)", 1, false)), "Test assertion failed")
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "Test assertion failed")
	_expect(greenhouse.is_planted() and greenhouse.get_crop_stage() == 0 and int(inventory.call("count_item", "potato_seeds")) == 0, "Test assertion failed")
	_expect((first_crop.texture as AtlasTexture).atlas.get_image().get_pixel(0, 0).a <= 0.01, "Test assertion failed")
	_expect((first_crop.texture as AtlasTexture).atlas.get_image().get_pixel(8, 11).a >= 0.99, "Test assertion failed")
	source.available_liters = 0.0
	greenhouse.call("_update_crop_growth", 30.0)
	_expect(is_equal_approx(float(greenhouse.get("_growth_seconds")), 0.0), "Test assertion failed")
	source.available_liters = 10_000.0
	greenhouse.call("_update_crop_growth", Greenhouse.FIRST_CYCLE_SECONDS - 1.0)
	_expect(not greenhouse.is_crop_ready(), "Test assertion failed")
	greenhouse.call("_update_crop_growth", 1.0)
	_expect(greenhouse.is_crop_ready() and greenhouse.get_crop_stage() == 4, "Test assertion failed")
	player.global_position = greenhouse.global_position + Vector2(300.0, 0.0)
	greenhouse.oxygen_reserve = 10.0
	greenhouse.call("_update_greenhouse_oxygen", 1.0)
	_expect(float(greenhouse.oxygen_reserve) > 10.0 and greenhouse.has_breathable_atmosphere(), "Test assertion failed")
	greenhouse.call("_update_greenhouse_oxygen", 1_000.0)
	_expect(float(greenhouse.oxygen_reserve) <= Greenhouse.GREENHOUSE_OXYGEN_CAPACITY, "Test assertion failed")
	player.global_position = greenhouse.global_position
	var food_before := int(inventory.call("count_item", "food_ration"))
	greenhouse.call("_process", 0.1)
	_expect(int(inventory.call("count_item", "food_ration")) == food_before and greenhouse.is_crop_ready(), "Test assertion failed")
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "Test assertion failed")
	var harvested_food := int(inventory.call("count_item", "food_ration")) - food_before
	_expect(harvested_food >= Greenhouse.HARVEST_FOOD - 1 and harvested_food <= Greenhouse.HARVEST_FOOD, "Test assertion failed")
	var food_slot: Dictionary = inventory.get("hotbar")[4]
	_expect(str(food_slot.get("id", "")) == "food_ration" and int(food_slot.get("count", 0)) == food_before + harvested_food, "Test assertion failed")
	_expect(greenhouse.is_planted() and not greenhouse.is_crop_ready() and greenhouse.get_crop_stage() == 0, "Test assertion failed")
	greenhouse.set_powered(true)
	root.get_node("WorldClock").call("set_game_hour", 23.0)
	greenhouse.call("_update_night_lighting")
	_expect(bool(greenhouse.get_node("GreenhouseNightLight").visible) and bool(greenhouse.get_node("GreenhouseLampGlow").visible), "Test assertion failed")
	greenhouse.call("_update_crop_growth", 45.0)
	var remaining_before_disconnect := float(greenhouse.call("get_remaining_growth_seconds"))
	greenhouse.set_powered(false)
	_expect(is_equal_approx(float(greenhouse.call("get_remaining_growth_seconds")), remaining_before_disconnect), "Test assertion failed")
	greenhouse.call("_update_crop_growth", 10.0)
	var remaining_after_unpowered_growth := float(greenhouse.call("get_remaining_growth_seconds"))
	_expect(is_equal_approx(remaining_after_unpowered_growth, remaining_before_disconnect - 10.0), "Test assertion failed")
	greenhouse.set_powered(true)
	_expect(is_equal_approx(float(greenhouse.call("get_remaining_growth_seconds")), remaining_after_unpowered_growth), "Test assertion failed")
	greenhouse.call("_update_crop_growth", remaining_after_unpowered_growth / 1.60 - 0.1)
	_expect(not greenhouse.is_crop_ready(), "Test assertion failed")
	greenhouse.call("_update_crop_growth", 0.1)
	_expect(greenhouse.is_crop_ready(), "Test assertion failed")
	_expect(is_equal_approx(greenhouse.get_power_demand_kw(), Greenhouse.POWER_DEMAND_KW + Greenhouse.POWERED_EXTRA_DEMAND_KW), "Test assertion failed")
	_expect(float(greenhouse.get("_water_consumed_liters")) > 0.0 and source.available_liters < 10_000.0, "Test assertion failed")
	greenhouse.set_powered(false)
	greenhouse.call("_update_night_lighting")
	_expect(not bool(greenhouse.get_node("GreenhouseNightLight").visible), "Test assertion failed")

	pipe_manager.call("unregister_fluid_source", source)
	pipes.erase(input_cell)
	pipes.erase(source_cell)
	input_pipe.queue_free()
	source_pipe.queue_free()
	source.queue_free()
	greenhouse.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _complete_sequence(greenhouse: Greenhouse, player: Node2D) -> void:
	for keycode in greenhouse.get_sequence_keys():
		_expect(greenhouse.handle_airlock_key(player, keycode), "Test assertion failed")


func _wait_door() -> void:
	await create_timer(0.55).timeout
	await process_frame


func _finish() -> void:
	if failures.is_empty():
		print("GREENHOUSE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("GREENHOUSE_SMOKE_FAIL: " + failure)
	quit(1)
