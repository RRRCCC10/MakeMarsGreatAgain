extends Node

## L'ossigeno diminuisce fuori da una struttura pressurizzata.
## In questa prima mappa non esistono ancora ambienti chiusi, quindi resta sempre in consumo.
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
	if is_in_closed_environment:
		_set_oxygen(oxygen + RECOVERY_PER_SECOND * delta)
	else:
		_set_oxygen(oxygen - LOSS_PER_SECOND * delta)


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
