class_name RockDrill
extends Node2D

## Autonomous mineral drill. Unlike the ice drill, it does not produce a fluid:
## it extracts physical samples and stores them until the player decides which
## ones to carry in the backpack and which ones to discard.

const POWER_DEVICE_SCRIPT := preload("res://scripts/PowerDevice.gd")
const ROCK_RESOURCE := preload("res://scripts/rock.gd")
const DRILL_SHEET := preload("res://assets/sprites/machines/rock_drill/rock_drill_spritesheet.png")

const TILE_SIZE := 16
# The 128 px-wide sprite sheet contains four complete poses side by side.
# Cropping it at 16 px split every drill in half and alternated the halves as
# if they were distinct animation frames.
const FRAME_SIZE := Vector2i(32, 48)
const FRAME_COUNT := 4
const POWER_DEMAND_KW := 85.0
const EXTRACTION_INTERVAL_SECONDS := 12.0
const STORAGE_CAPACITY := 32
const INTERACTION_DISTANCE := 74.0

const BIOME_LABELS := {
	0: "LANDING PLAIN",
	1: "DARK REGOLITH",
	2: "ROCKY CRATER",
	3: "ICE-CAP EDGE",
	4: "POLAR ICE",
	5: "BASALTIC PLATEAU",
}

var device_id := "rock_drill"
var origin_cell := Vector2i.ZERO
var is_preview := false
var placement_rotation := 0
var network_enabled := false
var powered := false
var incident_faulted := false
var sand_accumulation := 0
var biome_source_id := 0
var biome_label := "LANDING PLAIN"
var extraction_elapsed := 0.0
var animation_elapsed := 0.0
var animation_frame := 0
var total_samples_extracted := 0
var sample_stock: Array[Dictionary] = []

var sprite: Sprite2D
var physics_body: StaticBody2D
var status_light: Polygon2D
var storage_layer: CanvasLayer
var storage_root: Control
var storage_rows: VBoxContainer
var storage_summary: Label
var storage_feedback: Label
var _rng := RandomNumberGenerator.new()


func setup(cell: Vector2i, preview: bool = false, new_placement_rotation: int = 0) -> void:
	origin_cell = cell
	is_preview = preview
	placement_rotation = posmod(new_placement_rotation, 4)
	_rng.seed = int(cell.x) * 73856093 ^ int(cell.y) * 19349663 ^ 0x51F15E
	if is_node_ready():
		_apply_placement_rotation()
		_refresh_texture()


func _ready() -> void:
	z_index = 2
	_setup_sprite()
	_apply_placement_rotation()
	_refresh_texture()
	if is_preview:
		return
	add_to_group("rock_drills")
	_resolve_biome()
	if biome_source_id == 4:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null and achievements.has_method("record_polar_drill"):
			achievements.call("record_polar_drill")
	_setup_collision()
	_setup_status_light()
	_build_storage_ui()
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("register_target", self, "machine", "MINERAL DRILL")
	var sandstorms := get_node_or_null("/root/SandstormManager")
	if sandstorms != null:
		sandstorms.call("register_target", self, "MINERAL DRILL")


func _exit_tree() -> void:
	if not is_preview:
		var incidents := get_node_or_null("/root/IncidentManager")
		if incidents != null:
			incidents.call("unregister_target", self, "machine")
		var sandstorms := get_node_or_null("/root/SandstormManager")
		if sandstorms != null:
			sandstorms.call("unregister_target", self)
	if storage_layer != null and is_instance_valid(storage_layer):
		storage_layer.queue_free()
	if storage_root != null and storage_root.visible:
		BuildableRegistry.close_modal()


func _process(delta: float) -> void:
	if is_preview:
		return
	_update_status_light()
	if incident_faulted or not powered:
		return
	animation_elapsed += delta
	if animation_elapsed >= 0.10:
		animation_elapsed = 0.0
		animation_frame = (animation_frame + 1) % FRAME_COUNT
		_refresh_texture()
	if get_stock_count() >= STORAGE_CAPACITY:
		return
	extraction_elapsed += delta
	while extraction_elapsed >= EXTRACTION_INTERVAL_SECONDS and get_stock_count() < STORAGE_CAPACITY:
		extraction_elapsed -= EXTRACTION_INTERVAL_SECONDS
		_extract_sample()


