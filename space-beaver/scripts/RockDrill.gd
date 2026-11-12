class_name RockDrill
extends Node2D

## Trivella mineraria autonoma. A differenza della trivella del ghiaccio non
## produce un fluido: estrae campioni fisici e li conserva fino a quando il
## giocatore decide quali portare nello zaino e quali scartare.

const POWER_DEVICE_SCRIPT := preload("res://scripts/PowerDevice.gd")
const ROCK_RESOURCE := preload("res://scripts/rock.gd")
const DRILL_SHEET := preload("res://assets/rock_drill/rock_drill_spritesheet.png")

const TILE_SIZE := 16
const FRAME_SIZE := Vector2i(16, 48)
const FRAME_COUNT := 8
const POWER_DEMAND_KW := 85.0
const EXTRACTION_INTERVAL_SECONDS := 12.0
const STORAGE_CAPACITY := 32
const INTERACTION_DISTANCE := 74.0

const BIOME_LABELS := {
	0: "PIANURA DI ATTERRAGGIO",
	1: "REGOLITE SCURA",
	2: "CRATERE ROCCIOSO",
	3: "BORDO DELLA CALOTTA",
	4: "GHIACCIO POLARE",
	5: "ALTOPIANO BASALTICO",
}

var device_id := "rock_drill"
var origin_cell := Vector2i.ZERO
var is_preview := false
var placement_rotation := 0
var network_enabled := false
var powered := false
var biome_source_id := 0
var biome_label := "PIANURA DI ATTERRAGGIO"
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


func _exit_tree() -> void:
	if storage_layer != null and is_instance_valid(storage_layer):
		storage_layer.queue_free()
	if storage_root != null and storage_root.visible:
		BuildableRegistry.is_modal_open = false


func _process(delta: float) -> void:
	if is_preview:
		return
	_update_status_light()
	if not powered:
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
	var frame := AtlasTexture.new()
	frame.atlas = DRILL_SHEET
	frame.region = Rect2(Vector2i(posmod(animation_frame, FRAME_COUNT), 0) * FRAME_SIZE, FRAME_SIZE)
	sprite.texture = frame


func _setup_collision() -> void:
	physics_body = StaticBody2D.new()
	physics_body.name = "RockDrillCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# La colonna di perforazione può essere attraversata visivamente in alto;
	# la base è la parte che blocca effettivamente il cammino.
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
		"name": str(definition.get("name", "Campione")),
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
	## Compatibilità con il pannello rapido: E vicino alla trivella può ritirare
	## un campione; l'inventario dedicato consente invece di scegliere pile intere.
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
		storage_feedback.text = "%d campioni trasferiti nello zaino." % moved
	else:
		storage_feedback.text = "Zaino pieno: libera uno slot per trasferire il campione."
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
		storage_feedback.text = "Trasferiti %d campioni nello zaino." % moved
	_refresh_storage_ui()
	return moved


func discard_stock_stack(index: int) -> int:
	if index < 0 or index >= sample_stock.size():
		return 0
	var discarded := int(sample_stock[index].get("count", 0))
	sample_stock.remove_at(index)
	storage_feedback.text = "Scartati %d campioni dalla riserva." % discarded
	_refresh_storage_ui()
	return discarded


func discard_all_stock() -> int:
	var discarded := get_stock_count()
	sample_stock.clear()
	storage_feedback.text = "Riserva svuotata: %d campioni scartati." % discarded
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
	storage_root.visible = true
	BuildableRegistry.is_modal_open = true
	_refresh_storage_ui()
	return true


func close_storage() -> void:
	if storage_root != null:
		storage_root.visible = false
	BuildableRegistry.is_modal_open = false


func is_storage_open() -> bool:
	return storage_root != null and storage_root.visible


func set_powered(value: bool) -> void:
	powered = value and network_enabled
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
	return "TRIVELLA MINERARIA"


func get_connection_label() -> String:
	if not network_enabled:
		return "DISCONNESSA"
	return "COLLEGATO ALLA RETE" if bool(PowerGrid.connection_ok.get(self, false)) else "CAVO ELETTRICO NON COLLEGATO"


func get_interaction_summary() -> String:
	var state := "ESTRAZIONE ATTIVA" if powered else ("RISERVA PIENA" if get_stock_count() >= STORAGE_CAPACITY else "IN ATTESA DI POTENZA")
	return "%s · %s · %d/%d campioni" % [biome_label, state, get_stock_count(), STORAGE_CAPACITY]


