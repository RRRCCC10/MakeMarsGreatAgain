extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		push_error("Unable to load the main scene")
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

	_expect(str(suits.equipped_suit_id) == "suit_standard", "Test assertion failed")
	_expect(inventory.count_item("suit_standard") == 1, "Test assertion failed")
	_expect(_backpack_has_no_suits(inventory, suits), "Test assertion failed")
	_expect(is_equal_approx(float(oxygen.max_oxygen), 100.0), "Test assertion failed")
	_expect(current_scene.get_node_or_null("RadiationUI") != null, "Test assertion failed")

	economy.balance = 10_000_000_000
	_expect(shop.purchase("suit_reinforced"), "Test assertion failed")
	_expect(inventory.count_item("suit_reinforced") == 0, "Test assertion failed")
	_expect(delivery.count_uncollected("suit_reinforced") == 1, "Test assertion failed")
	delivery.call("_dispatch_pending_order")
	await process_frame
	var capsule: Node = delivery.active_capsules[0] if not delivery.active_capsules.is_empty() else null
	_expect(capsule != null, "Test assertion failed")
	if capsule != null:
		capsule.call("_land")
		capsule.call("collect_all")
		await process_frame
	_expect(inventory.count_item("suit_reinforced") == 1, "Test assertion failed")
	_expect(_backpack_has_no_suits(inventory, suits), "Test assertion failed")
	_expect(suits.call("equip", "suit_reinforced"), "Test assertion failed")
	_expect(is_equal_approx(float(oxygen.max_oxygen), 130.0), "Test assertion failed")
	_expect(float(oxygen.oxygen) > 129.0, "Test assertion failed")
	oxygen.oxygen = 111.0
	_expect(suits.call("equip", "suit_standard"), "Test assertion failed")
	_expect(suits.call("equip", "suit_reinforced"), "Test assertion failed")
	_expect(is_equal_approx(float(oxygen.oxygen), 111.0), "Test assertion failed")
	_expect(not shop.purchase("suit_reinforced"), "Test assertion failed")

	radiation.call("reset_for_new_mission")
	radiation.call("_process", 200.0)
	_expect(float(radiation.cumulative_dose_msv) < 1.0, "Test assertion failed")
	_expect(str(radiation.call("get_condition_label")) == "NOMINAL", "Test assertion failed")

	suits.call("equip", "suit_standard")
	radiation.call("reset_for_new_mission")
	radiation.call("force_event", "minor", true)
	for _step in 50:
		radiation.call("_process", 1.0)
	var standard_solar_dose := float(radiation.solar_dose_msv)
	inventory.add_item("suit_storm", "Solar-Storm Suit", 1, false)
	suits.call("equip", "suit_storm")
	radiation.call("reset_for_new_mission")
	radiation.call("force_event", "minor", true)
	for _step in 50:
		radiation.call("_process", 1.0)
	var storm_solar_dose := float(radiation.solar_dose_msv)
	_expect(standard_solar_dose > 70.0 and standard_solar_dose < 95.0, "Test assertion failed")
	_expect(storm_solar_dose < standard_solar_dose * 0.45, "Test assertion failed")

	radiation.acute_dose_msv = 750.0
	_expect(is_equal_approx(float(radiation.call("get_movement_multiplier")), 0.95), "Test assertion failed")
	radiation.acute_dose_msv = 1500.0
	_expect(is_equal_approx(float(radiation.call("get_movement_multiplier")), 0.90), "Test assertion failed")
	radiation.acute_dose_msv = 3000.0
	_expect(is_equal_approx(float(radiation.call("get_movement_multiplier")), 0.80), "Test assertion failed")
	radiation.acute_dose_msv = 4000.0
	_expect(bool(radiation.call("is_lethal")), "Test assertion failed")
	var death_data: Dictionary = game_state.call("_get_death_data", "radiation")
	_expect(str(death_data.get("title", "")).contains("RADIATION DAMAGE"), "Test assertion failed")
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