func _input(event: InputEvent) -> void:
	if storage_root == null or not storage_root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_E):
		close_storage()
		get_viewport().set_input_as_handled()


func _setup_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.name = "RockDrillSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func _apply_placement_rotation() -> void:
	rotation = float(placement_rotation) * PI * 0.5


func _refresh_texture() -> void:
	if sprite == null:
		return
	sprite.modulate = Color.WHITE if sand_accumulation <= 0 else Color(1.0, 0.78 - float(sand_accumulation) * 0.10, 0.58 - float(sand_accumulation) * 0.10)
	var frame := AtlasTexture.new()
	frame.atlas = DRILL_SHEET
	frame.region = Rect2(Vector2i(posmod(animation_frame, FRAME_COUNT), 0) * FRAME_SIZE, FRAME_SIZE)
	sprite.texture = frame


func _setup_collision() -> void:
	physics_body = StaticBody2D.new()
	physics_body.name = "RockDrillCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# The drilling column is visually passable at the top; the base is the part
	# that actually blocks movement.
	shape.size = Vector2(27.0, 15.0)
	collision.position = Vector2(0.0, 15.0)
	collision.shape = shape
	physics_body.add_child(collision)
	add_child(physics_body)


func _setup_status_light() -> void:
	status_light = Polygon2D.new()
	status_light.name = "MiningStatusLight"
	status_light.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
	status_light.position = Vector2(0.0, -18.0)
	status_light.z_index = 4
	add_child(status_light)
	_update_status_light()


func _update_status_light() -> void:
	if status_light == null:
		return
	status_light.visible = powered
	status_light.color = Color("72eda0") if get_stock_count() < STORAGE_CAPACITY else Color("ffb45d")


func _resolve_biome() -> void:
	var map_provider := get_tree().get_first_node_in_group("world_map_provider")
	if map_provider != null and map_provider.has_method("get_source_id"):
		biome_source_id = maxi(0, int(map_provider.call("get_source_id", origin_cell)))
	biome_label = str(BIOME_LABELS.get(biome_source_id, BIOME_LABELS[0]))


func _extract_sample() -> void:
	var variant := str(ROCK_RESOURCE.drill_variant_for_biome(biome_source_id, _rng.randf(), _rng.randf()))
	var definition: Dictionary = ROCK_RESOURCE.definition_for(variant)
	if bool(definition.get("deep_ice", false)):
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null and achievements.has_method("record_primordial_ice_found"):
			achievements.call("record_primordial_ice_found")
	for stock in sample_stock:
		if str(stock.get("variant", "")) == variant:
			stock["count"] = int(stock.get("count", 0)) + 1
			total_samples_extracted += 1
			_refresh_storage_ui()
			return
	sample_stock.append({
		"variant": variant,
		"id": str(definition.get("item_id", "")),
		"name": str(definition.get("name", "Sample")),
		"biome": str(definition.get("biome", biome_label)),
		"rarity": str(definition.get("rarity", "common")),
		"research_multiplier": float(definition.get("research_multiplier", 1.0)),
		"count": 1,
	})
	total_samples_extracted += 1
	_refresh_storage_ui()


func get_stock_count() -> int:
	var total := 0
	for stock in sample_stock:
		total += int(stock.get("count", 0))
	return total


func get_stock_items() -> Array[Dictionary]:
	return sample_stock.duplicate(true)


func take_stock_item(index: int = 0) -> bool:
	## Compatibility with the quick panel: E near the drill can retrieve one
	## sample, while the dedicated inventory lets the player choose whole stacks.
	if index < 0 or index >= sample_stock.size():
		return false
	var stock: Dictionary = sample_stock[index]
	if int(stock.get("count", 0)) <= 0 or not Inventory.add_rock(str(stock.get("variant", ""))):
		return false
	_consume_stock_unit(index)
	_refresh_storage_ui()
	return true


