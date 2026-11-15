extends Node

signal mission_failed(data: Dictionary)

var has_failed := false


func _process(_delta: float) -> void:
	if has_failed:
		return
	if Oxygen.oxygen <= 0.0:
		_fail_mission("oxygen")
	elif Hydration.thirst <= 0.0:
		_fail_mission("water")
	elif Hunger.hunger <= 0.0:
		_fail_mission("food")
	elif Radiation.is_lethal():
		_fail_mission("radiation")
	elif Temperature.is_lethal():
		_fail_mission("cold")


func restart_from_scratch() -> void:
	get_tree().paused = false
	has_failed = false
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("reset_for_new_mission")
	Inventory.reset_for_new_mission()
	Economy.reset_for_new_mission()
	Oxygen.reset_for_new_mission()
	SuitSystem.reset_for_new_mission()
	Hunger.reset_for_new_mission()
	Hydration.reset_for_new_mission()
	WorldClock.reset_for_new_mission()
	SpaceWeatherService.reset_for_new_mission()
	Radiation.reset_for_new_mission()
	Temperature.reset_for_new_mission()
	Shop.reset_for_new_mission()
	DeliveryManager.reset_for_new_mission()
	PipeManager.reset_for_new_mission()
	PowerGrid.reset_for_new_mission()
	BuildableRegistry.reset_for_new_mission()
	AchievementManager.reset_for_new_mission()
	FieldCamera.reset_for_new_mission()
	IncidentManager.reset_for_new_mission()
	SandstormManager.reset_for_new_mission()
	get_tree().reload_current_scene()


func _fail_mission(reason: String) -> void:
	has_failed = true
	var data := _get_death_data(reason)
	mission_failed.emit(data)
	get_tree().paused = true


func _get_death_data(reason: String) -> Dictionary:
	match reason:
		"oxygen":
			return {
				"code": "O₂ // 000",
				"title": "OXYGEN RESERVE DEPLETED",
				"message": "The suit oxygen partial pressure fell below the life-support threshold. Mars's atmosphere, almost entirely CO₂, cannot support human breathing.",
				"epilogue": "The mission ends in the silence of the red planet.",
				"color": Color("74cfff"),
			}
		"water":
			return {
				"code": "H₂O // 000",
				"title": "CRITICAL DEHYDRATION",
				"message": "Water reserves are depleted. Without water, the body can no longer regulate temperature or maintain the circulation required for survival.",
				"epilogue": "The base had power, but not its most essential resource.",
				"color": Color("5ee2e7"),
			}
		"radiation":
			return {
				"code": "RAD // 4000+",
				"title": "IRREVERSIBLE RADIATION DAMAGE",
				"message": "The absorbed dose exceeded the body's ability to repair damaged tissue. On Mars radiation is invisible, but every exposure leaves a mark.",
				"epilogue": "A stable base must protect life from the sky as well.",
				"color": Color("e779ff"),
			}
		"cold":
			return {
				"code": "TERM // 28.0°C",
				"title": "FATAL HYPOTHERMIA",
				"message": "Cold removed more heat than the suit could retain. Body temperature fell below the threshold at which heart, muscles, and brain can coordinate.",
				"epilogue": "On Mars, night is not merely dark: it is a system to engineer and survive.",
				"color": Color("70c9ea"),
			}
	return {
		"code": "KCAL // 000",
		"title": "FOOD RESERVES DEPLETED",
		"message": "The prolonged energy deficit made it impossible to continue operations. Every base system still depended on the strength of a single astronaut.",
		"epilogue": "On Mars, even a greenhouse is a life-support system.",
		"color": Color("ffbf66"),
	}
