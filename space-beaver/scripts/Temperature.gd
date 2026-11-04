extends Node

## Termoregolazione EVA. I valori rappresentano temperature superficiali
## marziane tipiche, non la temperatura dell'aria rarefatta. La tuta limita
## il flusso termico, mentre un modulo chiuso fornisce solo un riparo minimo.

signal changed(data: Dictionary)

const NORMAL_CORE_TEMPERATURE_C := 37.0
const LETHAL_CORE_TEMPERATURE_C := 28.0
const SHELTER_BONUS_C := 18.0
const COOLING_PER_GAP_C_PER_HOUR := 0.0065
const OPEN_AIR_RECOVERY_C_PER_HOUR := 0.22
const SHELTER_RECOVERY_C_PER_HOUR := 0.42

const BIOME_PROFILES := {
	0: {"name": "PIANURA DI ATTERRAGGIO", "day_c": -20.0, "night_c": -73.0},
	1: {"name": "REGOLITE SCURA", "day_c": -17.0, "night_c": -68.0},
	2: {"name": "CRATERE ROCCIOSO", "day_c": -35.0, "night_c": -88.0},
	3: {"name": "BORDO DELLA CALOTTA", "day_c": -52.0, "night_c": -98.0},
	4: {"name": "GHIACCIO POLARE", "day_c": -65.0, "night_c": -115.0},
	5: {"name": "ALTOPIANO BASALTICO", "day_c": -30.0, "night_c": -82.0},
}

var core_temperature_c := NORMAL_CORE_TEMPERATURE_C
var ambient_temperature_c := -20.0
var effective_temperature_c := -20.0
var cold_gap_c := 0.0
var current_biome_source_id := 0
var current_biome_name := "PIANURA DI ATTERRAGGIO"
var shelter_bonus_c := 0.0
var shelter_name := "ESPOSTO"
var is_sheltered := false
var _ui_timer := 0.0


func _ready() -> void:
	process_priority = -40
	reset_for_new_mission()


func _process(delta: float) -> void:
	var game_hours := WorldClock.get_game_hours_for_real_delta(delta)
	if game_hours <= 0.0:
		return
	var environment := _resolve_environment()
	current_biome_source_id = int(environment["source_id"])
	current_biome_name = str(environment["biome_name"])
	ambient_temperature_c = float(environment["ambient_c"])
	shelter_bonus_c = float(environment["shelter_bonus_c"])
	shelter_name = str(environment["shelter_name"])
	is_sheltered = shelter_bonus_c > 0.0
	_apply_thermal_step(game_hours, ambient_temperature_c, shelter_bonus_c)
	_ui_timer += delta
	if _ui_timer >= 0.10:
		_ui_timer = 0.0
		changed.emit(get_data())


func get_data() -> Dictionary:
	return {
		"core_temperature_c": core_temperature_c,
		"ambient_temperature_c": ambient_temperature_c,
		"effective_temperature_c": effective_temperature_c,
		"cold_gap_c": cold_gap_c,
		"biome_source_id": current_biome_source_id,
		"biome_name": current_biome_name,
		"shelter_bonus_c": shelter_bonus_c,
		"shelter_name": shelter_name,
		"is_sheltered": is_sheltered,
		"suit_tolerance_c": SuitSystem.get_cold_tolerance_c(),
		"condition": get_condition_label(),
		"condition_color": get_condition_color(),
		"movement_multiplier": get_movement_multiplier(),
		"oxygen_multiplier": get_oxygen_consumption_multiplier(),
		"thermal_health": get_thermal_health(),
	}


func get_surface_temperature_for_source(source_id: int, solar_factor: float = WorldClock.get_solar_factor()) -> float:
	var profile: Dictionary = BIOME_PROFILES.get(source_id, BIOME_PROFILES[0])
	return lerpf(float(profile["night_c"]), float(profile["day_c"]), clampf(solar_factor, 0.0, 1.0))


func get_biome_profile(source_id: int) -> Dictionary:
	return BIOME_PROFILES.get(source_id, BIOME_PROFILES[0]).duplicate()


func get_condition_label() -> String:
	if core_temperature_c <= LETHAL_CORE_TEMPERATURE_C:
		return "IPOTERMIA FATALE"
	if core_temperature_c < 31.5:
		return "IPOTERMIA GRAVE"
	if core_temperature_c < 33.5:
		return "IPOTERMIA MODERATA"
	if core_temperature_c < 35.5:
		return "BRIVIDI E DESTREZZA RIDOTTA"
	return "TERMICO STABILE"