func transfer_stock_stack(index: int) -> int:
	if index < 0 or index >= sample_stock.size():
		return 0
	var moved := 0
	var variant := str(sample_stock[index].get("variant", ""))
	while index < sample_stock.size() and int(sample_stock[index].get("count", 0)) > 0:
		if not Inventory.add_rock(variant):
			break
		_consume_stock_unit(index)
		moved += 1
	if moved > 0:
		storage_feedback.text = "%d samples moved to the backpack." % moved
	else:
		storage_feedback.text = "Backpack full: free one slot to move the sample."
	_refresh_storage_ui()
	return moved


func transfer_all_stock() -> int:
	var moved := 0
	var index := 0
	while index < sample_stock.size():
		moved += transfer_stock_stack(index)
		if index < sample_stock.size() and int(sample_stock[index].get("count", 0)) > 0:
			index += 1
	if moved > 0:
		storage_feedback.text = "Moved %d samples to the backpack." % moved
	_refresh_storage_ui()
	return moved


func discard_stock_stack(index: int) -> int:
	if index < 0 or index >= sample_stock.size():
		return 0
	var discarded := int(sample_stock[index].get("count", 0))
	sample_stock.remove_at(index)
	storage_feedback.text = "Discarded %d samples from storage." % discarded
	_refresh_storage_ui()
	return discarded


func discard_all_stock() -> int:
	var discarded := get_stock_count()
	sample_stock.clear()
	storage_feedback.text = "Storage emptied: %d samples discarded." % discarded
	_refresh_storage_ui()
	return discarded


func _consume_stock_unit(index: int) -> void:
	if index < 0 or index >= sample_stock.size():
		return
	sample_stock[index]["count"] = int(sample_stock[index].get("count", 0)) - 1
	if int(sample_stock[index].get("count", 0)) <= 0:
		sample_stock.remove_at(index)


func open_storage(player: Node2D) -> bool:
	if is_preview or player == null or player.global_position.distance_to(global_position) > INTERACTION_DISTANCE:
		return false
	if storage_root == null:
		return false
	if not BuildableRegistry.open_modal():
		return false
	storage_root.visible = true
	_refresh_storage_ui()
	return true


func close_storage() -> void:
	if storage_root != null:
		storage_root.visible = false
	BuildableRegistry.close_modal()


func is_storage_open() -> bool:
	return storage_root != null and storage_root.visible


func set_powered(value: bool) -> void:
	powered = value and network_enabled and not incident_faulted
	if not powered:
		animation_frame = 0
		animation_elapsed = 0.0
		_refresh_texture()
	_update_status_light()


func set_network_enabled(value: bool) -> void:
	if is_preview or network_enabled == value:
		return
	network_enabled = value
	if not network_enabled:
		set_powered(false)
	PowerGrid.request_rebuild()


func is_network_enabled() -> bool:
	return network_enabled


func get_power_connection_cell() -> Vector2i:
	return POWER_DEVICE_SCRIPT.rotated_cell_for(device_id, origin_cell, origin_cell + Vector2i.LEFT, placement_rotation)


func get_power_attach_direction() -> Vector2i:
	return POWER_DEVICE_SCRIPT.rotate_direction(Vector2i.RIGHT, placement_rotation)


func get_power_demand_kw() -> float:
	return POWER_DEMAND_KW


func get_occupied_power_cells() -> Array[Vector2i]:
	return POWER_DEVICE_SCRIPT.footprint_cells_for(device_id, origin_cell, placement_rotation)


func contains_world_point(world_point: Vector2) -> bool:
	var point_cell := Vector2i(floori(world_point.x / TILE_SIZE), floori(world_point.y / TILE_SIZE))
	return point_cell in get_occupied_power_cells()


func get_display_name() -> String:
	return "MINERAL DRILL"


func get_connection_label() -> String:
	if incident_faulted:
		return "FAULT — approach and repair"
	if not network_enabled:
		return "DISCONNECTED"
	return "CONNECTED TO GRID" if bool(PowerGrid.connection_ok.get(self, false)) else "POWER CABLE NOT CONNECTED"


