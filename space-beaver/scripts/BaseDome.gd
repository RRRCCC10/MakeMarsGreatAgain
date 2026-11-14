extends Node2D
class_name BaseDome

const TILE_SIZE := 16
const SIZES := {
	"dome_small": {"label": "Cupola base piccola", "radius": 62.0, "price": 1_200_000_000},
	"dome_medium": {"label": "Cupola base media", "radius": 108.0, "price": 2_400_000_000},
	"dome_large": {"label": "Cupola base grande", "radius": 145.0, "price": 4_000_000_000},
}
const THERMAL_SHELTER_BONUS_C := 8.0
const POWERED_THERMAL_SHELTER_BONUS_C := 45.0
const HEATER_DEMAND_KW := 35.0
const INITIAL_OXYGEN_UNITS := 180.0
const OXYGEN_PASSIVE_LOSS_PER_SECOND := 0.02
const OXYGEN_OCCUPANT_LOSS_PER_SECOND := 0.30
const OXYGEN_UNITS_PER_KG := 100.0
const OXYGEN_RESERVE_REFILL_UNITS_PER_SECOND := 1.5
const LEAD_DOME_COST := 500_000_000
const HYDROGEN_SHIELD_COST := 350_000_000
const ROVER_PAD_COST := 600_000_000
const ROVER_PURCHASE_COST := 2_400_000_000
const ROVER_RECALL_COST := 300_000_000
const ROVER_PAD_CHARGE_KW := 55.0
const ROVER_PAD_POWER_DEMAND_KW := 50.0
const OXYGEN_PIPE_SHEET := preload("res://sprites/machines/pipe-spritesheet.png")
const ROVER_PAD_TEXTURE := preload("res://assets/base_dome/rover_charging_pad.png")
const ROVER_SCRIPT := preload("res://scripts/Rover.gd")
const DOOR_FRAME_SECONDS := 0.11
const AIRLOCK_FRAMES := 4
const SEQUENCE_LENGTH := 4
const DIRECTION_NAMES := ["right", "down", "left", "up"]
const DIRECTION_VECTORS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const EXTERIOR_TEXTURES := {
	"dome_small": preload("res://assets/base_dome/small_exterior.png"),
	"dome_medium": preload("res://assets/base_dome/medium_exterior.png"),
	"dome_large": preload("res://assets/base_dome/large_exterior.png"),
}
const INTERIOR_TEXTURES := {
	"dome_small": preload("res://assets/base_dome/small_interior.png"),
	"dome_medium": preload("res://assets/base_dome/medium_interior.png"),
	"dome_large": preload("res://assets/base_dome/large_interior.png"),
}
const CORRIDOR_SHEETS := {
	"right": preload("res://assets/base_dome/corridor_right.png"),
	"down": preload("res://assets/base_dome/corridor_down.png"),
	"left": preload("res://assets/base_dome/corridor_left.png"),
	"up": preload("res://assets/base_dome/corridor_up.png"),
}
const DOOR_OPEN_SHEETS := {
	"right": preload("res://assets/base_dome/door_open_right.png"),
	"down": preload("res://assets/base_dome/door_open_down.png"),
	"left": preload("res://assets/base_dome/door_open_left.png"),
	"up": preload("res://assets/base_dome/door_open_up.png"),
}
const DOOR_CLOSE_SHEETS := {
	"right": preload("res://assets/base_dome/door_close_right.png"),
	"down": preload("res://assets/base_dome/door_close_down.png"),
	"left": preload("res://assets/base_dome/door_close_left.png"),
	"up": preload("res://assets/base_dome/door_close_up.png"),
}
const DIRECTION_KEYS := [KEY_D, KEY_S, KEY_A, KEY_W]
const DIRECTION_KEY_LABELS := ["D", "S", "A", "W"]

var dome_id := "dome_small"
var entrance_direction := 1
var is_preview := false
var _sprite: Sprite2D
var _corridor_sprite: Sprite2D
var _outer_door_sprite: Sprite2D
var _inner_door_sprite: Sprite2D
var _outer_gate: CollisionShape2D
var _inner_gate: CollisionShape2D
var _boundary_body: StaticBody2D
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _airlock_busy := false
var _outer_door_open := false
var _inner_door_open := false
var _airlock_path := ""
var _sequence_active := false
var _sequence_complete := false
var _sequence: Array[int] = []
var _sequence_progress := 0
var _sequence_feedback := ""
var _sequence_player: Node2D
var _first_door_crossed := false
var _faulted_doors := {"outer_door": false, "inner_door": false}
var network_enabled := true
var powered := false
var oxygen_reserve := INITIAL_OXYGEN_UNITS
var _oxygen_input_cell := Vector2i.ZERO
var _oxygen_port_marker: Sprite2D
var _dome_status_panel: PanelContainer
var _dome_status_label: Label
var configuration: Dictionary = {}
var _rover_pad_sprite: Sprite2D
var _rover_pad_area: Area2D
var _rover_pad_body: StaticBody2D
var _rover_pad_label: Label
var _rover_pad_feedback := ""


func _ready() -> void:
	_build_visuals()
	if not is_preview:
		add_to_group("base_domes")
		add_to_group("pressurized_interiors")
		_build_boundary_and_corridor()
		_build_prompt()
		_build_port_markers()
		var registry := get_tree().root.get_node_or_null("BuildableRegistry")
		if registry != null:
			registry.call("register_buildable", self, str(SIZES[dome_id]["label"]), "building", Callable(self, "_destroy"))
		call_deferred("_register_connections")
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("register_target", self, "outer_door", "PORTA ESTERNA · %s" % str(SIZES[dome_id]["label"]), 0.5)
			incidents.call("register_target", self, "inner_door", "PORTA INTERNA · %s" % str(SIZES[dome_id]["label"]), 0.5)
	_refresh_rover_pad()
	_apply_door_frames()


func setup(size_id: String, direction: int = 1, preview: bool = false, dome_configuration: Dictionary = {}) -> void:
	dome_id = size_id if SIZES.has(size_id) else "dome_small"
	entrance_direction = posmod(direction, 4)
	is_preview = preview
	configuration = dome_configuration.duplicate(true)
	if is_node_ready():
		_refresh_visuals()
		_refresh_rover_pad()
		_apply_door_frames()


