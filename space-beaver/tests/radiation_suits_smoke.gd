extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		push_error("Impossibile caricare la scena principale")
		quit(1)
		return
	await process_frame
	await process_frame
	var inventory: Node = root.get_node("Inventory")
	var shop: Node = root.get_node("Shop")
	var delivery: Node = root.get_node("DeliveryManager")
	var economy: Node = root.get_node("Economy")
	var suits: Node = root.get_node("SuitSystem")
	var oxygen: Node = root.get_node("Oxygen")
	var radiation: Node = root.get_node("Radiation")
	var game_state: Node = root.get_node("GameState")

	_expect(str(suits.equipped_suit_id) == "suit_standard", "La missione deve iniziare con la tuta standard")
	_expect(inventory.count_item("suit_standard") == 1, "La tuta standard deve risultare di proprieta' della missione")
	_expect(_backpack_has_no_suits(inventory, suits), "La tuta standard non deve occupare lo zaino")
	_expect(is_equal_approx(float(oxygen.max_oxygen), 100.0), "La tuta standard deve contenere 100 unita' di ossigeno")
	_expect(current_scene.get_node_or_null("RadiationUI") != null, "Il dosimetro deve essere presente nella scena")

	economy.balance = 10_000_000_000
	_expect(shop.purchase("suit_reinforced"), "La tuta rinforzata deve poter essere ordinata")
	_expect(inventory.count_item("suit_reinforced") == 0, "La tuta ordinata non deve apparire subito nell'inventario")
	_expect(delivery.count_uncollected("suit_reinforced") == 1, "La tuta deve viaggiare nella capsula")
	delivery.call("_dispatch_pending_order")
	await process_frame
	var capsule: Node = delivery.active_capsules[0] if not delivery.active_capsules.is_empty() else null
	_expect(capsule != null, "L'ordine della tuta deve generare una capsula")
	if capsule != null:
		capsule.call("_land")
		capsule.call("collect_all")
		await process_frame
	_expect(inventory.count_item("suit_reinforced") == 1, "La tuta deve entrare nell'inventario solo dopo il ritiro")
	_expect(_backpack_has_no_suits(inventory, suits), "La tuta ritirata deve restare nello slot equipaggiamento separato")
	_expect(suits.call("equip", "suit_reinforced"), "La tuta acquistata deve poter essere equipaggiata")
	_expect(is_equal_approx(float(oxygen.max_oxygen), 130.0), "La tuta rinforzata deve portare la capacita' O2 a 130")
	_expect(float(oxygen.oxygen) > 129.0, "Una tuta nuova deve arrivare con la propria riserva piena")
	oxygen.oxygen = 111.0
	_expect(suits.call("equip", "suit_standard"), "Deve essere possibile riequipaggiare la tuta standard")
	_expect(suits.call("equip", "suit_reinforced"), "Deve essere possibile tornare alla tuta rinforzata")
	_expect(is_equal_approx(float(oxygen.oxygen), 111.0), "Cambiare tuta non deve ricaricare ossigeno all'infinito")
	_expect(not shop.purchase("suit_reinforced"), "Una tuta gia' posseduta non deve poter essere acquistata due volte")

	# Il fondo cosmico deve restare molto basso durante una normale uscita.
	radiation.call("reset_for_new_mission")
	radiation.call("_process", 200.0)
	_expect(float(radiation.cumulative_dose_msv) < 1.0, "Il fondo cosmico non deve punire una normale attivita' esterna")
	_expect(str(radiation.call("get_condition_label")) == "NOMINALE", "Una normale uscita deve lasciare l'astronauta nominale")

	# Confronto controllato sullo stesso picco solare.
	suits.call("equip", "suit_standard")
	radiation.call("reset_for_new_mission")
	radiation.call("force_event", "minor", true)
	for _step in 50:
		radiation.call("_process", 1.0)
	var standard_solar_dose := float(radiation.solar_dose_msv)
	inventory.add_item("suit_storm", "Tuta EVA Storm", 1, false)
	suits.call("equip", "suit_storm")
	radiation.call("reset_for_new_mission")
	radiation.call("force_event", "minor", true)
	for _step in 50:
		radiation.call("_process", 1.0)
	var storm_solar_dose := float(radiation.solar_dose_msv)
	_expect(standard_solar_dose > 70.0 and standard_solar_dose < 95.0, "Il picco minore deve fornire una dose moderata con la tuta standard")
	_expect(storm_solar_dose < standard_solar_dose * 0.45, "La tuta Storm deve ridurre davvero la dose del picco solare")

	radiation.acute_dose_msv = 750.0
	_expect(is_equal_approx(float(radiation.call("get_movement_multiplier")), 0.95), "Tra 500 e 1000 mSv la penalita' deve essere soltanto del 5%")
	radiation.acute_dose_msv = 1500.0
	_expect(is_equal_approx(float(radiation.call("get_movement_multiplier")), 0.90), "Tra 1000 e 2000 mSv la penalita' deve essere del 10%")
	radiation.acute_dose_msv = 3000.0
	_expect(is_equal_approx(float(radiation.call("get_movement_multiplier")), 0.80), "Tra 2000 e 4000 mSv la penalita' deve essere del 20%")
	radiation.acute_dose_msv = 4000.0
	_expect(bool(radiation.call("is_lethal")), "A 4000 mSv la dose acuta deve essere letale")
	var death_data: Dictionary = game_state.call("_get_death_data", "radiation")
	_expect(str(death_data.get("title", "")).contains("RADIOLOGICO"), "Deve esistere un finale custom per le radiazioni")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("RADIATION_SUITS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _backpack_has_no_suits(inventory: Node, suits: Node) -> bool:
	for item in inventory.backpack:
		if bool(suits.call("is_suit", str(item.get("id", "")))):
			return false
	return true
