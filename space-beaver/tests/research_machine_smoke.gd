extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
const RESEARCH_SCRIPT := preload("res://scripts/ResearchMachine.gd")

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
	var shop := root.get_node("Shop")
	var economy := root.get_node("Economy")
	var target_cell := Vector2i(620, 430)
	var dome := DOME_SCRIPT.place(current_scene, "dome_large", target_cell, 1) as Node2D
	_expect(dome != null, "Serve una cupola grande libera per testare la ricerca")
	if dome == null:
		_finish()
		return
	await process_frame
	var research_cell := Vector2i(floori((dome.global_position.x - 8.0) / 16.0), floori((dome.global_position.y - 32.0) / 16.0))
	var target_position := RESEARCH_SCRIPT.world_position_for("xrd_diffractometer", research_cell)
	player.global_position = dome.global_position + Vector2(300.0, 0.0)
	_expect(RESEARCH_SCRIPT.can_place_at("xrd_diffractometer", target_position), "Il diffrattometro deve potersi piazzare dentro una cupola grande")
	_expect(not RESEARCH_SCRIPT.can_place_at("xrd_diffractometer", dome.global_position + Vector2(300.0, 0.0)), "Un macchinario di ricerca non deve potersi piazzare fuori dalla cupola grande")
	# Non esiste più una dimensione minima per i laboratori: la cupola piccola
	# deve accettare tutti e tre i modelli, purché la loro impronta non si
	# sovrapponga a giocatore, rocce o altri oggetti.
	var small_dome := DOME_SCRIPT.place(current_scene, "dome_small", Vector2i(650, 430), 1) as Node2D
	_expect(small_dome != null, "Serve una cupola piccola libera per verificare i laboratori")
	if small_dome != null:
		var small_cell := Vector2i(floori((small_dome.global_position.x - 8.0) / 16.0), floori((small_dome.global_position.y - 8.0) / 16.0))
		for lab_id in ["xrd_diffractometer", "raman_spectrometer", "icp_ms"]:
			var small_target := RESEARCH_SCRIPT.world_position_for(lab_id, small_cell)
			_expect(RESEARCH_SCRIPT.can_place_at(lab_id, small_target), "%s deve potersi piazzare nella cupola piccola" % lab_id)
	var machine := RESEARCH_SCRIPT.place(current_scene, "xrd_diffractometer", research_cell) as Node2D
	_expect(machine != null and machine.get_node_or_null("ResearchMachineCollision") is StaticBody2D, "Il laboratorio deve avere sprite e hitbox")
	if machine == null:
		_finish()
		return
	_expect(machine.get_node("ResearchSprite").texture is Texture2D, "A riposo il diffrattometro deve usare lo sprite spento")
	_expect(Vector2i(machine.call("get_power_connection_cell")) == Vector2i(dome.call("get_power_connection_cell")), "Il laboratorio nella cupola grande deve usare il raccordo elettrico esterno della cupola")
	_expect(not RESEARCH_SCRIPT.can_place_at("raman_spectrometer", target_position), "Due laboratori non devono sovrapporsi")
	player.global_position = machine.global_position
	_expect(not RESEARCH_SCRIPT.can_place_at("raman_spectrometer", machine.global_position + Vector2(32.0, 0.0)), "Non si può piazzare un laboratorio sotto il giocatore")
	var analysis_before_upgrade := float(machine.call("get_analysis_seconds"))
	economy.call("add_funds", 3_000_000_000)
	for expected_level in range(1, 6):
		var upgrade_event := InputEventKey.new()
		upgrade_event.keycode = KEY_U
		upgrade_event.pressed = true
		player.call("_unhandled_input", upgrade_event)
		_expect(int(machine.get("upgrade_level")) == expected_level, "Il laboratorio deve memorizzare il livello upgrade %d" % expected_level)
	_expect(is_equal_approx(float(machine.call("get_analysis_seconds")), 40.0), "Al quinto upgrade l'analisi deve durare esattamente 40 secondi")
	_expect(float(machine.call("get_analysis_seconds")) < analysis_before_upgrade, "Ogni upgrade deve ridurre il tempo di analisi")
	_expect(not bool(machine.call("try_upgrade", player)), "Il sesto upgrade non deve essere acquistabile")
	inventory.reset_for_new_mission()
	_expect(inventory.add_rock("roccia_basaltica"), "Il campione di pietra deve entrare nell'inventario")
	_expect(bool(machine.call("try_interact", player)), "E vicino al laboratorio deve caricare un campione")
	_expect(int(machine.get("state")) == 1 and inventory.count_item("rock_roccia_basaltica") == 0, "L'analisi deve consumare esattamente una pietra")
	_expect(is_equal_approx(float(machine.call("get_power_demand_kw")), 240.0), "Durante l'analisi il laboratorio deve richiedere molta corrente")
	machine.call("set_powered", false)
	machine.set("study_elapsed", 5.0)
	machine.call("_process", 10.0)
	_expect(is_equal_approx(float(machine.get("study_elapsed")), 5.0), "Senza alimentazione l'analisi deve restare in pausa")
	machine.call("set_powered", true)
	machine.set("study_elapsed", float(machine.call("get_analysis_seconds")))
	machine.call("_process", 0.01)
	_expect(int(machine.get("state")) == 2, "Dopo il timer il rapporto deve risultare pronto")
	_expect(is_equal_approx(float(machine.call("get_power_demand_kw")), 0.0), "A rapporto pronto il laboratorio non deve più assorbire 240 kW")
	var balance_before := int(economy.get("balance"))
	_expect(bool(machine.call("try_interact", player)), "E deve inviare il rapporto finito alla Terra")
	_expect(int(machine.get("state")) == 0 and int(economy.get("balance")) == balance_before + int(machine.call("get_reward")), "La consegna alla Terra deve pagare la ricompensa scientifica")
	# Il ghiaccio profondo primordiale può essere analizzato da qualsiasi
	# laboratorio. Forziamo il risultato raro per verificare il ramo economico
	# della vita antica senza rendere il test dipendente dal caso.
	inventory.reset_for_new_mission()
	_expect(inventory.add_rock("ghiaccio_profondo_primordiale"), "Il ghiaccio profondo primordiale deve entrare nell'inventario")
	_expect(bool(machine.call("try_interact", player)), "Il laboratorio deve accettare il ghiaccio primordiale")
	_expect(bool(machine.get("sample_is_primordial_ice")) and is_equal_approx(float(machine.call("get_biosignature_chance")), 0.20), "XRD deve offrire il 20%% di probabilità per una biosignatura")
	machine.set("ancient_life_detected", true)
	machine.call("set_powered", true)
	machine.set("study_elapsed", float(machine.call("get_analysis_seconds")))
	machine.call("_process", 0.01)
	_expect(int(machine.get("state")) == 2 and int(machine.call("get_reward")) >= 10_000_000_000, "Una biosignatura deve rendere il rapporto eccezionalmente remunerativo")
	var life_balance_before := int(economy.get("balance"))
	_expect(bool(machine.call("try_interact", player)), "Il rapporto di vita antica deve poter essere consegnato alla Terra")
	_expect(int(economy.get("balance")) == life_balance_before + int(machine.call("get_reward")), "La prova di vita deve includere il bonus economico straordinario")
	var achievements := root.get_node("AchievementManager")
	_expect(int(achievements.call("get_progress", "deep_ice_study")) == 1 and int(achievements.call("get_progress", "ancient_life")) == 1 and int(achievements.call("get_progress", "life_relay")) == 1, "Il rapporto biologico deve avanzare l'intero ramo della vita antica")
	_expect(is_equal_approx(float(RESEARCH_SCRIPT.get_definition("raman_spectrometer").get("biosignature_chance", 0.0)), 0.35) and is_equal_approx(float(RESEARCH_SCRIPT.get_definition("icp_ms").get("biosignature_chance", 0.0)), 0.55), "Laboratori più avanzati devono avere una probabilità di rilevamento maggiore")
	for item_id in ["xrd_diffractometer", "raman_spectrometer", "icp_ms"]:
		var definition: Dictionary = shop.call("get_definition", item_id)
		_expect(bool(definition.get("placeable", false)) and str(definition.get("category", "")) == "research", "%s deve essere acquistabile nello shop ricerca" % item_id)
		_expect(RESEARCH_SCRIPT.get_icon_texture(item_id) is Texture2D, "%s deve avere lo sprite spento disponibile" % item_id)
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


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_MACHINE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("RESEARCH_MACHINE_SMOKE_FAIL: " + failure)
	quit(1)