func get_radius() -> float:
	return float(SIZES.get(dome_id, SIZES["dome_small"])["radius"])


static func world_position_for(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


static func can_place_at(world_position: Vector2, size_id: String, dome_configuration: Dictionary = {}, direction: int = 1) -> bool:
	var definition: Dictionary = SIZES.get(size_id, SIZES["dome_small"])
	var radius := float(definition["radius"])
	var has_rover_pad := bool(dome_configuration.get("rover_pad", false)) and size_id in ["dome_medium", "dome_large"]
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	if not is_placement_clear_of_player_and_rocks(world_position, radius, direction):
		return false
	var map_provider: Node = tree.get_first_node_in_group("world_map_provider") if tree != null else null
	if map_provider != null and map_provider.has_method("clamp_world_position"):
		var clamped: Vector2 = map_provider.call("clamp_world_position", world_position, radius + 58.0)
		if clamped.distance_to(world_position) > 0.1:
			return false
	var registry := tree.root.get_node_or_null("BuildableRegistry") if tree != null else null
	if registry == null:
		return true
	for entry in registry.call("get_entries"):
		var other := entry.get("node") as Node2D
		if other == null or not is_instance_valid(other):
			continue
		if other.has_method("get_radius") and world_position.distance_to(other.global_position) < radius + float(other.call("get_radius")) + 8.0:
			return false
		if other.has_method("contains_world_point") and bool(other.call("contains_world_point", world_position)):
			return false
		if has_rover_pad:
			var pad_position := world_position + Vector2(-radius - 32.0, 0.0)
			if other.has_method("contains_world_point") and bool(other.call("contains_world_point", pad_position)):
				return false
			if other.has_method("get_radius") and pad_position.distance_to(other.global_position) < float(other.call("get_radius")) + 36.0:
				return false
		if other.has_method("contains_world_point"):
			for sample_index in 24:
				var angle := TAU * float(sample_index) / 24.0
				if bool(other.call("contains_world_point", world_position + Vector2(cos(angle), sin(angle)) * radius)):
					return false
	return true


static func is_placement_clear_of_player_and_rocks(center: Vector2, radius: float, direction: int = 1) -> bool:
	## Controlla l'intera impronta della cupola e la sua camera di decompressione.
	## Le rocce hanno un collider di circa 14px; il player ne occupa circa 12px.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var blockers: Array[Node2D] = []
	var player := tree.get_first_node_in_group("player") as Node2D
	if player != null:
		blockers.append(player)
	for rock in tree.get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and is_instance_valid(rock):
			blockers.append(rock as Node2D)
	var outward: Vector2 = DIRECTION_VECTORS[posmod(direction, DIRECTION_VECTORS.size())]
	var side := Vector2(-outward.y, outward.x)
	for blocker in blockers:
		var blocker_radius := 14.0 if blocker.is_in_group("collectible_rocks") else 12.0
		if blocker.global_position.distance_to(center) <= radius + blocker_radius:
			return false
		var relative := blocker.global_position - center
		var along := relative.dot(outward)
		var across := absf(relative.dot(side))
		if along >= radius - 16.0 - blocker_radius and along <= radius + 52.0 + blocker_radius and across <= 24.0 + blocker_radius:
			return false
	return true


static func place(parent: Node, size_id: String, cell: Vector2i, direction: int = 1, dome_configuration: Dictionary = {}) -> BaseDome:
	var world_position := world_position_for(cell)
	if not can_place_at(world_position, size_id, dome_configuration, direction):
		return null
	var dome := BaseDome.new()
	dome.setup(size_id, direction, false, dome_configuration)
	parent.add_child(dome)
	dome.global_position = world_position
	var achievements := parent.get_node_or_null("/root/AchievementManager")
	if achievements != null:
		achievements.call("record", "first_base")
	return dome


func contains_world_point(world_position: Vector2) -> bool:
	return global_position.distance_to(world_position) <= get_radius() - 8.0


func is_in_corridor(world_position: Vector2) -> bool:
	var relative := world_position - global_position
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	var side := Vector2(-outward.y, outward.x)
	var along := relative.dot(outward)
	var across := absf(relative.dot(side))
	return along >= get_radius() - 14.0 and along <= get_radius() + 47.0 and across <= 22.0


func get_outer_door_position() -> Vector2:
	return global_position + DIRECTION_VECTORS[entrance_direction] * (get_radius() + 24.0)


func get_inner_door_position() -> Vector2:
	return global_position + DIRECTION_VECTORS[entrance_direction] * (get_radius() - 8.0)


func get_corridor_center_position() -> Vector2:
	return global_position + DIRECTION_VECTORS[entrance_direction] * (get_radius() + 16.0)


func get_thermal_shelter_bonus_c() -> float:
	return POWERED_THERMAL_SHELTER_BONUS_C if powered else THERMAL_SHELTER_BONUS_C


func get_oxygen_input_cell() -> Vector2i:
	return _oxygen_input_cell


func is_oxygen_connected() -> bool:
	var pipe_manager := get_node_or_null("/root/PipeManager")
	return pipe_manager != null and bool(pipe_manager.call("is_input_connected", _oxygen_input_cell, Vector2i.LEFT, PipeSegment.Category.OXYGEN))


func has_breathable_atmosphere() -> bool:
	return oxygen_reserve > 0.0


func get_oxygen_loss_rate() -> float:
	return OXYGEN_PASSIVE_LOSS_PER_SECOND + (OXYGEN_OCCUPANT_LOSS_PER_SECOND if _player_is_inside() else 0.0)


func get_oxygen_reserve_percent() -> float:
	return clampf(oxygen_reserve / INITIAL_OXYGEN_UNITS, 0.0, 1.0)


func _player_is_inside() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and contains_world_point(player.global_position)


func _update_oxygen_reserve(delta: float) -> void:
	if delta <= 0.0:
		return
	var atmospheric_demand_units := get_oxygen_loss_rate() * delta
	var loss_units := minf(oxygen_reserve, atmospheric_demand_units)
	# Prima si applica il consumo (anche a cupola vuota), poi si reintegra solo
	# ciò che è stato realmente perso e che una sorgente può fornire ora.
	oxygen_reserve = maxf(0.0, oxygen_reserve - loss_units)
	var reserve_space := INITIAL_OXYGEN_UNITS - oxygen_reserve
	var refill_units := minf(maxf(atmospheric_demand_units, OXYGEN_RESERVE_REFILL_UNITS_PER_SECOND * delta), reserve_space)
	if refill_units <= 0.0 or not is_oxygen_connected():
		return
	# La richiesta segue il consumo atmosferico effettivo: il macchinario resta
	# comunque il limite reale, perché può consegnare solo il suo flusso corrente.
	var requested_kg := refill_units / OXYGEN_UNITS_PER_KG
	if requested_kg <= 0.0:
		return
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager == null:
		return
	var supplied_kg := float(pipe_manager.call("consume_connected_resource", _oxygen_input_cell, Vector2i.LEFT, PipeSegment.Category.OXYGEN, requested_kg))
	oxygen_reserve = minf(INITIAL_OXYGEN_UNITS, oxygen_reserve + maxf(0.0, supplied_kg) * OXYGEN_UNITS_PER_KG)


func handle_oxygen_port_right_click(world_position: Vector2) -> bool:
	if is_preview or _oxygen_port_marker == null or not is_instance_valid(_oxygen_port_marker):
		return false
	if world_position.distance_to(_oxygen_port_marker.global_position) > 13.0:
		return false
	_dome_status_panel.visible = not _dome_status_panel.visible
	_refresh_dome_status()
	return true


func _refresh_dome_status() -> void:
	if _dome_status_label == null or not _dome_status_panel.visible:
		return
	var loss_rate := get_oxygen_loss_rate()
	var seconds_left := oxygen_reserve / loss_rate if loss_rate > 0.0 else INF
	var connected_sources: Array = []
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager != null and pipe_manager.has_method("get_connected_source_nodes"):
		connected_sources = pipe_manager.call("get_connected_source_nodes", _oxygen_input_cell, Vector2i.LEFT, PipeSegment.Category.OXYGEN)
	var source_status := "nessuna sorgente collegata"
	if not connected_sources.is_empty():
		var source_names := PackedStringArray()
		for source in connected_sources:
			var name := str(source.call("get_display_name")) if source.has_method("get_display_name") else str(source.name)
			var flow := float(source.call("get_fluid_output_available_for_category", PipeSegment.Category.OXYGEN)) if source.has_method("get_fluid_output_available_for_category") else -1.0
			source_names.append("%s (%s)" % [name, "flusso disponibile %.3f kg/tick" % flow if flow >= 0.0 else "rete connessa; flusso non esposto"])
		source_status = ", ".join(source_names)
	var power_grid := get_node_or_null("/root/PowerGrid")
	var power_connected := power_grid != null and bool(power_grid.get("connection_ok").get(self, false))
	var occupied := _player_is_inside()
	var shields := PackedStringArray()
	if bool(configuration.get("lead_shielding", false)):
		shields.append("piombo")
	if bool(configuration.get("hydrogen_shielding", false)):
		shields.append("materiale idrogenato")
	var shield_status := ", ".join(shields) if not shields.is_empty() else "nessuna"
	var pad_status := "assente" if not has_rover_charging_pad() else ("alimentata · %.0f kW" % get_rover_pad_charge_rate_kw() if is_rover_pad_powered() else "presente · attende alimentazione")
	_dome_status_label.text = "%s\nO₂ cupola: %.1f / %.0f (%.0f%%)\nConsumo: %.2f unità/s (%s) — passivo %.2f + occupante %.2f\nAutonomia stimata al consumo attuale: %s\nTubo O₂: %s\nSorgente/i: %s\nRicarica riserva: max %.1f unità/s\nRiscaldamento: %s — bonus %.0f °C\nSchermature: %s\nBase rover: %s\nTasto destro sul raccordo per chiudere" % [str(SIZES[dome_id]["label"]), oxygen_reserve, INITIAL_OXYGEN_UNITS, get_oxygen_reserve_percent() * 100.0, loss_rate, "giocatore dentro" if occupied else "cupola vuota", OXYGEN_PASSIVE_LOSS_PER_SECOND, OXYGEN_OCCUPANT_LOSS_PER_SECOND if occupied else 0.0, _format_duration(seconds_left), "collegato" if not connected_sources.is_empty() else "scollegato", source_status, OXYGEN_RESERVE_REFILL_UNITS_PER_SECOND, "alimentato" if powered and power_connected else ("rete collegata, non alimentato" if power_connected else "non alimentato"), get_thermal_shelter_bonus_c(), shield_status, pad_status]


func _format_duration(seconds: float) -> String:
	if is_inf(seconds):
		return "indefinita"
	var total_minutes := int(floor(seconds / 60.0))
	return "%d h %02d min" % [total_minutes / 60, total_minutes % 60]


func is_network_enabled() -> bool:
	return network_enabled


func set_network_enabled(value: bool) -> void:
	if is_preview or network_enabled == value:
		return
	network_enabled = value
	if not network_enabled:
		set_powered(false)
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")


func get_display_name() -> String:
	return str(SIZES.get(dome_id, SIZES["dome_small"]).get("label", "Cupola abitativa")).to_upper()


func set_powered(value: bool) -> void:
	powered = value


func get_power_connection_cell() -> Vector2i:
	return Vector2i(floori((global_position.x - get_radius() - 8.0) / TILE_SIZE), floori(global_position.y / TILE_SIZE))


func get_power_demand_kw() -> float:
	return HEATER_DEMAND_KW + (ROVER_PAD_POWER_DEMAND_KW if has_rover_charging_pad() else 0.0)


func has_rover_charging_pad() -> bool:
	return bool(configuration.get("rover_pad", false)) and dome_id in ["dome_medium", "dome_large"]


func is_rover_on_charging_pad(rover: Node2D) -> bool:
	return has_rover_charging_pad() and is_instance_valid(rover) and rover.global_position.distance_to(_get_rover_parking_position()) <= 27.0


func is_rover_pad_powered() -> bool:
	var power_grid := get_node_or_null("/root/PowerGrid")
	return has_rover_charging_pad() and powered and power_grid != null and bool(power_grid.get("connection_ok").get(self, false))


func get_rover_pad_charge_rate_kw() -> float:
	return ROVER_PAD_CHARGE_KW if is_rover_pad_powered() else 0.0


func get_rover_pad_position() -> Vector2:
	return global_position + Vector2(-get_radius() - 32.0, 0.0)


func _player_is_at_rover_pad(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player) or not has_rover_charging_pad():
		return false
	# Il collider fisico ferma il player appena fuori dalla piattaforma; l'area
	# di utilizzo deve includere quel bordo, altrimenti E non arriva al dock.
	var bounds := Rect2(get_rover_pad_position() - Vector2(36.0, 36.0), Vector2(72.0, 72.0))
	return bounds.has_point(player.global_position)


func _get_rover_parking_position() -> Vector2:
	# Il mezzo occupa la metà alta della base: restano riconoscibili sia il rover
	# sia l'anello di ricarica sottostante.
	return get_rover_pad_position() + Vector2(-2.0, -13.0)


func get_cosmic_radiation_protection() -> float:
	if not _player_is_inside():
		return 0.0
	var protection := 0.0
	if bool(configuration.get("lead_shielding", false)):
		protection = 1.0 - (1.0 - protection) * (1.0 - 0.08)
	if bool(configuration.get("hydrogen_shielding", false)):
		protection = 1.0 - (1.0 - protection) * (1.0 - 0.35)
	return protection


func get_solar_radiation_protection() -> float:
	if not _player_is_inside():
		return 0.0
	var protection := 0.0
	if bool(configuration.get("lead_shielding", false)):
		protection = 1.0 - (1.0 - protection) * (1.0 - 0.25)
	if bool(configuration.get("hydrogen_shielding", false)):
		protection = 1.0 - (1.0 - protection) * (1.0 - 0.12)
	return protection


func get_power_attach_direction() -> Vector2i:
	return Vector2i.RIGHT


func get_occupied_power_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var min_cell := Vector2i(floori((global_position.x - get_radius()) / TILE_SIZE), floori((global_position.y - get_radius()) / TILE_SIZE))
	var max_cell := Vector2i(floori((global_position.x + get_radius()) / TILE_SIZE), floori((global_position.y + get_radius()) / TILE_SIZE))
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			if global_position.distance_to(Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)) <= get_radius():
				cells.append(Vector2i(x, y))
	return cells


