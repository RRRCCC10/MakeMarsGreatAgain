extends SceneTree


const GREENHOUSE_SCRIPT := preload("res://scripts/Greenhouse.gd")


func _init() -> void:
	call_deferred("_show")


func _show() -> void:
	DisplayServer.window_set_title("Greenhouse Visual Smoke")
	var world := Node2D.new()
	world.name = "VisualTestWorld"
	root.add_child(world)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1152, 0), Vector2(1152, 648), Vector2(0, 648)])
	background.color = Color("aa5539")
	world.add_child(background)
	var greenhouse := GREENHOUSE_SCRIPT.new() as Greenhouse
	greenhouse.setup_greenhouse(1, false)
	greenhouse.global_position = Vector2(576, 290)
	world.add_child(greenhouse)
	var player := Node2D.new()
	player.name = "VisualTestPlayer"
	player.add_to_group("player")
	player.z_index = 1
	player.global_position = greenhouse.global_position + Vector2(0, 30)
	var player_marker := Polygon2D.new()
	player_marker.polygon = PackedVector2Array([Vector2(-6, 8), Vector2(-6, -8), Vector2(6, -8), Vector2(6, 8)])
	player_marker.color = Color("ffcb83")
	player.add_child(player_marker)
	world.add_child(player)
	await process_frame
	greenhouse.call("_plant_crop")
	greenhouse.set("_growth_seconds", Greenhouse.FIRST_CYCLE_SECONDS * 0.70)
	greenhouse.call("_refresh_crop_visuals")
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	root.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(16, 14)
	label.text = "GREENHOUSE VISUAL TEST · floor, glass, beds, potatoes, door, and corridor"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f4f0d6"))
	overlay.add_child(label)
	await create_timer(20.0).timeout
	quit(0)