func get_condition_color() -> Color:
	if core_temperature_c <= LETHAL_CORE_TEMPERATURE_C:
		return Color("ff5868")
	if core_temperature_c < 31.5:
		return Color("ff815e")
	if core_temperature_c < 33.5:
		return Color("ffbf69")
	if core_temperature_c < 35.5:
		return Color("8ed6ff")
	return Color("7fe3ba")


func get_movement_multiplier() -> float:
	if core_temperature_c < 31.5:
		return 0.55
	if core_temperature_c < 33.5:
		return 0.75
	if core_temperature_c < 35.5:
		return 0.92
	return 1.0


func get_oxygen_consumption_multiplier() -> float:
	if core_temperature_c < 31.5:
		return 1.60
	if core_temperature_c < 33.5:
		return 1.35
	if core_temperature_c < 35.5:
		return 1.15
	return 1.0


func get_thermal_health() -> float:
	return clampf((core_temperature_c - LETHAL_CORE_TEMPERATURE_C) / (NORMAL_CORE_TEMPERATURE_C - LETHAL_CORE_TEMPERATURE_C) * 100.0, 0.0, 100.0)


func is_lethal() -> bool:
	return core_temperature_c <= LETHAL_CORE_TEMPERATURE_C


func reset_for_new_mission() -> void:
	core_temperature_c = NORMAL_CORE_TEMPERATURE_C
	ambient_temperature_c = get_surface_temperature_for_source(0)
	effective_temperature_c = ambient_temperature_c
	cold_gap_c = 0.0
	current_biome_source_id = 0
	current_biome_name = str(BIOME_PROFILES[0]["name"])
	shelter_bonus_c = 0.0
	shelter_name = "ESPOSTO"
	is_sheltered = false
	_ui_timer = 0.0
	changed.emit(get_data())


func _resolve_environment() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var source_id := 0
	if player != null and get_tree().current_scene != null:
		var map_provider := get_tree().current_scene.get_node_or_null("Map")
		if map_provider != null and map_provider.has_method("world_to_cell") and map_provider.has_method("get_source_id"):
			var cell: Vector2i = map_provider.call("world_to_cell", player.global_position)
			var resolved_source := int(map_provider.call("get_source_id", cell))
			if resolved_source >= 0:
				source_id = resolved_source
	var shelter := _get_shelter_at(player.global_position if player != null else Vector2.ZERO)
	var profile: Dictionary = BIOME_PROFILES.get(source_id, BIOME_PROFILES[0])
	return {
		"source_id": source_id,
		"biome_name": str(profile["name"]),
		"ambient_c": get_surface_temperature_for_source(source_id),
		"shelter_bonus_c": float(shelter["bonus_c"]),
		"shelter_name": str(shelter["name"]),
	}


func _get_shelter_at(world_position: Vector2) -> Dictionary:
	var strongest_bonus := 0.0
	var strongest_name := "ESPOSTO"
	for entry in BuildableRegistry.get_entries():
		var structure := entry.get("node") as Node2D
		if structure == null or not is_instance_valid(structure) or not structure.has_method("contains_world_point"):
			continue
		if not bool(structure.call("contains_world_point", world_position)):
			continue
		var bonus := 0.0
		if structure.has_method("get_thermal_shelter_bonus_c"):
			bonus = float(structure.call("get_thermal_shelter_bonus_c"))
		elif str(entry.get("kind", "")) in ["mission_structure", "building", "shelter"]:
			bonus = SHELTER_BONUS_C
		if bonus > strongest_bonus:
			strongest_bonus = bonus
			strongest_name = str(entry.get("display_name", "RIFUGIO"))
	return {"bonus_c": strongest_bonus, "name": strongest_name}


func _apply_thermal_step(game_hours: float, ambient_c: float, shelter_c: float) -> void:
	effective_temperature_c = ambient_c + maxf(0.0, shelter_c)
	var tolerance := SuitSystem.get_cold_tolerance_c()
	cold_gap_c = maxf(0.0, tolerance - effective_temperature_c)
	if cold_gap_c > 0.0:
		core_temperature_c = maxf(LETHAL_CORE_TEMPERATURE_C, core_temperature_c - cold_gap_c * COOLING_PER_GAP_C_PER_HOUR * game_hours)
	else:
		var recovery := SHELTER_RECOVERY_C_PER_HOUR if shelter_c > 0.0 else OPEN_AIR_RECOVERY_C_PER_HOUR
		core_temperature_c = minf(NORMAL_CORE_TEMPERATURE_C, core_temperature_c + recovery * game_hours)
