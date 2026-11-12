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
	_expect(bool(ProjectSettings.get_setting("display/window/size/resizable", false)), "La finestra deve essere ridimensionabile")
	_expect(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "expand", "Il canvas deve espandersi invece di fissare un rapporto")
	var inventory_panel := _find_named(current_scene, "ResponsiveInventoryPanel") as Control
	var shop_panel := _find_named(current_scene, "ResponsiveShopPanel") as Control
	var map_panel := _find_named(current_scene, "ResponsiveMapPanel") as Control
	var camera_panel := _find_named(root.get_node_or_null("FieldCamera"), "ResponsiveCameraArchive") as Control
	_expect(_uses_percentage_layout(inventory_panel, 0.06, 0.94), "L'inventario deve usare ancoraggi adattivi")
	_expect(_uses_percentage_layout(shop_panel, 0.04, 0.96), "Lo shop deve usare ancoraggi adattivi")
	_expect(_uses_percentage_layout(map_panel, 0.05, 0.95), "La mappa deve usare ancoraggi adattivi")
	_expect(_uses_percentage_layout(camera_panel, 0.08, 0.92), "L'archivio fotografico deve adattarsi alla finestra")
	_finish()


func _uses_percentage_layout(control: Control, left: float, right: float) -> bool:
	return control != null and is_equal_approx(control.anchor_left, left) and is_equal_approx(control.anchor_right, right) and is_equal_approx(control.offset_left, 0.0) and is_equal_approx(control.offset_right, 0.0)


func _find_named(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, target_name)
		if found != null:
			return found
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RESPONSIVE_UI_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("RESPONSIVE_UI_SMOKE_FAIL: " + failure)
	quit(1)
