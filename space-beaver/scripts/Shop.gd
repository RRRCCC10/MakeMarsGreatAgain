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
		"description": "Consuma 60 kW e produce 40 L/h. Uscita dell'acqua a destra, nella cella centrale.",
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

const CATEGORY_ORDER := ["equipment", "energy", "extraction", "life_support", "research"]
const CATEGORY_LABELS := {
	"equipment": "TUTE ED EQUIPAGGIAMENTO EVA",
	"energy": "ENERGIA E DISTRIBUZIONE",
	"extraction": "ESTRAZIONE RISORSE",
	"life_support": "SUPPORTO VITALE",
	"research": "RICERCA E ANALISI",
}

var is_open := false


func toggle() -> void:
	is_open = not is_open
	state_changed.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
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
	if not DeliveryManager.queue_item(item_id, definition, 1):
		Economy.add_funds(price)
		message_changed.emit("Impossibile preparare la spedizione.", true)
		return false
	message_changed.emit("%s aggiunto all'ordine unico. Partenza tra pochi secondi." % definition["name"], false)
	return true


func get_definition(item_id: String) -> Dictionary:
	return CATALOG.get(item_id, {})


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
	state_changed.emit()


func _transformer_already_owned() -> bool:
	return PowerGrid.has_transformer() or Inventory.count_item("transformer") > 0 or DeliveryManager.count_uncollected("transformer") > 0