func get_interaction_summary() -> String:
	var state := "FAULT" if incident_faulted else ("EXTRACTION ACTIVE" if powered else ("STORAGE FULL" if get_stock_count() >= STORAGE_CAPACITY else "AWAITING POWER"))
	return "%s · %s · %d/%d samples" % [biome_label, state, get_stock_count(), STORAGE_CAPACITY]


func get_inventory_output_label() -> String:
	return "SAMPLE STORAGE  ·  %d / %d" % [get_stock_count(), STORAGE_CAPACITY]


func get_machine_specs() -> Dictionary:
	var rare_count := 0
	for stock in sample_stock:
		if str(stock.get("rarity", "")) in ["rare", "ultra_rare"]:
			rare_count += int(stock.get("count", 0))
	var deep_ice_percent := ROCK_RESOURCE.deep_ice_probability_for_biome(biome_source_id) * 100.0
	return {
		"title": "MINERAL DRILL",
		"category": "IN-SITU GEOLOGICAL PROSPECTING",
		"status": "FAULT — REPAIR REQUIRED" if incident_faulted else ("EXTRACTION ACTIVE" if powered else ("STORAGE FULL" if get_stock_count() >= STORAGE_CAPACITY else get_connection_label())),
		"status_color": Color("ff6258") if incident_faulted else (Color("72eda0") if powered and get_stock_count() < STORAGE_CAPACITY else Color("ffb45d")),
		"principle": "A rotary head takes cores from the local regolith, sorts them by composition, and stores physical samples. The placement biome determines which minerals it can find.",
		"specs": ["Placement biome: %s" % biome_label, "Power demand: %.0f kW" % POWER_DEMAND_KW, "Rate: 1 sample every %.0f s" % EXTRACTION_INTERVAL_SECONDS, "Storage: %d / %d samples" % [get_stock_count(), STORAGE_CAPACITY], "Rare samples in storage: %d" % rare_count, "Local rare: 5%% · primordial deep ice: %.0f%%" % deep_ice_percent, "Total extracted: %d" % total_samples_extracted, "E: open storage · V: grid"],
	}


func set_incident_faulted(_target_id: String, value: bool) -> void:
	if incident_faulted == value:
		return
	incident_faulted = value
	if incident_faulted:
		set_powered(false)
	PowerGrid.request_rebuild()


func is_incident_faulted(_target_id: String = "machine") -> bool:
	return incident_faulted


func is_incident_operational() -> bool:
	return not incident_faulted


func can_receive_incident(_target_id: String = "machine") -> bool:
	return not is_preview and not incident_faulted


func get_incident_repair_position(_target_id: String = "machine") -> Vector2:
	return global_position


func get_sand_accumulation() -> int:
	return sand_accumulation


func set_sand_accumulation(level: int) -> void:
	var clamped := clampi(level, 0, 3)
	if sand_accumulation == clamped:
		return
	sand_accumulation = clamped
	_refresh_texture()


func get_sand_clean_position() -> Vector2:
	return global_position


func on_sand_buried() -> void:
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("force_incident", self, "machine")


