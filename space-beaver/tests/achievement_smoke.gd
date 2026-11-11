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
	_expect(definitions.size() >= 14, "La tavola deve avere tutti i nodi della missione dopo la rimozione della cupola grande")
	_expect(manager.is_unlocked("first_base"), "La prima tappa deve essere disponibile dall'inizio")
	_expect(not manager.is_unlocked("airlock_cycle"), "Il ramo sopravvivenza deve restare bloccato finché non viene riscattata la radice")
	_expect(not manager.is_unlocked("stable_grid"), "Il ramo habitat deve restare bloccato finché non viene riscattata la radice")
	_expect(not manager.is_unlocked("first_lab"), "Il ramo ricerca deve restare bloccato finché non viene riscattata la rete elettrica")

	# Il progresso di una tappa futura non si perde, ma la sua ricompensa non è
	# riscattabile prima dell'intera catena che la precede.
	manager.record("first_report")
	_expect(manager.is_reached("first_report"), "Un obiettivo futuro deve registrare il progresso anche da bloccato")
	_expect(not manager.is_claimable("first_report"), "Una ricompensa futura non deve essere riscattabile fuori ordine")
	manager.record("xrd_master")
	manager.record("raman_master")
	manager.record("icp_master")
	_expect(manager.is_reached("science_center"), "Il centro scientifico deve avanzare quando tutti e tre i laboratori arrivano al massimo")
	_expect(not manager.is_unlocked("science_center"), "Il nodo finale deve rispettare tutti i prerequisiti anche se il suo requisito è già completo")

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
	_expect(manager.get_prerequisites("ice_drill").size() == 2 and manager.get_prerequisites("first_lab") == ["stable_grid"], "Trivella e laboratorio devono avere i nuovi prerequisiti")
	_expect(manager.get_prerequisites("science_center").size() == 3, "Il centro scientifico deve richiedere i tre laboratori")

	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		if manager.is_claimed(achievement_id):
			continue
		if not manager.is_reached(achievement_id):
			manager.record(achievement_id)
		_expect(manager.is_unlocked(achievement_id), "%s deve sbloccarsi dopo la riscossione dei suoi prerequisiti" % achievement_id)
		_expect(manager.is_claimable(achievement_id), "%s deve luccicare/riscattarsi una volta raggiunto" % achievement_id)
		_expect(manager.claim(achievement_id), "La ricompensa di %s deve poter essere riscattata" % achievement_id)
		_expect(manager.is_claimed(achievement_id), "%s deve risultare colorato e riscosso dopo il click" % achievement_id)

	_expect(manager.has_effect("water_efficiency") and is_equal_approx(manager.get_water_loss_multiplier(), 0.90), "La ricompensa borraccia deve ridurre il consumo d'acqua del 10%")
	_expect(manager.has_effect("crop_efficiency") and is_equal_approx(manager.get_crop_growth_multiplier(), 1.05), "La ricompensa piantagione deve velocizzare le colture del 5%")
	_expect(manager.has_effect("research_bonus") and is_equal_approx(manager.get_research_reward_multiplier(), 1.05), "La ricompensa rapporto deve aumentare i ricavi di ricerca")
	_expect(manager.has_badge("COLONO MARZIANO") and manager.has_badge("DIRETTORE SCIENTIFICO"), "I badge delle tappe speciali devono essere salvati")
	manager.free()
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
