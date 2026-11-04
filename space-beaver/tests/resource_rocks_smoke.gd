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
		"Pianura di Ares": ["roccia_rossa", "pietra_rossastra"],
		"Nucleo polare": ["ghiaccio_leggero", "ghiaccio_blu"],
		"Crateri d'impatto": ["roccia_grigia", "roccia_scura"],
		"Formazione basaltica": ["roccia_basaltica", "basalto"],
		"Bordo della calotta": ["roccia_ghiacciata", "ghiaccio_profondo"],
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
		_expect(not str(rock.get_display_name()).is_empty(), "Ogni roccia deve avere un nome da raccogliere")
		var cell: Vector2i = map.call("world_to_cell", rock.global_position)
		map.call("ensure_cell_loaded", cell)
		var source := int(map.call("get_source_id", cell))
		_expect(source in expected_sources[variant], "%s deve poggiare sul terreno del suo bioma" % rock.name)

	_expect(counts.size() == 10, "Le dieci risorse geologiche devono essere tutte distribuite")
	for biome in expected_pairs:
		var pair: Array = expected_pairs[biome]
		var common := str(pair[0])
		var rare := str(pair[1])
		_expect(RockResource.definition_for(common).get("biome", "") == biome, "La roccia comune deve appartenere al suo bioma")
		_expect(RockResource.definition_for(rare).get("biome", "") == biome, "La roccia rara deve appartenere al suo bioma")
		_expect(int(counts.get(common, 0)) == 20, "%s deve avere 20 rocce comuni" % biome)
		_expect(int(counts.get(rare, 0)) == 5, "%s deve avere 5 rocce rare" % biome)

	var inventory: Node = root.get_node("Inventory")
	inventory.reset_for_new_mission()
	var collectible: Node
	for rock in get_nodes_in_group("collectible_rocks"):
		if bool(rock.is_authored):
			collectible = rock
			break
	var collected_definition: Dictionary = collectible.resource_definition()
	_expect(bool(collectible.call("collect")), "Una roccia vicina deve poter essere raccolta")
	await process_frame
	_expect(inventory.count_item(str(collected_definition.get("item_id", ""))) == 1, "La raccolta deve inserire il campione corretto nello zaino")

	inventory.reset_for_new_mission()
	_expect(inventory.add_rock("basalto"), "Il primo basalto deve entrare nello zaino")
	_expect(inventory.add_rock("basalto"), "Un secondo basalto deve accumularsi nello stesso stock")
	_expect(inventory.add_rock("roccia_basaltica"), "Una categoria diversa deve poter essere raccolta")
	_expect(inventory.count_item("rock_basalto") == 2, "Due basalti devono condividere uno stock")
	_expect(inventory.count_item("rock_roccia_basaltica") == 1, "La roccia basaltica deve restare separata dal basalto raro")

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