func get_sequence_keys() -> Array[int]:
	return _sequence.duplicate()


func is_sequence_active() -> bool:
	return _sequence_active


func is_sequence_complete() -> bool:
	return _sequence_complete


func is_door_open(door_name: String) -> bool:
	return _outer_door_open if door_name == "outer" else _inner_door_open


func can_interact(player: Node2D) -> bool:
	return not get_prompt_for_player(player).is_empty()


func get_prompt_for_player(player: Node2D) -> String:
	if is_preview or player == null or not is_instance_valid(player):
		return ""
	if is_incident_faulted("outer_door") and player.global_position.distance_to(get_outer_door_position()) <= 62.0:
		return "PORTA ESTERNA IN GUASTO · E  ·  RIPARA"
	if is_incident_faulted("inner_door") and player.global_position.distance_to(get_inner_door_position()) <= 58.0:
		return "PORTA INTERNA IN GUASTO · E  ·  RIPARA"
	if _player_is_at_rover_pad(player):
		var rover := _get_existing_rover()
		if rover == null:
			return "E  ·  COMPRA ROVER (%s)%s" % [_format_money(ROVER_PURCHASE_COST), "\n" + _rover_pad_feedback if not _rover_pad_feedback.is_empty() else ""]
		if is_rover_on_charging_pad(rover):
			var battery_percent := roundi(float(rover.get("battery_energy_kwh")) / Rover.BATTERY_CAPACITY_KWH * 100.0)
			return "ROVER ATTRACCATO · %d%% BATTERIA\nE  ·  SALI SUL ROVER · %s" % [battery_percent, "RICARICA RAPIDA" if is_rover_pad_powered() else "IN ATTESA DI ALIMENTAZIONE"]
		return "E  ·  RICHIAMA ROVER (%s)%s" % [_format_money(ROVER_RECALL_COST), "\n" + _rover_pad_feedback if not _rover_pad_feedback.is_empty() else ""]
	if _airlock_busy:
		if is_in_corridor(player.global_position) or player.global_position.distance_to(get_outer_door_position()) <= 36.0 or player.global_position.distance_to(get_inner_door_position()) <= 30.0:
			return "Porta in movimento — attendi"
		return ""
	if _sequence_active and player == _sequence_player:
		return _sequence_prompt()
	if is_in_corridor(player.global_position):
		if _sequence_complete:
			return "F  ·  Apri la porta %s" % ("interna" if _airlock_path == "enter" else "esterna")
		if _outer_door_open or _inner_door_open:
			var projected := (player.global_position - global_position).dot(DIRECTION_VECTORS[entrance_direction])
			if _airlock_path == "enter" and _outer_door_open and projected > get_radius() + 8.0:
				return "Attraversa la porta esterna per entrare"
			if _airlock_path == "exit" and _inner_door_open and projected < get_radius() + 8.0:
				return "Attraversa la porta interna per uscire"
			return "Attendi la chiusura della porta alle tue spalle"
		if _airlock_path not in ["enter", "exit"]:
			return "Apri la prima porta con E prima di avviare la sequenza"
		return "F  ·  Avvia la sequenza di %s" % ("pressurizzazione" if _airlock_path == "enter" else "decompressione")
	if not is_in_corridor(player.global_position) and contains_world_point(player.global_position) and player.global_position.distance_to(get_inner_door_position()) <= 30.0:
		return "E  ·  Chiudi la porta interna" if _inner_door_open else "E  ·  Apri la porta verso il corridoio"
	var projected := (player.global_position - global_position).dot(DIRECTION_VECTORS[entrance_direction])
	if not contains_world_point(player.global_position) and projected >= get_radius() + 32.0 and player.global_position.distance_to(get_outer_door_position()) <= 36.0:
		return "E  ·  Chiudi la porta esterna" if _outer_door_open else "E  ·  Apri la porta verso l'esterno"
	return ""


