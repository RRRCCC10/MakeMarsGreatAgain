extends SceneTree

const RockResource = preload("res://scripts/rock.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var expected_pairs := {
		"Ares Plain": ["roccia_rossa", "pietra_rossastra"],
		"Polar Core": ["ghiaccio_leggero", "ghiaccio_blu"],
		"Impact Craters": ["roccia_grigia", "roccia_scura"],
		"Basalt Formation": ["roccia_basaltica", "basalto"],
		"Ice-Cap Edge": ["roccia_ghiacciata", "ghiaccio_profondo"],
	}
	var counts := {}
	var expected_sources := {
		"roccia_rossa": [0, 1], "pietra_rossastra": [0, 1],
		"ghiaccio_leggero": [4], "ghiaccio_blu": [4],
		"roccia_grigia": [2], "roccia_scura": [2],
		"roccia_basaltica": [5], "basalto": [5],
		"roccia_ghiacciata": [3], "ghiaccio_profondo": [3],
	}
	var map := current_scene.get_node("Map")
	for rock in get_nodes_in_group("collectible_rocks"):
		if not bool(rock.is_authored):
			continue
		var variant := str(rock.rock_variant)
		counts[variant] = int(counts.get(variant, 0)) + 1
		_expect(not str(rock.get_display_name()).is_empty(), "Test assertion failed")
		var cell: Vector2i = map.call("world_to_cell", rock.global_position)
		map.call("ensure_cell_loaded", cell)
		var source := int(map.call("get_source_id", cell))
		_expect(source in expected_sources[variant], "Test assertion failed")
	_expect(counts.size() == 10, "Test assertion failed")
	for biome in expected_pairs:
		var pair: Array = expected_pairs[biome]
		var common := str(pair[0])
		var rare := str(pair[1])
		_expect(RockResource.definition_for(common).get("biome", "") == biome, "Test assertion failed")
		_expect(RockResource.definition_for(rare).get("biome", "") == biome, "Test assertion failed")
		_expect(int(counts.get(common, 0)) == 20, "Test assertion failed")
		_expect(int(counts.get(rare, 0)) == 5, "Test assertion failed")
	var inventory: Node = root.get_node("Inventory")
	inventory.reset_for_new_mission()
	var collectible: Node
	for rock in get_nodes_in_group("collectible_rocks"):
		if bool(rock.is_authored):
			collectible = rock
			break
	var collected_definition: Dictionary = collectible.resource_definition()
	_expect(bool(collectible.call("collect")), "Test assertion failed")
	await process_frame
	_expect(inventory.count_item(str(collected_definition.get("item_id", ""))) == 1, "Test assertion failed")

	inventory.reset_for_new_mission()
	_expect(inventory.add_rock("basalto"), "Test assertion failed")
	_expect(inventory.add_rock("basalto"), "Test assertion failed")
	_expect(inventory.add_rock("roccia_basaltica"), "Test assertion failed")
	_expect(inventory.count_item("rock_basalto") == 2, "Test assertion failed")
	_expect(inventory.count_item("rock_roccia_basaltica") == 1, "Test assertion failed")

	if failures.is_empty():
		print("RESOURCE_ROCKS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
