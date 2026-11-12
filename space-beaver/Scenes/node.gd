extends Node

const PIPE_SCENE := preload("res://Scenes/pipe.tscn")
const POWER_DEVICE_SCRIPT := preload("res://scripts/PowerDevice.gd")
const ROCK_DRILL_SCRIPT := preload("res://scripts/RockDrill.gd")
const PROCESS_MACHINE_SCRIPT := preload("res://scripts/ProcessMachine.gd")
const ROVER_SCRIPT := preload("res://scripts/Rover.gd")
const BASE_DOME_SCRIPT := preload("res://scripts/BaseDome.gd")
# Greenhouse.gd is kept as a project resource so the editor can resolve the
# typed preview and the manual power-control panel without a stale reference.
const GREENHOUSE_SCRIPT := preload("res://scripts/Greenhouse.gd")
const RESEARCH_MACHINE_SCRIPT := preload("res://scripts/ResearchMachine.gd")
const MACHINE_INTERACTION_DISTANCE := 76.0

@onready var camera: Camera2D = $"../Camera2D"

var pipe_shape := PipeSegment.ShapeType.STRAIGHT
var pipe_vertical := false
var pipe_preview: PipeSegment
var power_preview: PowerDevice
var rock_drill_preview: RockDrill
var process_preview: ProcessMachine
var rover_preview: Rover
var dome_preview: BaseDome
var greenhouse_preview: Greenhouse
var research_preview: Node2D
var dome_entrance_direction := 1
var machine_placement_rotation := 0
var demolition_root: Control
var demolition_question: Label
var pending_demolition: Dictionary = {}
var machine_info_root: Control
var machine_title: Label
var machine_category: Label
var machine_status: Label
var machine_specs: Label
var machine_principle: Label
var machine_power_button: Button
var inspected_machine: Node
var nearby_machine_root: PanelContainer
var nearby_machine_name: Label
var nearby_machine_summary: Label
var nearby_machine_connection: Label
var nearby_machine_stock: Label
var nearby_machine_prompt: Label
var nearby_machine: Node


func _ready() -> void:
	call_deferred("_create_pipe_preview")
	call_deferred("_create_power_preview")
	call_deferred("_create_rock_drill_preview")
	call_deferred("_create_process_preview")
	call_deferred("_create_rover_preview")
	call_deferred("_create_dome_preview")
	call_deferred("_create_greenhouse_preview")
	call_deferred("_create_research_preview")
	call_deferred("_create_demolition_ui")
	call_deferred("_create_machine_info_ui")
	call_deferred("_create_nearby_machine_ui")


func _create_pipe_preview() -> void:
	pipe_preview = PIPE_SCENE.instantiate() as PipeSegment
	pipe_preview.is_preview = true
	get_tree().current_scene.add_child(pipe_preview)
	pipe_preview.modulate = Color(0.55, 1.0, 0.62, 0.72)
	pipe_preview.visible = false


func _create_power_preview() -> void:
	power_preview = POWER_DEVICE_SCRIPT.new() as PowerDevice
	power_preview.is_preview = true
	get_tree().current_scene.add_child(power_preview)
	power_preview.visible = false


func _create_rock_drill_preview() -> void:
	rock_drill_preview = ROCK_DRILL_SCRIPT.new() as RockDrill
	rock_drill_preview.setup(Vector2i.ZERO, true)
	get_tree().current_scene.add_child(rock_drill_preview)
	rock_drill_preview.visible = false


func _create_rover_preview() -> void:
	rover_preview = ROVER_SCRIPT.new() as Rover
	rover_preview.is_preview = true
	get_tree().current_scene.add_child(rover_preview)
	rover_preview.visible = false


func _create_process_preview() -> void:
	process_preview = PROCESS_MACHINE_SCRIPT.new() as ProcessMachine
	process_preview.is_preview = true
	get_tree().current_scene.add_child(process_preview)
	process_preview.visible = false


func _create_dome_preview() -> void:
	dome_preview = BASE_DOME_SCRIPT.new() as BaseDome
	dome_preview.setup("dome_small", dome_entrance_direction, true)
	get_tree().current_scene.add_child(dome_preview)
	dome_preview.visible = false


