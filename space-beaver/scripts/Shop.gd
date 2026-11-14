extends Node

signal state_changed
signal message_changed(message: String, is_error: bool)

const CATALOG := {
	"solar_panel": {
		"name": "Pannello solare",
		"price": 500_000_000,
		"category": "energy",
		"placeable": true,
		"description": "Produce 100 kW durante il giorno. Richiede un'uscita libera a destra.",
	},
	"transformer": {
		"name": "Trasformatore",
		"price": 1_000_000_000,
		"category": "energy",
		"placeable": true,
		"description": "Collega i pannelli alle batterie. Ne e' consentito uno solo.",
	},
	"battery": {
		"name": "Batteria",
		"price": 750_000_000,
		"category": "energy",
		"placeable": true,
		"description": "Accumula 500 kWh e alimenta la rete quando i pannelli non bastano.",
	},
	"ice_drill": {
		"name": "Trivella di ghiaccio",
		"price": 1_250_000_000,
		"category": "extraction",
		"placeable": true,
		"description": "Consuma 60 kW e produce 80 L/h: abbastanza per serra ed elettrolizzatore con una riserva. Uscita dell'acqua a destra, nella cella centrale.",
	},
	"rock_drill": {
		"name": "Trivella mineraria",
		"price": 1_550_000_000,
		"category": "extraction",
		"placeable": true,
		"description": "Consuma 85 kW, estrae un campione ogni 12 s e conserva fino a 32 rocce. Il bioma di posa determina le scoperte, inclusa una rara al 5%.",
	},
	"electrolyzer": {
		"name": "Elettrolizzatore",
		"price": 1_800_000_000,
		"category": "life_support",
		"placeable": true,
		"description": "Consuma 65 kW e acqua da una tubazione in basso a sinistra. Accumula idrogeno e ossigeno; le due uscite possono essere collegate separatamente.",
	},
	"sabatier": {
		"name": "Reattore Sabatier",
		"price": 2_200_000_000,
		"category": "life_support",
		"placeable": true,
		"description": "Consuma 50 kW e idrogeno. Si installa nell'unico spazio a sinistra del razzo e carica direttamente il metano nel razzo, senza tubi.",
	},
	"xrd_diffractometer": {
		"name": "Diffrattometro a raggi X",
		"price": 1_600_000_000,
		"category": "research",
		"placeable": true,
		"description": "Analizza un campione in 2 min 30 s. Si installa in qualunque cupola abitativa e trasmette un rapporto scientifico alla Terra.",
	},
	"raman_spectrometer": {
		"name": "Spettrometro Raman",
		"price": 2_000_000_000,
		"category": "research",
		"placeable": true,
		"description": "Analizza un campione in 3 minuti. Si installa in qualunque cupola abitativa e trasmette un rapporto scientifico alla Terra.",
	},
	"icp_ms": {
		"name": "Spettrometro ICP-MS",
		"price": 2_800_000_000,
		"category": "research",
		"placeable": true,
		"description": "Analisi elementare avanzata in 4 minuti. Si installa in qualunque cupola abitativa e genera il rapporto più remunerativo.",
	},
	"dome_small": {
		"name": "Cupola base piccola",
		"price": 1_200_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Cupola piccola. Riserva iniziale di O₂ da rifornire con tubo; riparo termico minimo, riscaldamento con rete elettrica.",
	},
	"dome_medium": {
		"name": "Cupola base media",
		"price": 2_400_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Cupola media. Riserva iniziale di O₂ da rifornire con tubo; riparo termico minimo, riscaldamento con rete elettrica.",
	},
	"dome_large": {
		"name": "Cupola base grande",
		"price": 4_000_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Cupola grande. Riserva iniziale di O₂ da rifornire con tubo; riparo termico minimo, riscaldamento con rete elettrica.",
	},
	"greenhouse": {
		"name": "Serra di patate",
		"price": 3_200_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Serra con camera di decompressione, due aiuole da 8 piante e raccordo acqua sul lato sinistro.",
	},
	"potato_seeds": {
		"name": "Semi di patate (lotto)",
		"price": 120_000_000,
		"category": "habitats",
		"placeable": false,
		"description": "Un lotto semina tutte e 16 le piante della serra. Dopo il raccolto le piante ricrescono.",
	},
	"suit_reinforced": {
		"name": "Tuta EVA rinforzata",
		"price": 650_000_000,
		"category": "equipment",
		"placeable": false,
		"description": "Solare 45%, cosmica 8%, O₂ 130 e protezione termica fino a −82°C.",
	},
	"suit_explorer": {
		"name": "Tuta EVA Explorer",
		"price": 1_100_000_000,
		"category": "equipment",
		"placeable": false,
		"description": "Solare 60%, cosmica 12%, O₂ 160 e protezione termica fino a −96°C.",
	},
	"suit_storm": {
		"name": "Tuta EVA Storm",
		"price": 1_800_000_000,
		"category": "equipment",
		"placeable": false,
		"description": "Solare 75%, cosmica 18%, O₂ 200 e protezione termica fino a −110°C.",
	},
}