func _format_money(amount: int) -> String:
	var economy := get_node_or_null("/root/Economy")
	return str(economy.call("format_money", amount)) if economy != null else "$%d" % amount


func handle_airlock_key(player: Node2D, keycode: int) -> bool:
	if is_preview or _airlock_busy or player == null or not is_instance_valid(player):
		return false
	if keycode == KEY_E and _handle_rover_pad_action(player):
		return true
	if _sequence_active:
		if player != _sequence_player:
			return false
		if keycode in DIRECTION_KEYS:
			_accept_sequence_key(player, keycode)
		return true
	if keycode == KEY_E:
		var projected := (player.global_position - global_position).dot(DIRECTION_VECTORS[entrance_direction])
		if not contains_world_point(player.global_position) and projected >= get_radius() + 32.0 and player.global_position.distance_to(get_outer_door_position()) <= 36.0:
			if _outer_door_open:
				if not is_in_corridor(player.global_position):
					_animate_door("outer", false)
			else:
				_airlock_path = "enter"
				_reset_cycle()
				_animate_door("outer", true)
			return true
		if not is_in_corridor(player.global_position) and contains_world_point(player.global_position) and player.global_position.distance_to(get_inner_door_position()) <= 30.0:
			if _inner_door_open:
				_animate_door("inner", false)
			else:
				_airlock_path = "exit"
				_reset_cycle()
			_animate_door("inner", true)
			return true
	if keycode == KEY_F and is_in_corridor(player.global_position):
		if _sequence_complete:
			if _airlock_path == "enter" and player.global_position.distance_to(get_inner_door_position()) <= 32.0:
				_animate_door("inner", true)
				return true
			if _airlock_path == "exit" and player.global_position.distance_to(get_outer_door_position()) <= 32.0:
				_animate_door("outer", true)
				return true
			return false
		if _airlock_path in ["enter", "exit"] and _first_door_crossed and not _outer_door_open and not _inner_door_open:
			_start_sequence(player)
			return true
	return false


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "DomeSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 0
	add_child(_sprite)
	_corridor_sprite = Sprite2D.new()
	_corridor_sprite.name = "AirlockCorridor"
	_corridor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corridor_sprite.z_index = 0
	add_child(_corridor_sprite)
	_outer_door_sprite = Sprite2D.new()
	_outer_door_sprite.name = "OuterDoor"
	_outer_door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outer_door_sprite.z_index = 0
	add_child(_outer_door_sprite)
	_inner_door_sprite = Sprite2D.new()
	_inner_door_sprite.name = "InnerDoor"
	_inner_door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_inner_door_sprite.z_index = 0
	add_child(_inner_door_sprite)
	_refresh_visuals()


