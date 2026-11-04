extends CanvasLayer

const ROCK_ICON := preload("res://sprites/rock.png")
const ROCK_ICONS: Dictionary = {
	"rock_roccia_rossa": preload("res://sprites/rocks/roccia_rossa.png"),
	"rock_pietra_rossastra": preload("res://sprites/rocks/pietra_rossastra.png"),
	"rock_ghiaccio_leggero": preload("res://sprites/rocks/ghiaccio_leggero.png"),
	"rock_ghiaccio_blu": preload("res://sprites/rocks/ghiaccio_blu.png"),
	"rock_roccia_grigia": preload("res://sprites/rocks/roccia_grigia.png"),
	"rock_roccia_scura": preload("res://sprites/rocks/roccia_scura.png"),
	"rock_roccia_basaltica": preload("res://sprites/rocks/roccia_basaltica.png"),
	"rock_basalto": preload("res://sprites/rocks/basalto.png"),
	"rock_roccia_ghiacciata": preload("res://sprites/rocks/roccia_ghiacciata.png"),
	"rock_ghiaccio_profondo": preload("res://sprites/rocks/ghiaccio_profondo.png"),
}
const WATER_ICON := preload("res://sprites/water-bottle.jpg")
const RATION_ICON := preload("res://sprites/food-ration.jpg")
const HAMMER_ICON := preload("res://sprites/pipe-hammer.png")
const SOLAR_ICON := preload("res://sprites/machines/solar-panel-spritesheet.png")
const TRANSFORMER_SHEET := preload("res://sprites/machines/transformer-spritesheet.png")
const BATTERY_SHEET := preload("res://sprites/machines/battery-spritesheet.png")
const ICE_DRILL_SHEET := preload("res://sprites/machines/ice-drill-spritesheet.png")
const PLAYER_SHEET := preload("res://sprites/player-spritesheet.png")
const ROVER_SHEET := preload("res://assets/rover/rover_idle.png")
const ROCK_MASK_CODE := "shader_type canvas_item;\nvoid fragment() {\n    vec4 pixel = texture(TEXTURE, UV);\n    if (pixel.r > 0.90 && pixel.g > 0.90 && pixel.b > 0.90) {\n        pixel.a = 0.0;\n    }\n    COLOR = pixel;\n}\n"

var hotbar_buttons: Array[Button] = []
var hotbar_icons: Array[TextureRect] = []
var hotbar_number_labels: Array[Label] = []
var hotbar_name_labels: Array[Label] = []
var hotbar_amount_labels: Array[Label] = []
var backpack_buttons: Array[Button] = []
var backpack_icons: Array[TextureRect] = []
var backpack_name_labels: Array[Label] = []
var overlay: ColorRect
var detail_label: Label
var equip_button: Button
var suit_slot_icon: TextureRect
var suit_slot_name: Label
var suit_stats_label: Label
var suit_previous_button: Button
var suit_next_button: Button
var viewed_suit_id := ""
var suit_system: Node
var pickup_label: Label
var icon_mask_material: ShaderMaterial


