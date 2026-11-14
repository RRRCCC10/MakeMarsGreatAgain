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
		_expect(not definition.is_empty() and bool(definition.get("placeable", false)), "%s deve essere acquistabile e piazzabile" % size_id)
		_expect(str(definition.get("category", "")) == "habitats", "%s deve comparire nella categoria habitat" % size_id)
	_expect(shop.call("get_definition", "rover").is_empty(), "Il rover non deve essere acquistabile nello shop generale")
	var shop_ui: Node = current_scene.get_node("ShopUI")
	shop.toggle()
	await process_frame
	var shop_tabs := shop_ui.get("catalog_view") as TabContainer
	_expect(shop_tabs != null and shop_tabs.get_tab_count() == 3, "Lo shop deve avere esattamente tre sezioni navigabili")
	if shop_tabs != null:
		_expect(shop_tabs.get_tab_title(0) == "TUTE", "La prima sezione dello shop deve chiamarsi TUTE")
		_expect(not shop_tabs.get_tab_title(0).contains("VEICOLI"), "Lo shop non deve più mostrare una sezione veicoli")
	shop_ui.call("_select_or_purchase", "dome_small")
	await process_frame
	_expect(bool(shop_ui.get("dome_config_view").visible), "Selezionando la cupola si deve aprire la scelta di configurazione")
	_expect(shop_ui.get("dome_config_image").texture == DOME_SCRIPT.EXTERIOR_TEXTURES["dome_small"], "La selezione deve mostrare l'immagine reale della cupola")
	_expect(bool(shop_ui.get("dome_rover_pad_checkbox").disabled), "La base rover deve essere disponibile solo per cupole medie e grandi")
	shop_ui.call("_close_dome_config")
	var shop_viewport_size := root.get_viewport().get_visible_rect().size
	var shop_panel := shop_ui.get_child(0).get_child(0).get_child(0) as PanelContainer
	_expect(shop_panel != null and shop_panel.size.y <= shop_viewport_size.y, "Il pannello shop deve restare entro l'altezza visibile")
	_expect(shop_tabs != null and shop_tabs.visible and shop_tabs.size.y <= shop_viewport_size.y, "Le tre sezioni shop devono rimanere visibili nel viewport")
	shop.close()

	var player := current_scene.get_node("player") as Node2D
	var original_player_position := player.global_position
	var preview := DOME_SCRIPT.new() as BaseDome
	preview.setup("dome_small", 1, true)
	current_scene.add_child(preview)
	preview.global_position = Vector2.ZERO
	await process_frame
	_expect(preview.get_node("DomeSprite").texture == DOME_SCRIPT.EXTERIOR_TEXTURES["dome_small"], "L'anteprima deve mostrare lo sprite esterno")
	_expect(int(preview.get_node("DomeSprite").z_index) >= 0, "L'anteprima deve essere disegnata sopra al terreno")
	_expect(not preview.is_in_group("base_domes") and not preview.is_in_group("pressurized_interiors"), "L'anteprima non deve risultare interagibile o pressurizzata")
	preview.queue_free()
	for direction in 4:
		var oriented_preview := DOME_SCRIPT.new() as BaseDome
		oriented_preview.setup("dome_small", direction, true)
		current_scene.add_child(oriented_preview)
		var direction_name: String = DOME_SCRIPT.DIRECTION_NAMES[direction]
		var expected_sheet: Texture2D = DOME_SCRIPT.DOOR_CLOSE_SHEETS[direction_name]
		var outer_visual := oriented_preview.get_node("OuterDoor") as Sprite2D
		var oriented_frame := outer_visual.texture as AtlasTexture
		_expect(oriented_frame != null and oriented_frame.atlas == expected_sheet, "La porta esterna deve usare lo spritesheet corretto verso %s" % direction_name)
		_expect(oriented_preview.get_node("AirlockCorridor").texture != null, "Il corridoio deve avere uno sprite anche verso %s" % direction_name)
		oriented_preview.queue_free()

	var dome_cell := Vector2i(620, 430)
	var dome_target := DOME_SCRIPT.world_position_for(dome_cell)
	player.global_position = dome_target
	_expect(not DOME_SCRIPT.can_place_at(dome_target, "dome_small", {}, 1), "Non si deve poter piazzare una cupola sopra il giocatore")
	player.global_position = original_player_position
	var blocking_rock := Node2D.new()
	blocking_rock.add_to_group("collectible_rocks")
	blocking_rock.global_position = dome_target
	current_scene.add_child(blocking_rock)
	_expect(not DOME_SCRIPT.can_place_at(dome_target, "dome_small", {}, 1), "Non si deve poter piazzare una cupola sopra una roccia")
	blocking_rock.free()
	await process_frame
	_expect(DOME_SCRIPT.can_place_at(dome_target, "dome_small", {}, 1), "Rimossa la roccia, la cupola deve tornare piazzabile")
	var dome := DOME_SCRIPT.place(current_scene, "dome_small", dome_cell, 1) as BaseDome
	_expect(dome != null, "La cupola piccola deve potersi piazzare in un'area libera")
	if dome == null:
		_finish()
		return
	await process_frame
	_expect(dome.is_in_group("pressurized_interiors"), "La struttura piazzata deve avere un interno pressurizzato")
	var registered_oxygen_port := false
	for input_port in pipe_manager.get("fluid_inputs"):
		if input_port.get("node") == dome and int(input_port.get("category", -1)) == PipeSegment.Category.OXYGEN:
			registered_oxygen_port = true
	_expect(registered_oxygen_port, "La cupola deve registrare un ingresso O₂ compatibile con la rete dei tubi")
	_expect(dome.get_oxygen_input_cell() == Vector2i(floori((dome.global_position.x + dome.get_radius() + 8.0) / 16.0), floori(dome.global_position.y / 16.0)), "L'attacco O₂ deve trovarsi sulla cella effettiva di collegamento")
	_expect(not DOME_SCRIPT.can_place_at(dome.global_position, "dome_small"), "Le cupole non devono sovrapporsi")
	_expect(dome.contains_world_point(dome.global_position), "Il centro della cupola deve essere considerato interno")
	var boundary := dome.get_node_or_null("DomeAndCorridorCollision") as StaticBody2D
	_expect(boundary != null and boundary.get_child_count() >= 60, "La cupola e il corridoio devono avere collisioni fisiche")
	var outer_frame := dome.get_node("OuterDoor").texture as AtlasTexture
	var corridor_frame := dome.get_node("AirlockCorridor").texture as AtlasTexture
	var door_depth := outer_frame.region.size.y
	_expect(is_equal_approx(dome.get_node("AirlockCorridor").position.length() - corridor_frame.region.size.y * 0.5, dome.get_radius()), "Il corridoio deve iniziare dalla parete della cupola")
	_expect(is_equal_approx(dome.get_node("OuterDoor").position.length() + door_depth * 0.5, dome.get_radius() + corridor_frame.region.size.y), "La porta esterna deve stare al termine del corridoio")
	_expect(not dome.is_in_corridor(dome.global_position + Vector2(0.0, dome.get_radius() + 16.0) + Vector2(30.0, 0.0)), "Le pareti laterali devono delimitare la hitbox del corridoio")

	var temperature: Node = root.get_node("Temperature")
	var shelter: Dictionary = temperature.call("_get_shelter_at", dome.global_position)
	_expect(float(shelter.get("bonus_c", 0.0)) > 0.0 and float(shelter.get("bonus_c", 0.0)) < 45.0, "La cupola non alimentata deve dare solo un piccolo riparo termico")
	dome.set_powered(true)
	shelter = temperature.call("_get_shelter_at", dome.global_position)
	_expect(float(shelter.get("bonus_c", 0.0)) >= 45.0, "La cupola alimentata deve riscaldare molto di piu'")
	dome.set_powered(false)
	var oxygen: Node = root.get_node("Oxygen")
	var oxygen_connector := dome.get_node_or_null("OxygenPipeAttachment") as Sprite2D
	_expect(oxygen_connector != null and oxygen_connector.texture is AtlasTexture, "L'attacco O₂ deve usare lo sprite reale del tubo")
	_expect(dome.get_node_or_null("HeaterPowerPortMarker") == null, "Il collegamento elettrico non deve avere un attacco visibile")
	if oxygen_connector != null and oxygen_connector.texture is AtlasTexture:
		var connector_frame := oxygen_connector.texture as AtlasTexture
		_expect(connector_frame.atlas == preload("res://sprites/machines/pipe-spritesheet.png") and connector_frame.region == Rect2(32.0, 0.0, 16.0, 16.0), "L'attacco O₂ deve avere la stessa grafica della cella di tubo arancione")
	_expect(not dome.is_oxygen_connected(), "Senza tubo la riserva di ossigeno non deve risultare collegata")
	# Ingresso: E apre la porta esterna, il giocatore entra a piedi nel tunnel,
	# F avvia la sequenza WASD e F apre il portello interno a sequenza completata.
	var saved_player_mask: int = player.collision_mask
	player.collision_mask = 1 # isola i test del tunnel dalle rocce casuali della mappa
	player.global_position = dome.get_corridor_center_position()
	_expect(not bool(dome.call("handle_airlock_key", player, KEY_F)), "Non si deve avviare la decompressione senza aver aperto la prima porta")
	player.global_position = dome.get_outer_door_position() + Vector2.DOWN * 26.0
	_expect(not bool(dome.call("handle_airlock_key", player, KEY_F)), "Non si deve avviare il ciclo prima di aprire la porta esterna")
	Input.action_press("move_up")
	for _frame in 8:
		await physics_frame
	Input.action_release("move_up")
	_expect((player.global_position - dome.global_position).y > dome.get_radius() + 24.0, "La porta chiusa deve bloccare fisicamente l'accesso al corridoio")
	_expect(bool(dome.call("handle_airlock_key", player, KEY_E)), "E vicino al varco esterno deve aprirlo")
	_expect(not bool(dome.call("handle_airlock_key", player, KEY_F)), "La sequenza deve attendere che il giocatore attraversi la prima porta")
	await _wait_door()
	_expect(dome.is_door_open("outer"), "L'animazione deve lasciare aperta la porta esterna")
	_expect(bool(dome.get_node("DomeAndCorridorCollision/OuterGate").disabled), "La hitbox del varco esterno deve sparire quando la porta e' aperta")
	Input.action_press("move_up")
	# La durata e' espressa in distanza, non nella precedente velocita' fissa
	# del giocatore: attraversiamo il varco anche con il passo calibrato a 64 px/s.
	for _frame in 48:
		await physics_frame
	Input.action_release("move_up")
	await process_frame
	await _wait_door()
	_expect((player.global_position - dome.global_position).y <= dome.get_radius() + 8.0, "Con il varco aperto il giocatore deve poter attraversarlo a piedi")
	_expect(not dome.is_door_open("outer"), "La porta esterna deve richiudersi dopo aver superato il varco")
	player.global_position = dome.get_corridor_center_position()
	Input.action_press("move_left")
	for _frame in 8:
		await physics_frame
	Input.action_release("move_left")
	_expect(absf(player.global_position.x - dome.global_position.x) < 10.0, "Le pareti laterali devono impedire di uscire dai lati del corridoio")
	player.global_position = dome.get_corridor_center_position() - Vector2.DOWN * 10.0
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("outer"), "La porta esterna deve chiudersi quando il giocatore entra nel corridoio")
	player.collision_mask = saved_player_mask
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "F nel corridoio deve avviare la sequenza")
	_expect(dome.is_sequence_active(), "La sequenza di pressurizzazione deve risultare attiva")
	_expect(not player.is_physics_processing(), "Durante il minigioco il giocatore deve restare fermo")
	_expect(str(dome.call("get_prompt_for_player", player)).contains("WASD"), "A schermo devono apparire le istruzioni dei tasti")
	_complete_sequence(dome, player)
	_expect(dome.is_sequence_complete(), "La sequenza corretta deve completare la pressurizzazione")
	_expect(player.is_physics_processing(), "Il movimento deve riattivarsi dopo la sequenza")
	player.global_position = dome.get_inner_door_position()
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "F completato vicino al varco interno deve aprirlo")
	await _wait_door()
	_expect(dome.is_door_open("inner"), "La porta interna deve aprirsi dopo la pressurizzazione")
	player.global_position = dome.global_position + Vector2.DOWN * (dome.get_radius() - 25.0)
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("inner"), "La porta interna deve richiudersi quando il giocatore entra nella cupola")
	_expect(dome.contains_world_point(player.global_position), "Il giocatore deve poter attraversare il varco interno")
	player.global_position = dome.get_outer_door_position() + Vector2.DOWN * 26.0
	dome.oxygen_reserve = BaseDome.INITIAL_OXYGEN_UNITS
	var reserve_before_passive := dome.oxygen_reserve
	dome.call("_update_oxygen_reserve", 5.0)
	_expect(is_equal_approx(float(dome.oxygen_reserve), reserve_before_passive - BaseDome.OXYGEN_PASSIVE_LOSS_PER_SECOND * 5.0), "La riserva deve perdere ossigeno passivamente anche senza occupanti")
	player.global_position = dome.global_position
	_expect(is_equal_approx(dome.get_oxygen_loss_rate(), BaseDome.OXYGEN_PASSIVE_LOSS_PER_SECOND + BaseDome.OXYGEN_OCCUPANT_LOSS_PER_SECOND), "La presenza del giocatore deve aggiungere consumo d'ossigeno")
	var reserve_before_occupied := dome.oxygen_reserve
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(is_equal_approx(float(dome.oxygen_reserve), reserve_before_occupied - dome.get_oxygen_loss_rate() * 0.25), "Il consumo della cupola deve essere effettivamente maggiore quando occupata")
	oxygen.oxygen = 20.0
	oxygen.call("_process", 0.25)
	_expect(is_equal_approx(float(oxygen.oxygen), float(oxygen.max_oxygen)), "La riserva iniziale deve mantenere respirabile la cupola e ricaricare la tuta")
	dome.oxygen_reserve = 0.0
	oxygen.oxygen = 20.0
	oxygen.call("_process", 0.25)
	_expect(float(oxygen.oxygen) < 20.0, "Quando la riserva della cupola finisce, l'ossigeno della tuta deve consumarsi anche al suo interno")
	dome.oxygen_reserve = BaseDome.INITIAL_OXYGEN_UNITS
	dome.call("_process", 0.0)
	_expect(dome.get_node("DomeSprite").texture == DOME_SCRIPT.INTERIOR_TEXTURES["dome_small"], "Entrando deve essere mostrato lo sprite interno")

	# Uscita inversa: E apre il portello interno, F dopo decompressione apre quello esterno.
	player.global_position = dome.global_position + Vector2.DOWN * (dome.get_radius() - 25.0)
	_expect(bool(dome.call("handle_airlock_key", player, KEY_E)), "In uscita E deve aprire la porta interna")
	await _wait_door()
	player.global_position = dome.get_corridor_center_position()
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("inner"), "In uscita la porta interna deve chiudersi dietro al giocatore")
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "F nel corridoio deve avviare la decompressione")
	_complete_sequence(dome, player)
	_expect(dome.is_sequence_complete(), "La sequenza inversa deve completare la decompressione")
	player.global_position = dome.get_outer_door_position()
	_expect(bool(dome.call("handle_airlock_key", player, KEY_F)), "In uscita F deve aprire la porta esterna dopo la sequenza")
	await _wait_door()
	player.global_position = dome.get_outer_door_position() + Vector2.DOWN * 26.0
	await process_frame
	await _wait_door()
	_expect(not dome.is_door_open("outer"), "La porta esterna deve richiudersi quando si esce")
	oxygen.call("_process", 0.25)
	_expect(float(oxygen.oxygen) < float(oxygen.max_oxygen), "Fuori dalla cupola l'ossigeno deve tornare a consumarsi")
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
	_expect(dome.is_oxygen_connected(), "Un tubo O₂ collegato alla porta esterna deve rifornire la cupola")
	player.global_position = dome.global_position
	dome.oxygen_reserve = 0.0
	electrolyzer.oxygen_flow_kg = 0.0
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(is_equal_approx(float(dome.oxygen_reserve), 0.0), "Un tubo collegato senza flusso non deve rifornire la cupola")
	electrolyzer.oxygen_flow_kg = 10.0
	dome.oxygen_reserve = 179.2
	var reserve_before_recharge := dome.oxygen_reserve
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(float(dome.oxygen_reserve) > reserve_before_recharge, "Il tubo deve aumentare la riserva verso il pieno, non solo pareggiare il consumo")
	dome.oxygen_reserve = 0.0
	oxygen.oxygen = 20.0
	dome.call("_update_oxygen_reserve", 0.25)
	_expect(electrolyzer.oxygen_flow_kg < 10.0, "Il rifornimento deve prelevare una quantità reale dalla sorgente collegata")
	oxygen.call("_process", 0.25)
	_expect(is_equal_approx(float(oxygen.oxygen), float(oxygen.max_oxygen)), "La rete O₂ connessa deve mantenere respirabile l'interno")
	_expect(dome.oxygen_reserve > 0.0, "Il tubo collegato deve ricaricare la riserva della cupola")
	_expect(bool(dome.call("handle_oxygen_port_right_click", oxygen_connector.global_position)), "Il raccordo O₂ deve aprire il pannello di stato con il tasto destro")
	_expect(str(dome.get("_dome_status_label").text).contains("Autonomia stimata") and str(dome.get("_dome_status_label").text).contains("Sorgente/i"), "Il pannello deve mostrare dati completi sulla cupola e la rete O₂")
	pipe_manager.call("unregister_fluid_source", electrolyzer)
	registered_pipes.erase(port_cell)
	registered_pipes.erase(source_cell)
	port_pipe.queue_free()
	source_pipe.queue_free()
	electrolyzer.queue_free()

	root.get_node("Economy").call("reset_for_new_mission")
	_expect(bool(shop.call("purchase", "dome_small")), "Lo shop deve completare l'acquisto della cupola")
	_expect(int(root.get_node("DeliveryManager").call("count_uncollected", "dome_small")) > 0, "La cupola acquistata deve arrivare tramite consegna")
	root.get_node("Economy").call("reset_for_new_mission")
	var configured_options := {"lead_shielding": true, "hydrogen_shielding": true, "rover_pad": true}
	_expect(int(shop.call("get_dome_total_price", "dome_medium", configured_options)) == 3_850_000_000, "Il prezzo configurato deve includere cupola e addon")
	shop.toggle()
	await process_frame
	shop_ui.call("_select_or_purchase", "dome_medium")
	await process_frame
	shop_ui.get("dome_lead_checkbox").button_pressed = true
	shop_ui.get("dome_hydrogen_checkbox").button_pressed = true
	shop_ui.get("dome_rover_pad_checkbox").button_pressed = true
	shop_ui.call("_refresh_dome_config_price")
	_expect(str(shop_ui.get("dome_config_total").text).contains(str(root.get_node("Economy").call("format_money", 3_850_000_000))), "La configurazione visuale deve aggiornare il totale con i moduli selezionati")
	shop_ui.call("_confirm_dome_purchase")
	var queued_configuration: Dictionary = {}
	for queued_item in root.get_node("DeliveryManager").get("pending_order").values():
		if str(queued_item.get("id", "")) == "dome_medium":
			queued_configuration = queued_item.get("configuration", {})
	_expect(queued_configuration == configured_options, "La configurazione deve conservarsi nell'ordine di consegna")
	shop.close()
	var configured_capsule := DeliveryCapsule.new()
	configured_capsule.setup([{"id": "dome_medium", "name": "Cupola media configurata", "count": 1, "placeable": true, "configuration": configured_options}], Vector2(11_000, 11_000))
	current_scene.add_child(configured_capsule)
	configured_capsule.set("state", DeliveryCapsule.State.LANDED)
	_expect(bool(configured_capsule.call("collect_all")), "La capsula deve consegnare la cupola configurata nell'inventario")
	var inventory: Node = root.get_node("Inventory")
	var delivered_configuration: Dictionary = {}
	for item in inventory.get("backpack"):
		if str(item.get("id", "")) == "dome_medium":
			delivered_configuration = item.get("configuration", {})
	_expect(delivered_configuration == configured_options, "L'inventario deve conservare le schermature e la base rover dopo il ritiro")
	var configured_dome := DOME_SCRIPT.new() as BaseDome
	configured_dome.setup("dome_medium", 1, false, configured_options)
	current_scene.add_child(configured_dome)
	configured_dome.global_position = Vector2(12_000, 12_000)
	await process_frame
	_expect(configured_dome.has_rover_charging_pad() and configured_dome.get_node_or_null("RoverChargingPad") != null, "La base rover deve essere visualizzata accanto alla cupola")
	var pad_area := configured_dome.get_node_or_null("RoverPadInteractionArea") as Area2D
	_expect(pad_area != null and pad_area.get_node_or_null("RoverPadHitbox") is CollisionShape2D, "La base rover deve avere una hitbox di interazione reale")
	var pad_body := configured_dome.get_node_or_null("RoverPadBody") as StaticBody2D
	_expect(pad_body != null and pad_body.get_node_or_null("RoverPadCollision") is CollisionShape2D and pad_body.collision_layer == 2, "La base rover deve avere una collisione fisica per il player")
	player.global_position = configured_dome.global_position
	_expect(is_equal_approx(configured_dome.get_cosmic_radiation_protection(), 1.0 - 0.92 * 0.65), "Le schermature selezionate devono ridurre i raggi cosmici all'interno")
	_expect(is_equal_approx(configured_dome.get_solar_radiation_protection(), 1.0 - 0.75 * 0.88), "Le schermature selezionate devono ridurre la dose solare all'interno")
	var radiation: Node = root.get_node("Radiation")
	_expect(is_equal_approx(float(radiation.call("_get_dome_radiation_protection", "get_cosmic_radiation_protection")), configured_dome.get_cosmic_radiation_protection()), "Il sistema di radiazione deve applicare la schermatura cosmica della cupola")
	_expect(is_equal_approx(float(radiation.call("_get_dome_radiation_protection", "get_solar_radiation_protection")), configured_dome.get_solar_radiation_protection()), "Il sistema di radiazione deve applicare la schermatura solare della cupola")
	player.global_position = configured_dome.get_rover_pad_position()
	for existing_rover in get_nodes_in_group("rovers"):
		existing_rover.queue_free()
	await process_frame
	root.get_node("Economy").call("add_funds", 5_000_000_000)
	var funds_before_rover_purchase := int(root.get_node("Economy").get("balance"))
	_expect(bool(configured_dome.call("_player_is_at_rover_pad", player)), "Il player deve poter raggiungere l'area di interazione del dock")
	_expect(bool(configured_dome.call("handle_airlock_key", player, KEY_E)), "Il rover deve potersi acquistare dalla base dedicata")
	_expect(BaseDome.ROVER_PURCHASE_COST > BaseDome.ROVER_RECALL_COST, "Comprare il rover deve costare più del richiamo")
	_expect(int(root.get_node("Economy").get("balance")) == funds_before_rover_purchase - BaseDome.ROVER_PURCHASE_COST, "L'acquisto alla base deve addebitare il costo del rover (prima %d, dopo %d)" % [funds_before_rover_purchase, int(root.get_node("Economy").get("balance"))])
	var rovers: Array = get_nodes_in_group("rovers")
	var base_rover := rovers.back() as Rover if not rovers.is_empty() else null
	await process_frame
	_expect(base_rover != null and configured_dome.is_rover_on_charging_pad(base_rover), "Il rover acquistato deve apparire sulla base di ricarica")
	if base_rover != null:
		base_rover.facing_index = 3
		base_rover.sprite.visible = false
		configured_dome.call("_update_rover_pad_status")
		_expect(base_rover.z_index > int(configured_dome.get_node("RoverChargingPad").z_index), "Il rover attraccato deve essere disegnato sopra la piattaforma per restare visibile")
		_expect(base_rover.facing_index == 0 and base_rover.sprite.visible, "Un rover già presente sul dock deve ripristinare sprite laterale visibile")
		_expect(bool(configured_dome.get_node("RoverPadStatus").visible), "Il dock deve mostrare stato e batteria del rover attraccato")
		_expect(not bool(configured_dome.call("_handle_rover_pad_action", player)), "Il dock non deve consumare E quando il rover è già attraccato")
		var board_event := InputEventKey.new()
		board_event.keycode = KEY_E
		board_event.pressed = true
		player.call("_input", board_event)
		_expect(bool(player.call("is_driving_rover")), "Premendo E vicino al rover attraccato il player deve salirci")
		if bool(player.call("is_driving_rover")):
			base_rover.call("exit_rover")
	if base_rover != null:
		base_rover.battery_energy_kwh = 10.0
		configured_dome.set_powered(true)
		root.get_node("PowerGrid").get("connection_ok")[configured_dome] = true
		_expect(is_equal_approx(float(configured_dome.call("get_rover_pad_charge_rate_kw")), BaseDome.ROVER_PAD_CHARGE_KW), "La base alimentata deve fornire ricarica rapida")
		base_rover.call("_charge_from_solar", 10.0)
		_expect(float(base_rover.battery_energy_kwh) > 10.0, "La ricarica dalla base deve aumentare la batteria")
		base_rover.global_position += Vector2(300.0, 0.0)
		player.global_position = configured_dome.get_rover_pad_position()
		var funds_before_recall := int(root.get_node("Economy").get("balance"))
		_expect(bool(configured_dome.call("handle_airlock_key", player, KEY_E)), "Un rover lontano deve poter essere richiamato pagando")
		_expect(configured_dome.is_rover_on_charging_pad(base_rover), "Il richiamo deve riportare il rover alla base")
		_expect(int(root.get_node("Economy").get("balance")) == funds_before_recall - BaseDome.ROVER_RECALL_COST, "Il richiamo deve addebitare la tariffa senza alterare la carica")
	_finish()


func _complete_sequence(dome: BaseDome, player: Node2D) -> void:
	var keys: Array[int] = dome.get_sequence_keys()
	for keycode in keys:
		_expect(bool(dome.call("handle_airlock_key", player, keycode)), "La sequenza deve accettare i tasti direzionali indicati")


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
		failures.append(message)