func _refresh_visuals() -> void:
	if _sprite == null:
		return
	var direction_name: String = DIRECTION_NAMES[entrance_direction]
	var corridor_frame := _sheet_frame(CORRIDOR_SHEETS[direction_name], 0)
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	var corridor_length := corridor_frame.region.size.x if not is_zero_approx(outward.x) else corridor_frame.region.size.y
	_corridor_sprite.texture = corridor_frame
	_corridor_sprite.position = outward * (get_radius() + corridor_length * 0.5)
	_outer_door_sprite.position = outward * (get_radius() + corridor_length - _door_depth(direction_name) * 0.5)
	_inner_door_sprite.position = outward * (get_radius() - _door_depth(direction_name) * 0.5)
	if is_preview:
		_sprite.texture = EXTERIOR_TEXTURES[dome_id]
	else:
		_update_interior_art()
	_refresh_rover_pad()


func _refresh_rover_pad() -> void:
	if not has_rover_charging_pad():
		if is_instance_valid(_rover_pad_sprite):
			_rover_pad_sprite.queue_free()
		if is_instance_valid(_rover_pad_area):
			_rover_pad_area.queue_free()
		if is_instance_valid(_rover_pad_body):
			_rover_pad_body.queue_free()
		if is_instance_valid(_rover_pad_label):
			_rover_pad_label.queue_free()
		_rover_pad_sprite = null
		_rover_pad_area = null
		_rover_pad_body = null
		_rover_pad_label = null
		return
	if _rover_pad_sprite == null or not is_instance_valid(_rover_pad_sprite):
		_rover_pad_sprite = Sprite2D.new()
		_rover_pad_sprite.name = "RoverChargingPad"
		_rover_pad_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_rover_pad_sprite.texture = ROVER_PAD_TEXTURE
		_rover_pad_sprite.z_index = 3
		add_child(_rover_pad_sprite)
	_rover_pad_sprite.position = Vector2(-get_radius() - 32.0, 0.0)
	_rover_pad_sprite.visible = true
	if _rover_pad_area == null or not is_instance_valid(_rover_pad_area):
		_rover_pad_area = Area2D.new()
		_rover_pad_area.name = "RoverPadInteractionArea"
		_rover_pad_area.collision_layer = 0
		_rover_pad_area.collision_mask = 1
		_rover_pad_area.monitoring = true
		_rover_pad_area.monitorable = false
		_rover_pad_area.position = Vector2(-get_radius() - 32.0, 0.0)
		var pad_shape := CollisionShape2D.new()
		pad_shape.name = "RoverPadHitbox"
		var pad_rectangle := RectangleShape2D.new()
		pad_rectangle.size = Vector2(72.0, 72.0)
		pad_shape.shape = pad_rectangle
		_rover_pad_area.add_child(pad_shape)
		add_child(_rover_pad_area)
	if _rover_pad_body == null or not is_instance_valid(_rover_pad_body):
		_rover_pad_body = StaticBody2D.new()
		_rover_pad_body.name = "RoverPadBody"
		# Il player urta la base (layer 2, come le rocce); il rover la ignora
		# perché usa la sola layer 1 per poter partire senza restare incastrato.
		_rover_pad_body.collision_layer = 2
		_rover_pad_body.collision_mask = 0
		_rover_pad_body.position = Vector2(-get_radius() - 32.0, 0.0)
		var body_shape := CollisionShape2D.new()
		body_shape.name = "RoverPadCollision"
		var body_rectangle := RectangleShape2D.new()
		body_rectangle.size = Vector2(44.0, 44.0)
		body_shape.shape = body_rectangle
		_rover_pad_body.add_child(body_shape)
		add_child(_rover_pad_body)
	if _rover_pad_label == null or not is_instance_valid(_rover_pad_label):
		_rover_pad_label = Label.new()
		_rover_pad_label.name = "RoverPadStatus"
		_rover_pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rover_pad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rover_pad_label.add_theme_font_size_override("font_size", 10)
		_rover_pad_label.add_theme_color_override("font_color", Color("f4f0d6"))
		_rover_pad_label.add_theme_color_override("font_shadow_color", Color("101820", 0.95))
		_rover_pad_label.add_theme_constant_override("shadow_offset_x", 1)
		_rover_pad_label.add_theme_constant_override("shadow_offset_y", 1)
		_rover_pad_label.z_index = 12
		_rover_pad_label.size = Vector2(150.0, 18.0)
		_rover_pad_label.position = Vector2(-get_radius() - 107.0, -43.0)
		add_child(_rover_pad_label)
	_update_rover_pad_status()


