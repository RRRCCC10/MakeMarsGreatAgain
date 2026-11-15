extends SceneTree


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
	var landing = current_scene.get_node_or_null("LandingSequence")
	var inventory = root.get_node_or_null("Inventory")
	_expect(landing != null, "Test assertion failed")
	_expect(inventory != null, "Test assertion failed")
	if landing == null or inventory == null:
		_finish()
		return

	inventory.reset_for_new_mission()
	var catalog: Array[Dictionary] = landing.get_return_manifest_catalog()
	_expect(catalog.size() > 0, "Test assertion failed")
	for definition in catalog:
		_expect(not str(definition.get("name", "")).is_empty(), "Test assertion failed")
		_expect(not str(definition.get("biome", "")).is_empty(), "Test assertion failed")
		_expect(not str(definition.get("rarity", "")).is_empty(), "Test assertion failed")
		var item_id := str(definition.get("item_id", ""))
		_expect(not item_id.is_empty(), "Test assertion failed")
		if item_id.is_empty():
			continue
		_expect(bool(inventory.add_item(item_id, str(definition.get("name", "Sample")), 1, false)), "Test assertion failed")
		landing._load_available_return_samples()

	_expect(bool(inventory.add_alien_life_sample()), "Test assertion failed")
	landing._load_available_return_samples()
	var readiness: Dictionary = landing.get_return_readiness()
	_expect(int(readiness.get("geology_loaded", 0)) == catalog.size(), "Test assertion failed")
	_expect(bool(readiness.get("life_loaded", false)), "Test assertion failed")
	_expect(not bool(readiness.get("ready", true)), "Test assertion failed")
	_expect(landing.manifest_list.text.contains(str(catalog[0].get("name", ""))), "Test assertion failed")
	_expect(landing.manifest_list.text.contains(str(catalog[0].get("biome", ""))), "Test assertion failed")
	_expect(landing.manifest_list.text.contains("BIOLOGICAL SAMPLE"), "Test assertion failed")
	landing.manifest_root.visible = true
	await process_frame
	_expect(landing.manifest_scroll.get_v_scroll_bar().max_value > 0.0, "Test assertion failed")
	landing.manifest_root.visible = false

	var sabatier_marker := Node.new()
	landing.register_sabatier_operation(sabatier_marker)
	sabatier_marker.free()
	_expect(landing.sabatier_qualified, "Test assertion failed")
	_expect(is_equal_approx(landing.load_methane_kg(9999.0), landing.METHANE_CAPACITY_KG), "Test assertion failed")
	readiness = landing.get_return_readiness()
	_expect(bool(readiness.get("ready", false)), "Test assertion failed")
	landing._try_launch_return()
	_expect(landing.return_launch_in_progress, "Test assertion failed")
	landing._update_return_launch(landing.RETURN_LAUNCH_DURATION + 0.1)
	_expect(landing.return_launch_finished, "Test assertion failed")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RETURN_MISSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
