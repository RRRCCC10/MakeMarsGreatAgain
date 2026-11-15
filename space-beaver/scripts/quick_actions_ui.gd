extends CanvasLayer

## Barra di accesso rapido alle tre pagine principali. I pannelli restano
## modali e continuano a usare UIState: qui ci sono solo i comandi visibili.

const UI_FONT := preload("res://assets/fonts/font-regular.ttf")
const ELECTRICAL_MISSION_ID := "stable_grid"

var _root: Control
var _shop_button: Button
var _power_button: Button
var _achievement_button: Button


func _ready() -> void:
	layer = 84
	_build_ui()
	AchievementManager.achievement_updated.connect(_on_achievement_updated)
	AchievementManager.achievement_claimed.connect(_on_achievement_claimed)
	_refresh()


func _process(_delta: float) -> void:
	if _root == null:
		return
	var shop_open := _panel_is_open("ShopUI")
	var power_open := _panel_is_open("PowerUI")
	var achievements_open := AchievementManager.is_board_open
	# La hotbar/zaino è un pannello interattivo: i tasti rapidi non devono
	# restargli sopra né dal punto di vista visivo né da quello dell'input.
	_root.visible = not _landing_is_active() and not Inventory.is_open and not shop_open and not power_open and not achievements_open


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "QuickActionsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Questo layer vive sopra l'inventario: PASS intercetta comunque il mouse
	# prima dei pannelli sottostanti. IGNORE lascia davvero passare le aree
	# vuote, mentre i figli (la colonna con i tre pulsanti) restano cliccabili.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var row := VBoxContainer.new()
	row.name = "QuickActionsColumn"
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = -184.0
	row.offset_top = -58.0
	row.offset_right = -16.0
	row.offset_bottom = 58.0
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(row)

	_shop_button = _make_button("SHOP", "Apri l'emporio logistico (B)")
	_shop_button.pressed.connect(_open_shop)
	row.add_child(_shop_button)
	_power_button = _make_button("ELETTRICITÀ", "Completa la missione RETE ELETTRICA per sbloccare il pannello")
	_power_button.pressed.connect(_open_power)
	row.add_child(_power_button)
	_achievement_button = _make_button("ACHIEVEMENT", "Apri la tavola degli obiettivi (J)")
	_achievement_button.pressed.connect(_open_achievements)
	row.add_child(_achievement_button)


func _make_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(168.0, 34.0)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _button_style(Color("142b35"), Color("4b9aae")))
	button.add_theme_stylebox_override("hover", _button_style(Color("214d5d"), Color("80d8eb")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("326675"), Color("b1effa")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("20272b"), Color("5d676b")))
	button.add_theme_color_override("font_color", Color("d8f4f6"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("8c989b"))
	return button


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _refresh() -> void:
	if _power_button == null:
		return
	var unlocked := AchievementManager.is_reached(ELECTRICAL_MISSION_ID)
	_power_button.disabled = not unlocked
	_power_button.text = "ELETTRICITÀ" if unlocked else "ELETTRICITÀ · BLOCCATO"


func _on_achievement_updated(_achievement_id: String) -> void:
	_refresh()


func _on_achievement_claimed(_achievement_id: String, _reward_label: String) -> void:
	_refresh()


func _open_shop() -> void:
	Shop.toggle()


func _open_power() -> void:
	if _power_button.disabled:
		return
	var power_ui := get_tree().current_scene.get_node_or_null("PowerUI")
	if power_ui != null and power_ui.has_method("toggle"):
		power_ui.call("toggle")


func _open_achievements() -> void:
	var board := get_tree().current_scene.get_node_or_null("AchievementBoard")
	if board != null and board.has_method("toggle"):
		board.call("toggle")


func _landing_is_active() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var landing := tree.current_scene.get_node_or_null("LandingSequence")
	if landing == null:
		return false
	if landing.has_method("is_active"):
		return bool(landing.call("is_active"))
	return not bool(landing.get("landing_complete"))


func _panel_is_open(node_name: String) -> bool:
	if node_name == "ShopUI":
		return Shop.is_open
	var panel := get_tree().current_scene.get_node_or_null(node_name)
	if panel == null:
		return false
	var panel_root := panel.get("_root") as Control
	return panel_root != null and panel_root.visible
