extends SceneTree

class HydrogenSource extends Node2D:
	var stock := 10.0

	func consume_fluid_resource_for_category(category: int, amount: float) -> float:
		if category != PipeSegment.Category.HYDROGEN:
			return 0.0
		var supplied := minf(stock, amount)
		stock -= supplied
		return supplied


var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_result := change_scene_to_file("res://Scenes/main.tscn")
	if scene_result != OK:
		push_error("Unable to load the main scene: %s" % scene_result)
		quit(1)
		return
	await process_frame
	await process_frame
	var scene := current_scene
	var grid: Node = root.get_node("PowerGrid")
	var pipes: Node = root.get_node("PipeManager")
	var machine = grid.place_process_machine(scene, "electrolyzer", Vector2i(40, 38))
	var water_source = grid.place_device(scene, "ice_drill", Vector2i(34, 39))
	_expect(machine != null and water_source != null, "Test assertion failed")
	if machine == null or water_source == null:
		_finish()
		return
	var source_pipe = pipes.place_pipe(scene, water_source.get_fluid_output_cell(), 0, false)
	var middle_pipe_a = pipes.place_pipe(scene, Vector2i(37, 39), 0, false)
	var middle_pipe_b = pipes.place_pipe(scene, Vector2i(38, 39), 0, false)
	var water_pipe = pipes.place_pipe(scene, machine.get_water_input_cell(), 0, false)
	_expect(water_pipe != null, "Test assertion failed")
	_expect(source_pipe != null and middle_pipe_a != null and middle_pipe_b != null, "Test assertion failed")
	_expect(middle_pipe_b != null and middle_pipe_b.category == PipeSegment.Category.WATER, "Test assertion failed")
	_expect(water_pipe != null and water_pipe.category == PipeSegment.Category.WATER, "Test assertion failed")
	_expect(water_pipe != null and water_pipe.shape_type == PipeSegment.ShapeType.STRAIGHT and not water_pipe.is_vertical, "Test assertion failed")
	water_pipe.setup(machine.get_water_input_cell(), PipeSegment.ShapeType.CROSS, false, PipeSegment.Category.WATER)
	pipes.register_fluid_input(machine, machine.get_water_input_cell(), PipeSegment.Category.WATER, Vector2i.RIGHT)
	_expect(water_pipe.shape_type == PipeSegment.ShapeType.STRAIGHT and not water_pipe.is_vertical, "Test assertion failed")
	_expect(pipes.is_input_connected(machine.get_water_input_cell(), Vector2i.RIGHT, PipeSegment.Category.WATER), "Test assertion failed")
	water_source.water_storage_liters = 100.0
	machine.powered = true
	machine._process(1.0)
	_expect(is_zero_approx(machine.water_consumed_liters), "Test assertion failed")
	_expect(is_zero_approx(machine.hydrogen_flow_kg) and is_zero_approx(machine.oxygen_flow_kg), "Test assertion failed")
	_expect(is_equal_approx(water_source.water_storage_liters, 100.0), "Test assertion failed")
	var hydrogen_pipe = pipes.place_pipe(scene, machine.get_hydrogen_output_cell(), 0, false)
	_expect(hydrogen_pipe != null and hydrogen_pipe.category == PipeSegment.Category.HYDROGEN, "Test assertion failed")
	_expect(hydrogen_pipe != null and not hydrogen_pipe.is_vertical, "Test assertion failed")
	machine._process(1.0)
	var hydrogen_flow: float = machine.hydrogen_flow_kg
	_expect(hydrogen_flow > 0.0 and is_zero_approx(machine.oxygen_flow_kg), "Test assertion failed")
	_expect(water_source.water_storage_liters < 100.0, "Test assertion failed")
	machine._process(1.0)
	_expect(is_equal_approx(machine.hydrogen_flow_kg, hydrogen_flow), "Test assertion failed")
	var oxygen_pipe = pipes.place_pipe(scene, machine.get_oxygen_output_cell(), 0, false)
	_expect(oxygen_pipe != null and oxygen_pipe.category == PipeSegment.Category.OXYGEN, "Test assertion failed")
	_expect(oxygen_pipe != null and not oxygen_pipe.is_vertical, "Test assertion failed")
	machine._process(1.0)
	_expect(machine.hydrogen_flow_kg > 0.0 and machine.oxygen_flow_kg > 0.0, "Test assertion failed")
	var rocket: Node2D = scene.get_node("LandingSequence")
	var sabatier_cell := Vector2i(floori((rocket.global_position.x - 64.0 - 24.0) / 16.0), floori((rocket.global_position.y - 24.0) / 16.0))
	var sabatier = grid.place_process_machine(scene, "sabatier", sabatier_cell)
	_expect(sabatier != null, "Test assertion failed")
	if sabatier != null:
		var hydrogen_input = pipes.place_pipe(scene, sabatier.get_hydrogen_input_cell(), 0, false)
		_expect(hydrogen_input != null and hydrogen_input.category == PipeSegment.Category.HYDROGEN, "Test assertion failed")
		_expect(hydrogen_input != null and hydrogen_input.shape_type == PipeSegment.ShapeType.STRAIGHT and not hydrogen_input.is_vertical, "Test assertion failed")
		if hydrogen_input != null:
			var hydrogen_source := HydrogenSource.new()
			scene.add_child(hydrogen_source)
			pipes.register_fluid_source(hydrogen_source, sabatier.get_hydrogen_input_cell(), PipeSegment.Category.HYDROGEN, Vector2i.RIGHT)
			sabatier.powered = true
			sabatier._process(1.0)
			_expect(hydrogen_source.stock < 10.0, "Test assertion failed")
			_expect(rocket.methane_kg > 0.0, "Test assertion failed")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PROCESS_MACHINE_FLUID_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
