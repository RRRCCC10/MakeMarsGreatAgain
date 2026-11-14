extends Node

## La riserva della tuta si ricarica dentro una cupola con atmosfera respirabile.
## Ogni cupola ha una carica iniziale limitata, rifornita da una rete O₂ collegata.
signal changed(current: float, maximum: float)

const MAX_OXYGEN := 100.0
const LOSS_PER_SECOND := 0.30
const RECOVERY_PER_SECOND := 2.0

var oxygen := MAX_OXYGEN
var max_oxygen := MAX_OXYGEN
var is_in_closed_environment := false


func _ready() -> void:
	changed.emit(oxygen, max_oxygen)


func _process(delta: float) -> void:
	var dome := _get_player_dome()
	var breathable := dome != null and bool(dome.call("has_breathable_atmosphere"))
	is_in_closed_environment = breathable
	if breathable:
		_set_oxygen(max_oxygen)
	else:
		var thermal_multiplier := 1.0
		var temperature := get_node_or_null("/root/Temperature")
		if temperature != null and temperature.has_method("get_oxygen_consumption_multiplier"):
			thermal_multiplier = float(temperature.call("get_oxygen_consumption_multiplier"))
		var storm_multiplier := 1.0
		var sandstorms := get_node_or_null("/root/SandstormManager")
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if sandstorms != null and player != null and sandstorms.has_method("get_outdoor_oxygen_multiplier"):
			storm_multiplier = float(sandstorms.call("get_outdoor_oxygen_multiplier", player))
		_set_oxygen(oxygen - LOSS_PER_SECOND * thermal_multiplier * storm_multiplier * delta)


func _player_inside_pressurized_dome() -> bool:
	return _get_player_dome() != null


func _get_player_dome() -> Node:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	for dome in get_tree().get_nodes_in_group("pressurized_interiors"):
		if not is_instance_valid(dome) or not dome.has_method("contains_world_point") or not bool(dome.call("contains_world_point", player.global_position)):
			continue
		return dome
	return null


func set_closed_environment(value: bool) -> void:
	is_in_closed_environment = value


func _set_oxygen(value: float) -> void:
	var new_value := clampf(value, 0.0, max_oxygen)
	if new_value == oxygen:
		return
	oxygen = new_value
	changed.emit(oxygen, max_oxygen)


func set_suit_capacity(capacity: float, reserve: float = -1.0) -> void:
	max_oxygen = maxf(1.0, capacity)
	if reserve >= 0.0:
		oxygen = clampf(reserve, 0.0, max_oxygen)
	else:
		oxygen = minf(oxygen, max_oxygen)
	changed.emit(oxygen, max_oxygen)


func reset_for_new_mission() -> void:
	max_oxygen = MAX_OXYGEN
	oxygen = MAX_OXYGEN
	is_in_closed_environment = false
	changed.emit(oxygen, max_oxygen)