func _ready() -> void:
	layer = 70
	suit_system = get_node("/root/SuitSystem")
	_build_ui()
	Inventory.changed.connect(_refresh)
	suit_system.equipped_changed.connect(_on_suit_equipped)
	suit_system.owned_suits_changed.connect(_on_owned_suits_changed)
	viewed_suit_id = str(suit_system.equipped_suit_id)
	_refresh()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	pickup_label = Label.new()
	pickup_label.anchor_left = 0.5
	pickup_label.anchor_right = 0.5
	pickup_label.anchor_top = 1.0
	pickup_label.anchor_bottom = 1.0
	pickup_label.offset_left = -205
	pickup_label.offset_right = 205
	pickup_label.offset_top = -118
	pickup_label.offset_bottom = -86
	pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pickup_label.add_theme_font_size_override("font_size", 12)
	pickup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pickup_label)

	var hotbar_row := HBoxContainer.new()
	hotbar_row.anchor_left = 0.5
	hotbar_row.anchor_right = 0.5
	hotbar_row.anchor_top = 1.0
	hotbar_row.anchor_bottom = 1.0
	hotbar_row.offset_left = -178
	hotbar_row.offset_right = 178
	hotbar_row.offset_top = -82
	hotbar_row.offset_bottom = -6
	hotbar_row.add_theme_constant_override("separation", 4)
	root.add_child(hotbar_row)
	var icon_shader := Shader.new()
	icon_shader.code = ROCK_MASK_CODE
	icon_mask_material = ShaderMaterial.new()
	icon_mask_material.shader = icon_shader
	for index in Inventory.HOTBAR_SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(68, 76)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.pressed.connect(_on_hotbar_pressed.bind(index))
		hotbar_row.add_child(button)
		hotbar_buttons.append(button)
		var number_label := Label.new()
		number_label.position = Vector2(5, 2)
		number_label.size = Vector2(18, 16)
		number_label.text = str(index + 1)
		number_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
		number_label.add_theme_font_size_override("font_size", 12)
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number_label)
		hotbar_number_labels.append(number_label)
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(20, 14)
		icon.size = Vector2(28, 31)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		hotbar_icons.append(icon)
		var amount_label := Label.new()
		amount_label.position = Vector2(35, 2)
		amount_label.size = Vector2(29, 16)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.add_theme_font_size_override("font_size", 10)
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(amount_label)
		hotbar_amount_labels.append(amount_label)
		var name_label := Label.new()
		name_label.position = Vector2(2, 51)
		name_label.size = Vector2(64, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		hotbar_name_labels.append(name_label)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.02, 0.03, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -290
	panel.offset_bottom = 290
	overlay.add_child(panel)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	panel.add_child(contents)
	var title := Label.new()
	title.text = "INVENTARIO  ·  TAB per chiudere"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(title)
	var equipment_panel := PanelContainer.new()
	equipment_panel.name = "SuitEquipmentPanel"
	equipment_panel.custom_minimum_size = Vector2(720, 92)
	equipment_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equipment_panel.add_theme_stylebox_override("panel", _slot_style(Color("111a22f2"), Color("6fc9e8")))
	contents.add_child(equipment_panel)
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 8)
	equipment_panel.add_child(equipment_row)
	var equipment_title := Label.new()
	equipment_title.text = "// SLOT TUTA //"
	equipment_title.custom_minimum_size = Vector2(112, 0)
	equipment_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_title.add_theme_color_override("font_color", Color("8edff2"))
	equipment_row.add_child(equipment_title)
	suit_previous_button = Button.new()
	suit_previous_button.text = "<"
	suit_previous_button.custom_minimum_size = Vector2(30, 64)
	suit_previous_button.pressed.connect(_cycle_suit.bind(-1))
	equipment_row.add_child(suit_previous_button)
	var suit_slot := Button.new()
	suit_slot.name = "SuitSlot"
	suit_slot.custom_minimum_size = Vector2(116, 64)
	suit_slot.pressed.connect(_cycle_suit.bind(1))
	equipment_row.add_child(suit_slot)
	suit_slot_icon = TextureRect.new()
	suit_slot_icon.position = Vector2(5, 4)
	suit_slot_icon.size = Vector2(42, 54)
	suit_slot_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	suit_slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	suit_slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	suit_slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suit_slot.add_child(suit_slot_icon)
	suit_slot_name = Label.new()
	suit_slot_name.position = Vector2(48, 5)
	suit_slot_name.size = Vector2(63, 54)
	suit_slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_slot_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	suit_slot_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	suit_slot_name.add_theme_font_size_override("font_size", 10)
	suit_slot_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suit_slot.add_child(suit_slot_name)
	suit_next_button = Button.new()
	suit_next_button.text = ">"
	suit_next_button.custom_minimum_size = Vector2(30, 64)
	suit_next_button.pressed.connect(_cycle_suit.bind(1))
	equipment_row.add_child(suit_next_button)
	suit_stats_label = Label.new()
	suit_stats_label.custom_minimum_size = Vector2(225, 64)
	suit_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	suit_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	suit_stats_label.add_theme_font_size_override("font_size", 10)
	equipment_row.add_child(suit_stats_label)
	equip_button = Button.new()
	equip_button.custom_minimum_size = Vector2(135, 40)
	equip_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip_button.pressed.connect(_equip_selected_suit)
	equipment_row.add_child(equip_button)
	var inventory_title := Label.new()
	inventory_title.text = "// ZAINO //"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_title.add_theme_color_override("font_color", Color("cbd8dc"))
	contents.add_child(inventory_title)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	contents.add_child(grid)
	var rock_shader := Shader.new()
	rock_shader.code = ROCK_MASK_CODE
	var rock_material := ShaderMaterial.new()
	rock_material.shader = rock_shader
	var slot_normal := _slot_style(Color(0.13, 0.13, 0.16, 0.96), Color(0.37, 0.37, 0.42))
	var slot_hover := _slot_style(Color(0.22, 0.22, 0.27, 0.98), Color(0.78, 0.66, 0.39))
	for index in Inventory.BACKPACK_SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 70)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_theme_stylebox_override("normal", slot_normal)
		button.add_theme_stylebox_override("hover", slot_hover)
		button.add_theme_stylebox_override("pressed", slot_hover)
		button.add_theme_stylebox_override("focus", slot_hover)
		button.pressed.connect(_on_backpack_pressed.bind(index))
		grid.add_child(button)
		backpack_buttons.append(button)
		var icon := TextureRect.new()
		icon.texture = ROCK_ICON
		icon.material = rock_material
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(8, 24)
		icon.scale = Vector2(2, 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		backpack_icons.append(icon)
		var slot_name := Label.new()
		slot_name.position = Vector2(4, 51)
		slot_name.size = Vector2(88, 15)
		slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_name.add_theme_font_size_override("font_size", 10)
		slot_name.add_theme_color_override("font_outline_color", Color("05090d"))
		slot_name.add_theme_constant_override("outline_size", 2)
		slot_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(slot_name)
		backpack_name_labels.append(slot_name)

	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(detail_label)
	# La hotbar resta leggibile anche quando l'inventario completo è aperto.
	root.move_child(hotbar_row, root.get_child_count() - 1)


func _slot_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _process(_delta: float) -> void:
	if Inventory.is_open or Shop.is_open:
		pickup_label.text = ""
		return
	var player := get_tree().get_first_node_in_group("player")
	var selected_id := str(Inventory.get_selected_item().get("id", ""))
	if selected_id in ["pipe_hammer", "solar_panel", "transformer", "battery", "ice_drill", "rover"] and player != null:
		var builder := player.get_node_or_null("Node")
		if builder != null and builder.has_method("get_build_help_text"):
			pickup_label.text = str(builder.call("get_build_help_text"))
		else:
			pickup_label.text = "Click sinistro per posizionare"
	else:
		if player != null and player.has_method("is_driving_rover") and bool(player.call("is_driving_rover")):
			pickup_label.text = "E  ·  Scendi dal rover     ·     Raccolta rocce disponibile solo a piedi"
		else:
			pickup_label.text = "E  ·  Raccogli pietra" if player != null and player.nearest_rock() != null else "TAB  ·  Inventario     B  ·  Emporio"


func _refresh() -> void:
	overlay.visible = Inventory.is_open
	_refresh_suit_slot()
	for index in Inventory.HOTBAR_SIZE:
		var button := hotbar_buttons[index]
		var item := Inventory.hotbar[index]
		button.text = ""
		var item_icon := _item_icon(item)
		hotbar_icons[index].texture = item_icon
		hotbar_icons[index].visible = item_icon != null
		hotbar_icons[index].material = icon_mask_material if item.get("id", "") in ["water_bottle", "food_ration"] else null
		_update_hotbar_labels(index, item)
		var is_selected := Inventory.selected_hotbar_index == index
		button.add_theme_stylebox_override("normal", _slot_style(Color(0.11, 0.10, 0.12, 0.94), Color(1.0, 0.70, 0.25) if is_selected else Color(0.38, 0.36, 0.39)))
		button.add_theme_stylebox_override("hover", _slot_style(Color(0.18, 0.16, 0.18, 0.98), Color(1.0, 0.76, 0.32)))
		button.add_theme_stylebox_override("pressed", _slot_style(Color(0.22, 0.18, 0.14, 0.98), Color(1.0, 0.82, 0.38)))
		button.add_theme_stylebox_override("focus", _slot_style(Color(0.11, 0.10, 0.12, 0.94), Color(1.0, 0.70, 0.25)))
		button.modulate = Color.WHITE
	for index in Inventory.BACKPACK_SIZE:
		var button := backpack_buttons[index]
		var item := Inventory.backpack[index]
		var is_rock: bool = Inventory.is_rock_item(str(item.get("id", "")))
		button.text = "x" + str(item.get("count", 0)) if is_rock else ""
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_rock else HORIZONTAL_ALIGNMENT_CENTER
		if item.is_empty():
			backpack_name_labels[index].text = ""
		elif is_rock:
			backpack_name_labels[index].text = str(item.get("name", "Pietra"))
		else:
			backpack_name_labels[index].text = "%s x%d" % [str(item.get("name", "")), int(item.get("count", 0))]
		var backpack_icon := _item_icon(item)
		backpack_icons[index].texture = backpack_icon
		backpack_icons[index].material = icon_mask_material if item.get("id", "") == "rock" else null
		backpack_icons[index].position = Vector2(20, 5)
		backpack_icons[index].size = Vector2(56, 50)
		backpack_icons[index].scale = Vector2.ONE
		backpack_icons[index].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backpack_icons[index].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		backpack_icons[index].visible = backpack_icon != null
		backpack_icons[index].modulate = Color.WHITE
		button.modulate = Color(1.0, 0.84, 0.45) if Inventory.selected_backpack_index == index else Color.WHITE
	if Inventory.selected_backpack_index >= 0:
		var selected := Inventory.backpack[Inventory.selected_backpack_index]
		var selected_id := str(selected.get("id", ""))
		detail_label.text = "%s · campione geologico, non piazzabile" % str(selected.get("name", "Pietra")) if Inventory.is_rock_item(selected_id) else str(selected.get("name", ""))
	else:
		detail_label.text = "Slot rapido " + str(Inventory.selected_hotbar_index + 1) + " · premi 1-5 per cambiarlo. Clicca un oggetto costruibile per equipaggiarlo."


func _update_hotbar_labels(index: int, item: Dictionary) -> void:
	hotbar_name_labels[index].text = ""
	hotbar_amount_labels[index].text = ""
	if item.is_empty():
		return
	match item.get("id", ""):
		"pipe_hammer":
			hotbar_name_labels[index].text = "Tubi"
		"water_bottle":
			hotbar_name_labels[index].text = "Acqua"
			hotbar_amount_labels[index].text = "%.1fL" % float(item.get("liters", 0.0))
		"food_ration":
			hotbar_name_labels[index].text = "Razioni " + str(item.get("count", 0))
		"solar_panel":
			hotbar_name_labels[index].text = "Pannello x" + str(item.get("count", 0))
		"transformer":
			hotbar_name_labels[index].text = "Trasform. x" + str(item.get("count", 0))
		"battery":
			hotbar_name_labels[index].text = "Batteria x" + str(item.get("count", 0))
		"ice_drill":
			hotbar_name_labels[index].text = "Trivella x" + str(item.get("count", 0))
		"rover":
			hotbar_name_labels[index].text = "Rover x" + str(item.get("count", 0))
		_:
			hotbar_name_labels[index].text = str(item.get("name", ""))


func _item_icon(item: Dictionary) -> Texture2D:
	var item_id := str(item.get("id", ""))
	if ROCK_ICONS.has(item_id):
		return ROCK_ICONS[item_id]
	match item_id:
		"pipe_hammer":
			return HAMMER_ICON
		"water_bottle":
			return WATER_ICON
		"food_ration":
			return RATION_ICON
		"solar_panel":
			return SOLAR_ICON
		"transformer":
			return _first_frame(TRANSFORMER_SHEET)
		"battery":
			return _first_frame(BATTERY_SHEET)
		"ice_drill":
			return _first_frame(ICE_DRILL_SHEET, Vector2i(32, 48))
		"rover":
			return _first_frame(ROVER_SHEET, Vector2i(48, 32))
		"rock":
			return ROCK_ICON
		"suit_standard", "suit_reinforced", "suit_explorer", "suit_storm":
			return _first_frame(PLAYER_SHEET, Vector2i(32, 32))
		_:
			return null


func _first_frame(sheet: Texture2D, frame_size: Vector2i = Vector2i(16, 16)) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2.ZERO, frame_size)
	return atlas


