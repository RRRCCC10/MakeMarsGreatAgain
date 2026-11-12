extends SceneTree

const ACHIEVEMENT_MANAGER := preload("res://scripts/AchievementManager.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ACHIEVEMENT_MANAGER.new()
	manager.set_persistence_enabled_for_test(false)
	manager.reset_runtime_for_test()
	var definitions: Array = manager.get_ordered_definitions()
	_expect(definitions.size() >= 40, "La tavola deve ospitare contratti a piedi, ricerca industriale e il ramo della vita antica")
	_expect(manager.is_unlocked("first_base"), "La prima tappa deve essere disponibile dall'inizio")
	_expect(manager.is_unlocked("first_field_sample") and manager.is_unlocked("first_horizon"), "Raccolta ed esplorazione devono essere disponibili senza rete o macchinari")
	_expect(not manager.is_unlocked("airlock_cycle"), "Il ramo sopravvivenza deve restare bloccato finché non viene riscattata la radice")
	_expect(not manager.is_unlocked("stable_grid"), "Il ramo habitat deve restare bloccato finché non viene riscattata la radice")
	_expect(not manager.is_unlocked("first_lab"), "Il ramo ricerca deve restare bloccato finché non viene riscattata la rete elettrica")

	# Il progresso di una tappa futura non si perde, ma la sua ricompensa non è
	# riscattabile prima dell'intera catena che la precede.
	manager.record("first_report")
	_expect(manager.is_reached("first_report"), "Un obiettivo futuro deve registrare il progresso anche da bloccato")
	_expect(not manager.is_claimable("first_report"), "Una ricompensa futura non deve essere riscattabile fuori ordine")
	manager.record_research_report("xrd_diffractometer", "sample_a", "Pianura di atterraggio", "rare")
	manager.record_research_report("xrd_diffractometer", "sample_b", "Pianura di atterraggio", "common")
	manager.record_research_report("xrd_diffractometer", "sample_c", "Cratere roccioso", "common")
	_expect(manager.get_progress("xrd_fieldwork") == 3, "I rapporti XRD devono avanzare il contratto della disciplina")
	_expect(manager.get_progress("rare_signal") == 1 and manager.get_progress("regional_atlas") == 2, "Rarità e biomi distinti devono alimentare contratti separati")
	_expect(manager.get_progress("chain_of_custody") == 3 and manager.get_progress("data_convoy") == 3, "Ogni rapporto deve alimentare i contratti di trasmissione")
	_expect(not manager.is_unlocked("science_center"), "Il nodo finale deve restare bloccato senza calibrazioni, ponte Terra e atlante")
	manager.record_field_sample("roccia_rossa", "common")
	manager.record_field_sample("roccia_grigia", "common")
	manager.record_field_sample("roccia_scura", "rare")
	_expect(manager.is_reached("field_notes") and manager.is_reached("surface_catalog") and manager.is_reached("surface_anomaly"), "Le missioni a piedi devono avanzare raccolta, catalogo e anomalia senza elettricità")
	manager.record_exploration_source(0)
	manager.record_exploration_source(1)
	manager.record_exploration_source(4)
	_expect(manager.is_reached("biome_survey") and manager.is_reached("polar_expedition"), "L'esplorazione del polo deve avanzare i contratti senza richiedere una rete")
	manager.record_polar_drill()
	manager.record_primordial_ice_found()
	manager.record_deep_ice_study()
	manager.record_ancient_life_discovery()
	_expect(manager.is_reached("primordial_ice") and manager.is_reached("ancient_life") and manager.is_reached("life_relay"), "Il ramo vita antica deve registrare trivella polare, ghiaccio e scoperta biologica")

	# Dopo la radice i tre rami sono indipendenti: si può avanzare nell'habitat
	# anche se il ciclo airlock non è stato ancora riscattato.
	manager.record("first_base")
	_expect(manager.claim("first_base"), "La radice deve poter essere riscossa")
	_expect(manager.is_unlocked("airlock_cycle") and manager.is_unlocked("stable_grid"), "La radice deve aprire i rami airlock e rete elettrica")
	manager.record("stable_grid")
	_expect(manager.claim("stable_grid"), "Il ramo habitat deve potersi riscattare indipendentemente")
	_expect(manager.is_unlocked("greenhouse") and manager.is_unlocked("first_lab"), "Serra e primo laboratorio devono dipendere dalla rete elettrica")
	_expect(not manager.is_unlocked("ice_drill"), "La trivella deve aspettare anche il ciclo airlock")
	manager.record("airlock_cycle")
	_expect(manager.claim("airlock_cycle"), "Il ciclo airlock deve potersi riscuotere nel suo ramo")
	_expect(manager.is_unlocked("ice_drill"), "La trivella deve sbloccarsi solo con airlock e rete elettrica riscossi")
	_expect(manager.get_prerequisites("ice_drill").size() == 2 and manager.get_prerequisites("first_lab") == ["stable_grid"], "Trivella e laboratorio devono avere i prerequisiti corretti")
	_expect(manager.get_prerequisites("first_extraction").size() == 2, "La trivella mineraria deve richiedere logistica d'acqua e laboratorio")
	_expect(manager.get_prerequisites("science_center").size() == 5, "Il direttorato deve richiedere i tre laboratori, ponte Terra e atlante")

	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		if manager.is_claimed(achievement_id):
			continue
		if not manager.is_reached(achievement_id):
			manager.set_reached(achievement_id)
		_expect(manager.is_unlocked(achievement_id), "%s deve sbloccarsi dopo la riscossione dei suoi prerequisiti" % achievement_id)
		_expect(manager.is_claimable(achievement_id), "%s deve luccicare/riscattarsi una volta raggiunto" % achievement_id)
		_expect(manager.claim(achievement_id), "La ricompensa di %s deve poter essere riscattata" % achievement_id)
		_expect(manager.is_claimed(achievement_id), "%s deve risultare colorato e riscosso dopo il click" % achievement_id)

	_expect(manager.has_effect("water_efficiency") and is_equal_approx(manager.get_water_loss_multiplier(), 0.90), "La ricompensa borraccia deve ridurre il consumo d'acqua del 10%")
	_expect(manager.has_effect("crop_efficiency") and is_equal_approx(manager.get_crop_growth_multiplier(), 1.05), "La ricompensa piantagione deve velocizzare le colture del 5%")
	_expect(manager.has_effect("research_bonus") and manager.get_research_reward_multiplier("xrd_diffractometer", "rare") > 1.5, "I contratti riscossi devono moltiplicare in modo sostanziale i ricavi della ricerca")
	_expect(manager.has_badge("COLONO MARZIANO") and manager.has_badge("DIRETTORE SCIENTIFICO"), "I badge delle tappe speciali devono essere salvati")
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
	_expect(is_equal_approx(bonus_manager.get_research_reward_multiplier(), 1.10), "Il primo segnale deve aumentare del 10% il valore di ogni rapporto")
	bonus_manager.free()
	_finish()


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
