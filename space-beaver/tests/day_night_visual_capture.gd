extends SceneTree

const CAPTURE_HOURS := {
	"day": 12.0,
	"dusk": 17.5,
	"night": 0.0,
	"dawn": 5.5,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var clock: Node = root.get_node("WorldClock")
	var power_grid: Node = root.get_node("PowerGrid")
	clock.running = false
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Impossibile caricare la scena principale: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var main_scene: Node = current_scene
	_add_power_devices(main_scene, power_grid)
	for capture_name in CAPTURE_HOURS:
		clock.set_game_hour(float(CAPTURE_HOURS[capture_name]))
		power_grid._update_energy(0.0)
		power_grid.emit_signal("stats_changed", power_grid.get_stats())
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		await process_frame
		var image := root.get_texture().get_image()
		var result := image.save_png("res://tests/captures/%s.png" % capture_name)
		if result != OK:
			push_error("Impossibile salvare la cattura %s: %s" % [capture_name, result])
			quit(1)
			return
	print("DAY_NIGHT_VISUAL_CAPTURE_OK")
	quit(0)


func _add_power_devices(main_scene: Node, power_grid: Node) -> void:
	power_grid.place_device(main_scene, "solar_panel", Vector2i(-8, 2))
	power_grid.place_device(main_scene, "transformer", Vector2i(-2, 2))
	power_grid.place_device(main_scene, "battery", Vector2i(4, 2))
	power_grid.battery_energy_kwh = 400.0
	power_grid.rebuild_network()
