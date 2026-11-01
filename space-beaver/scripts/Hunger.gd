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
	_set_hunger(hunger - LOSS_PER_SECOND * delta)


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
