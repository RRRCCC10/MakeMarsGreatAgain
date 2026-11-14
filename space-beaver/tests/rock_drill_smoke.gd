extends SceneTree

const ROCK_RESOURCE := preload("res://scripts/rock.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var power_grid := root.get_node("PowerGrid")
	var clock := root.get_node("WorldClock")
	var inventory := root.get_node("Inventory")
	var shop := root.get_node("Shop")
	var player := current_scene.get_node("player") as Node2D

	var panel = power_grid.place_device(current_scene, "solar_panel", Vector2i(-12, 8))
	var transformer = power_grid.place_device(current_scene, "transformer", Vector2i(-6, 8))
	var battery = power_grid.place_device(current_scene, "battery", Vector2i(0, 8))
	var drill = power_grid.place_device(current_scene, "rock_drill", Vector2i(6, 8))
	_expect(drill != null, "La trivella mineraria deve potersi piazzare su terreno libero")
	if drill == null:
		_finish()
		return
	_expect(drill.get_node_or_null("RockDrillCollision") is StaticBody2D, "La trivella mineraria deve avere una hitbox")
	var drill_sprite := drill.get_node_or_null("RockDrillSprite") as Sprite2D
	_expect(drill_sprite != null and drill_sprite.texture is AtlasTexture, "La trivella mineraria deve mostrare un frame dello spritesheet")
	if drill_sprite != null and drill_sprite.texture is AtlasTexture:
		var first_frame := drill_sprite.texture as AtlasTexture
		_expect(first_frame.region.size == Vector2(32.0, 48.0), "Ogni frame della trivella mineraria deve usare una posa completa da 32x48 px")
	panel.set_network_enabled(true)
	transformer.set_network_enabled(true)
	battery.set_network_enabled(true)
	drill.set_network_enabled(true)
	clock.running = true
	clock.set_game_hour(12.0)
	power_grid.battery_energy_kwh = 100.0
	power_grid.rebuild_network()
	power_grid._update_energy(0.0)
	_expect(is_equal_approx(power_grid.demand_kw, 85.0), "La trivella mineraria collegata deve richiedere 85 kW")
	_expect(bool(drill.get("powered")), "La trivella mineraria deve ricevere potenza dalla rete")
	drill._process(12.1)
	_expect(int(drill.call("get_stock_count")) == 1, "La trivella deve estrarre un campione dopo dodici secondi")
	var stock: Array = drill.call("get_stock_items")
	_expect(not stock.is_empty() and str(stock[0].get("biome", "")).length() > 0, "Il campione in riserva deve conservare la provenienza")
	player.global_position = drill.global_position
	var open_storage_event := InputEventKey.new()
	open_storage_event.keycode = KEY_E
	open_storage_event.pressed = true
	var builder := current_scene.get_node("player/Node")
	builder.call("_update_nearby_machine_ui")
	builder.call("_unhandled_input", open_storage_event)
	_expect(int(drill.call("get_stock_count")) == 1, "Il pannello rapido non deve sottrarre un campione: E deve restare riservato al deposito")
	player.call("_unhandled_input", open_storage_event)
	_expect(bool(drill.call("is_storage_open")) and bool(root.get_node("BuildableRegistry").get("is_modal_open")), "La riserva deve bloccare il movimento come l'inventario")
	var sample_id := str(stock[0].get("id", ""))
	_expect(int(drill.call("transfer_stock_stack", 0)) == 1, "Il giocatore deve poter trasferire soltanto la pila selezionata")
	_expect(int(inventory.call("count_item", sample_id)) == 1 and int(drill.call("get_stock_count")) == 0, "Il trasferimento deve togliere il campione dalla trivella e aggiungerlo allo zaino")
	drill.call("close_storage")
	_expect(not bool(root.get_node("BuildableRegistry").get("is_modal_open")), "Chiudere la riserva deve riabilitare il movimento")
	drill._process(24.1)
	_expect(int(drill.call("get_stock_count")) == 2, "La trivella deve poter accumulare più campioni nella riserva")
	_expect(int(drill.call("discard_all_stock")) == 2 and int(drill.call("get_stock_count")) == 0, "Il giocatore deve poter scartare tutta la riserva della trivella")

	var expected_rares := ["shoshonite_olivinica", "goethite_idrata", "impactite_vetrosa", "sali_solfati_idrati", "ghiaccio_salmastro", "olivina_ferrifera"]
	for source_id in expected_rares.size():
		var rare_variant := str(ROCK_RESOURCE.drill_variant_for_biome(source_id, 0.049, 0.1))
		var common_roll := 0.10 if source_id == 4 else 0.05
		var common_variant := str(ROCK_RESOURCE.drill_variant_for_biome(source_id, common_roll, 0.1))
		var expected_variant: String = "ghiaccio_profondo_primordiale" if source_id == 4 else str(expected_rares[source_id])
		_expect(rare_variant == expected_variant, "Ogni bioma deve avere una scoperta speciale e il polo privilegia il ghiaccio primordiale")
		_expect(str(ROCK_RESOURCE.definition_for(common_variant).get("rarity", "")) == "common", "Fuori dal 5%% la trivella deve trovare campioni comuni")
		_expect(str(ROCK_RESOURCE.drill_variant_for_biome(source_id, 0.009, 0.1)) == "ghiaccio_profondo_primordiale", "Il ghiaccio profondo primordiale deve essere raro ma possibile in ogni bioma")
	_expect(is_equal_approx(ROCK_RESOURCE.deep_ice_probability_for_biome(0), 0.01) and is_equal_approx(ROCK_RESOURCE.deep_ice_probability_for_biome(4), 0.10), "Il ghiaccio primordiale deve salire dall'1%% al 10%% nel polo")
	var rare_definition: Dictionary = ROCK_RESOURCE.definition_for("olivina_ferrifera")
	var deep_ice_definition: Dictionary = ROCK_RESOURCE.definition_for("ghiaccio_profondo_primordiale")
	var common_definition: Dictionary = ROCK_RESOURCE.definition_for("roccia_base")
	_expect(float(rare_definition.get("research_multiplier", 0.0)) > float(common_definition.get("research_multiplier", 0.0)), "Un campione raro e remoto deve valere più della pietra iniziale")
	_expect(bool(deep_ice_definition.get("deep_ice", false)) and float(deep_ice_definition.get("research_multiplier", 0.0)) > float(rare_definition.get("research_multiplier", 0.0)), "Il ghiaccio primordiale deve essere un campione eccezionale per la ricerca")
	var catalog: Dictionary = shop.call("get_definition", "rock_drill")
	_expect(bool(catalog.get("placeable", false)) and str(catalog.get("category", "")) == "extraction", "La trivella mineraria deve essere acquistabile nello shop estrazione")
	var registry := root.get_node("BuildableRegistry")
	var drill_entry: Dictionary = registry.call("find_at", drill.global_position)
	_expect(not drill_entry.is_empty() and bool(registry.call("destroy", drill_entry)), "La trivella deve poter essere recuperata con la demolizione")
	_expect(int(inventory.call("count_item", "rock_drill")) == 1, "Recuperare la trivella deve restituirla nell'inventario")
	clock.running = false
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ROCK_DRILL_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
