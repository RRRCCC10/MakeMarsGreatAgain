extends Node

## Registro comune per tubi, strutture e macchinari demolibili.
## I macchinari futuri possono registrarsi specificando nome, tipo e funzione di rimozione.

var is_modal_open := false
var _entries: Array[Dictionary] = []


func register_buildable(node: Node2D, display_name: String, kind: String, destroy_action: Callable) -> void:
	unregister_buildable(node)
	_entries.append({
		"node": node,
		"display_name": display_name,
		"kind": kind,
		"destroy_action": destroy_action,
	})


func unregister_buildable(node: Node) -> void:
	for index in range(_entries.size() - 1, -1, -1):
		var registered_node: Node = _entries[index].get("node")
		if not is_instance_valid(registered_node) or registered_node == node:
			_entries.remove_at(index)


func find_at(world_position: Vector2) -> Dictionary:
	_cleanup_invalid_entries()
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index]
		var node: Node2D = entry.get("node") as Node2D
		if node != null and node.has_method("contains_world_point") and node.contains_world_point(world_position):
			return entry
	return {}


func destroy(entry: Dictionary) -> bool:
	var node: Node = entry.get("node")
	if not is_instance_valid(node):
		_cleanup_invalid_entries()
		return false
	var action: Callable = entry.get("destroy_action", Callable())
	if action.is_valid():
		var action_result = action.call()
		if action_result is bool and not action_result:
			return false
	else:
		node.queue_free()
	unregister_buildable(node)
	return true


func get_entries() -> Array[Dictionary]:
	_cleanup_invalid_entries()
	return _entries.duplicate()


func _cleanup_invalid_entries() -> void:
	for index in range(_entries.size() - 1, -1, -1):
		var node: Node = _entries[index].get("node")
		if not is_instance_valid(node):
			_entries.remove_at(index)


func reset_for_new_mission() -> void:
	is_modal_open = false
	_entries.clear()