func _update_rover_pad_status() -> void:
	if not is_instance_valid(_rover_pad_label):
		return
	var rover := _get_existing_rover()
	var docked := rover != null and is_rover_on_charging_pad(rover)
	_rover_pad_label.visible = docked
	if docked:
		# Non forzare l'aspetto "parcheggiato" dopo che il player e' salito:
		# il rover puo' restare per un istante sulla piazzola prima di partire.
		if rover.has_method("present_docked_at_base") and not is_instance_valid(rover.get("driver") as Node):
			rover.call("present_docked_at_base")
		var battery_percent := 0
		if rover.get("battery_energy_kwh") != null:
			battery_percent = roundi(float(rover.get("battery_energy_kwh")) / Rover.BATTERY_CAPACITY_KWH * 100.0)
		_rover_pad_label.text = "ROVER · %d%% · %s" % [battery_percent, "RICARICA RAPIDA" if is_rover_pad_powered() else "IN ATTESA DI ALIMENTAZIONE"]


func _get_existing_rover() -> Node2D:
	for rover in get_tree().get_nodes_in_group("rovers"):
		if rover is Node2D and is_instance_valid(rover) and not rover.is_queued_for_deletion() and not bool(rover.get("is_preview")):
			return rover as Node2D
	return null


func _handle_rover_pad_action(player: Node2D) -> bool:
	if not _player_is_at_rover_pad(player):
		return false
	_rover_pad_feedback = ""
	var rover := _get_existing_rover()
	if rover == null:
		var economy := get_node_or_null("/root/Economy")
		if economy == null or not bool(economy.call("spend", ROVER_PURCHASE_COST)):
			_rover_pad_feedback = "Fondi insufficienti per il rover"
			_update_prompt()
			return true
		rover = ROVER_SCRIPT.new() as Node2D
		get_tree().current_scene.add_child(rover)
		rover.global_position = _get_rover_parking_position()
		rover.set("battery_energy_kwh", Rover.STARTING_ENERGY_KWH)
		rover.call("present_docked_at_base")
		_rover_pad_feedback = "Rover acquistato · %d%% batteria" % roundi(Rover.STARTING_ENERGY_KWH / Rover.BATTERY_CAPACITY_KWH * 100.0)
		_update_prompt()
		return true
	if is_rover_on_charging_pad(rover):
		# Non rubare E al player: il suo handler deve poter far salire sul rover.
		return false
	if not rover.has_method("can_be_recalled_to_base") or not bool(rover.call("can_be_recalled_to_base")):
		_rover_pad_feedback = "Scendi dal rover e chiudi i pannelli prima del richiamo"
		_update_prompt()
		return true
	var economy := get_node_or_null("/root/Economy")
	if economy == null or not bool(economy.call("spend", ROVER_RECALL_COST)):
		_rover_pad_feedback = "Fondi insufficienti per richiamare il rover"
		_update_prompt()
		return true
	rover.call("prepare_base_recall", _get_rover_parking_position())
	_rover_pad_feedback = "Rover richiamato · costo %s" % _format_money(ROVER_RECALL_COST)
	_update_prompt()
	return true


func _update_interior_art() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_inside := player != null and contains_world_point(player.global_position)
	_sprite.texture = INTERIOR_TEXTURES[dome_id] if player_inside else EXTERIOR_TEXTURES[dome_id]


func _process(delta: float) -> void:
	if is_preview:
		return
	_update_oxygen_reserve(delta)
	_update_interior_art()
	_update_airlock_state()
	_update_prompt()
	_update_port_markers()
	_refresh_dome_status()
	_update_rover_pad_status()


func _register_connections() -> void:
	if is_preview or not is_inside_tree():
		return
	var oxygen_port_position := global_position + Vector2(get_radius() + 8.0, 0.0)
	_oxygen_input_cell = Vector2i(floori(oxygen_port_position.x / TILE_SIZE), floori(oxygen_port_position.y / TILE_SIZE))
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager != null:
		pipe_manager.call("register_fluid_input", self, _oxygen_input_cell, PipeSegment.Category.OXYGEN, Vector2i.LEFT)
		var pipe_cell_center: Vector2 = pipe_manager.call("cell_to_world", _oxygen_input_cell)
		_oxygen_port_marker.position = pipe_cell_center - global_position
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("register_consumer", self, get_power_connection_cell(), get_power_demand_kw(), get_power_attach_direction())


func _build_port_markers() -> void:
	_oxygen_port_marker = Sprite2D.new()
	_oxygen_port_marker.name = "OxygenPipeAttachment"
	_oxygen_port_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_oxygen_port_marker.z_index = 3
	var pipe_frame := AtlasTexture.new()
	pipe_frame.atlas = OXYGEN_PIPE_SHEET
	pipe_frame.region = Rect2(32.0, 0.0, TILE_SIZE, TILE_SIZE)
	_oxygen_port_marker.texture = pipe_frame
	_oxygen_port_marker.position = Vector2(get_radius() + 8.0, 0.0)
	add_child(_oxygen_port_marker)


