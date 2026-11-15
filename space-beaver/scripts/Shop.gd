extends Node

signal state_changed
signal message_changed(message: String, is_error: bool)

const CATALOG := {
	"solar_panel": {
		"name": "Solar Panel",
		"price": 500_000_000,
		"category": "energy",
		"placeable": true,
		"description": "Generates 100 kW during daylight. Requires a clear output on its right side.",
	},
	"transformer": {
		"name": "Transformer",
		"price": 1_000_000_000,
		"category": "energy",
		"placeable": true,
		"description": "Connects panels, batteries, and machines. You can buy more than one: each transformer starts an independent grid.",
	},
	"battery": {
		"name": "Battery",
		"price": 750_000_000,
		"category": "energy",
		"placeable": true,
		"description": "Stores 500 kWh and powers the grid when panels are insufficient.",
	},
	"ice_drill": {
		"name": "Ice Drill",
		"price": 1_250_000_000,
		"category": "extraction",
		"placeable": true,
		"description": "Uses 60 kW and produces 80 L/h: enough for the greenhouse and electrolyzer with a reserve. Water exits on the right at the central cell.",
	},
	"rock_drill": {
		"name": "Mineral Drill",
		"price": 1_550_000_000,
		"category": "extraction",
		"placeable": true,
		"description": "Uses 85 kW, extracts one sample every 12 s, and stores up to 32 rocks. The placement biome determines discoveries, including a 5% rare sample.",
	},
	"electrolyzer": {
		"name": "Electrolyzer",
		"price": 1_800_000_000,
		"category": "life_support",
		"placeable": true,
		"description": "Uses 65 kW and water from a lower-left pipe. Produces continuous H₂ and O₂; each output can be connected separately and the gases are not stored in the machine.",
	},
	"sabatier": {
		"name": "Sabatier Reactor",
		"price": 2_200_000_000,
		"category": "life_support",
		"placeable": true,
		"description": "Uses 50 kW and hydrogen. Install it in the only space left of the rocket to load methane directly into the rocket without pipes.",
	},
	"xrd_diffractometer": {
		"name": "X-ray Diffractometer",
		"price": 1_600_000_000,
		"category": "research",
		"placeable": true,
		"description": "Analyzes a sample in 2 min 30 s. Install it in any habitat dome to transmit a scientific report to Earth.",
	},
	"raman_spectrometer": {
		"name": "Raman Spectrometer",
		"price": 2_000_000_000,
		"category": "research",
		"placeable": true,
		"description": "Analyzes a sample in 3 minutes. Install it in any habitat dome to transmit a scientific report to Earth.",
	},
	"icp_ms": {
		"name": "ICP-MS Spectrometer",
		"price": 2_800_000_000,
		"category": "research",
		"placeable": true,
		"description": "Performs advanced elemental analysis in 4 minutes. Install it in any habitat dome to generate the highest-value report.",
	},
	"dome_small": {
		"name": "Small Base Dome",
		"price": 1_200_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Small dome. Its initial O₂ reserve must be supplied through a pipe; minimal thermal shelter and grid-powered heating.",
	},
	"dome_medium": {
		"name": "Medium Base Dome",
		"price": 2_400_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Medium dome. Its initial O₂ reserve must be supplied through a pipe; minimal thermal shelter and grid-powered heating.",
	},
	"dome_large": {
		"name": "Large Base Dome",
		"price": 4_000_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Large dome. Its initial O₂ reserve must be supplied through a pipe; minimal thermal shelter and grid-powered heating.",
	},
	"greenhouse": {
		"name": "Potato Greenhouse",
		"price": 3_200_000_000,
		"category": "habitats",
		"placeable": true,
		"description": "Greenhouse with an airlock, two beds of 8 plants, and a water connector on the left side.",
	},
	"potato_seeds": {
		"name": "Potato Seeds (batch)",
		"price": 120_000_000,
		"category": "habitats",
		"placeable": false,
		"description": "One batch plants all 16 greenhouse plants. Plants regrow after harvesting.",
	},
	"suit_reinforced": {
		"name": "Reinforced EVA Suit",
		"price": 650_000_000,
		"category": "equipment",
		"placeable": false,
		"description": "Solar 45%, cosmic 8%, O₂ 130, and thermal protection to −82°C.",
	},
	"suit_explorer": {
		"name": "Explorer EVA Suit",
		"price": 1_100_000_000,
		"category": "equipment",
		"placeable": false,
		"description": "Solar 60%, cosmic 12%, O₂ 160, and thermal protection to −96°C.",
	},
	"suit_storm": {
		"name": "Storm EVA Suit",
		"price": 1_800_000_000,
		"category": "equipment",
		"placeable": false,
		"description": "Solar 75%, cosmic 18%, O₂ 200, and thermal protection to −110°C.",
	},
}

