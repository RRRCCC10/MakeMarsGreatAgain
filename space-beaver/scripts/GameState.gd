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
	Inventory.reset_for_new_mission()
	Economy.reset_for_new_mission()
	Oxygen.reset_for_new_mission()
	SuitSystem.reset_for_new_mission()
	Hunger.reset_for_new_mission()
	Hydration.reset_for_new_mission()
	WorldClock.reset_for_new_mission()
	Radiation.reset_for_new_mission()
	Temperature.reset_for_new_mission()
	Shop.reset_for_new_mission()
	DeliveryManager.reset_for_new_mission()
	PipeManager.reset_for_new_mission()
	PowerGrid.reset_for_new_mission()
	BuildableRegistry.reset_for_new_mission()
	AchievementManager.reset_for_new_mission()
	FieldCamera.reset_for_new_mission()
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
				"title": "RISERVA D'OSSIGENO ESAURITA",
				"message": "La pressione parziale dell'ossigeno nella tuta e' scesa sotto la soglia vitale. Su Marte l'atmosfera, composta quasi interamente da CO₂, non puo' sostenere la respirazione umana.",
				"epilogue": "La missione termina nel silenzio del pianeta rosso.",
				"color": Color("74cfff"),
			}
		"water":
			return {
				"code": "H₂O // 000",
				"title": "DISIDRATAZIONE CRITICA",
				"message": "Le riserve idriche sono finite. Senza acqua il corpo non riesce piu' a regolare la temperatura ne' a mantenere la circolazione necessaria alla sopravvivenza.",
				"epilogue": "La base aveva energia, ma non la risorsa piu' essenziale.",
				"color": Color("5ee2e7"),
			}
		"radiation":
			return {
				"code": "RAD // 4000+",
				"title": "DANNO RADIOLOGICO IRREVERSIBILE",
				"message": "La dose assorbita ha superato la capacita' dell'organismo di riparare i tessuti danneggiati. Su Marte la radiazione non si vede, ma ogni esposizione lascia una traccia.",
				"epilogue": "Una base stabile deve proteggere la vita anche dal cielo.",
				"color": Color("e779ff"),
			}
		"cold":
			return {
				"code": "TERM // 28.0°C",
				"title": "IPOTERMIA FATALE",
				"message": "Il freddo ha sottratto piu' calore di quanto la tuta potesse trattenere. La temperatura corporea e' scesa sotto la soglia in cui cuore, muscoli e cervello riescono a funzionare in modo coordinato.",
				"epilogue": "Su Marte, la notte non e' soltanto buia: e' un sistema da progettare e sopravvivere.",
				"color": Color("70c9ea"),
			}
	return {
		"code": "KCAL // 000",
		"title": "RISERVE ALIMENTARI ESAURITE",
		"message": "Il deficit energetico prolungato ha reso impossibile continuare le operazioni. Ogni sistema della base dipendeva ancora dalla forza dell'unico astronauta.",
		"epilogue": "Su Marte anche una serra e' un sistema di supporto vitale.",
		"color": Color("ffbf66"),
	}

