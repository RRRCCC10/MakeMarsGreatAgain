extends SceneTree

const DOME_SCRIPT := preload("res://scripts/BaseDome.gd")


class ExternalOxygenSource:
	extends Node2D
	var available_kg := 1.0

	func consume_fluid_resource_for_category(category: int, requested_kg: float) -> float:
		if category != PipeSegment.Category.OXYGEN:
			return 0.0
		var supplied := minf(available_kg, requested_kg)
		available_kg -= supplied
		return supplied

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://Scenes/main.tscn") != OK:
		_fail("Unable to load the main scene")
		_finish()
		return
	await process_frame
	await process_frame
	var scene := current_scene
	var grid: Node = root.get_node("PowerGrid")
	var pipes: Node = root.get_node("PipeManager")
	var machine = grid.place_process_machine(scene, "electrolyzer", Vector2i(40, 38))
	_expect(machine != null, "Test assertion failed")
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
	_expect(oxygen_pipe != null, "Test assertion failed")
	for y in range(vertical_start.y, corner.y):
		var pipe = pipes.place_pipe(scene, Vector2i(oxygen_source.x, y), 0 if y == vertical_start.y else 0, true)
		_expect(pipe != null, "Test assertion failed")
	var corner_pipe = pipes.place_pipe(scene, corner, 1, false)
	_expect(corner_pipe != null, "Test assertion failed")
	for x in range(corner.x + 1, oxygen_port.x):
		var pipe = pipes.place_pipe(scene, Vector2i(x, corner.y), 0, false)
		_expect(pipe != null, "Test assertion failed")
	var port_pipe = pipes.place_pipe(scene, oxygen_port, 0, false)
	_expect(port_pipe != null, "Test assertion failed")
	_expect(bool(pipes.call("is_source_connected", machine, PipeSegment.Category.OXYGEN)), "Test assertion failed")
	_expect(bool(dome.call("is_oxygen_connected")), "Test assertion failed")

	var external_source := ExternalOxygenSource.new()
	scene.add_child(external_source)
	var external_sink := Node2D.new()
	scene.add_child(external_sink)
	var source_port := Vector2i(180, 130)
	var sink_port := Vector2i(188, 130)
	pipes.register_fluid_source(external_source, source_port, PipeSegment.Category.OXYGEN, Vector2i.LEFT)
	pipes.register_fluid_input(external_sink, sink_port, PipeSegment.Category.OXYGEN, Vector2i.LEFT)
	for x in range(source_port.x + 1, sink_port.x + 2):
		var external_pipe = pipes.place_pipe(scene, Vector2i(x, source_port.y), PipeSegment.ShapeType.STRAIGHT, false)
		_expect(external_pipe != null, "Test assertion failed")
	_expect(bool(pipes.call("is_source_connected", external_source, PipeSegment.Category.OXYGEN)), "Test assertion failed")
	_expect(bool(pipes.call("is_input_connected", sink_port, Vector2i.LEFT, PipeSegment.Category.OXYGEN)), "Test assertion failed")
	_expect(is_equal_approx(float(pipes.call("consume_connected_resource", sink_port, Vector2i.LEFT, PipeSegment.Category.OXYGEN, 0.25)), 0.25), "Test assertion failed")
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
