extends SceneTree

const ACHIEVEMENT_MANAGER := preload("res://scripts/AchievementManager.gd")

var failures: Array[String] = []
var reached_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ACHIEVEMENT_MANAGER.new()
	manager.set_persistence_enabled_for_test(false)
	manager.reset_runtime_for_test()
	manager.achievement_reached.connect(_on_achievement_reached)
	var definitions: Array = manager.get_ordered_definitions()
	_expect(definitions.size() >= 55, "Test assertion failed")
	_expect(manager.is_unlocked("first_base"), "Test assertion failed")
	_expect(manager.is_unlocked("first_field_sample") and manager.is_unlocked("first_horizon"), "Test assertion failed")
	_expect(not manager.is_unlocked("airlock_cycle"), "Test assertion failed")
	_expect(not manager.is_unlocked("stable_grid"), "Test assertion failed")
	_expect(not manager.is_unlocked("first_lab"), "Test assertion failed")

	manager.record("first_report")
	_expect(manager.is_reached("first_report"), "Test assertion failed")
	_expect(not manager.is_claimable("first_report"), "Test assertion failed")
	_expect(reached_events.size() == 1 and str(reached_events[0].get("id", "")) == "first_report" and not bool(reached_events[0].get("claimable", true)), "Test assertion failed")
	manager.record_research_report("xrd_diffractometer", "sample_a", "Pianura di atterraggio", "rare")
	manager.record_research_report("xrd_diffractometer", "sample_b", "Pianura di atterraggio", "common")
	manager.record_research_report("xrd_diffractometer", "sample_c", "Cratere roccioso", "common")
	_expect(manager.get_progress("xrd_fieldwork") == 3, "Test assertion failed")
	_expect(manager.get_progress("rare_signal") == 1 and manager.get_progress("regional_atlas") == 2, "Test assertion failed")
	_expect(manager.get_progress("chain_of_custody") == 3 and manager.get_progress("data_convoy") == 3, "Test assertion failed")
	_expect(not manager.is_unlocked("science_center"), "Test assertion failed")
	manager.record_field_sample("roccia_rossa", "common")
	manager.record_field_sample("roccia_grigia", "common")
	manager.record_field_sample("roccia_scura", "rare")
	_expect(manager.is_reached("field_notes") and manager.is_reached("surface_catalog") and manager.is_reached("surface_anomaly"), "Test assertion failed")
	manager.record_exploration_source(0)
	manager.record_exploration_source(1)
	manager.record_exploration_source(4)
	_expect(manager.is_reached("biome_survey") and manager.is_reached("polar_expedition"), "Test assertion failed")
	manager.record_photo_transmission({"source_id": 0, "tags": ["panorama"]})
	manager.record_photo_transmission({"source_id": 3, "tags": ["rock", "dawn_ice"]})
	manager.record_photo_transmission({"source_id": 4, "tags": ["polar", "rare_rock", "night_sky"]})
	_expect(manager.is_reached("contact_sheet") and manager.is_reached("biome_gallery"), "Test assertion failed")
	_expect(manager.is_reached("field_portrait") and manager.is_reached("rare_lens") and manager.is_reached("dawn_ice") and manager.is_reached("polar_light"), "Test assertion failed")
	manager.record_polar_drill()
	manager.record_primordial_ice_found()
	manager.record_deep_ice_study()
	manager.record_ancient_life_discovery()
	_expect(manager.is_reached("primordial_ice") and manager.is_reached("ancient_life") and manager.is_reached("life_relay"), "Test assertion failed")

	manager.record("first_base")
	_expect(reached_events.any(func(event: Dictionary) -> bool: return str(event.get("id", "")) == "first_base" and bool(event.get("claimable", false))), "Test assertion failed")
	_expect(manager.claim("first_base"), "Test assertion failed")
	_expect(manager.is_unlocked("airlock_cycle") and manager.is_unlocked("stable_grid"), "Test assertion failed")
	manager.record("stable_grid")
	_expect(manager.claim("stable_grid"), "Test assertion failed")
	_expect(manager.is_unlocked("greenhouse") and manager.is_unlocked("first_lab"), "Test assertion failed")
	_expect(not manager.is_unlocked("ice_drill"), "Test assertion failed")
	manager.record("airlock_cycle")
	_expect(manager.claim("airlock_cycle"), "Test assertion failed")
	_expect(manager.is_unlocked("ice_drill"), "Test assertion failed")
	_expect(manager.get_prerequisites("ice_drill").size() == 2 and manager.get_prerequisites("first_lab") == ["stable_grid"], "Test assertion failed")
	_expect(manager.get_prerequisites("first_extraction").size() == 2, "Test assertion failed")
	_expect(manager.get_prerequisites("science_center").size() == 5, "Test assertion failed")

	var pending_ids: Array[String] = []
	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		if not manager.is_claimed(achievement_id):
			pending_ids.append(achievement_id)
	while not pending_ids.is_empty():
		var claimed_this_pass := false
		for index in range(pending_ids.size() - 1, -1, -1):
			var pending_id := pending_ids[index]
			if not manager.is_reached(pending_id):
				manager.set_reached(pending_id)
			if not manager.is_unlocked(pending_id):
				continue
			_expect(manager.is_claimable(pending_id), "Test assertion failed")
			_expect(manager.claim(pending_id), "Test assertion failed")
			_expect(manager.is_claimed(pending_id), "Test assertion failed")
			pending_ids.remove_at(index)
			claimed_this_pass = true
		if claimed_this_pass:
			continue
		for blocked_id in pending_ids:
			_expect(false, "Test assertion failed")
		break

	_expect(manager.has_effect("water_efficiency") and is_equal_approx(manager.get_water_loss_multiplier(), 0.90), "Test assertion failed")
	_expect(manager.has_effect("crop_efficiency") and is_equal_approx(manager.get_crop_growth_multiplier(), 1.05), "Test assertion failed")
	_expect(manager.has_effect("research_bonus") and manager.get_research_reward_multiplier("xrd_diffractometer", "rare") > 1.5, "Test assertion failed")
	_expect(manager.has_badge("MARTIAN COLONIST") and manager.has_badge("SCIENTIFIC DIRECTOR"), "Test assertion failed")
	manager.free()
	var bonus_manager := ACHIEVEMENT_MANAGER.new()
	bonus_manager.reset_runtime_for_test()
	bonus_manager.record("first_base")
	bonus_manager.claim("first_base")
	bonus_manager.record("stable_grid")
	bonus_manager.claim("stable_grid")
	bonus_manager.record("first_lab")
	bonus_manager.claim("first_lab")
	bonus_manager.record("first_report")
	bonus_manager.claim("first_report")
	_expect(is_equal_approx(bonus_manager.get_research_reward_multiplier(), 1.10), "Test assertion failed")
	bonus_manager.free()
	_finish()


func _on_achievement_reached(achievement_id: String, claimable_now: bool) -> void:
	reached_events.append({"id": achievement_id, "claimable": claimable_now})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ACHIEVEMENT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("ACHIEVEMENT_SMOKE_FAIL: " + failure)
	quit(1)