func _create_greenhouse_preview() -> void:
	greenhouse_preview = GREENHOUSE_SCRIPT.new() as Greenhouse
	greenhouse_preview.setup_greenhouse(dome_entrance_direction, true)
	get_tree().current_scene.add_child(greenhouse_preview)
	greenhouse_preview.visible = false


func _create_research_preview() -> void:
	var preview := RESEARCH_MACHINE_SCRIPT.new()
	preview.call("setup", "xrd_diffractometer", true)
	research_preview = preview as Node2D
	get_tree().current_scene.add_child(research_preview)
	research_preview.visible = false


func _process(_delta: float) -> void:
	if machine_info_root != null and machine_info_root.visible:
		_refresh_machine_info()
	_update_nearby_machine_ui()
	var blocked := Inventory.is_open or Shop.is_open or BuildableRegistry.is_modal_open or AchievementManager.is_board_open
	var selected_id := str(Inventory.get_selected_item().get("id", ""))
	if pipe_preview != null:
		var pipe_active: bool = not blocked and selected_id == "pipe_hammer"
		pipe_preview.visible = pipe_active
		if pipe_active:
			var pipe_cell: Vector2i = PipeManager.get_mouse_cell(camera)
			pipe_preview.setup(pipe_cell, pipe_shape, pipe_vertical)
			pipe_preview.global_position = PipeManager.cell_to_world(pipe_cell)
			pipe_preview.modulate = Color(0.55, 1.0, 0.62, 0.72) if PipeManager.can_place_pipe(pipe_cell, pipe_shape, pipe_vertical) else Color(1.0, 0.28, 0.24, 0.68)
	if power_preview != null:
		var power_active: bool = not blocked and selected_id in ["solar_panel", "transformer", "battery", "ice_drill"]
		power_preview.visible = power_active
		if power_active:
			var power_cell := PowerGrid.get_mouse_cell(camera)
			power_preview.setup(selected_id, power_cell, true, machine_placement_rotation)
			power_preview.global_position = PowerGrid.device_world_position(selected_id, power_cell, machine_placement_rotation)
			power_preview.modulate = Color(0.55, 1.0, 0.62, 0.72) if PowerGrid.can_place_device(selected_id, power_cell, machine_placement_rotation) else Color(1.0, 0.28, 0.24, 0.72)
	if rock_drill_preview != null:
		var rock_drill_active: bool = not blocked and selected_id == "rock_drill"
		rock_drill_preview.visible = rock_drill_active
		if rock_drill_active:
			var rock_drill_cell := PowerGrid.get_mouse_cell(camera)
			rock_drill_preview.setup(rock_drill_cell, true, machine_placement_rotation)
			rock_drill_preview.global_position = PowerGrid.device_world_position("rock_drill", rock_drill_cell, machine_placement_rotation)
			rock_drill_preview.modulate = Color(0.55, 1.0, 0.62, 0.72) if PowerGrid.can_place_device("rock_drill", rock_drill_cell, machine_placement_rotation) else Color(1.0, 0.28, 0.24, 0.72)
	if process_preview != null:
		var process_active := not blocked and selected_id in ["electrolyzer", "sabatier"]
		process_preview.visible = process_active
		if process_active:
			var process_cell: Vector2i = ProcessMachine.sabatier_target_cell() if selected_id == "sabatier" else PowerGrid.get_mouse_cell(camera)
			process_preview.setup(selected_id, process_cell, true, machine_placement_rotation)
			process_preview.global_position = ProcessMachine.world_position_for(selected_id, process_cell)
			process_preview.modulate = Color(0.55, 1.0, 0.62, 0.82) if PowerGrid.can_place_device(selected_id, process_cell, machine_placement_rotation) else Color(1.0, 0.28, 0.24, 0.82)
	if research_preview != null:
		var research_active := not blocked and selected_id in ["xrd_diffractometer", "raman_spectrometer", "icp_ms"]
		research_preview.visible = research_active
		if research_active:
			var research_cell := PowerGrid.get_mouse_cell(camera)
			research_preview.call("setup", selected_id, true, machine_placement_rotation)
			research_preview.global_position = RESEARCH_MACHINE_SCRIPT.world_position_for(selected_id, research_cell, machine_placement_rotation)
			research_preview.modulate = Color(0.55, 1.0, 0.62, 0.82) if RESEARCH_MACHINE_SCRIPT.can_place_at(selected_id, research_preview.global_position, machine_placement_rotation) else Color(1.0, 0.28, 0.24, 0.82)
	if rover_preview != null:
		var rover_active: bool = not blocked and selected_id == "rover"
		rover_preview.visible = rover_active
		if rover_active:
			var rover_cell := PowerGrid.get_mouse_cell(camera)
			rover_preview.global_position = Rover.placement_world_position(rover_cell)
			rover_preview.modulate = Color(0.55, 1.0, 0.62, 0.72) if Rover.can_place_at(rover_preview.global_position) else Color(1.0, 0.28, 0.24, 0.72)
	if dome_preview != null:
		var dome_active: bool = not blocked and selected_id in ["dome_small", "dome_medium", "dome_large"]
		dome_preview.visible = dome_active
		if dome_active:
			var dome_cell := PowerGrid.get_mouse_cell(camera)
			var dome_configuration: Dictionary = Inventory.get_selected_item().get("configuration", {})
			dome_preview.setup(selected_id, dome_entrance_direction, true, dome_configuration)
			dome_preview.global_position = BaseDome.world_position_for(dome_cell)
			dome_preview.modulate = Color(0.55, 1.0, 0.62, 0.72) if BaseDome.can_place_at(dome_preview.global_position, selected_id, dome_configuration, dome_entrance_direction) else Color(1.0, 0.28, 0.24, 0.72)
	if greenhouse_preview != null:
		var greenhouse_active: bool = not blocked and selected_id == "greenhouse"
		greenhouse_preview.visible = greenhouse_active
		if greenhouse_active:
			var greenhouse_cell := PowerGrid.get_mouse_cell(camera)
			greenhouse_preview.setup_greenhouse(dome_entrance_direction, true)
			greenhouse_preview.global_position = BaseDome.world_position_for(greenhouse_cell)
			greenhouse_preview.modulate = Color(0.55, 1.0, 0.62, 0.72) if bool(greenhouse_preview.call("can_place_greenhouse_at", greenhouse_preview.global_position)) else Color(1.0, 0.28, 0.24, 0.72)