func _on_hotbar_pressed(index: int) -> void:
	if Inventory.is_open and Inventory.selected_backpack_index >= 0:
		Inventory.move_selected_to_hotbar(index)
	else:
		Inventory.select_hotbar(index)


func _on_backpack_pressed(index: int) -> void:
	Inventory.select_backpack(index)
	if Inventory.backpack[index].get("placeable", false):
		var target_slot := Inventory.selected_hotbar_index
		if target_slot == 0 or target_slot >= 3:
			target_slot = 1
		Inventory.move_selected_to_hotbar(target_slot)


func _equip_selected_suit() -> void:
	if bool(suit_system.call("equip", viewed_suit_id)):
		_refresh()


func _cycle_suit(direction: int) -> void:
	var owned: Array = suit_system.call("get_owned_suit_ids")
	if owned.is_empty():
		return
	var index := owned.find(viewed_suit_id)
	if index < 0:
		index = 0
	viewed_suit_id = owned[posmod(index + direction, owned.size())]
	_refresh_suit_slot()


func _refresh_suit_slot() -> void:
	var owned: Array = suit_system.call("get_owned_suit_ids")
	if viewed_suit_id.is_empty() or viewed_suit_id not in owned:
		viewed_suit_id = str(suit_system.equipped_suit_id)
	var definition: Dictionary = suit_system.call("get_definition", viewed_suit_id)
	suit_slot_icon.texture = _first_frame(PLAYER_SHEET, Vector2i(32, 32))
	suit_slot_icon.modulate = definition.get("tint", Color.WHITE)
	suit_slot_name.text = str(definition.get("short_name", "EVA"))
	suit_stats_label.text = "SOL %d%%   COS %d%%   FREDDO %+.0f°C\nO2 %.0f   VELOCITA' %d%%" % [
		roundi(float(definition.get("solar_protection", 0.0)) * 100.0),
		roundi(float(definition.get("cosmic_protection", 0.0)) * 100.0),
		float(definition.get("cold_tolerance_c", -68.0)),
		float(definition.get("oxygen_capacity", 100.0)),
		roundi(float(definition.get("movement_multiplier", 1.0)) * 100.0),
	]
	var equipped := str(suit_system.equipped_suit_id) == viewed_suit_id
	equip_button.disabled = equipped
	equip_button.text = "EQUIPAGGIATA" if equipped else "EQUIPAGGIA"
	suit_previous_button.disabled = owned.size() <= 1
	suit_next_button.disabled = owned.size() <= 1


func _on_suit_equipped(suit_id: String, _definition: Dictionary) -> void:
	viewed_suit_id = suit_id
	_refresh()


func _on_owned_suits_changed() -> void:
	var owned: Array = suit_system.call("get_owned_suit_ids")
	if not owned.is_empty():
		viewed_suit_id = owned.back()
	_refresh()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB:
		if Shop.is_open:
			Shop.close()
		else:
			Inventory.toggle_open()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and Inventory.is_open:
		Inventory.toggle_open()
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
		Inventory.select_hotbar(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
