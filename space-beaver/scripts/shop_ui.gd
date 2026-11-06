extends CanvasLayer

const SOLAR_TEXTURE := preload("res://sprites/machines/solar-panel-spritesheet.png")
const TRANSFORMER_SHEET := preload("res://sprites/machines/transformer-spritesheet.png")
const BATTERY_SHEET := preload("res://sprites/machines/battery-spritesheet.png")
const ICE_DRILL_SHEET := preload("res://sprites/machines/ice-drill-spritesheet.png")
const ELECTROLYZER_SHEET := preload("res://assets/electrolyzer.png")
const SABATIER_SHEET := preload("res://assets/sabatier.png")
const PLAYER_SHEET := preload("res://sprites/player-spritesheet.png")
const ROVER_SHEET := preload("res://assets/rover/rover_idle.png")
const SHOP_SECTIONS := [
	{"label": "TUTE", "categories": ["equipment"]},
	{"label": "BASE & INFRASTRUTTURE", "categories": ["habitats", "energy", "life_support"]},
	{"label": "RISORSE & RICERCA", "categories": ["extraction", "research"]},
]

var overlay: ColorRect
var message_label: Label
var order_label: Label
var buy_buttons: Dictionary = {}
var catalog_view: Control
var dome_config_view: VBoxContainer
var dome_config_image: TextureRect
var dome_config_title: Label
var dome_config_total: Label
var dome_lead_checkbox: Button
var dome_hydrogen_checkbox: Button
var dome_rover_pad_checkbox: Button
var selected_dome_id := ""


