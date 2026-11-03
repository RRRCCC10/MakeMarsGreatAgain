extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Impossibile caricare la scena principale: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var landing = current_scene.get_node_or_null("LandingSequence")
	var player := current_scene.get_node_or_null("player") as CharacterBody2D
	_expect(landing != null, "La scena deve contenere la sequenza di atterraggio")
	_expect(player != null and player.visible, "In headless l'astronauta deve apparire nello stato finale")
	if landing != null:
		_expect(landing.landing_complete, "La sequenza headless deve completarsi immediatamente")
		_expect(landing.pad_sprite != null and landing.pad_sprite.visible, "La piattaforma deve restare sulla mappa")
		_expect(landing.landed_rocket != null and landing.landed_rocket.visible, "Il razzo atterrato deve restare sulla piattaforma")
		_expect(landing.landed_rocket.texture == landing.rocket_frames[0], "Il razzo atterrato deve usare il primo frame fermo")
		_expect(landing.rocket_frames.size() == 30, "Lo spritesheet del razzo deve essere diviso nei 30 frame 32x64")
		_expect(not landing.get_occupied_power_cells().is_empty(), "Il sito di atterraggio deve bloccare tubi e cavi")
	var mission_site_registered := false
	for entry in root.get_node("BuildableRegistry").get_entries():
		if entry.get("kind", "") == "mission_structure":
			mission_site_registered = true
			break
	_expect(mission_site_registered, "Il sito di atterraggio deve essere registrato come struttura permanente")

	if failures.is_empty():
		print("MISSION_LANDING_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
