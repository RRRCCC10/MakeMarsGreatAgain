extends SceneTree

## Verifica il traguardo conclusivo senza dipendere da input o UI: ogni
## litologia deve entrare nel manifesto, il campione biologico deve essere
## richiesto, e il lancio deve aspettare propellente Sabatier reale.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var landing = current_scene.get_node_or_null("LandingSequence")
	var inventory = root.get_node_or_null("Inventory")
	_expect(landing != null, "La scena deve contenere il razzo di ritorno")
	_expect(inventory != null, "Il manifesto deve usare l'inventario della missione")
	if landing == null or inventory == null:
		_finish()
		return

	inventory.reset_for_new_mission()
	var catalog: Array[Dictionary] = landing.get_return_manifest_catalog()
	_expect(catalog.size() > 0, "Il manifesto deve richiedere ogni campione geologico")
	for definition in catalog:
		_expect(not str(definition.get("name", "")).is_empty(), "Ogni campione deve avere un nome leggibile")
		_expect(not str(definition.get("biome", "")).is_empty(), "Ogni campione deve indicare il bioma di provenienza")
		_expect(not str(definition.get("rarity", "")).is_empty(), "Ogni campione deve indicare la rarità")
		var item_id := str(definition.get("item_id", ""))
		_expect(not item_id.is_empty(), "Ogni campione deve avere un id inventario")
		if item_id.is_empty():
			continue
		_expect(bool(inventory.add_item(item_id, str(definition.get("name", "Campione")), 1, false)), "Il campione %s deve entrare nello zaino" % item_id)
		landing._load_available_return_samples()

	_expect(bool(inventory.add_alien_life_sample()), "Il campione biologico deve poter entrare nello zaino")
	landing._load_available_return_samples()
	var readiness: Dictionary = landing.get_return_readiness()
	_expect(int(readiness.get("geology_loaded", 0)) == catalog.size(), "Il manifesto deve sigillare tutti i campioni geologici")
	_expect(bool(readiness.get("life_loaded", false)), "Il manifesto deve richiedere e sigillare il campione biologico")
	_expect(not bool(readiness.get("ready", true)), "Senza Sabatier e metano il razzo non deve poter decollare")
	_expect(landing.manifest_list.text.contains(str(catalog[0].get("name", ""))), "Il manifesto a bordo deve mostrare i nomi dei campioni")
	_expect(landing.manifest_list.text.contains(str(catalog[0].get("biome", ""))), "Il manifesto a bordo deve mostrare il luogo di ritrovamento")
	_expect(landing.manifest_list.text.contains("CAMPIONE BIOLOGICO"), "Il manifesto a bordo deve mostrare il campione di vita aliena")

	var sabatier_marker := Node.new()
	landing.register_sabatier_operation(sabatier_marker)
	sabatier_marker.free()
	_expect(landing.sabatier_qualified, "La prima produzione effettiva del Sabatier deve qualificare la propulsione")
	_expect(is_equal_approx(landing.load_methane_kg(9999.0), landing.METHANE_CAPACITY_KG), "Il serbatoio deve accettare metano fino alla sua capacità")
	readiness = landing.get_return_readiness()
	_expect(bool(readiness.get("ready", false)), "Manifesto, Sabatier e serbatoio pieno devono rendere possibile il lancio")
	landing._try_launch_return()
	_expect(landing.return_launch_in_progress, "Il lancio deve iniziare solo dopo tutti i requisiti")
	landing._update_return_launch(landing.RETURN_LAUNCH_DURATION + 0.1)
	_expect(landing.return_launch_finished, "L'animazione del razzo deve chiudere la missione")
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