func _unhandled_input(event: InputEvent) -> void:
	if BuildableRegistry.is_modal_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if machine_info_root != null and machine_info_root.visible:
				_close_machine_info()
			else:
				_close_demolition_ui()
			get_viewport().set_input_as_handled()
		return
		return
	if Inventory.is_open or Shop.is_open or AchievementManager.is_board_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and nearby_machine != null:
		if event.keycode == KEY_V:
			_toggle_nearby_network()
			get_viewport().set_input_as_handled()
			return
		# La trivella mineraria usa E per aprire il proprio deposito a due colonne:
		# non deve essere trattata come uno stock generico da ritirare un pezzo alla
		# volta, altrimenti il giocatore non può scegliere le pile da trasferire.
		if event.keycode == KEY_E and _nearby_has_stock() and not nearby_machine.is_in_group("rock_drills"):
			nearby_machine.call("take_stock_item", 0)
			_update_nearby_machine_ui()
			get_viewport().set_input_as_handled()
			return
	var item := Inventory.get_selected_item()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_world_position := camera.get_global_mouse_position()
		for dome in get_tree().get_nodes_in_group("base_domes"):
			if is_instance_valid(dome) and dome.has_method("handle_oxygen_port_right_click") and bool(dome.call("handle_oxygen_port_right_click", mouse_world_position)):
				get_viewport().set_input_as_handled()
				return
		_try_demolish_at_mouse(item)
		get_viewport().set_input_as_handled()
		return
	if item.get("id", "") == "pipe_hammer" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			pipe_shape = PipeSegment.ShapeType.CROSS if pipe_shape == PipeSegment.ShapeType.STRAIGHT else PipeSegment.ShapeType.STRAIGHT
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R and pipe_shape == PipeSegment.ShapeType.STRAIGHT:
			pipe_vertical = not pipe_vertical
			get_viewport().set_input_as_handled()
			return
	if item.get("id", "") in ["dome_small", "dome_medium", "dome_large", "greenhouse"] and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		dome_entrance_direction = posmod(dome_entrance_direction + 1, 4)
		get_viewport().set_input_as_handled()
		return
	if item.get("id", "") in ["solar_panel", "transformer", "battery", "ice_drill", "rock_drill", "electrolyzer", "sabatier", "xrd_diffractometer", "raman_spectrometer", "icp_ms"] and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		machine_placement_rotation = posmod(machine_placement_rotation + 1, 4)
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("left_click"):
		return
	var clicked_entry := BuildableRegistry.find_at(camera.get_global_mouse_position())
	if not clicked_entry.is_empty():
		var clicked_node: Node = clicked_entry.get("node")
		if is_instance_valid(clicked_node) and clicked_node.has_method("get_machine_specs"):
			_show_machine_info(clicked_entry)
			get_viewport().set_input_as_handled()
			return
	if item.is_empty():
		return
	match item.get("id", ""):
		"water_bottle":
			Hydration.drink_from_selected_bottle()
		"food_ration":
			Hunger.eat_selected_ration()
		"pipe_hammer":
			var cell := PipeManager.get_mouse_cell(camera)
			PipeManager.place_pipe(get_tree().current_scene, cell, pipe_shape, pipe_vertical)
		"solar_panel", "transformer", "battery", "ice_drill", "rock_drill":
			var cell := PowerGrid.get_mouse_cell(camera)
			if PowerGrid.place_device(get_tree().current_scene, str(item.get("id", "")), cell, machine_placement_rotation) != null:
				Inventory.consume_selected_item()
		"electrolyzer", "sabatier":
			var process_cell: Vector2i = ProcessMachine.sabatier_target_cell() if item.get("id", "") == "sabatier" else PowerGrid.get_mouse_cell(camera)
			if item.get("id", "") == "sabatier" and PowerGrid.get_mouse_cell(camera) not in ProcessMachine.footprint_cells("sabatier", process_cell):
				return
			if PowerGrid.place_process_machine(get_tree().current_scene, str(item.get("id", "")), process_cell, machine_placement_rotation) != null:
				Inventory.consume_selected_item()
		"xrd_diffractometer", "raman_spectrometer", "icp_ms":
			var research_cell := PowerGrid.get_mouse_cell(camera)
			if RESEARCH_MACHINE_SCRIPT.place(get_tree().current_scene, str(item.get("id", "")), research_cell, machine_placement_rotation) != null:
				Inventory.consume_selected_item()
		"rover":
			var rover_cell := PowerGrid.get_mouse_cell(camera)
			var stored_battery := float(Inventory.call("peek_selected_rover_battery"))
			if stored_battery < 0.0:
				stored_battery = Rover.STARTING_ENERGY_KWH
			if Rover.place(get_tree().current_scene, rover_cell, stored_battery) != null:
				Inventory.consume_selected_item()
		"dome_small", "dome_medium", "dome_large":
			var dome_cell := PowerGrid.get_mouse_cell(camera)
			var dome_configuration: Dictionary = item.get("configuration", {})
			if BaseDome.place(get_tree().current_scene, str(item.get("id", "")), dome_cell, dome_entrance_direction, dome_configuration) != null:
				Inventory.consume_selected_item()
		"greenhouse":
			var greenhouse_cell := PowerGrid.get_mouse_cell(camera)
			var greenhouse_position := BaseDome.world_position_for(greenhouse_cell)
			if greenhouse_preview != null and bool(greenhouse_preview.call("can_place_greenhouse_at", greenhouse_position)):
				var greenhouse := GREENHOUSE_SCRIPT.new() as Greenhouse
				greenhouse.setup_greenhouse(dome_entrance_direction, false)
				get_tree().current_scene.add_child(greenhouse)
				greenhouse.global_position = greenhouse_position
				Inventory.consume_selected_item()
		_:
			if item.get("placeable", false):
				var cell := GridManager.get_mouse_grid_position(camera)
				if GridManager.place_item(cell, item.get("id", "")):
					Inventory.consume_selected_item()