const CATEGORY_ORDER := ["equipment", "vehicles", "habitats", "energy", "extraction", "life_support", "research"]
const CATEGORY_LABELS := {
	"equipment": "EVA SUITS AND EQUIPMENT",
	"vehicles": "EXPLORATION VEHICLES",
	"habitats": "HABITATS AND DOMES",
	"energy": "POWER AND DISTRIBUTION",
	"extraction": "RESOURCE EXTRACTION",
	"life_support": "LIFE SUPPORT",
	"research": "RESEARCH AND ANALYSIS",
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
		message_changed.emit("Item unavailable.", true)
		return false
	if SuitSystem.is_suit(item_id) and (SuitSystem.owns_suit(item_id) or DeliveryManager.count_uncollected(item_id) > 0):
		message_changed.emit("This suit is already owned by the mission.", true)
		return false
	var definition: Dictionary = CATALOG[item_id]
	var price := int(definition["price"])
	if not Economy.spend(price):
		message_changed.emit("Insufficient budget.", true)
		return false
	var configuration := get_current_seed_configuration() if item_id == "potato_seeds" else {}
	if not DeliveryManager.queue_item(item_id, definition, 1, configuration):
		Economy.add_funds(price)
		message_changed.emit("Unable to prepare the shipment.", true)
		return false
	message_changed.emit("%s added to the consolidated order. Launching in a few seconds." % definition["name"], false)
	return true


func get_dome_addon_prices() -> Dictionary:
	return {
		"lead_shielding": 500_000_000,
		"hydrogen_shielding": 350_000_000,
		"rover_pad": 600_000_000,
	}


func purchase_dome(item_id: String, configuration: Dictionary = {}) -> bool:
	if item_id not in ["dome_small", "dome_medium", "dome_large"] or not CATALOG.has(item_id):
		message_changed.emit("Invalid dome configuration.", true)
		return false
	if bool(configuration.get("rover_pad", false)) and item_id == "dome_small":
		message_changed.emit("The rover pad requires a medium or large dome.", true)
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
		message_changed.emit("Insufficient budget for this configuration.", true)
		return false
	var definition: Dictionary = CATALOG[item_id].duplicate(true)
	definition["name"] = _dome_order_name(str(definition["name"]), options)
	if not DeliveryManager.queue_item(item_id, definition, 1, options):
		Economy.add_funds(price)
		message_changed.emit("Unable to prepare the shipment.", true)
		return false
	message_changed.emit("Configured dome added to the order · %s." % Economy.format_money(price), false)
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
		parts.append("lead shielding")
	if options["hydrogen_shielding"]:
		parts.append("hydrogen shielding")
	if options["rover_pad"]:
		parts.append("rover pad")
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
	var base := "One batch plants all 16 greenhouse plants. The batch keeps its genetic levels after purchase."
	if not are_seed_genetics_unlocked():
		return base + " Bioengineering: complete First Harvest and the Perseverance mission."
	return "%s Purchased levels: yield %d/%d · speed %d/%d." % [base, potato_seed_yield_level, MAX_SEED_UPGRADE_LEVEL, potato_seed_speed_level, MAX_SEED_UPGRADE_LEVEL]


func purchase_seed_upgrade(track: String) -> bool:
	if not are_seed_genetics_unlocked():
		message_changed.emit("Bioengineering locked: complete First Harvest and the Perseverance mission.", true)
		return false
	if track not in SEED_UPGRADE_COSTS:
		return false
	var level := get_seed_upgrade_level(track)
	if level >= MAX_SEED_UPGRADE_LEVEL:
		message_changed.emit("Genetic upgrade already at the maximum level.", true)
		return false
	var price := get_seed_upgrade_price(track)
	if price < 0 or not Economy.spend(price):
		message_changed.emit("Insufficient budget for the genetic upgrade.", true)
		return false
	if track == "yield":
		potato_seed_yield_level += 1
	else:
		potato_seed_speed_level += 1
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("record"):
		achievements.call("record", "genetic_modification")
	message_changed.emit("GM seeds upgraded: %s level %d. New batches retain the improvement." % ["yield" if track == "yield" else "speed", get_seed_upgrade_level(track)], false)
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
