extends Node

## La fame rappresenta la sazieta' del protagonista: 100 significa completamente sazio.
signal changed(current: float, maximum: float)

const MAX_HUNGER := 100.0
const LOSS_PER_SECOND := 0.20
const RESTORE_PER_RATION := 30.0

var hunger := MAX_HUNGER


func _ready() -> void:
	changed.emit(hunger, MAX_HUNGER)


func _process(delta: float) -> void:
	var storm_multiplier := 1.0
	var sandstorms := get_node_or_null("/root/SandstormManager")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if sandstorms != null and player != null and sandstorms.has_method("get_outdoor_hunger_multiplier"):
		storm_multiplier = float(sandstorms.call("get_outdoor_hunger_multiplier", player))
	_set_hunger(hunger - LOSS_PER_SECOND * storm_multiplier * delta)


func eat_selected_ration() -> bool:
	var item := Inventory.get_selected_item()
	if item.get("id", "") != "food_ration":
		return false
	if not Inventory.consume_selected_item():
		return false
	_set_hunger(hunger + RESTORE_PER_RATION)
	return true


func _set_hunger(value: float) -> void:
	var new_value := clampf(value, 0.0, MAX_HUNGER)
	if new_value == hunger:
		return
	hunger = new_value
	changed.emit(hunger, MAX_HUNGER)


func reset_for_new_mission() -> void:
	hunger = MAX_HUNGER
	changed.emit(hunger, MAX_HUNGER)