func get_build_help_text() -> String:
	var selected_id := str(Inventory.get_selected_item().get("id", ""))
	if selected_id == "solar_panel":
		return "PANNELLO: Click posiziona  ·  R ruota (%s)  ·  Dx riprende" % _machine_rotation_label()
	if selected_id == "transformer":
		return "TRASFORMATORE UNICO: Click posiziona  ·  R ruota (%s)  ·  Dx riprende" % _machine_rotation_label()
	if selected_id == "battery":
		return "BATTERIA: Click posiziona  ·  R ruota (%s)  ·  500 kWh  ·  Dx riprende" % _machine_rotation_label()
	if selected_id == "ice_drill":
		return "TRIVELLA: Click posiziona  ·  R ruota (%s)  ·  60 kW  ·  Dx rimuove" % _machine_rotation_label()
	if selected_id == "rock_drill":
		return "TRIVELLA ROCCE: Click posiziona  ·  R ruota (%s)  ·  85 kW  ·  E apre riserva  ·  Dx rimuove" % _machine_rotation_label()
	if selected_id == "electrolyzer":
		return "ELETTROLIZZATORE: Click posiziona  ·  R ruota (%s)  ·  65 kW + acqua e uscite H₂/O₂  ·  Dx rimuove" % _machine_rotation_label()
	if selected_id == "sabatier":
		return "SABATIER: a sinistra del razzo  ·  R ruota (%s)  ·  50 kW + tubo H₂  ·  CH₄ diretto" % _machine_rotation_label()
	if selected_id == "rover":
		return "ROVER: Click posiziona  ·  E sali/scendi  ·  F apre i pannelli solari  ·  Dx riprende"
	if selected_id in ["dome_small", "dome_medium", "dome_large"]:
		return "CUPOLE: Click posiziona  ·  R ruota ingresso/camera  ·  E usa la camera di decompressione  ·  Dx demolisce"
	if selected_id == "greenhouse":
		return "SERRA: Click posiziona  ·  R ruota ingresso/camera  ·  acqua a sinistra  ·  E semina dentro  ·  Dx demolisce"
	if selected_id in ["xrd_diffractometer", "raman_spectrometer", "icp_ms"]:
		return "RICERCA: Click in una cupola abitativa  ·  R ruota (%s)  ·  E pietra/rapporto  ·  U upgrade  ·  Dx riprende" % _machine_rotation_label()
	var shape_name := "CROCE" if pipe_shape == PipeSegment.ShapeType.CROSS else ("DRITTO VERTICALE" if pipe_vertical else "DRITTO ORIZZONTALE")
	return "TUBI: " + shape_name + "  ·  $100 MLN  ·  T tipo  ·  R ruota  ·  Dx demolisce"