const CATEGORY_ORDER := ["equipment", "vehicles", "habitats", "energy", "extraction", "life_support", "research"]
const CATEGORY_LABELS := {
	"equipment": "TUTE ED EQUIPAGGIAMENTO EVA",
	"vehicles": "VEICOLI DI ESPLORAZIONE",
	"habitats": "HABITAT E CUPOLE",
	"energy": "ENERGIA E DISTRIBUZIONE",
	"extraction": "ESTRAZIONE RISORSE",
	"life_support": "SUPPORTO VITALE",
	"research": "RICERCA E ANALISI",
}
const SEED_UPGRADE_COSTS := {
	"yield": [300_000_000, 500_000_000, 750_000_000, 1_050_000_000, 1_400_000_000],
	"speed": [350_000_000, 575_000_000, 850_000_000, 1_150_000_000, 1_550_000_000],
}
const MAX_SEED_UPGRADE_LEVEL := 5

var is_open := false
var potato_seed_yield_level := 0
var potato_seed_speed_level := 0


func open() -> bool:
	if is_open:
		return true
	if not _try_open_ui_modal():
		return false
	is_open = true
	state_changed.emit()
	return true


func toggle() -> bool:
	if is_open:
		close()
		return false
	return open()


func close() -> void:
	if not is_open:
		_close_ui_modal()
		return
	is_open = false
	_close_ui_modal()
	state_changed.emit()


func purchase(item_id: String) -> bool:
	if not CATALOG.has(item_id):
		message_changed.emit("Oggetto non disponibile.", true)
		return false
	if item_id == "transformer" and _transformer_already_owned():
		message_changed.emit("Puoi possedere un solo trasformatore.", true)
		return false
	if SuitSystem.is_suit(item_id) and (SuitSystem.owns_suit(item_id) or DeliveryManager.count_uncollected(item_id) > 0):
		message_changed.emit("Questa tuta e' gia' di proprieta' della missione.", true)
		return false
	var definition: Dictionary = CATALOG[item_id]
	var price := int(definition["price"])
	if not Economy.spend(price):
		message_changed.emit("Budget insufficiente.", true)
		return false
	var configuration := get_current_seed_configuration() if item_id == "potato_seeds" else {}
	if not DeliveryManager.queue_item(item_id, definition, 1, configuration):
		Economy.add_funds(price)
		message_changed.emit("Impossibile preparare la spedizione.", true)
		return false
	message_changed.emit("%s aggiunto all'ordine unico. Partenza tra pochi secondi." % definition["name"], false)
	return true


func get_dome_addon_prices() -> Dictionary:
	return {
		"lead_shielding": 500_000_000,
		"hydrogen_shielding": 350_000_000,
		"rover_pad": 600_000_000,
	}


func purchase_dome(item_id: String, configuration: Dictionary = {}) -> bool:
	if item_id not in ["dome_small", "dome_medium", "dome_large"] or not CATALOG.has(item_id):
		message_changed.emit("Configurazione cupola non valida.", true)
		return false
	if bool(configuration.get("rover_pad", false)) and item_id == "dome_small":
		message_changed.emit("La base rover richiede una cupola media o grande.", true)
		return false
	var options := {
		"lead_shielding": bool(configuration.get("lead_shielding", false)),
		"hydrogen_shielding": bool(configuration.get("hydrogen_shielding", false)),
		"rover_pad": bool(configuration.get("rover_pad", false)),
	}
	var price := int(CATALOG[item_id]["price"])
	var add_on_prices := get_dome_addon_prices()
	for option in options:
		if options[option]:
			price += int(add_on_prices[option])
	if not Economy.spend(price):
		message_changed.emit("Budget insufficiente per questa configurazione.", true)
		return false
	var definition: Dictionary = CATALOG[item_id].duplicate(true)
	definition["name"] = _dome_order_name(str(definition["name"]), options)
	if not DeliveryManager.queue_item(item_id, definition, 1, options):
		Economy.add_funds(price)
		message_changed.emit("Impossibile preparare la spedizione.", true)
		return false
	message_changed.emit("Cupola configurata aggiunta all'ordine · %s." % Economy.format_money(price), false)
	return true


