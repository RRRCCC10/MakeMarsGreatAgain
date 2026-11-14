extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var power_grid: Node = root.get_node("PowerGrid")
	var pipe_manager: Node = root.get_node("PipeManager")
	var clock: Node = root.get_node("WorldClock")
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Impossibile caricare la scena principale: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var main_scene: Node = current_scene
	var panel = power_grid.place_device(main_scene, "solar_panel", Vector2i(-8, 6))
	var transformer = power_grid.place_device(main_scene, "transformer", Vector2i(-2, 6))
	var battery = power_grid.place_device(main_scene, "battery", Vector2i(4, 6))
	var drill = power_grid.place_device(main_scene, "ice_drill", Vector2i(10, 6))
	_expect(drill != null, "La trivella deve poter essere posizionata")
	if drill == null:
		_finish()
		return
	_expect(not panel.is_network_enabled() and not transformer.is_network_enabled() and not battery.is_network_enabled() and not drill.is_network_enabled(), "I dispositivi appena piazzati devono essere disconnessi")
	panel.set_network_enabled(true)
	transformer.set_network_enabled(true)
	battery.set_network_enabled(true)
	drill.set_network_enabled(true)
	var output_cell := Vector2i(12, 6)
	var pipe = pipe_manager.place_pipe(main_scene, output_cell, 0, false)
	_expect(pipe != null, "Il tubo deve poter essere posizionato nella cella di uscita a destra")
	_expect(pipe != null and pipe.category == 2, "Il tubo collegato alla trivella deve diventare automaticamente acqua")
	_expect(pipe_manager.is_source_connected(drill), "L'uscita della trivella deve riconoscere il tubo orizzontale")

	clock.running = true
	clock.time_scale = 1.0
	clock.set_game_hour(12.0)
	power_grid.battery_energy_kwh = 100.0
	power_grid.rebuild_network()
	power_grid._update_energy(1.0)
	_expect(is_equal_approx(power_grid.demand_kw, 60.0), "La trivella collegata deve richiedere 60 kW")
	_expect(drill.powered, "La trivella deve ricevere alimentazione dalla rete")
	var frame_before: int = int(drill.animation_frame)
	drill._process(20.0)
	_expect(drill.animation_frame != frame_before, "La trivella alimentata deve animarsi")
	_expect(drill.water_extracted_liters >= 79.9, "In un'ora di gioco la trivella deve estrarre 80 L")
	_expect(drill.water_transported_liters >= 79.9, "Con il tubo collegato l'acqua deve essere trasportata")
	var specs: Dictionary = drill.get_machine_specs()
	_expect(str(specs.get("title", "")).contains("TRIVELLA"), "La scheda tecnica della trivella deve essere disponibile")
	var registry: Node = root.get_node("BuildableRegistry")
	var builder: Node = main_scene.get_node("player/Node")
	var player: Node2D = main_scene.get_node("player")
	player.global_position = drill.global_position
	builder.call("_update_nearby_machine_ui")
	_expect(builder.nearby_machine == drill, "Avvicinandosi deve essere selezionata la trivella nel menu rapido")
	_expect(builder.nearby_machine_root.visible, "Il menu rapido deve aprirsi vicino a un macchinario")
	builder.call("_toggle_nearby_network")
	_expect(not drill.is_network_enabled(), "V deve disconnettere il macchinario")
	_expect(not bool(power_grid.connection_ok.get(drill, false)), "La disconnessione deve rimuovere il collegamento elettrico")
	builder.call("_toggle_nearby_network")
	_expect(drill.is_network_enabled(), "V deve riconnettere il macchinario")
	_expect(bool(power_grid.connection_ok.get(drill, false)), "La riconnessione deve ricreare il collegamento elettrico")
	power_grid._update_energy(0.0)
	var inventory: Node = root.get_node("Inventory")
	inventory.call("select_hotbar", 3)
	var bottle: Dictionary = inventory.call("get_selected_item")
	bottle["liters"] = 0.3
	builder.call("_update_nearby_machine_ui")
	_expect(not builder.nearby_machine_root.visible, "Con la borraccia selezionata il pannello generico della trivella non deve coprire il comando di ricarica")
	var inventory_ui: Node = main_scene.get_node_or_null("InventoryUI")
	if inventory_ui != null:
		inventory_ui.call("_process", 0.0)
		_expect(str(inventory_ui.pickup_label.text).begins_with("E · RIEMPI BORRACCIA"), "Vicino alla trivella deve rimanere visibile solo il comando per riempire la borraccia")
	else:
		_expect(false, "L'interfaccia inventario deve essere disponibile per il prompt della borraccia")
	var water_before_refill := float(drill.water_storage_liters)
	var refill_event := InputEventKey.new()
	refill_event.keycode = KEY_E
	refill_event.pressed = true
	player.call("_unhandled_input", refill_event)
	_expect(is_equal_approx(float(bottle.get("liters", 0.0)), 2.0), "Con borraccia selezionata, E vicino alla trivella alimentata deve riempirla")
	_expect(float(drill.water_storage_liters) < water_before_refill, "Riempire la borraccia deve sottrarre acqua reale dalla riserva della trivella")
	# La riserva è acqua già estratta: il refill manuale non deve richiedere che
	# la trivella resti connessa alla rete elettrica.
	bottle["liters"] = 0.3
	drill.set_network_enabled(false)
	var reserve_before_unpowered_refill := float(drill.water_storage_liters)
	_expect(str(drill.get_bottle_refill_prompt()).begins_with("E · RIEMPI BORRACCIA"), "Una trivella scollegata ma con acqua in riserva deve mostrare il comando di refill")
	_expect(drill.try_refill_selected_bottle(player), "Il refill deve essere accettato anche senza corrente")
	_expect(is_equal_approx(float(bottle.get("liters", 0.0)), 2.0) and float(drill.water_storage_liters) < reserve_before_unpowered_refill, "La borraccia deve poter usare la riserva della trivella scollegata")
	var drill_entry: Dictionary = registry.find_at(drill.global_position)
	builder.call("_show_machine_info", drill_entry)
	_expect(registry.is_modal_open, "Il click sul macchinario deve aprire una finestra modale")
	_expect(builder.machine_info_root.visible, "La finestra tecnica deve essere visibile")
	_expect(builder.machine_title.text.contains("TRIVELLA"), "La finestra deve mostrare i dati del macchinario selezionato")
	builder.call("_close_machine_info")
	clock.running = false
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("ICE_DRILL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