func get_pipe_help_text() -> String:
	return get_build_help_text()


func _machine_rotation_label() -> String:
	return ["EST", "SUD", "OVEST", "NORD"][posmod(machine_placement_rotation, 4)]


func _try_demolish_at_mouse(item: Dictionary) -> void:
	var entry := BuildableRegistry.find_at(camera.get_global_mouse_position())
	if entry.is_empty():
		return
	if entry.get("kind", "") == "mission_structure":
		return
	if entry.get("kind", "") == "power_device":
		BuildableRegistry.destroy(entry)
		return
	if item.get("id", "") == "pipe_hammer" and entry.get("kind", "") == "pipe":
		BuildableRegistry.destroy(entry)
		return
	_show_demolition_ui(entry)


func _create_demolition_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().current_scene.add_child(layer)

	demolition_root = Control.new()
	demolition_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demolition_root.visible = false
	layer.add_child(demolition_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.025, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	demolition_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190.0
	panel.offset_top = -92.0
	panel.offset_right = 190.0
	panel.offset_bottom = 92.0
	panel.add_theme_stylebox_override("panel", _demolition_panel_style())
	demolition_root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := Label.new()
	title.text = "!!  CONFERMA DEMOLIZIONE  !!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("ffca67"))
	content.add_child(title)

	demolition_question = Label.new()
	demolition_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demolition_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demolition_question.add_theme_font_size_override("font_size", 13)
	demolition_question.add_theme_color_override("font_color", Color("e5eeee"))
	content.add_child(demolition_question)

	var warning := Label.new()
	warning.text = "NESSUN RIMBORSO DEL BUDGET"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 12)
	warning.add_theme_color_override("font_color", Color("ff7d6b"))
	content.add_child(warning)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	content.add_child(buttons)
	var confirm_button := _make_demolition_button("[ DEMOLISCI ]", Color("a53a32"))
	confirm_button.pressed.connect(_confirm_demolition)
	buttons.add_child(confirm_button)
	var cancel_button := _make_demolition_button("[ ANNULLA ]", Color("304c58"))
	cancel_button.pressed.connect(_close_demolition_ui)
	buttons.add_child(cancel_button)


