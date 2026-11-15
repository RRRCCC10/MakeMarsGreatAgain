extends SceneTree

const GREENHOUSE_SCRIPT := preload("res://scripts/Greenhouse.gd")

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
	var shop := root.get_node("Shop")
	var inventory := root.get_node("Inventory")
	var achievements := root.get_node("AchievementManager")
	var player := current_scene.get_node("player") as Node2D
	shop.call("reset_for_new_mission")
	inventory.call("reset_for_new_mission")
	var claimed: Dictionary = achievements.get("_claimed")
	var effects: Dictionary = achievements.get("_effects")
	claimed["first_harvest"] = true
	effects["genetic_seed_access"] = true
	_expect(bool(shop.call("are_seed_genetics_unlocked")), "Test assertion failed")
	_expect(bool(inventory.call("add_item", "potato_seeds", "Semi di patate", 1, false, {"yield_level": 0, "speed_level": 0})), "Test assertion failed")
	var greenhouse := GREENHOUSE_SCRIPT.new() as Greenhouse
	greenhouse.setup_greenhouse(1, false)
	current_scene.add_child(greenhouse)
	greenhouse.global_position = Vector2(420.0, 320.0)
	await process_frame
	player.global_position = greenhouse.global_position
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "Test assertion failed")
	_expect(int(greenhouse.call("get_crop_seed_configuration").get("yield_level", -1)) == 0, "Test assertion failed")
	root.get_node("Economy").balance = 10_000_000_000
	_expect(bool(shop.call("purchase_seed_upgrade", "yield")), "Test assertion failed")
	_expect(bool(shop.call("purchase_seed_upgrade", "speed")), "Test assertion failed")
	_expect(int(greenhouse.call("get_crop_seed_configuration").get("yield_level", -1)) == 0 and int(greenhouse.call("get_crop_seed_configuration").get("speed_level", -1)) == 0, "Test assertion failed")
	var stronger_configuration: Dictionary = shop.call("get_current_seed_configuration")
	_expect(bool(inventory.call("add_item", "potato_seeds", "Semi GM", 1, false, stronger_configuration)), "Test assertion failed")
	_expect(greenhouse.get_prompt_for_player(player).contains("SOSTITUISCI LOTTO"), "Test assertion failed")
	_expect(greenhouse.handle_airlock_key(player, KEY_E), "Test assertion failed")
	var planted_configuration: Dictionary = greenhouse.call("get_crop_seed_configuration")
	_expect(int(planted_configuration.get("yield_level", 0)) == 1 and int(planted_configuration.get("speed_level", 0)) == 1, "Test assertion failed")
	_expect(int(greenhouse.call("get_harvest_food")) > Greenhouse.HARVEST_FOOD - 1, "Test assertion failed")
	greenhouse.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SEED_GENETICS_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("SEED_GENETICS_SMOKE_FAIL: " + failure)
	quit(1)
