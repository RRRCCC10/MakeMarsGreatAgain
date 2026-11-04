extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var scene := current_scene
	var scatter: Node = scene.get_node_or_null("RockScatter")
	_expect(scatter != null, "La scena deve avere il distributore di risorse")
	if scatter != null:
		_expect(int(scatter.call("get_generated_count")) >= 600, "I chunk iniziali devono contenere molte piu' rocce raccoglibili")
	var generated_base_rocks := 0
	for rock in get_nodes_in_group("collectible_rocks"):
		if not bool(rock.is_authored) and str(rock.rock_variant) == "roccia_base":
			generated_base_rocks += 1
	_expect(generated_base_rocks > 0, "La sabbia base deve mantenere la pietra originale")

	var map_ui: Node = scene.get_node_or_null("WorldMapUI")
	_expect(map_ui != null, "La scena deve avere la carta topografica")
	if map_ui != null:
		_expect(int(map_ui.call("get_explored_block_count")) > 0, "La carta deve rivelare un raggio attorno al giocatore")
		map_ui.call("toggle_map")
		_expect(bool(map_ui.is_open) and map_ui.map_root.visible, "Mappa deve potersi aprire senza una schermata bloccante")
		_expect(not root.get_node("Inventory").is_open and not root.get_node("Shop").is_open and not root.get_node("BuildableRegistry").is_modal_open, "La carta non deve bloccare il movimento")
		map_ui.call("toggle_map")
		var map_key := InputEventKey.new()
		map_key.pressed = true
		map_key.keycode = KEY_M
		map_ui._unhandled_input(map_key)
		_expect(bool(map_ui.is_open) and map_ui.map_root.visible, "Il tasto M deve aprire la carta")

	var player: Node = scene.get_node("player")
	var camera: Camera2D = player.get_node("Camera2D")
	var original_zoom := camera.zoom.x
	var zoom_in := InputEventMouseButton.new()
	zoom_in.pressed = true
	zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	player._unhandled_input(zoom_in)
	_expect(camera.zoom.x == original_zoom, "Con la mappa aperta la rotella non deve cambiare la visuale del giocatore")
	_expect(float(map_ui.map_zoom) > 1.0, "Con la mappa aperta la rotella deve cambiare lo zoom della carta")
	map_ui.call("toggle_map")
	var zoom_out := InputEventMouseButton.new()
	zoom_out.pressed = true
	zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	player._unhandled_input(zoom_out)
	_expect(camera.zoom.x < original_zoom, "Con la mappa chiusa la rotella deve rimpicciolire la visuale")

	if failures.is_empty():
		print("EXPLORATION_NAVIGATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