func _show_demolition_ui(entry: Dictionary) -> void:
	pending_demolition = entry
	demolition_question.text = "Vuoi rimuovere:  %s ?" % entry.get("display_name", "OGGETTO")
	demolition_root.visible = true
	BuildableRegistry.is_modal_open = true


func _confirm_demolition() -> void:
	var entry := pending_demolition
	_close_demolition_ui()
	if not entry.is_empty():
		BuildableRegistry.destroy(entry)


func _close_demolition_ui() -> void:
	pending_demolition = {}
	BuildableRegistry.is_modal_open = false
	if demolition_root != null:
		demolition_root.visible = false


func _create_nearby_machine_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	get_tree().current_scene.add_child(layer)
	nearby_machine_root = PanelContainer.new()
	nearby_machine_root.anchor_left = 0.5
	nearby_machine_root.anchor_right = 0.5
	nearby_machine_root.offset_left = -245.0
	nearby_machine_root.offset_top = 18.0
	nearby_machine_root.offset_right = 245.0
	nearby_machine_root.offset_bottom = 154.0
	nearby_machine_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nearby_machine_root.add_theme_stylebox_override("panel", _nearby_machine_style())
	nearby_machine_root.visible = false
	layer.add_child(nearby_machine_root)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	nearby_machine_root.add_child(rows)
	nearby_machine_name = Label.new()
	nearby_machine_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_machine_name.add_theme_font_size_override("font_size", 15)
	nearby_machine_name.add_theme_color_override("font_color", Color("ffe38a"))
	rows.add_child(nearby_machine_name)
	nearby_machine_summary = Label.new()
	nearby_machine_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_machine_summary.add_theme_font_size_override("font_size", 11)
	nearby_machine_summary.add_theme_color_override("font_color", Color("d7e3e3"))
	rows.add_child(nearby_machine_summary)
	nearby_machine_connection = Label.new()
	nearby_machine_connection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_machine_connection.add_theme_font_size_override("font_size", 12)
	rows.add_child(nearby_machine_connection)
	nearby_machine_stock = Label.new()
	nearby_machine_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_machine_stock.add_theme_font_size_override("font_size", 10)
	nearby_machine_stock.add_theme_color_override("font_color", Color("9fb7c2"))
	rows.add_child(nearby_machine_stock)
	nearby_machine_prompt = Label.new()
	nearby_machine_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_machine_prompt.add_theme_font_size_override("font_size", 12)
	nearby_machine_prompt.add_theme_color_override("font_color", Color("7ed7ff"))
	rows.add_child(nearby_machine_prompt)


