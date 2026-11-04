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
	root.get_node("Economy").spend(500_000_000)
	root.get_node("Inventory").add_item("battery", "Batteria", 2, true)
	root.get_node("Oxygen").oxygen = 12.0
	root.get_node("Hunger").hunger = 13.0
	root.get_node("Hydration").thirst = 14.0
	root.get_node("Temperature").core_temperature_c = 31.0
	root.get_node("DeliveryManager").queue_item("solar_panel", {"name": "Pannello solare", "placeable": true}, 1)
	root.get_node("GameState").restart_from_scratch()
	await process_frame
	await process_frame
	await process_frame
	_expect(root.get_node("Economy").balance == 10_000_000_000, "Il budget deve ripartire dal valore iniziale")
	_expect(root.get_node("Inventory").count_item("battery") == 0, "Gli oggetti acquistati devono essere azzerati")
	# Dopo il reload sono gia' trascorsi pochi frame di gioco, quindi le tre
	# risorse possono essere appena sotto 100 pur essendo state ripristinate.
	_expect(root.get_node("Oxygen").oxygen > 99.9, "L'ossigeno deve ripartire da 100")
	_expect(root.get_node("Hunger").hunger > 99.9, "La fame deve ripartire da 100")
	_expect(root.get_node("Hydration").thirst > 99.9, "La sete deve ripartire da 100")
	_expect(root.get_node("Temperature").core_temperature_c > 36.9, "La temperatura corporea deve ripartire da 37°C")
	_expect(root.get_node("DeliveryManager").pending_order.is_empty(), "Gli ordini devono essere cancellati")
	var authored_rock_count := 0
	for rock in current_scene.get_tree().get_nodes_in_group("collectible_rocks"):
		if bool(rock.is_authored):
			authored_rock_count += 1
	_expect(authored_rock_count == 125, "Le rocce fisiche della mappa devono essere ripristinate")
	if failures.is_empty():
		print("RESTART_FROM_ZERO_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
