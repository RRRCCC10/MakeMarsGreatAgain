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
		"Ares Plain": ["red_regolith", "ferric_stone"],
		"Polar Core": ["dusty_ice", "blue_ice"],
		"Impact Craters": ["crater_stone", "impact_glass"],
		"Basalt Formation": ["basaltic_rock", "black_basalt"],
		"Ice-Cap Edge": ["cryogenic_rock", "deep_ice"],
	}
	var counts := {}
	var expected_sources := {
		"red_regolith": [0, 1], "ferric_stone": [0, 1],
		"dusty_ice": [4], "blue_ice": [4],
		"crater_stone": [2], "impact_glass": [2],
		"basaltic_rock": [5], "black_basalt": [5],
		"cryogenic_rock": [3], "deep_ice": [3],
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
	_expect(inventory.add_rock("black_basalt"), "Test assertion failed")
	_expect(inventory.add_rock("black_basalt"), "Test assertion failed")
	_expect(inventory.add_rock("basaltic_rock"), "Test assertion failed")
	_expect(inventory.count_item("rock_black_basalt") == 2, "Test assertion failed")
	_expect(inventory.count_item("rock_basaltic_rock") == 1, "Test assertion failed")

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
