extends Node

## Punto unico e prioritario per l'interazione con i rover.
##
## L'interazione non appartiene ai pannelli della cupola o dei macchinari:
## questi possono mostrare informazioni e usare E in _unhandled_input, ma non
## devono mai poter intercettare l'imbarco. Essendo un autoload, questo nodo
## riceve l'input prima della scena di gioco e rende E affidabile anche vicino
## a una base, una macchina o un'interfaccia informativa.

const INTERACTION_KEY := KEY_E


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# Legge sia il carattere prodotto dal layout sia il tasto fisico. In questo
	# modo E continua a funzionare anche con un layout di tastiera differente.
	if event.keycode != INTERACTION_KEY and event.physical_keycode != INTERACTION_KEY:
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


func _is_input_blocked() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return (ui_state != null and bool(ui_state.call("blocks_world_actions"))) or get_tree().paused