func _update_nearby_machine_ui() -> void:
	if nearby_machine_root == null:
		return
	if Inventory.is_open or Shop.is_open or BuildableRegistry.is_modal_open or AchievementManager.is_board_open:
		nearby_machine = null
		nearby_machine_root.visible = false
		return
	var closest_entry := _find_nearest_electrical_device()
	if closest_entry.is_empty():
		nearby_machine = null
		nearby_machine_root.visible = false
		return
	nearby_machine = closest_entry.get("node") as Node
	if not is_instance_valid(nearby_machine):
		nearby_machine_root.visible = false
		return
	nearby_machine_root.visible = true
	nearby_machine_name.text = str(closest_entry.get("display_name", "MACCHINARIO"))
	nearby_machine_summary.text = str(nearby_machine.call("get_interaction_summary"))
	var connection_label := str(nearby_machine.call("get_connection_label"))
	nearby_machine_connection.text = connection_label
	var enabled := bool(nearby_machine.call("is_network_enabled"))
	var connection_color := Color("72eda0") if connection_label == "COLLEGATO ALLA RETE" else (Color("ffb45d") if enabled else Color("ff776d"))
	nearby_machine_connection.add_theme_color_override("font_color", connection_color)
	# Non tutti i macchinari hanno uno stock ritirabile a mano: i serbatoi
	# dell'elettrolizzatore escono tramite tubi, e il Sabatier carica il razzo.
	var stock: Array = []
	if nearby_machine.has_method("get_stock_items"):
		stock = Array(nearby_machine.call("get_stock_items"))
	if stock.is_empty():
		nearby_machine_stock.text = str(nearby_machine.call("get_inventory_output_label")) if nearby_machine.has_method("get_inventory_output_label") else "STOCK  ·  nessun output disponibile"
	else:
		var first: Dictionary = stock[0]
		if nearby_machine.is_in_group("rock_drills"):
			var sample_count := int(nearby_machine.call("get_stock_count")) if nearby_machine.has_method("get_stock_count") else stock.size()
			nearby_machine_stock.text = "RISERVA  ·  %d campioni  ·  E apri deposito" % sample_count
		else:
			nearby_machine_stock.text = "STOCK  ·  %s x%d  ·  E ritira" % [str(first.get("name", "Output")), int(first.get("count", 0))]
	nearby_machine_prompt.text = "V  ·  DISCONNETTI DALLA RETE" if enabled else "V  ·  CONNETTI ALLA RETE"


func _find_nearest_electrical_device() -> Dictionary:
	var player := get_parent() as Node2D
	if player == null:
		return {}
	var closest: Dictionary = {}
	var best_distance := MACHINE_INTERACTION_DISTANCE
	for entry in BuildableRegistry.get_entries():
		var node := entry.get("node") as Node2D
		if node == null or not node.has_method("is_network_enabled"):
			continue
		# La serra è un edificio, ma deve poter essere volontariamente connessa
		# o disconnessa dalla rete con V, come gli altri consumatori elettrici.
		var supports_greenhouse_power := node.has_method("get_interaction_summary") and node.has_method("get_connection_label")
		if entry.get("kind", "") not in ["power_device", "machine"] and not supports_greenhouse_power:
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best_distance = distance
			closest = entry
	return closest


func _toggle_nearby_network() -> void:
	if not is_instance_valid(nearby_machine):
		return
	var enabled := bool(nearby_machine.call("is_network_enabled"))
	nearby_machine.call("set_network_enabled", not enabled)
	PowerGrid.rebuild_network()
	_update_nearby_machine_ui()


func _nearby_has_stock() -> bool:
	return is_instance_valid(nearby_machine) and nearby_machine.has_method("get_stock_items") and not Array(nearby_machine.call("get_stock_items")).is_empty()