func _ready() -> void:
	layer = 80
	_build_ui()
	Shop.state_changed.connect(_refresh)
	Shop.message_changed.connect(_show_message)
	Economy.balance_changed.connect(_on_balance_changed)
	DeliveryManager.order_changed.connect(_refresh_order)
	_refresh()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.02, 0.025, 0.90)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(940.0, viewport_size.x - 24.0)
	var panel_height := minf(600.0, viewport_size.y - 20.0)
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	panel.add_child(rows)
	var title := _label("// EMPORIO LOGISTICO MISSIONE //", 20, Color("ffe38a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var subtitle := _label("B per chiudere  ·  Gli acquisti ravvicinati viaggiano nella stessa capsula", 12, Color("c5d2d4"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(subtitle)
	rows.add_child(HSeparator.new())
	var tabs := TabContainer.new()
	var content_width := minf(890.0, panel_width - 54.0)
	var content_height := maxf(180.0, minf(330.0, viewport_size.y - 320.0))
	tabs.custom_minimum_size = Vector2(content_width, content_height)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)
	for section in SHOP_SECTIONS:
		_add_section(tabs, section, content_width, content_height)
	catalog_view = tabs
	dome_config_view = _build_dome_config_view()
	dome_config_view.custom_minimum_size = Vector2(content_width, content_height)
	dome_config_view.visible = false
	rows.add_child(dome_config_view)
	order_label = _label("", 12, Color("8cd9ff"))
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rows.add_child(order_label)
	message_label = _label("", 13, Color("7fe39d"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(message_label)
	var close_button := Button.new()
	close_button.text = "[ CHIUDI EMPORIO ]"
	close_button.custom_minimum_size = Vector2(220, 34)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_stylebox_override("normal", _button_style(Color("304c58")))
	close_button.add_theme_stylebox_override("hover", _button_style(Color("456c7b")))
	close_button.pressed.connect(Shop.close)
	rows.add_child(close_button)


func _add_section(parent: TabContainer, section_data: Dictionary, content_width: float, content_height: float) -> void:
	var scroll := ScrollContainer.new()
	var section_label := str(section_data["label"])
	scroll.name = section_label
	scroll.custom_minimum_size = Vector2(content_width, content_height)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.set_tab_title(parent.get_tab_count() - 1, section_label)
	var groups := VBoxContainer.new()
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("separation", 12)
	scroll.add_child(groups)
	for category in section_data["categories"]:
		_add_category_group(groups, str(category))


func _add_category_group(parent: VBoxContainer, category: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 7)
	parent.add_child(group)
	group.add_child(_label("▸ %s" % Shop.get_category_label(category), 14, Color("86d4e5")))
	var cards := HFlowContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	group.add_child(cards)
	var item_ids := Shop.get_items_for_category(category)
	for item_id in item_ids:
		_add_card(cards, item_id, _texture_for_item(item_id))
func _build_dome_config_view() -> VBoxContainer:
	var config := VBoxContainer.new()
	config.custom_minimum_size = Vector2(890, 330)
	config.alignment = BoxContainer.ALIGNMENT_CENTER
	config.add_theme_constant_override("separation", 4)
	var back := Button.new()
	back.text = "← TORNA ALLE SEZIONI DELLO SHOP"
	back.custom_minimum_size = Vector2(280, 30)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_dome_config)
	config.add_child(back)
	dome_config_image = TextureRect.new()
	dome_config_image.custom_minimum_size = Vector2(76, 56)
	dome_config_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dome_config_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dome_config_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dome_config_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	config.add_child(dome_config_image)
	dome_config_title = _label("", 18, Color("e8f0ed"))
	dome_config_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	config.add_child(dome_config_title)
	var shield_header := _label("SCHERMATURE E MODULI", 14, Color("86d4e5"))
	shield_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	config.add_child(shield_header)
	var prices: Dictionary = Shop.get_dome_addon_prices()
	dome_lead_checkbox = _make_dome_option("Piombo · solare −25%%, cosmica −8%% (+%s)" % Economy.format_money(int(prices["lead_shielding"])))
	dome_lead_checkbox.toggled.connect(_on_dome_option_toggled.bind(dome_lead_checkbox))
	config.add_child(dome_lead_checkbox)
	dome_hydrogen_checkbox = _make_dome_option("Materiale idrogenato · cosmica −35%%, solare −12%% (+%s)" % Economy.format_money(int(prices["hydrogen_shielding"])))
	dome_hydrogen_checkbox.toggled.connect(_on_dome_option_toggled.bind(dome_hydrogen_checkbox))
	config.add_child(dome_hydrogen_checkbox)
	dome_rover_pad_checkbox = _make_dome_option("Base di ricarica rover accanto alla cupola (+%s)" % Economy.format_money(int(prices["rover_pad"])))
	dome_rover_pad_checkbox.toggled.connect(_on_dome_option_toggled.bind(dome_rover_pad_checkbox))
	config.add_child(dome_rover_pad_checkbox)
	dome_config_total = _label("", 14, Color("ffe38a"))
	dome_config_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	config.add_child(dome_config_total)
	var confirm := Button.new()
	confirm.text = "[ CONFERMA CUPOLA E ORDINA ]"
	confirm.custom_minimum_size = Vector2(280, 34)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.add_theme_stylebox_override("normal", _button_style(Color("3b664a")))
	confirm.add_theme_stylebox_override("hover", _button_style(Color("559266")))
	confirm.pressed.connect(_confirm_dome_purchase)
	config.add_child(confirm)
	_refresh_dome_config_price()
	return config


func _make_dome_option(description: String) -> Button:
	var option := Button.new()
	option.toggle_mode = true
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.custom_minimum_size = Vector2(620, 36)
	option.add_theme_font_size_override("font_size", 13)
	option.add_theme_color_override("font_color", Color("d9e3e4"))
	option.add_theme_color_override("font_hover_color", Color("ffffff"))
	option.add_theme_color_override("font_pressed_color", Color("ffffff"))
	option.add_theme_stylebox_override("normal", _button_style(Color("1c2b32")))
	option.add_theme_stylebox_override("hover", _button_style(Color("29444d")))
	option.add_theme_stylebox_override("pressed", _button_style(Color("315c49")))
	option.add_theme_stylebox_override("hover_pressed", _button_style(Color("3c7056")))
	option.set_meta("description", description)
	_update_dome_option_text(option)
	return option


func _update_dome_option_text(option: Button) -> void:
	var mark := "☑" if option.button_pressed else "☐"
	option.text = "%s  %s" % [mark, str(option.get_meta("description"))]


func _on_dome_option_toggled(pressed: bool, option: Button) -> void:
	_update_dome_option_text(option)
	_refresh_dome_config_price()


func _add_card(parent: HFlowContainer, item_id: String, texture: Texture2D) -> void:
	var definition := Shop.get_definition(item_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(206, 242)
	card.add_theme_stylebox_override("panel", _card_style())
	parent.add_child(card)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 6)
	card.add_child(rows)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(84, 60)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if SuitSystem.is_suit(item_id):
		icon.modulate = SuitSystem.get_definition(item_id).get("tint", Color.WHITE)
	rows.add_child(icon)
	var name_label := _label(str(definition["name"]).to_upper(), 14, Color("e8f0ed"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(name_label)
	var price_label := _label(Economy.format_money(int(definition["price"])), 15, Color("ffe38a"))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(price_label)
	var description := _label(str(definition["description"]), 11, Color("b8c5c6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size = Vector2(180, 64)
	rows.add_child(description)
	var buy := Button.new()
	buy.text = "[ CONFIGURA ]" if item_id in ["dome_small", "dome_medium", "dome_large"] else "[ ORDINA ]"
	buy.custom_minimum_size = Vector2(150, 32)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy.add_theme_stylebox_override("normal", _button_style(Color("3b664a")))
	buy.add_theme_stylebox_override("hover", _button_style(Color("559266")))
	buy.pressed.connect(_select_or_purchase.bind(item_id))
	rows.add_child(buy)
	buy_buttons[item_id] = buy


func _select_or_purchase(item_id: String) -> void:
	if item_id in ["dome_small", "dome_medium", "dome_large"]:
		selected_dome_id = item_id
		var definition := Shop.get_definition(item_id)
		dome_lead_checkbox.button_pressed = false
		dome_hydrogen_checkbox.button_pressed = false
		dome_rover_pad_checkbox.button_pressed = false
		dome_rover_pad_checkbox.disabled = item_id == "dome_small"
		dome_config_title.text = str(definition["name"]).to_upper()
		dome_config_image.texture = _texture_for_item(item_id)
		_refresh_dome_config_price()
		catalog_view.visible = false
		dome_config_view.visible = true
		return
	Shop.purchase(item_id)
	_refresh_order()


func _close_dome_config() -> void:
	selected_dome_id = ""
	dome_config_view.visible = false
	catalog_view.visible = true


func _confirm_dome_purchase() -> void:
	if selected_dome_id.is_empty():
		return
	if Shop.purchase_dome(selected_dome_id, _get_dome_configuration()):
		_close_dome_config()
		_refresh_order()


func _get_dome_configuration() -> Dictionary:
	return {
		"lead_shielding": dome_lead_checkbox.button_pressed,
		"hydrogen_shielding": dome_hydrogen_checkbox.button_pressed,
		"rover_pad": dome_rover_pad_checkbox.button_pressed,
	}


func _refresh_dome_config_price(_toggled: bool = false) -> void:
	if dome_config_total == null:
		return
	var total := Shop.get_dome_total_price(selected_dome_id, _get_dome_configuration()) if not selected_dome_id.is_empty() else 0
	dome_config_total.text = "TOTALE CUPOLA CONFIGURATA: %s" % Economy.format_money(total)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_B and not BuildableRegistry.is_modal_open:
		if Inventory.is_open:
			Inventory.toggle_open()
		Shop.toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and Shop.is_open:
		Shop.close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	overlay.visible = Shop.is_open
	if Shop.is_open:
		message_label.text = "Seleziona i componenti: verranno raggruppati in un unico lancio."
	_refresh_buttons()
	_refresh_order()


func _refresh_buttons() -> void:
	for item_id in buy_buttons:
		var definition := Shop.get_definition(item_id)
		var disabled := not Economy.can_afford(int(definition["price"]))
		if item_id == "transformer":
			disabled = disabled or PowerGrid.has_transformer() or Inventory.count_item("transformer") > 0 or DeliveryManager.count_uncollected("transformer") > 0
		elif SuitSystem.is_suit(item_id):
			disabled = disabled or SuitSystem.owns_suit(item_id) or DeliveryManager.count_uncollected(item_id) > 0
		buy_buttons[item_id].disabled = disabled


func _refresh_order() -> void:
	if order_label == null:
		return
	var status := DeliveryManager.get_delivery_status()
	if bool(status["pending"]):
		order_label.text = "ORDINE APERTO (%.1f s)  ·  %s" % [float(status["seconds"]), str(status["pending_summary"])]
	else:
		order_label.text = "Nessun ordine in preparazione"
	_refresh_buttons()


func _show_message(message: String, is_error: bool) -> void:
	message_label.text = message
	message_label.add_theme_color_override("font_color", Color("ff776d") if is_error else Color("7fe39d"))


func _on_balance_changed(_current: int) -> void:
	_refresh_buttons()


func _texture_for_item(item_id: String) -> Texture2D:
	if item_id in ["dome_small", "dome_medium", "dome_large"]:
		return BaseDome.EXTERIOR_TEXTURES[item_id]
	match item_id:
		"solar_panel":
			return SOLAR_TEXTURE
		"transformer":
			return _atlas_frame(TRANSFORMER_SHEET, Vector2i(32, 32))
		"battery":
			return _atlas_frame(BATTERY_SHEET, Vector2i(16, 16))
		"ice_drill":
			return _atlas_frame(ICE_DRILL_SHEET, Vector2i(32, 48))
		"electrolyzer":
			return _atlas_frame(ELECTROLYZER_SHEET, Vector2i(32, 32))
		"sabatier":
			return _atlas_frame(SABATIER_SHEET, Vector2i(48, 48))
		"rover":
			return _atlas_frame(ROVER_SHEET, Vector2i(48, 32))
		"suit_reinforced", "suit_explorer", "suit_storm":
			return _atlas_frame(PLAYER_SHEET, Vector2i(32, 32))
	return null


func _atlas_frame(sheet: Texture2D, frame_size: Vector2i) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2.ZERO, frame_size)
	return atlas


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("05090d"))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101820")
	style.border_color = Color("dfbd52")
	style.set_border_width_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17232b")
	style.border_color = Color("607d8b")
	style.set_border_width_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("d5e0de")
	style.set_border_width_all(2)
	return style
