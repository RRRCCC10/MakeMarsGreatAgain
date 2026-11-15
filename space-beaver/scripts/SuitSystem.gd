extends Node

signal equipped_changed(suit_id: String, definition: Dictionary)
signal owned_suits_changed

const STANDARD_SUIT_ID := "suit_standard"
const SUIT_ORDER: Array[String] = ["suit_standard", "suit_reinforced", "suit_explorer", "suit_storm"]
const SUITS := {
	"suit_standard": {
		"name": "Standard EVA Suit",
		"short_name": "EVA STANDARD",
		"solar_protection": 0.30,
		"cosmic_protection": 0.05,
		"cold_tolerance_c": -50.0,
		"oxygen_capacity": 100.0,
		"movement_multiplier": 1.0,
		"tint": Color("fff1e4"),
		"description": "Light starting suit. Basic shielding, O₂ 100, and limited thermal protection down to −50°C: going outside at night is risky.",
	},
	"suit_reinforced": {
		"name": "Reinforced EVA Suit",
		"short_name": "REINFORCED EVA",
		"solar_protection": 0.45,
		"cosmic_protection": 0.08,
		"cold_tolerance_c": -72.0,
		"oxygen_capacity": 130.0,
		"movement_multiplier": 0.98,
		"tint": Color("a8d8ff"),
		"description": "Hydrogen-rich polymer layers. Solar 45%, O₂ 130, and cold resistance down to −72°C.",
	},
	"suit_explorer": {
		"name": "Exploration Suit",
		"short_name": "EVA EXPLORER",
		"solar_protection": 0.60,
		"cosmic_protection": 0.12,
		"cold_tolerance_c": -90.0,
		"oxygen_capacity": 160.0,
		"movement_multiplier": 1.0,
		"tint": Color("a9f0c0"),
		"description": "Advanced composite, full mobility, O₂ 160, and cold resistance down to −90°C.",
	},
	"suit_storm": {
		"name": "Solar-Storm Suit",
		"short_name": "EVA STORM",
		"solar_protection": 0.75,
		"cosmic_protection": 0.18,
		"cold_tolerance_c": -112.0,
		"oxygen_capacity": 200.0,
		"movement_multiplier": 0.94,
		"tint": Color("e1b5ff"),
		"description": "Maximum portable protection: solar 75%, O₂ 200, and cold resistance down to −112°C.",
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
	if suit_id != STANDARD_SUIT_ID:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			achievements.call("record", "exploration_suit")
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
	return float(get_equipped_definition().get("cold_tolerance_c", -50.0))


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