func _update_port_markers() -> void:
	if _oxygen_port_marker != null:
		_oxygen_port_marker.modulate = Color.WHITE if is_oxygen_connected() else Color(0.86, 0.86, 0.86, 1.0)


func _build_boundary_and_corridor() -> void:
	_boundary_body = StaticBody2D.new()
	_boundary_body.name = "DomeAndCorridorCollision"
	_boundary_body.collision_layer = 1
	_boundary_body.collision_mask = 0
	add_child(_boundary_body)
	var radius := get_radius()
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	var side := Vector2(-outward.y, outward.x)
	# Parete circolare con varco della larghezza del corridoio.
	var count := 72
	var half_arc := asin(clampf(19.0 / radius, 0.0, 0.95))
	var entrance_angle := outward.angle()
	for index in count:
		var angle_a := TAU * float(index) / count
		var angle_b := TAU * float(index + 1) / count
		var midpoint := wrapf((angle_a + angle_b) * 0.5, 0.0, TAU)
		var delta_angle := absf(wrapf(midpoint - entrance_angle + PI, 0.0, TAU) - PI)
		if delta_angle <= half_arc:
			continue
		_add_segment(Vector2(cos(angle_a), sin(angle_a)) * radius, Vector2(cos(angle_b), sin(angle_b)) * radius)
	# I due bordi lunghi sono la hitbox fisica del corridoio.
	_add_segment(outward * radius + side * 16.0, outward * (radius + 32.0) + side * 16.0)
	_add_segment(outward * radius - side * 16.0, outward * (radius + 32.0) - side * 16.0)
	_outer_gate = _add_gate("OuterGate", get_radius() + 24.0, false)
	_inner_gate = _add_gate("InnerGate", get_radius() - 8.0, false)


func _add_segment(point_a: Vector2, point_b: Vector2) -> CollisionShape2D:
	var segment := SegmentShape2D.new()
	segment.a = point_a
	segment.b = point_b
	var shape := CollisionShape2D.new()
	shape.shape = segment
	_boundary_body.add_child(shape)
	return shape


func _add_gate(gate_name: String, distance: float, is_open: bool) -> CollisionShape2D:
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	var side := Vector2(-outward.y, outward.x)
	var gate := _add_segment(outward * distance - side * 16.0, outward * distance + side * 16.0)
	gate.name = gate_name
	gate.disabled = is_open
	return gate


func _door_depth(direction_name: String) -> float:
	var sheet: Texture2D = DOOR_OPEN_SHEETS[direction_name]
	var frame := _sheet_frame(sheet, 0)
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	return frame.region.size.x if not is_zero_approx(outward.x) else frame.region.size.y


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AirlockPromptLayer"
	layer.layer = 80
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 0.77
	_prompt_panel.anchor_bottom = 0.77
	_prompt_panel.offset_left = -240.0
	_prompt_panel.offset_right = 240.0
	_prompt_panel.offset_top = -38.0
	_prompt_panel.offset_bottom = 38.0
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.075, 0.94)
	panel_style.border_color = Color("7ed7ff")
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	_prompt_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_color", Color("e9f8ff"))
	_prompt_panel.add_child(_prompt_label)
	_dome_status_panel = PanelContainer.new()
	_dome_status_panel.anchor_left = 1.0
	_dome_status_panel.anchor_right = 1.0
	_dome_status_panel.anchor_top = 0.0
	_dome_status_panel.anchor_bottom = 0.0
	_dome_status_panel.offset_left = -390.0
	_dome_status_panel.offset_right = -16.0
	_dome_status_panel.offset_top = 16.0
	_dome_status_panel.offset_bottom = 300.0
	_dome_status_panel.visible = false
	_dome_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dome_status_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_dome_status_panel)
	_dome_status_label = Label.new()
	_dome_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dome_status_label.add_theme_font_size_override("font_size", 12)
	_dome_status_label.add_theme_color_override("font_color", Color("e9f8ff"))
	_dome_status_panel.add_child(_dome_status_label)


func _update_prompt() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var prompt := get_prompt_for_player(player)
	_prompt_panel.visible = not prompt.is_empty()
	_prompt_label.text = prompt


func _sequence_prompt() -> String:
	var keys := PackedStringArray()
	for index in _sequence.size():
		var label: String = DIRECTION_KEY_LABELS[DIRECTION_KEYS.find(_sequence[index])]
		keys.append("[%s]" % label if index == _sequence_progress else label)
	var phase := "PRESSURIZZAZIONE" if _airlock_path == "enter" else "DECOMPRESSIONE"
	var feedback := ""
	if not _sequence_feedback.is_empty():
		feedback = "  ·  " + _sequence_feedback
	return "%s — premi in ordine: %s\nProgresso %d/%d  ·  WASD%s" % [phase, "  →  ".join(keys), _sequence_progress, _sequence.size(), feedback]


func _start_sequence(player: Node2D) -> void:
	_sequence.clear()
	for _index in SEQUENCE_LENGTH:
		_sequence.append(DIRECTION_KEYS[randi_range(0, DIRECTION_KEYS.size() - 1)])
	_sequence_progress = 0
	_sequence_feedback = ""
	_sequence_active = true
	_sequence_complete = false
	_sequence_player = player
	_corridor_sprite.texture = _sheet_frame(CORRIDOR_SHEETS[DIRECTION_NAMES[entrance_direction]], 0)
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.set_physics_process(false)
	_update_prompt()


func _accept_sequence_key(player: Node2D, keycode: int) -> void:
	if keycode == _sequence[_sequence_progress]:
		_sequence_progress += 1
		_sequence_feedback = ""
		_corridor_sprite.texture = _sheet_frame(CORRIDOR_SHEETS[DIRECTION_NAMES[entrance_direction]], mini(_sequence_progress, AIRLOCK_FRAMES - 1))
		if _sequence_progress >= _sequence.size():
			_sequence_active = false
			_sequence_complete = true
			_sequence_player = null
			player.set_physics_process(true)
			_update_prompt()
			return
	else:
		_sequence_progress = 0
		_sequence_feedback = "Errore: sequenza ripartita"
		_corridor_sprite.texture = _sheet_frame(CORRIDOR_SHEETS[DIRECTION_NAMES[entrance_direction]], 0)
	_update_prompt()


