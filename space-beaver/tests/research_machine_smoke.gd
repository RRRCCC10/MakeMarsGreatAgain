extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const RESEARCH_SCRIPT := preload("res://scripts/ResearchMachine.gd")

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
	var shop := root.get_node("Shop")
	var economy := root.get_node("Economy")
	var target_cell := Vector2i(620, 430)
	var dome := DOME_SCRIPT.place(current_scene, "dome_large", target_cell, 1) as Node2D
	_expect(dome != null, "Test assertion failed")
	if dome == null:
		_finish()
		return
	await process_frame
	var research_cell := Vector2i(floori((dome.global_position.x - 8.0) / 16.0), floori((dome.global_position.y - 32.0) / 16.0))
	var target_position := RESEARCH_SCRIPT.world_position_for("xrd_diffractometer", research_cell)
	player.global_position = dome.global_position + Vector2(300.0, 0.0)
	_expect(RESEARCH_SCRIPT.can_place_at("xrd_diffractometer", target_position), "Test assertion failed")
	_expect(not RESEARCH_SCRIPT.can_place_at("xrd_diffractometer", dome.global_position + Vector2(300.0, 0.0)), "Test assertion failed")
	var small_dome := DOME_SCRIPT.place(current_scene, "dome_small", Vector2i(650, 430), 1) as Node2D
	_expect(small_dome != null, "Test assertion failed")
	if small_dome != null:
		var small_cell := Vector2i(floori((small_dome.global_position.x - 8.0) / 16.0), floori((small_dome.global_position.y - 8.0) / 16.0))
		for lab_id in ["xrd_diffractometer", "raman_spectrometer", "icp_ms"]:
			var small_target := RESEARCH_SCRIPT.world_position_for(lab_id, small_cell)
			_expect(RESEARCH_SCRIPT.can_place_at(lab_id, small_target), "Test assertion failed")
	var machine := RESEARCH_SCRIPT.place(current_scene, "xrd_diffractometer", research_cell) as Node2D
	_expect(machine != null and machine.get_node_or_null("ResearchMachineCollision") is StaticBody2D, "Test assertion failed")
	if machine == null:
		_finish()
		return
	_expect(_has_visible_pixels(machine.get_node("ResearchSprite").texture as Texture2D), "Test assertion failed")
	_expect(Vector2i(machine.call("get_power_connection_cell")) == Vector2i(dome.call("get_power_connection_cell")), "Test assertion failed")
	_expect(not RESEARCH_SCRIPT.can_place_at("raman_spectrometer", target_position), "Test assertion failed")
	player.global_position = machine.global_position
	_expect(not RESEARCH_SCRIPT.can_place_at("raman_spectrometer", machine.global_position + Vector2(32.0, 0.0)), "Test assertion failed")
	var analysis_before_upgrade := float(machine.call("get_analysis_seconds"))
	economy.call("add_funds", 3_000_000_000)
	for expected_level in range(1, 6):
		var upgrade_event := InputEventKey.new()
		upgrade_event.keycode = KEY_U
		upgrade_event.pressed = true
		player.call("_unhandled_input", upgrade_event)
		_expect(int(machine.get("upgrade_level")) == expected_level, "Test assertion failed")
	_expect(is_equal_approx(float(machine.call("get_analysis_seconds")), 40.0), "Test assertion failed")
	_expect(float(machine.call("get_analysis_seconds")) < analysis_before_upgrade, "Test assertion failed")
	_expect(not bool(machine.call("try_upgrade", player)), "Test assertion failed")
	inventory.reset_for_new_mission()
	_expect(inventory.add_rock("basaltic_rock"), "Test assertion failed")
	_expect(inventory.add_rock("impact_glass"), "Test assertion failed")
	_expect(bool(machine.call("try_interact", player)), "Test assertion failed")
	_expect(int(machine.get("state")) == 0 and inventory.count_item("rock_basaltic_rock") == 1 and inventory.count_item("rock_impact_glass") == 1, "Test assertion failed")
	var sample_picker := machine.get("_sample_picker_root") as Control
	_expect(sample_picker != null and sample_picker.visible, "Test assertion failed")
	var rock_thumbnails: Array[Node] = sample_picker.find_children("*", "TextureRect", true, false) if sample_picker != null else []
	_expect(not rock_thumbnails.is_empty() and (rock_thumbnails.front() as TextureRect).texture is Texture2D, "Test assertion failed")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	machine.call("_on_sample_picker_gui_input", escape_event)
	_expect(sample_picker != null and not sample_picker.visible, "Test assertion failed")
	_expect(bool(machine.call("try_interact", player)) and sample_picker != null and sample_picker.visible, "Test assertion failed")
	machine.call("_select_sample", "rock_basaltic_rock")
	_expect(int(machine.get("state")) == 1 and inventory.count_item("rock_basaltic_rock") == 0 and inventory.count_item("rock_impact_glass") == 1, "Test assertion failed")
	_expect(is_equal_approx(float(machine.call("get_power_demand_kw")), 240.0), "Test assertion failed")
	machine.call("set_powered", false)
	machine.set("study_elapsed", 5.0)
	machine.call("_process", 10.0)
	_expect(is_equal_approx(float(machine.get("study_elapsed")), 5.0), "Test assertion failed")
	machine.call("set_powered", true)
	machine.set("study_elapsed", float(machine.call("get_analysis_seconds")))
	machine.call("_process", 0.01)
	_expect(int(machine.get("state")) == 2, "Test assertion failed")
	_expect(is_equal_approx(float(machine.call("get_power_demand_kw")), 0.0), "Test assertion failed")
	var balance_before := int(economy.get("balance"))
	_expect(bool(machine.call("try_interact", player)) and bool(machine.get("report_signed")), "Test assertion failed")
	_expect(int(machine.get("state")) == 2, "Test assertion failed")
	_expect(bool(machine.call("try_interact", player)), "Test assertion failed")
	_expect(int(machine.get("state")) == 0 and int(economy.get("balance")) == balance_before + int(machine.call("get_reward")), "Test assertion failed")
	inventory.reset_for_new_mission()
	_expect(inventory.add_rock("primordial_deep_ice"), "Test assertion failed")
	_expect(bool(machine.call("try_interact", player)), "Test assertion failed")
	_expect(bool(machine.get("sample_is_primordial_ice")) and is_equal_approx(float(machine.call("get_biosignature_chance")), 0.20), "Test assertion failed")
	machine.set("ancient_life_detected", true)
	machine.call("set_powered", true)
	machine.set("study_elapsed", float(machine.call("get_analysis_seconds")))
	machine.call("_process", 0.01)
	_expect(int(machine.get("state")) == 2 and int(machine.call("get_reward")) >= 10_000_000_000, "Test assertion failed")
	var life_balance_before := int(economy.get("balance"))
	_expect(bool(machine.call("try_interact", player)) and bool(machine.get("report_signed")), "Test assertion failed")
	_expect(bool(machine.call("try_interact", player)), "Test assertion failed")
	_expect(int(economy.get("balance")) == life_balance_before + int(machine.call("get_reward")), "Test assertion failed")
	var achievements := root.get_node("AchievementManager")
	_expect(int(achievements.call("get_progress", "deep_ice_study")) == 1 and int(achievements.call("get_progress", "ancient_life")) == 1 and int(achievements.call("get_progress", "life_relay")) == 1, "Test assertion failed")
	_expect(is_equal_approx(float(RESEARCH_SCRIPT.get_definition("raman_spectrometer").get("biosignature_chance", 0.0)), 0.35) and is_equal_approx(float(RESEARCH_SCRIPT.get_definition("icp_ms").get("biosignature_chance", 0.0)), 0.55), "Test assertion failed")
	_expect(inventory.add_rock("impact_glass"), "Test assertion failed")
	_expect(bool(machine.call("try_interact", player)) and int(machine.get("state")) == 1, "Test assertion failed")
	var removed_machine_id := machine.get_instance_id()
	_expect(bool(machine.call("pickup")), "Test assertion failed")
	_expect(inventory.count_item("xrd_diffractometer") == 1, "Test assertion failed")
	await process_frame
	var buildable_registry := root.get_node("BuildableRegistry")
	var still_registered := false
	for entry in buildable_registry.get_entries():
		var registered_node := entry.get("node") as Node
		if registered_node != null and registered_node.get_instance_id() == removed_machine_id:
			still_registered = true
	_expect(not still_registered, "Test assertion failed")
	for item_id in ["xrd_diffractometer", "raman_spectrometer", "icp_ms"]:
		var definition: Dictionary = shop.call("get_definition", item_id)
		_expect(bool(definition.get("placeable", false)) and str(definition.get("category", "")) == "research", "Test assertion failed")
		_expect(_has_visible_pixels(RESEARCH_SCRIPT.get_icon_texture(item_id)), "Test assertion failed")
	if is_instance_valid(machine):
		machine.queue_free()
	if is_instance_valid(dome):
		dome.queue_free()
	if is_instance_valid(small_dome):
		small_dome.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _fail(message: String) -> void:
	failures.append(message)


func _has_visible_pixels(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	return image != null and not image.is_empty() and image.get_used_rect().has_area()


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_MACHINE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("RESEARCH_MACHINE_SMOKE_FAIL: " + failure)
	quit(1)
