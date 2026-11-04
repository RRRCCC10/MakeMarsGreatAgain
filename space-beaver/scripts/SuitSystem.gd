extends Node

signal equipped_changed(suit_id: String, definition: Dictionary)
signal owned_suits_changed

const STANDARD_SUIT_ID := "suit_standard"
const SUIT_ORDER: Array[String] = ["suit_standard", "suit_reinforced", "suit_explorer", "suit_storm"]
const SUITS := {
	"suit_standard": {
		"name": "Tuta EVA standard",
		"short_name": "EVA STANDARD",
		"solar_protection": 0.30,
		"cosmic_protection": 0.05,
		"cold_tolerance_c": -68.0,
		"oxygen_capacity": 100.0,
		"movement_multiplier": 1.0,
		"tint": Color("fff1e4"),
		"description": "Tuta iniziale leggera. Schermatura di base, O₂ 100 e protezione termica fino a −68°C.",
	},
	"suit_reinforced": {
		"name": "Tuta EVA rinforzata",
		"short_name": "EVA RINFORZATA",
		"solar_protection": 0.45,
		"cosmic_protection": 0.08,
		"cold_tolerance_c": -82.0,
		"oxygen_capacity": 130.0,
		"movement_multiplier": 0.98,
		"tint": Color("a8d8ff"),
		"description": "Strati polimerici ricchi di idrogeno. Solare 45%, O₂ 130 e freddo fino a −82°C.",
	},
	"suit_explorer": {
		"name": "Tuta da esplorazione",
		"short_name": "EVA EXPLORER",
		"solar_protection": 0.60,
		"cosmic_protection": 0.12,
		"cold_tolerance_c": -96.0,
		"oxygen_capacity": 160.0,
		"movement_multiplier": 1.0,
		"tint": Color("a9f0c0"),
		"description": "Composito avanzato, mobilita' completa, O₂ 160 e freddo fino a −96°C.",
	},
	"suit_storm": {
		"name": "Tuta anti-tempesta solare",
		"short_name": "EVA STORM",
		"solar_protection": 0.75,
		"cosmic_protection": 0.18,
		"cold_tolerance_c": -110.0,
		"oxygen_capacity": 200.0,
		"movement_multiplier": 0.94,
		"tint": Color("e1b5ff"),
		"description": "Massima protezione portatile: solare 75%, O₂ 200 e freddo fino a −110°C.",
	},
}

var equipped_suit_id := STANDARD_SUIT_ID
var oxygen_by_suit: Dictionary = {}
var owned_suits: Dictionary = {}


func _ready() -> void:
	reset_for_new_mission()


func get_definition(suit_id: String = equipped_suit_id) -> Dictionary:
	return SUITS.get(suit_id, SUITS[STANDARD_SUIT_ID])


func get_equipped_definition() -> Dictionary:
	return get_definition(equipped_suit_id)


func is_suit(item_id: String) -> bool:
	return SUITS.has(item_id)


func owns_suit(suit_id: String) -> bool:
	return bool(owned_suits.get(suit_id, false))


func acquire_suit(suit_id: String) -> bool:
	if not SUITS.has(suit_id) or owns_suit(suit_id):
		return false
	owned_suits[suit_id] = true
	owned_suits_changed.emit()
	return true


func get_owned_suit_ids() -> Array[String]:
	var result: Array[String] = []
	for suit_id in SUIT_ORDER:
		if owns_suit(suit_id):
			result.append(suit_id)
	return result


func equip(suit_id: String) -> bool:
	if not SUITS.has(suit_id) or not owns_suit(suit_id):
		return false
	if suit_id == equipped_suit_id:
		return true
	oxygen_by_suit[equipped_suit_id] = Oxygen.oxygen
	equipped_suit_id = suit_id
	var definition := get_equipped_definition()
	var capacity := float(definition["oxygen_capacity"])
	var reserve := float(oxygen_by_suit.get(suit_id, capacity))
	oxygen_by_suit[suit_id] = reserve
	Oxygen.set_suit_capacity(capacity, reserve)
	equipped_changed.emit(equipped_suit_id, definition)
	return true


func get_solar_protection() -> float:
	return float(get_equipped_definition()["solar_protection"])


func get_cosmic_protection() -> float:
	return float(get_equipped_definition()["cosmic_protection"])


func get_cold_tolerance_c() -> float:
	return float(get_equipped_definition().get("cold_tolerance_c", -68.0))


func get_movement_multiplier() -> float:
	return float(get_equipped_definition()["movement_multiplier"])


func reset_for_new_mission() -> void:
	equipped_suit_id = STANDARD_SUIT_ID
	owned_suits = {STANDARD_SUIT_ID: true}
	oxygen_by_suit = {STANDARD_SUIT_ID: 100.0}
	if get_node_or_null("/root/Oxygen") != null:
		Oxygen.set_suit_capacity(100.0, 100.0)
	owned_suits_changed.emit()
	equipped_changed.emit(equipped_suit_id, get_equipped_definition())

