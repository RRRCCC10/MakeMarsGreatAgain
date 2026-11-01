extends Node

signal order_changed
signal capsule_dispatched(capsule: Node)
signal capsule_landed(capsule: Node)
signal capsule_emptied

const CAPSULE_SCRIPT := preload("res://scripts/DeliveryCapsule.gd")
const BATCH_WINDOW_SECONDS := 4.0

var pending_order: Dictionary = {}
var batch_time_remaining := 0.0
var active_capsules: Array[Node] = []
var _landing_sequence := 0


func _process(delta: float) -> void:
	_cleanup_capsules()
	if pending_order.is_empty():
		return
	batch_time_remaining = maxf(0.0, batch_time_remaining - delta)
	order_changed.emit()
	if batch_time_remaining <= 0.0:
		_dispatch_pending_order()


func queue_item(item_id: String, definition: Dictionary, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	var item: Dictionary = pending_order.get(item_id, {
		"id": item_id,
		"name": str(definition.get("name", "Oggetto")),
		"count": 0,
		"placeable": bool(definition.get("placeable", true)),
	})
	item["count"] = int(item.get("count", 0)) + amount
	pending_order[item_id] = item
	# Ogni nuovo acquisto riapre per pochi secondi la stessa spedizione.
	batch_time_remaining = BATCH_WINDOW_SECONDS
	order_changed.emit()
	return true


func count_uncollected(item_id: String) -> int:
	var total := int(pending_order.get(item_id, {}).get("count", 0))
	for capsule in active_capsules:
		if not is_instance_valid(capsule):
			continue
		for item in capsule.get("contents"):
			if str(item.get("id", "")) == item_id:
				total += int(item.get("count", 0))
	return total


func get_pending_summary() -> String:
	var parts := PackedStringArray()
	for item in pending_order.values():
		parts.append("%s x%d" % [str(item.get("name", "Oggetto")), int(item.get("count", 0))])
	return "  ·  ".join(parts)


func get_delivery_status() -> Dictionary:
	_cleanup_capsules()
	var descending := 0
	var landed := 0
	for capsule in active_capsules:
		if bool(capsule.call("is_landed")):
			landed += 1
		else:
			descending += 1
	return {
		"pending": not pending_order.is_empty(),
		"pending_summary": get_pending_summary(),
		"seconds": batch_time_remaining,
		"descending": descending,
		"landed": landed,
	}


func notify_capsule_landed(capsule: Node) -> void:
	if is_instance_valid(capsule):
		capsule_landed.emit(capsule)
		order_changed.emit()


func notify_capsule_emptied(capsule: Node) -> void:
	active_capsules.erase(capsule)
	capsule_emptied.emit()
	order_changed.emit()


func reset_for_new_mission() -> void:
	pending_order.clear()
	batch_time_remaining = 0.0
	for capsule in active_capsules:
		if is_instance_valid(capsule):
			capsule.queue_free()
	active_capsules.clear()
	_landing_sequence = 0
	order_changed.emit()


func _dispatch_pending_order() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		batch_time_remaining = 0.25
		return
	var contents: Array[Dictionary] = []
	for item in pending_order.values():
		contents.append(item.duplicate(true))
	pending_order.clear()
	batch_time_remaining = 0.0
	var capsule := CAPSULE_SCRIPT.new()
	capsule.setup(contents, _choose_landing_position())
	scene.add_child(capsule)
	active_capsules.append(capsule)
	_landing_sequence += 1
	capsule_dispatched.emit(capsule)
	order_changed.emit()


func _choose_landing_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var center := player.global_position if player != null else Vector2.ZERO
	var candidates: Array[Vector2] = [
		Vector2(112, -64), Vector2(-112, -64), Vector2(128, 64), Vector2(-128, 64),
		Vector2(0, -128), Vector2(0, 128), Vector2(160, 0), Vector2(-160, 0),
	]
	for offset_index in candidates.size():
		var index := (offset_index + _landing_sequence) % candidates.size()
		var candidate := _snap_to_grid(center + candidates[index])
		if _landing_position_is_clear(candidate):
			return candidate
	return _snap_to_grid(center + Vector2(192 + _landing_sequence * 32, -96))


func _landing_position_is_clear(position: Vector2) -> bool:
	for rock in get_tree().get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and position.distance_to(rock.global_position) < 42.0:
			return false
	for entry in BuildableRegistry.get_entries():
		var node: Node = entry.get("node")
		if is_instance_valid(node) and node.has_method("contains_world_point") and bool(node.call("contains_world_point", position)):
			return false
	for capsule in active_capsules:
		if is_instance_valid(capsule) and position.distance_to(capsule.global_position) < 52.0:
			return false
	return true


func _snap_to_grid(position: Vector2) -> Vector2:
	return Vector2(roundi(position.x / 16.0) * 16, roundi(position.y / 16.0) * 16)


func _cleanup_capsules() -> void:
	for index in range(active_capsules.size() - 1, -1, -1):
		if not is_instance_valid(active_capsules[index]):
			active_capsules.remove_at(index)

