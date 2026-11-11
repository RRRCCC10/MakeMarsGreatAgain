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
	var board := current_scene.get_node_or_null("AchievementBoard")
	_expect(board != null, "La scena principale deve contenere la tavola achievement")
	if board == null:
		_finish()
		return
	board.call("open")
	await process_frame
	var root_ui := board.get_node_or_null("AchievementBoardRoot") as Control
	var achievements := root.get_node_or_null("AchievementManager")
	_expect(root_ui != null and root_ui.visible, "J/apertura deve rendere visibile la tavola")
	_expect(achievements != null and bool(achievements.get("is_board_open")), "Con la tavola aperta il gioco deve bloccare le interazioni nel mondo")
	_expect(achievements != null and int(achievements.call("get_progress", "first_base")) == 0, "Ogni nuovo avvio deve ignorare i progressi achievement delle sessioni precedenti")
	var survival_ui := current_scene.get_node_or_null("SurvivalUI") as CanvasLayer
	var power_ui := current_scene.get_node_or_null("PowerUI") as CanvasLayer
	_expect(survival_ui != null and not survival_ui.visible and power_ui != null and not power_ui.visible, "Con la tavola aperta gli altri HUD devono sparire")
	var graph := _find_named(root_ui, "MissionGraph") as Control
	var graph_links := _find_named(root_ui, "GraphLinks") as Control
	var definitions: Array = achievements.call("get_ordered_definitions") if achievements != null else []
	_expect(graph != null, "La tavola deve contenere un grafo dedicato")
	_expect(graph_links != null, "Il grafo deve disegnare le connessioni tra i nodi")
	if graph != null:
		var node_count := 0
		for child in graph.get_children():
			if str(child.name).begins_with("AchievementNode_"):
				node_count += 1
		_expect(node_count == definitions.size(), "Ogni obiettivo deve diventare un nodo del grafo")
		_expect(graph.get_node_or_null("AchievementNode_first_base") != null and graph.get_node_or_null("AchievementNode_science_center") != null and graph.get_node_or_null("AchievementNode_large_dome") == null, "Il grafo deve avere radice, nodo finale e nessuna missione cupola grande")
	board.call("close")
	_expect((achievements == null or not bool(achievements.get("is_board_open"))) and not root_ui.visible, "Chiudere la tavola deve riattivare il gioco")
	_expect(survival_ui != null and survival_ui.visible and power_ui != null and power_ui.visible, "Chiudere la tavola deve ripristinare gli HUD")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _find_named(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, target_name)
		if found != null:
			return found
	return null


func _finish() -> void:
	if failures.is_empty():
		print("ACHIEVEMENT_BOARD_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("ACHIEVEMENT_BOARD_SMOKE_FAIL: " + failure)
	quit(1)