func _nearby_machine_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.085, 0.96)
	style.border_color = Color("4ea8c7")
	style.set_border_width_all(3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _create_machine_info_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	get_tree().current_scene.add_child(layer)
	machine_info_root = Control.new()
	machine_info_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	machine_info_root.visible = false
	layer.add_child(machine_info_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.018, 0.025, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	machine_info_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_top = -230.0
	panel.offset_right = 330.0
	panel.offset_bottom = 230.0
	panel.add_theme_stylebox_override("panel", _machine_panel_style())
	machine_info_root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	var header := Label.new()
	header.text = "// SCHEDA SCIENTIFICA E TECNICA //"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color("7ed7ff"))
	content.add_child(header)
	machine_title = Label.new()
	machine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_title.add_theme_font_size_override("font_size", 20)
	machine_title.add_theme_color_override("font_color", Color("ffe38a"))
	content.add_child(machine_title)
	machine_category = Label.new()
	machine_category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_category.add_theme_font_size_override("font_size", 12)
	machine_category.add_theme_color_override("font_color", Color("9fb7c2"))
	content.add_child(machine_category)
	machine_status = Label.new()
	machine_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_status.add_theme_font_size_override("font_size", 16)
	content.add_child(machine_status)

	var divider := HSeparator.new()
	content.add_child(divider)
	var technical_title := Label.new()
	technical_title.text = "DATI OPERATIVI"
	technical_title.add_theme_font_size_override("font_size", 13)
	technical_title.add_theme_color_override("font_color", Color("72eda0"))
	content.add_child(technical_title)
	machine_specs = Label.new()
	machine_specs.custom_minimum_size = Vector2(610, 112)
	machine_specs.add_theme_font_size_override("font_size", 12)
	machine_specs.add_theme_color_override("font_color", Color("dce8e8"))
	content.add_child(machine_specs)
	var science_title := Label.new()
	science_title.text = "PRINCIPIO SCIENTIFICO"
	science_title.add_theme_font_size_override("font_size", 13)
	science_title.add_theme_color_override("font_color", Color("7ed7ff"))
	content.add_child(science_title)
	machine_principle = Label.new()
	machine_principle.custom_minimum_size = Vector2(610, 70)
	machine_principle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	machine_principle.add_theme_font_size_override("font_size", 12)
	machine_principle.add_theme_color_override("font_color", Color("c5d2d4"))
	content.add_child(machine_principle)
	machine_power_button = _make_demolition_button("[ CONNETTI ALLA RETE ]", Color("315d4c"))
	machine_power_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	machine_power_button.visible = false
	machine_power_button.pressed.connect(_toggle_inspected_network)
	content.add_child(machine_power_button)
	var close_button := _make_demolition_button("[ CHIUDI · ESC ]", Color("304c58"))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_machine_info)
	content.add_child(close_button)


func _show_machine_info(entry: Dictionary) -> void:
	inspected_machine = entry.get("node") as Node
	if not is_instance_valid(inspected_machine) or not inspected_machine.has_method("get_machine_specs"):
		return
	machine_info_root.visible = true
	BuildableRegistry.is_modal_open = true
	_refresh_machine_info()


func _refresh_machine_info() -> void:
	if not is_instance_valid(inspected_machine):
		_close_machine_info()
		return
	var data: Dictionary = inspected_machine.call("get_machine_specs")
	machine_title.text = str(data.get("title", "MACCHINARIO"))
	machine_category.text = str(data.get("category", "SISTEMA"))
	machine_status.text = str(data.get("status", ""))
	machine_status.add_theme_color_override("font_color", data.get("status_color", Color.WHITE))
	var rendered_specs := PackedStringArray()
	for specification in data.get("specs", []):
		rendered_specs.append("▪  " + str(specification))
	machine_specs.text = "\n".join(rendered_specs)
	machine_principle.text = str(data.get("principle", ""))
	var can_toggle_network := inspected_machine.has_method("set_network_enabled") and inspected_machine.has_method("is_network_enabled")
	machine_power_button.visible = can_toggle_network
	if can_toggle_network:
		var enabled := bool(inspected_machine.call("is_network_enabled"))
		machine_power_button.text = "[ DISCONNETTI ELETTRICITÀ ]" if enabled else "[ CONNETTI ELETTRICITÀ ]"


func _toggle_inspected_network() -> void:
	if not is_instance_valid(inspected_machine) or not inspected_machine.has_method("set_network_enabled"):
		return
	var enabled := bool(inspected_machine.call("is_network_enabled"))
	inspected_machine.call("set_network_enabled", not enabled)
	PowerGrid.rebuild_network()
	_refresh_machine_info()


func _close_machine_info() -> void:
	inspected_machine = null
	BuildableRegistry.is_modal_open = false
	if machine_info_root != null:
		machine_info_root.visible = false


func _machine_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1921")
	style.border_color = Color("4ea8c7")
	style.set_border_width_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _demolition_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b22")
	style.border_color = Color("e6a74d")
	style.set_border_width_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _make_demolition_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 32)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.16)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.18)))
	return button


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("d5e0de")
	style.set_border_width_all(2)
	return style
