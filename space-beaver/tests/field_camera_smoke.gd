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
	await process_frame
	var inventory := root.get_node_or_null("Inventory")
	var achievements := root.get_node_or_null("AchievementManager")
	var camera := root.get_node_or_null("FieldCamera")
	_expect(inventory != null and achievements != null and camera != null, "Autoload inventario, achievement e telecamera devono esistere")
	if inventory == null or achievements == null or camera == null:
		_finish()
		return
	inventory.call("reset_for_new_mission")
	achievements.call("reset_for_new_mission")
	camera.call("reset_for_new_mission")
	for sample_index in 8:
		achievements.call("record_field_sample", "roccia_test_%d" % sample_index, "common")
	_expect(bool(achievements.call("claim", "first_field_sample")), "Prima pietra deve aprire il contratto della sacca")
	_expect(bool(achievements.call("claim", "field_notes")), "Taccuino deve poter essere riscattato prima della sacca")
	_expect(bool(achievements.call("claim", "sample_satchel")), "Sacca campioni deve consegnare la ricompensa fisica")
	var camera_slot := -1
	for index in inventory.backpack.size():
		if str(inventory.backpack[index].get("id", "")) == "field_camera":
			camera_slot = index
			break
	_expect(camera_slot >= 0, "La telecamera consegnata deve essere realmente presente nello zaino")
	if camera_slot >= 0:
		inventory.call("select_backpack", camera_slot)
		_expect(bool(inventory.call("move_selected_to_hotbar", 1)), "La telecamera deve potersi equipaggiare in uno slot rapido")
		inventory.call("select_hotbar", 1)
	var photo: Dictionary = camera.call("take_photo")
	await process_frame
	_expect(not photo.is_empty(), "P deve produrre uno scatto con metadati di campo")
	_expect(int(camera.call("get_photo_count")) == 1 and int(camera.call("get_unsent_count")) == 1, "Uno scatto deve restare nel rullino finché non viene inviato")
	_expect(bool(camera.call("transmit_oldest_photo")), "O deve trasmettere lo scatto non inviato alla Terra")
	_expect(int(camera.call("get_photo_count", true)) == 1 and int(camera.call("get_unsent_count")) == 0, "La trasmissione deve aggiornare lo stato del rullino")
	_expect(int(achievements.call("get_progress", "first_photo")) == 1, "Un invio fotografico deve avanzare il contratto Primo scatto")
	camera.call("open_archive")
	_expect(bool(camera.get("is_archive_open")), "C deve aprire l'archivio fotografico")
	camera.call("close_archive")
	_expect(not bool(camera.get("is_archive_open")), "L'archivio deve richiudersi senza bloccare il gioco")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIELD_CAMERA_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_CAMERA_SMOKE_FAIL: " + failure)
	quit(1)
