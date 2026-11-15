extends Node

## Shared registry for removable pipes, structures, and machines.
## Future machines can register a name, type, and removal function.

signal entries_changed

var is_modal_open := false
var _entries: Array[Dictionary] = []


func open_modal() -> bool:
	if is_modal_open:
		return _is_own_modal_active()
	if not _try_open_ui_modal():
		return false
	is_modal_open = true
	return true


func close_modal() -> void:
	is_modal_open = false
	_close_ui_modal()


func _try_open_ui_modal() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state == null or bool(ui_state.call("try_open_modal", &"world_panel"))


func _close_ui_modal() -> void:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null:
		ui_state.call("close_modal", &"world_panel")


func _is_own_modal_active() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	return ui_state == null or bool(ui_state.call("is_modal_active", &"world_panel"))


func register_buildable(node: Node2D, display_name: String, kind: String, destroy_action: Callable) -> void:
	unregister_buildable(node, false)
	_entries.append({
		"node": node,
		"display_name": display_name,
		"kind": kind,
		"destroy_action": destroy_action,
	})
	entries_changed.emit()


func unregister_buildable(node: Node, notify: bool = true) -> void:
	var changed := false
	for index in range(_entries.size() - 1, -1, -1):
		var registered_node: Node = _entries[index].get("node")
		if not is_instance_valid(registered_node) or registered_node == node:
			_entries.remove_at(index)
			changed = true
	if changed and notify:
		entries_changed.emit()


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
	var changed := false
	for index in range(_entries.size() - 1, -1, -1):
		var node: Node = _entries[index].get("node")
		if not is_instance_valid(node):
			_entries.remove_at(index)
			changed = true
	if changed:
		entries_changed.emit()


func reset_for_new_mission() -> void:
	close_modal()
	var had_entries := not _entries.is_empty()
	_entries.clear()
	if had_entries:
		entries_changed.emit()
