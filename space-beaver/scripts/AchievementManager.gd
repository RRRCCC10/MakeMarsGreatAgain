extends Node

## Progressione della singola missione. Ogni nuovo avvio parte da zero: gli
## obiettivi avanzano anche prima di essere disponibili, ma le ricompense si
## riscattano rispettando il grafo dei prerequisiti.

signal achievement_updated(achievement_id: String)
signal achievement_claimable(achievement_id: String)
signal achievement_claimed(achievement_id: String, reward_label: String)

const ACHIEVEMENTS := [
	{
		"id": "first_base", "title": "PRIMA BASE", "icon": "⌂", "color": Color("70c8ff"),
		"description": "Posiziona la prima cupola abitativa.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 150_000_000, "label": "+ $150 MLN"},
	},
	{
		"id": "airlock_cycle", "title": "ACCESSO SICURO", "icon": "⇄", "color": Color("9cc8ff"),
		"description": "Completa un ciclo della camera di decompressione.", "target": 1,
		"prerequisites": ["first_base"],
		"reward": {"badge": "COLONO MARZIANO", "label": "Badge: Colono marziano"},
	},
	{
		"id": "stable_grid", "title": "RETE ELETTRICA", "icon": "ϟ", "color": Color("ffe079"),
		"description": "Rendi operativa la rete con pannelli, trasformatore e batteria.", "target": 1,
		"prerequisites": ["first_base"],
		"reward": {"funds": 150_000_000, "label": "+ $150 MLN"},
	},
	{
		"id": "ice_drill", "title": "PRIMA TRIVELLA", "icon": "⌄", "color": Color("6de8ff"),
		"description": "Posiziona una trivella del ghiaccio.", "target": 1,
		"prerequisites": ["airlock_cycle", "stable_grid"],
		"reward": {"funds": 100_000_000, "label": "+ $100 MLN"},
	},
	{
		"id": "refill_bottle", "title": "BORRACCIA RICARICATA", "icon": "◒", "color": Color("73dfff"),
		"description": "Riempi una borraccia alla trivella alimentata.", "target": 1,
		"prerequisites": ["ice_drill"],
		"reward": {"effect": "water_efficiency", "label": "Consumo acqua -10%"},
	},
	{
		"id": "greenhouse", "title": "SERRA OPERATIVA", "icon": "♧", "color": Color("89e89a"),
		"description": "Collega una serra a una sorgente d'acqua.", "target": 1,
		"prerequisites": ["stable_grid"],
		"reward": {"funds": 200_000_000, "label": "+ $200 MLN"},
	},
	{
		"id": "first_planting", "title": "PRIMA PIANTAGIONE", "icon": "✦", "color": Color("9ce66f"),
		"description": "Pianta il primo lotto di patate.", "target": 1,
		"prerequisites": ["greenhouse"],
		"reward": {"effect": "crop_efficiency", "label": "Crescita colture +5%"},
	},
	{
		"id": "first_harvest", "title": "PRIMO RACCOLTO", "icon": "▣", "color": Color("e8c45b"),
		"description": "Raccogli 16 patate mature.", "target": 1,
		"prerequisites": ["first_planting"],
		"reward": {"funds": 300_000_000, "label": "+ $300 MLN"},
	},
	{
		"id": "first_lab", "title": "PRIMO LABORATORIO", "icon": "⚗", "color": Color("a4baff"),
		"description": "Installa il primo strumento scientifico in una cupola abitativa.", "target": 1,
		"prerequisites": ["stable_grid"],
		"reward": {"funds": 250_000_000, "label": "+ $250 MLN"},
	},
	{
		"id": "first_report", "title": "PRIMO RAPPORTO", "icon": "▤", "color": Color("79d9ff"),
		"description": "Trasmetti alla Terra il primo rapporto scientifico.", "target": 1,
		"prerequisites": ["first_lab"],
		"reward": {"effect": "research_bonus", "label": "Ricavi ricerca +5%"},
	},
	{
		"id": "xrd_master", "title": "XRD CALIBRATO", "icon": "X", "color": Color("ffaf73"),
		"description": "Porta il diffrattometro XRD al livello 5.", "target": 1,
		"prerequisites": ["first_lab"],
		"reward": {"funds": 300_000_000, "label": "+ $300 MLN"},
	},
	{
		"id": "raman_master", "title": "RAMAN CALIBRATO", "icon": "R", "color": Color("d48cff"),
		"description": "Porta lo spettrometro Raman al livello 5.", "target": 1,
		"prerequisites": ["first_lab"],
		"reward": {"funds": 350_000_000, "label": "+ $350 MLN"},
	},
	{
		"id": "icp_master", "title": "ICP-MS CALIBRATO", "icon": "I", "color": Color("72efd3"),
		"description": "Porta l'ICP-MS al livello 5.", "target": 1,
		"prerequisites": ["first_lab"],
		"reward": {"funds": 450_000_000, "label": "+ $450 MLN"},
	},
	{
		"id": "science_center", "title": "CENTRO SCIENTIFICO", "icon": "★", "color": Color("ffe36e"),
		"description": "Completa la calibrazione massima dei tre laboratori.", "target": 1,
		"prerequisites": ["xrd_master", "raman_master", "icp_master"],
		"reward": {"funds": 1_000_000_000, "badge": "DIRETTORE SCIENTIFICO", "label": "+ $1 MLD · Direttore scientifico"},
	},
]

