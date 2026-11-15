extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")

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
	var scene := current_scene
	var grid: Node = root.get_node("PowerGrid")
	var pipes: Node = root.get_node("PipeManager")
	var machine = grid.place_process_machine(scene, "electrolyzer", Vector2i(40, 38))
	_expect(machine != null, "L'elettrolizzatore deve poter essere installato")
	if machine == null:
		_finish()
		return
	var dome := DOME_SCRIPT.new() as BaseDome
	dome.setup("dome_small", 1, false, {})
	scene.add_child(dome)
	dome.global_position = Vector2(65 * 16 + 8, 62 * 16 + 8)
	await process_frame
	await process_frame
	var oxygen_source: Vector2i = machine.get_oxygen_output_cell()
	var oxygen_port: Vector2i = dome.get_oxygen_input_cell()
	var vertical_start: Vector2i = oxygen_source + Vector2i.DOWN
	var corner := Vector2i(oxygen_source.x, oxygen_port.y)
	var oxygen_pipe = pipes.place_pipe(scene, oxygen_source, PipeSegment.ShapeType.CROSS, false)
	_expect(oxygen_pipe != null, "Il tubo sulla porta O₂ deve poter essere posato")
	for y in range(vertical_start.y, corner.y):
		var pipe = pipes.place_pipe(scene, Vector2i(oxygen_source.x, y), 0 if y == vertical_start.y else 0, true)
		_expect(pipe != null, "Il ramo verticale O₂ deve poter essere posato")
	var corner_pipe = pipes.place_pipe(scene, corner, 1, false)
	_expect(corner_pipe != null, "La curva O₂ deve poter essere posata")
	for x in range(corner.x + 1, oxygen_port.x):
		var pipe = pipes.place_pipe(scene, Vector2i(x, corner.y), 0, false)
		_expect(pipe != null, "Il ramo orizzontale O₂ deve poter essere posato")
	var port_pipe = pipes.place_pipe(scene, oxygen_port, 0, false)
	_expect(port_pipe != null, "Il tubo sul raccordo O₂ della cupola deve poter essere posato")
	_expect(bool(pipes.call("is_source_connected", machine, PipeSegment.Category.OXYGEN)), "L'uscita O₂ dell'elettrolizzatore deve riconoscere il percorso")
	_expect(bool(dome.call("is_oxygen_connected")), "La cupola deve riconoscere l'ossigeno dall'elettrolizzatore anche su un percorso con curva")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ELECTROLYZER_DOME_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("ELECTROLYZER_DOME_SMOKE_FAIL: " + failure)
	quit(1)
