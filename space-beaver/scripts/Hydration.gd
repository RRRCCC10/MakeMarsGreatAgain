extends Node

## La sete rappresenta l'idratazione del protagonista: 100 significa completamente idratato.
signal changed(current: float, maximum: float)

const MAX_THIRST := 100.0
const LOSS_PER_SECOND := 0.30
const DRINK_AMOUNT_LITERS := 0.2
const THIRST_RESTORED_PER_DRINK := 10.0

var thirst := MAX_THIRST


func _ready() -> void:
	changed.emit(thirst, MAX_THIRST)


func _process(delta: float) -> void:
	_set_thirst(thirst - LOSS_PER_SECOND * _get_achievement_loss_multiplier() * delta)


func _get_achievement_loss_multiplier() -> float:
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("get_water_loss_multiplier"):
		return float(achievements.call("get_water_loss_multiplier"))
	return 1.0


func drink_from_selected_bottle() -> bool:
	var bottle := Inventory.get_selected_item()
	if bottle.get("id", "") != "water_bottle":
		return false
	var liters := float(bottle.get("liters", 0.0))
	if liters + 0.001 < DRINK_AMOUNT_LITERS:
		return false
	bottle["liters"] = roundf((liters - DRINK_AMOUNT_LITERS) * 10.0) / 10.0
	Inventory.changed.emit()
	_set_thirst(thirst + THIRST_RESTORED_PER_DRINK)
	return true


func _set_thirst(value: float) -> void:
	var new_value := clampf(value, 0.0, MAX_THIRST)
	if new_value == thirst:
		return
	thirst = new_value
	changed.emit(thirst, MAX_THIRST)


func reset_for_new_mission() -> void:
	thirst = MAX_THIRST
	changed.emit(thirst, MAX_THIRST)