func _reset_cycle() -> void:
	_sequence_active = false
	_sequence_complete = false
	_sequence.clear()
	_sequence_progress = 0
	_sequence_feedback = ""
	_sequence_player = null
	_first_door_crossed = false
	if _corridor_sprite != null:
		_corridor_sprite.texture = _sheet_frame(CORRIDOR_SHEETS[DIRECTION_NAMES[entrance_direction]], 0)


func _animate_door(door_name: String, open: bool) -> void:
	if _airlock_busy:
		return
	if open and is_incident_faulted("%s_door" % door_name):
		_update_prompt()
		return
	_airlock_busy = true
	var direction_name: String = DIRECTION_NAMES[entrance_direction]
	var sheet: Texture2D = DOOR_OPEN_SHEETS[direction_name] if open else DOOR_CLOSE_SHEETS[direction_name]
	var door_sprite := _outer_door_sprite if door_name == "outer" else _inner_door_sprite
	var gate := _outer_gate if door_name == "outer" else _inner_gate
	for frame_index in AIRLOCK_FRAMES:
		var animation_frame := frame_index if open else frame_index
		door_sprite.texture = _sheet_frame(sheet, animation_frame)
		await get_tree().create_timer(DOOR_FRAME_SECONDS).timeout
	if door_name == "outer":
		_outer_door_open = open
	else:
		_inner_door_open = open
	gate.set_deferred("disabled", open)
	_airlock_busy = false
	_apply_door_frames()
	_update_prompt()


func _apply_door_frames() -> void:
	if _outer_door_sprite == null or _inner_door_sprite == null:
		return
	var direction_name: String = DIRECTION_NAMES[entrance_direction]
	var closed_frame := AIRLOCK_FRAMES - 1
	_outer_door_sprite.texture = _sheet_frame(DOOR_OPEN_SHEETS[direction_name], closed_frame) if _outer_door_open else _sheet_frame(DOOR_CLOSE_SHEETS[direction_name], closed_frame)
	_inner_door_sprite.texture = _sheet_frame(DOOR_OPEN_SHEETS[direction_name], closed_frame) if _inner_door_open else _sheet_frame(DOOR_CLOSE_SHEETS[direction_name], closed_frame)
	if _outer_gate != null:
		_outer_gate.set_deferred("disabled", _outer_door_open)
	if _inner_gate != null:
		_inner_gate.set_deferred("disabled", _inner_door_open)


func _sheet_frame(sheet: Texture2D, frame_index: int) -> AtlasTexture:
	var frame_width := int(sheet.get_width() / AIRLOCK_FRAMES)
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(frame_index * frame_width, 0, frame_width, sheet.get_height())
	return frame


func _update_airlock_state() -> void:
	if _airlock_busy:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var in_corridor := is_in_corridor(player.global_position)
	var in_dome := contains_world_point(player.global_position)
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	var projected := (player.global_position - global_position).dot(outward)
	if _airlock_path == "enter":
		# Chiudi solo dopo che il centro del personaggio ha superato il piano
		# della porta con spazio sufficiente, evitando di richiuderla addosso.
		if _outer_door_open and in_corridor and projected <= get_radius() + 8.0:
			_first_door_crossed = true
			_animate_door("outer", false)
		elif _inner_door_open and in_dome and projected <= get_radius() - 24.0:
			_animate_door("inner", false)
			_record_achievement("airlock_cycle")
			_reset_cycle()
			_airlock_path = ""
	elif _airlock_path == "exit":
		if _inner_door_open and in_corridor and projected >= get_radius() + 8.0:
			_first_door_crossed = true
			_animate_door("inner", false)
		elif _outer_door_open and projected >= get_radius() + 43.0:
			_animate_door("outer", false)
			_record_achievement("airlock_cycle")
			_reset_cycle()
			_airlock_path = ""


func set_incident_faulted(target_id: String, value: bool) -> void:
	if not _faulted_doors.has(target_id) or bool(_faulted_doors[target_id]) == value:
		return
	_faulted_doors[target_id] = value
	if value:
		_reset_cycle()
		_airlock_path = ""
	_update_prompt()


func is_incident_faulted(target_id: String) -> bool:
	return bool(_faulted_doors.get(target_id, false))


func can_receive_incident(target_id: String) -> bool:
	if is_preview or not _faulted_doors.has(target_id) or is_incident_faulted(target_id):
		return false
	# Non interrompere mai una camera d'aria durante animazione, ciclo o
	# attraversamento: un incidente blocca l'apertura della porta a riposo.
	return not _airlock_busy and not _sequence_active and not _outer_door_open and not _inner_door_open and _airlock_path.is_empty()


func get_incident_repair_position(target_id: String) -> Vector2:
	return get_outer_door_position() if target_id == "outer_door" else get_inner_door_position()


func _destroy() -> bool:
	if _airlock_busy or _sequence_active:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and (contains_world_point(player.global_position) or is_in_corridor(player.global_position)):
		return false
	queue_free()
	return true


func _record_achievement(achievement_id: String) -> void:
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null:
		achievements.call("record", achievement_id)


func _exit_tree() -> void:
	if not is_preview and is_inside_tree():
		var incidents := get_tree().root.get_node_or_null("IncidentManager")
		if incidents != null:
			incidents.call("unregister_target", self)
		var pipe_manager := get_tree().root.get_node_or_null("PipeManager")
		if pipe_manager != null:
			pipe_manager.call("unregister_fluid_source", self)
		var power_grid := get_tree().root.get_node_or_null("PowerGrid")
		if power_grid != null:
			power_grid.call("unregister_consumer", self)
		var registry := get_tree().root.get_node_or_null("BuildableRegistry")
		if registry != null:
			registry.call("unregister_buildable", self, false)