func get_dome_total_price(item_id: String, configuration: Dictionary = {}) -> int:
	if not CATALOG.has(item_id):
		return 0
	var total := int(CATALOG[item_id]["price"])
	var prices := get_dome_addon_prices()
	for option in prices:
		if bool(configuration.get(option, false)):
			total += int(prices[option])
	return total


func _dome_order_name(base_name: String, options: Dictionary) -> String:
	var parts := PackedStringArray([base_name])
	if options["lead_shielding"]:
		parts.append("piombo")
	if options["hydrogen_shielding"]:
		parts.append("schermatura idrogenata")
	if options["rover_pad"]:
		parts.append("base rover")
	return " · ".join(parts)


func get_definition(item_id: String) -> Dictionary:
	var definition: Dictionary = CATALOG.get(item_id, {}).duplicate(true)
	if item_id == "potato_seeds" and not definition.is_empty():
		definition["description"] = get_potato_seed_description()
	return definition


func are_seed_genetics_unlocked() -> bool:
	var achievements := get_node_or_null("/root/AchievementManager")
	return achievements != null and bool(achievements.call("is_claimed", "first_harvest")) and bool(achievements.call("has_effect", "genetic_seed_access"))


func get_seed_upgrade_level(track: String) -> int:
	return potato_seed_yield_level if track == "yield" else (potato_seed_speed_level if track == "speed" else 0)


func get_seed_upgrade_price(track: String) -> int:
	if track not in SEED_UPGRADE_COSTS:
		return -1
	var level := get_seed_upgrade_level(track)
	var costs: Array = SEED_UPGRADE_COSTS[track]
	return int(costs[level]) if level >= 0 and level < costs.size() else -1


func get_current_seed_configuration() -> Dictionary:
	return {
		"yield_level": potato_seed_yield_level,
		"speed_level": potato_seed_speed_level,
	}


func get_potato_seed_description() -> String:
	var base := "Un lotto semina tutte e 16 le piante della serra. Il lotto conserva i suoi livelli genetici anche dopo l'acquisto."
	if not are_seed_genetics_unlocked():
		return base + " Bioingegneria: completa Primo raccolto e la missione Perseverance."
	return "%s Livelli ordinati: resa %d/%d · velocità %d/%d." % [base, potato_seed_yield_level, MAX_SEED_UPGRADE_LEVEL, potato_seed_speed_level, MAX_SEED_UPGRADE_LEVEL]


func purchase_seed_upgrade(track: String) -> bool:
	if not are_seed_genetics_unlocked():
		message_changed.emit("Bioingegneria bloccata: completa Primo raccolto e la missione Perseverance.", true)
		return false
	if track not in SEED_UPGRADE_COSTS:
		return false
	var level := get_seed_upgrade_level(track)
	if level >= MAX_SEED_UPGRADE_LEVEL:
		message_changed.emit("Upgrade genetico già al livello massimo.", true)
		return false
	var price := get_seed_upgrade_price(track)
	if price < 0 or not Economy.spend(price):
		message_changed.emit("Budget insufficiente per l'upgrade genetico.", true)
		return false
	if track == "yield":
		potato_seed_yield_level += 1
	else:
		potato_seed_speed_level += 1
	message_changed.emit("Semi GM aggiornati: %s livello %d. I nuovi lotti mantengono il miglioramento." % ["resa" if track == "yield" else "velocità", get_seed_upgrade_level(track)], false)
	state_changed.emit()
	return true


func get_category_ids() -> Array[String]:
	var result: Array[String] = []
	for category in CATEGORY_ORDER:
		for definition in CATALOG.values():
			if str(definition.get("category", "")) == category:
				result.append(category)
				break
	return result


func get_items_for_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in CATALOG.keys():
		if str(CATALOG[item_id].get("category", "")) == category:
			result.append(str(item_id))
	return result


func get_category_label(category: String) -> String:
	return str(CATEGORY_LABELS.get(category, category.to_upper()))


func reset_for_new_mission() -> void:
	is_open = false
	potato_seed_yield_level = 0
	potato_seed_speed_level = 0
	_close_ui_modal()
	state_changed.emit()


func _try_open_ui_modal() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state == null or bool(ui_state.call("try_open_modal", &"shop"))


func _close_ui_modal() -> void:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", &"shop")


func _transformer_already_owned() -> bool:
	return PowerGrid.has_transformer() or Inventory.count_item("transformer") > 0 or DeliveryManager.count_uncollected("transformer") > 0
