extends Node

## Punto unico e prioritario per l'interazione con i rover.
##
## L'interazione non appartiene ai pannelli della cupola o dei macchinari:
## questi possono mostrare informazioni e usare E in _unhandled_input, ma non
## devono mai poter intercettare l'imbarco. Essendo un autoload, questo nodo
## riceve l'input prima della scena di gioco e rende E affidabile anche vicino
## a una base, una macchina o un'interfaccia informativa.

const INTERACTION_KEY := KEY_E
const ROVER_CLEAN_DISTANCE := 94.0
const HOLD_TO_CLEAN_SECONDS := 0.28

var _pending_player: Node2D
var _pending_rover: Node2D
var _pending_clean_target: Node2D
var _pending_water_drill: Node2D
var _pending_elapsed := 0.0
var _pending_cleaning_started := false


func _process(delta: float) -> void:
	if _pending_player == null or not is_instance_valid(_pending_player):
		_clear_pending()
		return
	if not Input.is_key_pressed(INTERACTION_KEY):
		if _pending_water_drill != null:
			_resolve_water_drill_short_press()
		else:
			_resolve_pending_short_press()
		return
	if _pending_cleaning_started:
		return
	_pending_elapsed += delta
	if _pending_elapsed < HOLD_TO_CLEAN_SECONDS:
		return
	var sandstorms := get_node_or_null("/root/SandstormManager")
	if sandstorms != null and bool(sandstorms.call("begin_nearby_cleaning", _pending_player, _pending_clean_target)):
		_pending_cleaning_started = true
	else:
		_clear_pending()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	# Legge sia il carattere prodotto dal layout sia il tasto fisico. In questo
	# modo E continua a funzionare anche con un layout di tastiera differente.
	if event.keycode != INTERACTION_KEY and event.physical_keycode != INTERACTION_KEY:
		return
	if not event.pressed:
		if _pending_player != null and not _pending_cleaning_started:
			if _pending_water_drill != null:
				_resolve_water_drill_short_press()
			else:
				_resolve_pending_short_press()
		else:
			_clear_pending()
		return
	if _is_input_blocked():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_driving_rover") and bool(player.call("is_driving_rover")):
		var driven_rover := player.get("mounted_rover") as Node
		if is_instance_valid(driven_rover) and driven_rover.has_method("exit_rover") and bool(driven_rover.call("exit_rover")):
			get_viewport().set_input_as_handled()
		return
	var dusty_rover := _find_dusty_rover(player)
	if dusty_rover != null:
		# Una pressione breve conserva il comando storico di salita; la pulizia
		# parte solo dopo una pressione continua, evitando il conflitto tra E.
		_pending_player = player
		_pending_rover = dusty_rover
		_pending_clean_target = dusty_rover
		_pending_water_drill = null
		_pending_elapsed = 0.0
		_pending_cleaning_started = false
		get_viewport().set_input_as_handled()
		return
	var dirty_water_drill := _find_dirty_water_drill(player)
	if dirty_water_drill != null and not _target_blocked_inside_dome(player, dirty_water_drill):
		# Come per il rover, E breve mantiene l'azione contestuale; solo una
		# pressione continua avvia la pulizia della sabbia.
		_pending_player = player
		_pending_rover = null
		_pending_clean_target = dirty_water_drill
		_pending_water_drill = dirty_water_drill
		_pending_elapsed = 0.0
		_pending_cleaning_started = false
		get_viewport().set_input_as_handled()
		return
	var nearest_rover := _find_boardable_rover(player)
	if nearest_rover != null and bool(nearest_rover.call("board", player)):
		get_viewport().set_input_as_handled()


func _find_boardable_rover(player: Node2D) -> Node:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("rovers"):
		if not candidate is Node2D or not candidate.has_method("can_board") or not candidate.has_method("board"):
			continue
		var rover := candidate as Node2D
		if not bool(rover.call("can_board", player)):
			continue
		var distance := player.global_position.distance_to(rover.global_position)
		if distance < nearest_distance:
			nearest = rover
			nearest_distance = distance
	return nearest


func _find_dusty_rover(player: Node2D) -> Node2D:
	var nearest: Node2D
	var nearest_distance := ROVER_CLEAN_DISTANCE
	for candidate in get_tree().get_nodes_in_group("rovers"):
		if not candidate is Node2D or not candidate.has_method("get_sand_accumulation"):
			continue
		var rover := candidate as Node2D
		if int(rover.call("get_sand_accumulation")) <= 0:
			continue
		var distance := player.global_position.distance_to(rover.global_position)
		if distance <= nearest_distance:
			nearest = rover
			nearest_distance = distance
	return nearest


func _find_dirty_water_drill(player: Node2D) -> Node2D:
	var nearest: Node2D
	var nearest_distance := ROVER_CLEAN_DISTANCE
	for candidate in get_tree().get_nodes_in_group("ice_drills"):
		if not candidate is Node2D or not candidate.has_method("get_sand_accumulation"):
			continue
		var drill := candidate as Node2D
		if int(drill.call("get_sand_accumulation")) <= 0:
			continue
		var distance := player.global_position.distance_to(drill.global_position)
		if distance <= nearest_distance:
			nearest = drill
			nearest_distance = distance
	return nearest


func _resolve_pending_short_press() -> void:
	if _pending_player != null and _pending_rover != null and is_instance_valid(_pending_rover):
		if bool(_pending_rover.call("can_board", _pending_player)):
			_pending_rover.call("board", _pending_player)
	_clear_pending()


func _resolve_water_drill_short_press() -> void:
	var player := _pending_player
	var drill := _pending_water_drill
	if player != null and is_instance_valid(player) and drill != null and is_instance_valid(drill):
		var selected: Dictionary = Inventory.get_selected_item() if Inventory != null else {}
		if str(selected.get("id", "")) == "water_bottle" and drill.has_method("try_refill_selected_bottle"):
			drill.call("try_refill_selected_bottle", player)
	_clear_pending()


func _clear_pending() -> void:
	_pending_player = null
	_pending_rover = null
	_pending_clean_target = null
	_pending_water_drill = null
	_pending_elapsed = 0.0
	_pending_cleaning_started = false


func _target_blocked_inside_dome(player: Node2D, target: Node2D) -> bool:
	return player.has_method("_external_target_blocked_inside_dome") and bool(player.call("_external_target_blocked_inside_dome", target))


func _is_input_blocked() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return (ui_state != null and bool(ui_state.call("blocks_world_actions"))) or get_tree().paused