func _build_storage_ui() -> void:
	storage_layer = CanvasLayer.new()
	storage_layer.name = "RockDrillStorageLayer"
	storage_layer.layer = 130
	get_tree().current_scene.add_child(storage_layer)
	storage_root = Control.new()
	storage_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storage_root.mouse_filter = Control.MOUSE_FILTER_STOP
	storage_root.visible = false
	storage_layer.add_child(storage_root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.03, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	storage_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -405
	panel.offset_right = 405
	panel.offset_top = -270
	panel.offset_bottom = 270
	panel.add_theme_stylebox_override("panel", _storage_panel_style())
	storage_root.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 9)
	panel.add_child(contents)
	var title := Label.new()
	title.text = "// MINERAL DRILL STORAGE //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ffd979"))
	contents.add_child(title)
	storage_summary = Label.new()
	storage_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storage_summary.add_theme_font_size_override("font_size", 12)
	storage_summary.add_theme_color_override("font_color", Color("b9d9e2"))
	contents.add_child(storage_summary)
	var hint := Label.new()
	hint.text = "Click TAKE to move only that stack to the backpack. Samples remain here until you choose or discard them."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("91b7c4"))
	contents.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 290)
	contents.add_child(scroll)
	storage_rows = VBoxContainer.new()
	storage_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(storage_rows)
	storage_feedback = Label.new()
	storage_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_feedback.add_theme_font_size_override("font_size", 11)
	storage_feedback.add_theme_color_override("font_color", Color("83e9ad"))
	contents.add_child(storage_feedback)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	contents.add_child(actions)
	var take_all := Button.new()
	take_all.text = "[ TAKE ALL ]"
	take_all.custom_minimum_size = Vector2(170, 38)
	take_all.pressed.connect(transfer_all_stock)
	actions.add_child(take_all)
	var discard_all := Button.new()
	discard_all.text = "[ DISCARD STORAGE ]"
	discard_all.custom_minimum_size = Vector2(190, 38)
	discard_all.pressed.connect(discard_all_stock)
	discard_all.add_theme_color_override("font_color", Color("ff8b78"))
	actions.add_child(discard_all)
	var close := Button.new()
	close.text = "[ CLOSE · E / ESC ]"
	close.custom_minimum_size = Vector2(180, 38)
	close.pressed.connect(close_storage)
	actions.add_child(close)


func _refresh_storage_ui() -> void:
	if storage_root == null or storage_rows == null:
		return
	storage_summary.text = "%s · power %s · storage %d/%d · deep ice (model) %.0f%%" % [biome_label, "ACTIVE" if powered else "INACTIVE", get_stock_count(), STORAGE_CAPACITY, ROCK_RESOURCE.deep_ice_probability_for_biome(biome_source_id) * 100.0]
	for child in storage_rows.get_children():
		child.queue_free()
	if sample_stock.is_empty():
		var empty := Label.new()
		empty.text = "Storage is empty. Connect the drill to the grid and wait for the first geological sample."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(730, 100)
		empty.add_theme_color_override("font_color", Color("8197a0"))
		storage_rows.add_child(empty)
		return
	for index in sample_stock.size():
		var stock: Dictionary = sample_stock[index]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _stock_row_style(str(stock.get("rarity", "common")) in ["rare", "ultra_rare"]))
		storage_rows.add_child(row)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		row.add_child(content)
		var info := Label.new()
		info.custom_minimum_size = Vector2(455, 46)
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stock_rarity := str(stock.get("rarity", "common"))
		var rarity := "ULTRA RARE · DEEP ICE" if stock_rarity == "ultra_rare" else ("RARE · 5%" if stock_rarity == "rare" else "COMMON")
		info.text = "%s x%d\n%s · %s · research value ×%.2f" % [str(stock.get("name", "Sample")).to_upper(), int(stock.get("count", 0)), str(stock.get("biome", biome_label)), rarity, float(stock.get("research_multiplier", 1.0))]
		info.add_theme_font_size_override("font_size", 11)
		info.add_theme_color_override("font_color", Color("a8fff0") if rarity.begins_with("ULTRA") else (Color("ffe18b") if rarity.begins_with("RARE") else Color("d3e3e6")))
		content.add_child(info)
		var take := Button.new()
		take.text = "TAKE\nSTACK"
		take.custom_minimum_size = Vector2(106, 45)
		take.pressed.connect(transfer_stock_stack.bind(index))
		content.add_child(take)
		var discard := Button.new()
		discard.text = "DISCARD\nSTACK"
		discard.custom_minimum_size = Vector2(106, 45)
		discard.add_theme_color_override("font_color", Color("ff9d89"))
		discard.pressed.connect(discard_stock_stack.bind(index))
		content.add_child(discard)


func _storage_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1720fa")
	style.border_color = Color("d9a353")
	style.set_border_width_all(3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _stock_row_style(is_rare: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c26153d") if is_rare else Color("12242cbb")
	style.border_color = Color("f0ca64") if is_rare else Color("416e7c")
	style.set_border_width_all(1)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