var _progress: Dictionary = {}
var _claimed: Dictionary = {}
var _badges: Dictionary = {}
var _effects: Dictionary = {}
var is_board_open := false


func _ready() -> void:
	_reset_session_state()


func get_ordered_definitions() -> Array:
	return ACHIEVEMENTS.duplicate(true)


func get_definition(achievement_id: String) -> Dictionary:
	for definition in ACHIEVEMENTS:
		if str(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)
	return {}


func get_progress(achievement_id: String) -> int:
	return int(_progress.get(achievement_id, 0))


func get_target(achievement_id: String) -> int:
	return int(get_definition(achievement_id).get("target", 1))


func get_prerequisites(achievement_id: String) -> Array[String]:
	var prerequisites: Array[String] = []
	var raw_prerequisites: Array = get_definition(achievement_id).get("prerequisites", [])
	for prerequisite in raw_prerequisites:
		var prerequisite_id := str(prerequisite)
		if not prerequisite_id.is_empty():
			prerequisites.append(prerequisite_id)
	return prerequisites


func get_dependent_ids(achievement_id: String) -> Array[String]:
	var children: Array[String] = []
	for definition in ACHIEVEMENTS:
		var child_id := str(definition.get("id", ""))
		if achievement_id in get_prerequisites(child_id):
			children.append(child_id)
	return children


func is_reached(achievement_id: String) -> bool:
	return get_progress(achievement_id) >= get_target(achievement_id)


func is_claimed(achievement_id: String) -> bool:
	return bool(_claimed.get(achievement_id, false))


func is_unlocked(achievement_id: String) -> bool:
	if get_definition(achievement_id).is_empty():
		return false
	for prerequisite_id in get_prerequisites(achievement_id):
		if not is_claimed(prerequisite_id):
			return false
	return true


func is_claimable(achievement_id: String) -> bool:
	return is_unlocked(achievement_id) and is_reached(achievement_id) and not is_claimed(achievement_id)


func get_status(achievement_id: String) -> String:
	if not is_unlocked(achievement_id):
		return "locked"
	if is_claimable(achievement_id):
		return "claimable"
	if is_claimed(achievement_id):
		return "claimed"
	return "available"


func record(achievement_id: String, amount: int = 1) -> bool:
	var definition := get_definition(achievement_id)
	if definition.is_empty() or amount <= 0:
		return false
	var old_progress := get_progress(achievement_id)
	var new_progress := mini(get_target(achievement_id), old_progress + amount)
	if new_progress == old_progress:
		return false
	_progress[achievement_id] = new_progress
	_refresh_composite_achievements()
	_save_progress()
	achievement_updated.emit(achievement_id)
	if is_claimable(achievement_id):
		achievement_claimable.emit(achievement_id)
	return true


func set_reached(achievement_id: String) -> bool:
	var target := get_target(achievement_id)
	var missing := target - get_progress(achievement_id)
	return record(achievement_id, missing) if missing > 0 else false


func claim(achievement_id: String) -> bool:
	if not is_claimable(achievement_id):
		return false
	var definition := get_definition(achievement_id)
	var reward: Dictionary = definition.get("reward", {})
	_claimed[achievement_id] = true
	var funds := int(reward.get("funds", 0))
	if funds > 0 and is_inside_tree():
		var economy := get_node_or_null("/root/Economy")
		if economy != null:
			economy.call("add_funds", funds)
	var badge := str(reward.get("badge", ""))
	if not badge.is_empty():
		_badges[badge] = true
	var effect := str(reward.get("effect", ""))
	if not effect.is_empty():
		_effects[effect] = true
	_save_progress()
	achievement_updated.emit(achievement_id)
	for child_id in get_dependent_ids(achievement_id):
		achievement_updated.emit(child_id)
		if is_claimable(child_id):
			achievement_claimable.emit(child_id)
	achievement_claimed.emit(achievement_id, str(reward.get("label", "Ricompensa riscattata")))
	return true


func get_water_loss_multiplier() -> float:
	return 0.90 if has_effect("water_efficiency") else 1.0


func get_crop_growth_multiplier() -> float:
	return 1.05 if has_effect("crop_efficiency") else 1.0


func get_research_reward_multiplier() -> float:
	return 1.05 if has_effect("research_bonus") else 1.0


func has_effect(effect_id: String) -> bool:
	return bool(_effects.get(effect_id, false))


func has_badge(badge_id: String) -> bool:
	return bool(_badges.get(badge_id, false))


func set_persistence_enabled_for_test(enabled: bool) -> void:
	# Gli achievement non sono persistenti per scelta di design. Manteniamo
	# questa API soltanto per compatibilità con i test esistenti.
	if enabled:
		push_warning("La persistenza degli achievement è disabilitata: ogni avvio è una nuova missione.")


func reset_runtime_for_test() -> void:
	_reset_session_state()


func _reset_session_state() -> void:
	_progress.clear()
	_claimed.clear()
	_badges.clear()
	_effects.clear()
	is_board_open = false


func _refresh_composite_achievements() -> void:
	if is_reached("xrd_master") and is_reached("raman_master") and is_reached("icp_master"):
		var center_old := get_progress("science_center")
		if center_old < get_target("science_center"):
			_progress["science_center"] = get_target("science_center")
			achievement_updated.emit("science_center")
			if is_claimable("science_center"):
				achievement_claimable.emit("science_center")


func _save_progress() -> void:
	# Nessun salvataggio su disco: F5 / nuovo avvio deve sempre ripartire da zero.
	pass
