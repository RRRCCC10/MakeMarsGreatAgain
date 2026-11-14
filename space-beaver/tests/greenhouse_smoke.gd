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
		return "Sorgente acqua test"


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
	var player := current_scene.get_node("player") as Node2D
	var inventory := root.get_node("Inventory")
	var shop_ui := current_scene.get_node("ShopUI")
	var inventory_ui := current_scene.get_node("InventoryUI")
	var greenhouse := GREENHOUSE_SCRIPT.new() as Greenhouse
	greenhouse.setup_greenhouse(1, false)
	current_scene.add_child(greenhouse)
	# Posizione identica al piazzamento reale (centro della cella da 16px).
	greenhouse.global_position = Greenhouse.world_position_for(Vector2i(875, 875))
	await process_frame
	await process_frame

	_expect(greenhouse.is_in_group("base_domes") and greenhouse.is_in_group("pressurized_interiors"), "La serra deve usare l'interno pressurizzato e la camera d'aria della cupola")
	_expect(greenhouse.get_node_or_null("GreenhouseBase") is Sprite2D and greenhouse.get_node_or_null("GreenhouseGlass") is Sprite2D, "Base e vetro della serra devono essere due sprite sovrapposti")
	var floor_sprite := greenhouse.get_node("GreenhouseBase") as Sprite2D
	var first_bed := greenhouse.get_node("PotatoBed0") as Sprite2D
	var first_crop := greenhouse.get_node("PotatoPlant00") as Sprite2D
	_expect(floor_sprite.z_index == 0 and first_bed.z_index == 0 and first_crop.z_index == 0 and player.z_index > 0, "Pavimento, terra e piante devono stare sopra la TileMap ma sotto il personaggio")
	_expect((TRANSPARENCY.without_white_background(GREENHOUSE_SOURCE).get_image().get_pixel(0, 0).a) <= 0.01 and (TRANSPARENCY.without_white_background(POTATO_SOURCE).get_image().get_pixel(0, 0).a) <= 0.01, "Le miniature di serra e semi devono avere lo sfondo bianco trasparente")
	# Regressione del bug visivo: il filtro deve svuotare solo il bianco esterno,
	# non il pavimento chiaro, il vetro, la terra o la vegetazione della serra.
	_expect(floor_sprite.texture.get_image().get_pixel(80, 80).a >= 0.99, "Il pavimento chiaro della serra non deve diventare trasparente")
	_expect(first_bed.texture.get_image().get_pixel(16, 32).a >= 0.99, "La terra delle aiuole non deve diventare trasparente")
	var glass_sprite := greenhouse.get_node("GreenhouseGlass") as Sprite2D
	_expect(glass_sprite.texture.get_image().get_pixel(80, 80).a >= 0.99, "Il vetro della serra deve restare visibile sopra il pavimento")
	for item_id in ["greenhouse", "potato_seeds"]:
		var shop_icon: Texture2D = shop_ui.call("_texture_for_item", item_id)
		var inventory_icon: Texture2D = inventory_ui.call("_item_icon", {"id": item_id})
		_expect(shop_icon.get_image().get_pixel(0, 0).a <= 0.01 and inventory_icon.get_image().get_pixel(0, 0).a <= 0.01, "Shop e inventario devono mostrare %s senza riquadro bianco" % item_id)
	_expect(greenhouse.get_node_or_null("DomeAndCorridorCollision") is StaticBody2D, "Pareti e corridoio della serra devono avere collisioni")
	var beds_collision := greenhouse.get_node_or_null("GreenhouseBedCollision") as StaticBody2D
	_expect(beds_collision != null and beds_collision.get_child_count() == 2, "Le due aiuole devono avere due hitbox che lasciano libero il corridoio centrale")
	_expect(greenhouse.get_node_or_null("WaterPipeAttachment") is Sprite2D and greenhouse.get_water_input_cell().x < floori(greenhouse.global_position.x / 16.0), "Il raccordo acqua deve trovarsi sul lato sinistro della serra")
	_expect(is_equal_approx((greenhouse.get_node("WaterPipeAttachment") as Sprite2D).position.x, -greenhouse.get_radius()), "Il raccordo visibile dell'acqua deve toccare la parete sinistra, non restare distante")
	_expect(greenhouse.get_water_input_cell() not in greenhouse.get_occupied_power_cells(), "Il raccordo acqua deve stare fuori dall'impronta: il tubo deve poter essere piazzato davvero")
	_expect(greenhouse.get_node_or_null("PotatoPlant15") is Sprite2D, "La serra deve creare tutti i 16 posti per le piante")
	_expect(greenhouse.contains_world_point(greenhouse.global_position + Vector2(69.0, 0.0)) and not greenhouse.contains_world_point(greenhouse.global_position + Vector2(72.0, 0.0)), "La hitbox circolare deve essere più piccola della grafica esterna")
	_expect(is_equal_approx(greenhouse.get_node("AirlockCorridor").position.y, 96.0) and is_equal_approx(greenhouse.get_node("OuterDoor").position.y, 104.0) and is_equal_approx(greenhouse.get_node("InnerDoor").position.y, 72.0), "Corridoio e porta esterna devono agganciarsi alla porta interna senza spostarla")
	# Percorso reale completo della camera: usa senza variazioni le soglie della
	# cupola base, E → attraversamento → F/WASD → F.
	player.global_position = greenhouse.get_outer_door_position() + Vector2.DOWN * 26.0
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "E deve aprire la porta esterna della serra")
	await _wait_door()
	player.global_position = greenhouse.global_position + Vector2.DOWN * (greenhouse.get_radius() + 8.0)
	await process_frame
	await _wait_door()
	_expect(not greenhouse.is_door_open("outer"), "La porta esterna della serra deve richiudersi dopo l'ingresso nel corridoio")
	_expect(greenhouse.handle_airlock_key(player, KEY_F), "F nel corridoio deve avviare la pressurizzazione della serra")
	_complete_sequence(greenhouse, player)
	player.global_position = greenhouse.get_inner_door_position()
	_expect(greenhouse.handle_airlock_key(player, KEY_F), "La porta interna deve aprirsi al termine della sequenza")
	await _wait_door()
	player.global_position = greenhouse.global_position
	await process_frame
	await _wait_door()
	_expect(greenhouse.contains_world_point(player.global_position) and not greenhouse.is_door_open("inner"), "Il player deve entrare realmente nella serra e la porta interna deve chiudersi")

	var glass := greenhouse.get_node("GreenhouseGlass") as Sprite2D
	player.global_position = greenhouse.global_position + Vector2(300.0, 0.0)
	greenhouse.call("_update_interior_art")
	var exterior_alpha := glass.modulate.a
	player.global_position = greenhouse.global_position
	greenhouse.call("_update_interior_art")
	_expect(glass.modulate.a < exterior_alpha and glass.modulate.a <= 0.23, "Il vetro deve diventare molto più trasparente entrando nella serra")

	var pipe_manager := root.get_node("PipeManager")
	var input_cell := greenhouse.get_water_input_cell()
	var source_cell := input_cell + Vector2i.LEFT
	_expect(bool(pipe_manager.call("can_place_pipe", input_cell, PipeSegment.ShapeType.STRAIGHT, false)), "Il gioco deve consentire davvero di piazzare il tubo acqua sul raccordo esterno")
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
	_expect(greenhouse.is_water_connected() and not greenhouse.has_water_source(), "Il raccordo deve riconoscere il tubo fisico anche se è ancora grigio e non ha una sorgente")
	var source := FakeWaterSource.new()
	current_scene.add_child(source)
	pipe_manager.call("register_fluid_source", source, source_cell, PipeSegment.Category.WATER, Vector2i.LEFT)
	_expect(greenhouse.is_water_connected() and greenhouse.has_water_source() and input_pipe.category == PipeSegment.Category.WATER and source_pipe.category == PipeSegment.Category.WATER, "Una linea diretta trivella-acqua deve alimentare la serra e colorare tutta la rete in blu")
	_expect(int(root.get_node("PowerGrid").get("consumers").filter(func(entry): return entry.get("node") == greenhouse).size()) == 1, "La serra deve essere registrata come consumatore elettrico")
	_expect(not greenhouse.is_network_enabled() and not greenhouse.powered, "La serra deve partire scollegata: l'elettricità si abilita solo dal pannello manuale")
	greenhouse.set_network_enabled(false)
	root.get_node("PowerGrid").call("rebuild_network")
	_expect(not greenhouse.is_network_enabled() and greenhouse.get_connection_label() == "RETE SERRA DISATTIVATA" and not greenhouse.powered, "Vicino alla serra il player deve poter scegliere di scollegarla dalla corrente")
	greenhouse.set_network_enabled(true)
	root.get_node("PowerGrid").call("rebuild_network")
	_expect(greenhouse.is_network_enabled(), "La serra deve poter essere ricollegata volontariamente alla corrente")

	_expect(bool(inventory.call("add_item", "potato_seeds", "Semi di patate (lotto)", 1, false)), "I semi devono poter essere ricevuti nell'inventario")
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "E dentro la serra deve seminare il lotto di patate")
	_expect(greenhouse.is_planted() and greenhouse.get_crop_stage() == 0 and int(inventory.call("count_item", "potato_seeds")) == 0, "La semina deve consumare un lotto e mostrare il primo stadio")
	_expect((first_crop.texture as AtlasTexture).atlas.get_image().get_pixel(0, 0).a <= 0.01, "La pianta deve avere fondo trasparente e sovrapporsi alla terra senza sostituirla")
	_expect((first_crop.texture as AtlasTexture).atlas.get_image().get_pixel(8, 11).a >= 0.99, "Il primo stadio della pianta deve restare visibile sopra la terra")
	source.available_liters = 0.0
	greenhouse.call("_update_crop_growth", 30.0)
	_expect(is_equal_approx(float(greenhouse.get("_growth_seconds")), 0.0), "Senza flusso d'acqua la coltura non deve avanzare anche se il tubo è presente")
	source.available_liters = 10_000.0
	greenhouse.call("_update_crop_growth", Greenhouse.FIRST_CYCLE_SECONDS - 1.0)
	_expect(not greenhouse.is_crop_ready(), "La prima coltura non deve essere pronta prima di 5 minuti")
	greenhouse.call("_update_crop_growth", 1.0)
	_expect(greenhouse.is_crop_ready() and greenhouse.get_crop_stage() == 4, "Il quinto frame deve indicare la prima raccolta pronta dopo 5 minuti")
	player.global_position = greenhouse.global_position + Vector2(300.0, 0.0)
	greenhouse.oxygen_reserve = 10.0
	greenhouse.call("_update_greenhouse_oxygen", 1.0)
	_expect(float(greenhouse.oxygen_reserve) > 10.0 and greenhouse.has_breathable_atmosphere(), "Le 16 piante mature devono produrre una piccola quantità di O₂ nella serra")
	greenhouse.call("_update_greenhouse_oxygen", 1_000.0)
	_expect(float(greenhouse.oxygen_reserve) <= Greenhouse.GREENHOUSE_OXYGEN_CAPACITY, "L'ossigeno prodotto dalle piante deve avere una capacità massima, non essere infinito")
	player.global_position = greenhouse.global_position
	var food_before := int(inventory.call("count_item", "food_ration"))
	greenhouse.call("_try_harvest_nearby")
	_expect(int(inventory.call("count_item", "food_ration")) == food_before + Greenhouse.HARVEST_FOOD, "Una raccolta vicina deve consegnare tutte e 16 le razioni nello slot cibo")
	var food_slot: Dictionary = inventory.get("hotbar")[4]
	_expect(str(food_slot.get("id", "")) == "food_ration" and int(food_slot.get("count", 0)) == food_before + Greenhouse.HARVEST_FOOD, "Le 16 patate devono finire proprio nello slot delle razioni")
	_expect(greenhouse.is_planted() and not greenhouse.is_crop_ready() and greenhouse.get_crop_stage() == 0, "Dopo il raccolto le piante devono restare seminate per la crescita successiva")
	greenhouse.set_powered(true)
	root.get_node("WorldClock").call("set_game_hour", 23.0)
	greenhouse.call("_update_night_lighting")
	_expect(bool(greenhouse.get_node("GreenhouseNightLight").visible) and bool(greenhouse.get_node("GreenhouseLampGlow").visible), "Di notte una serra alimentata deve accendere la luce interna")
	greenhouse.call("_update_crop_growth", 45.0)
	var remaining_before_disconnect := float(greenhouse.call("get_remaining_growth_seconds"))
	greenhouse.set_powered(false)
	_expect(is_equal_approx(float(greenhouse.call("get_remaining_growth_seconds")), remaining_before_disconnect), "Scollegare la serra non deve restituire il tempo guadagnato con la corrente")
	greenhouse.call("_update_crop_growth", 10.0)
	var remaining_after_unpowered_growth := float(greenhouse.call("get_remaining_growth_seconds"))
	_expect(is_equal_approx(remaining_after_unpowered_growth, remaining_before_disconnect - 10.0), "Senza corrente deve avanzare solo il tempo reale residuo")
	greenhouse.set_powered(true)
	_expect(is_equal_approx(float(greenhouse.call("get_remaining_growth_seconds")), remaining_after_unpowered_growth), "Ricollegare la serra non deve applicare il bonus retroattivamente")
	greenhouse.call("_update_crop_growth", remaining_after_unpowered_growth / 1.60 - 0.1)
	_expect(not greenhouse.is_crop_ready(), "La ricrescita alimentata non deve completarsi prima del tempo ridotto")
	greenhouse.call("_update_crop_growth", 0.1)
	_expect(greenhouse.is_crop_ready(), "Con elettricità la ricrescita deve completarsi con il bonus del 60%")
	_expect(is_equal_approx(greenhouse.get_power_demand_kw(), Greenhouse.POWER_DEMAND_KW + Greenhouse.POWERED_EXTRA_DEMAND_KW), "La serra alimentata deve aumentare il consumo elettrico")
	_expect(float(greenhouse.get("_water_consumed_liters")) > 0.0 and source.available_liters < 10_000.0, "La crescita deve prelevare acqua reale dalla sorgente collegata")
	greenhouse.set_powered(false)
	greenhouse.call("_update_night_lighting")
	_expect(not bool(greenhouse.get_node("GreenhouseNightLight").visible), "Se stacchi l'elettricità la luce notturna della serra deve spegnersi")

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
		_expect(greenhouse.handle_airlock_key(player, keycode), "La sequenza della camera serra deve accettare i tasti mostrati")


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
