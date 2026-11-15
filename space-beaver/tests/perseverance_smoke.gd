extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("impossibile caricare la scena principale")
		_finish()
		return
	await process_frame
	await process_frame
	var mission := root.get_node_or_null("PerseveranceMission")
	var camera := root.get_node_or_null("FieldCamera")
	var inventory := root.get_node_or_null("Inventory")
	var achievements := root.get_node_or_null("AchievementManager")
	var player := current_scene.get_node_or_null("player") as Node2D
	_expect(mission != null and camera != null and inventory != null and achievements != null and player != null, "Test assertion failed")
	if mission == null or camera == null or inventory == null or achievements == null or player == null:
		_finish()
		return
	mission.call("reset_for_new_mission")
	var next_hours := float(mission.call("get_next_break_in_game_hours"))
	_expect(next_hours >= 72.0 and next_hours <= 96.0, "Test assertion failed")
	mission.call("force_break_for_test", Vector2(360.0, 320.0))
	await process_frame
	var rover := mission.get("rover") as Node2D
	_expect(rover != null and rover.is_in_group("perseverance_rover"), "Test assertion failed")
	_expect(int(mission.get("state")) == mission.State.AWAIT_PHOTO, "Test assertion failed")
	var arrow := mission.get("_arrow") as Control
	player.global_position = rover.global_position + Vector2(15.0 * 16.0, 0.0)
	mission.call("_update_guidance")
	_expect(arrow != null and not arrow.visible, "Test assertion failed")
	player.global_position = rover.global_position + Vector2(15.0 * 16.0 + 1.0, 0.0)
	mission.call("_update_guidance")
	_expect(arrow != null and arrow.visible, "Test assertion failed")
	player.global_position = rover.global_position + Vector2(24.0, 0.0)
	inventory.hotbar[1] = {"id": "field_camera", "name": "Telecamera scientifica", "count": 1, "placeable": false, "tool": true}
	inventory.call("select_hotbar", 1)
	var photo: Dictionary = camera.call("take_photo")
	_expect("perseverance" in Array(photo.get("tags", [])), "Test assertion failed")
	_expect(bool(camera.call("transmit_oldest_photo")), "Test assertion failed")
	_expect(int(mission.get("state")) == mission.State.AWAIT_STUDY, "Test assertion failed")
	mission.call("_create_damage_report")
	_expect(int(mission.get("state")) == mission.State.REPORT_READY, "Test assertion failed")
	var report_label := mission.get("_report_label") as Label
	_expect(report_label != null and report_label.text.contains("PERSEVERANCE (NASA, 2021)") and report_label.text.contains("45.22 km") and report_label.text.contains("Jezero Crater"), "Test assertion failed")
	_send_key(mission, KEY_F)
	_expect(int(mission.get("state")) == mission.State.REPORT_SIGNED, "Test assertion failed")
	_send_key(mission, KEY_R)
	_expect(int(mission.get("state")) == mission.State.REPAIRING, "Test assertion failed")
	var sequence: Array = mission.get("_repair_sequence")
	_expect(sequence.size() == 5, "Test assertion failed")
	for keycode in sequence:
		_send_key(mission, int(keycode))
	_expect(int(mission.get("state")) == mission.State.REPAIRED, "Test assertion failed")
	_expect(int(achievements.call("get_progress", "perseverance_photo")) == 1 and int(achievements.call("get_progress", "perseverance_report")) == 1 and int(achievements.call("get_progress", "perseverance_repair")) == 1, "Test assertion failed")
	var repeat_hours := float(mission.call("get_next_break_in_game_hours"))
	_expect(repeat_hours >= 7.0 * 24.0 and repeat_hours <= 10.0 * 24.0, "Test assertion failed")
	player.global_position = rover.global_position + Vector2(10_000.0, 0.0)
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		player_camera.force_update_scroll()
	_expect(bool(mission.call("_repaired_rover_is_far_outside_view")), "Test assertion failed")
	mission.call("_process", 0.0)
	_expect(mission.get("rover") == null, "Test assertion failed")
	mission.call("reset_for_new_mission")
	_finish()


func _send_key(mission: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	mission.call("_unhandled_input", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PERSEVERANCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("PERSEVERANCE_SMOKE_FAIL: " + failure)
	quit(1)