func get_inventory_output_label() -> String:
	return "RISERVA CAMPIONI  ·  %d / %d" % [get_stock_count(), STORAGE_CAPACITY]


func get_machine_specs() -> Dictionary:
	var rare_count := 0
	for stock in sample_stock:
		if str(stock.get("rarity", "")) in ["rare", "ultra_rare"]:
			rare_count += int(stock.get("count", 0))
	var deep_ice_percent := ROCK_RESOURCE.deep_ice_probability_for_biome(biome_source_id) * 100.0
	return {
		"title": "TRIVELLA MINERARIA",
		"category": "PROSPEZIONE GEOLOGICA IN SITU",
		"status": "ESTRAZIONE ATTIVA" if powered else ("RISERVA PIENA" if get_stock_count() >= STORAGE_CAPACITY else get_connection_label()),
		"status_color": Color("72eda0") if powered and get_stock_count() < STORAGE_CAPACITY else Color("ffb45d"),
		"principle": "Una testa rotativa preleva carote dal regolite locale, le vaglia per composizione e conserva i campioni fisici. Il bioma di posa decide quali minerali può trovare.",
		"specs": ["Bioma di posa: %s" % biome_label, "Assorbimento: %.0f kW" % POWER_DEMAND_KW, "Cadenza: 1 campione ogni %.0f s" % EXTRACTION_INTERVAL_SECONDS, "Riserva: %d / %d campioni" % [get_stock_count(), STORAGE_CAPACITY], "Campioni rari in riserva: %d" % rare_count, "Raro locale: 5%% · ghiaccio profondo primordiale: %.0f%%" % deep_ice_percent, "Totale estratto: %d" % total_samples_extracted, "E: apri riserva · V: rete"],
	}


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
	title.text = "// RISERVA TRIVELLA MINERARIA //"
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
	hint.text = "Clicca PRENDI per trasferire soltanto quella pila nello zaino. I campioni restano qui finché non li scegli o li scarti."
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
	take_all.text = "[ PRENDI TUTTO ]"
	take_all.custom_minimum_size = Vector2(170, 38)
	take_all.pressed.connect(transfer_all_stock)
	actions.add_child(take_all)
	var discard_all := Button.new()
	discard_all.text = "[ SCARTA RISERVA ]"
	discard_all.custom_minimum_size = Vector2(190, 38)
	discard_all.pressed.connect(discard_all_stock)
	discard_all.add_theme_color_override("font_color", Color("ff8b78"))
	actions.add_child(discard_all)
	var close := Button.new()
	close.text = "[ CHIUDI · E / ESC ]"
	close.custom_minimum_size = Vector2(180, 38)
	close.pressed.connect(close_storage)
	actions.add_child(close)


func _refresh_storage_ui() -> void:
	if storage_root == null or storage_rows == null:
		return
	storage_summary.text = "%s · alimentazione %s · riserva %d/%d · ghiaccio primordiale %.0f%%" % [biome_label, "ATTIVA" if powered else "NON ATTIVA", get_stock_count(), STORAGE_CAPACITY, ROCK_RESOURCE.deep_ice_probability_for_biome(biome_source_id) * 100.0]
	for child in storage_rows.get_children():
		child.queue_free()
	if sample_stock.is_empty():
		var empty := Label.new()
		empty.text = "La riserva è vuota. Collega la trivella alla rete e attendi la prima carota geologica."
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
		var rarity := "ULTRA RARO · GHIACCIO PRIMORDIALE" if stock_rarity == "ultra_rare" else ("RARO · 5%" if stock_rarity == "rare" else "COMUNE")
		info.text = "%s x%d\n%s · %s · valore ricerca ×%.2f" % [str(stock.get("name", "Campione")).to_upper(), int(stock.get("count", 0)), str(stock.get("biome", biome_label)), rarity, float(stock.get("research_multiplier", 1.0))]
		info.add_theme_font_size_override("font_size", 11)
		info.add_theme_color_override("font_color", Color("a8fff0") if rarity.begins_with("ULTRA") else (Color("ffe18b") if rarity.begins_with("RARO") else Color("d3e3e6")))
		content.add_child(info)
		var take := Button.new()
		take.text = "PRENDI\nPILA"
		take.custom_minimum_size = Vector2(106, 45)
		take.pressed.connect(transfer_stock_stack.bind(index))
		content.add_child(take)
		var discard := Button.new()
		discard.text = "SCARTA\nPILA"
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
