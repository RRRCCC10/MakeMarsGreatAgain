extends CanvasLayer

const TILE_SIZE := 16
const REVEAL_RADIUS_TILES := 10
const DRAW_BLOCK_TILES := 4

const TERRAIN_COLORS := {
	0: Color("bc593d"), # sabbia base
	1: Color("7b3430"), # regolite scura
	2: Color("9a8278"), # pietra da cratere
	3: Color("b9d2d2"), # ghiaccio polveroso
	4: Color("2d85aa"), # ghiaccio blu
	5: Color("2b2025"), # basalto
}

class MapCanvas extends Control:
	var map_ui: Node

	func _draw() -> void:
		if map_ui != null:
			map_ui._draw_map(self)


var map_provider: Node
var player: Node2D
var world_rect := Rect2i()
var explored_blocks: Dictionary = {}
var last_revealed_cell := Vector2i(999999, 999999)
var map_root: Control
var map_canvas: MapCanvas
var is_open := false
var map_zoom := 1.0

const MIN_MAP_ZOOM := 1.0
const MAX_MAP_ZOOM := 8.0
const MAP_ZOOM_FACTOR := 1.25


func _ready() -> void:
	add_to_group("world_map_ui")
	layer = 45
	_build_ui()
	call_deferred("_setup")


func _setup() -> void:
	map_provider = get_parent().get_node_or_null("Map")
	player = get_tree().get_first_node_in_group("player") as Node2D
	if map_provider == null or not map_provider.has_method("get_world_rect") or player == null:
		push_error("WorldMapUI: provider della mappa o player non trovato")
		return
	var provided_rect = map_provider.call("get_world_rect")
	if not provided_rect is Rect2i:
		push_error("WorldMapUI: il provider non ha restituito un Rect2i")
		return
	world_rect = provided_rect
	_reveal_around_player()


func _process(_delta: float) -> void:
	_reveal_around_player()
	if is_open and map_canvas != null:
		map_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_map()
		get_viewport().set_input_as_handled()


func handle_mouse_wheel(event: InputEventMouseButton) -> bool:
	if not is_open or not event.pressed:
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		map_zoom = clampf(map_zoom * MAP_ZOOM_FACTOR, MIN_MAP_ZOOM, MAX_MAP_ZOOM)
		map_canvas.queue_redraw()
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		map_zoom = clampf(map_zoom / MAP_ZOOM_FACTOR, MIN_MAP_ZOOM, MAX_MAP_ZOOM)
		map_canvas.queue_redraw()
		return true
	return false


func toggle_map() -> void:
	is_open = not is_open
	map_root.visible = is_open
	if is_open:
		_reveal_around_player()
		map_canvas.queue_redraw()


func _reveal_around_player() -> void:
	if map_provider == null or player == null:
		return
	var cell: Vector2i = map_provider.call("world_to_cell", player.global_position)
	if cell == last_revealed_cell:
		return
	last_revealed_cell = cell
	var changed := false
	for y in range(-REVEAL_RADIUS_TILES, REVEAL_RADIUS_TILES + 1):
		for x in range(-REVEAL_RADIUS_TILES, REVEAL_RADIUS_TILES + 1):
			if x * x + y * y > REVEAL_RADIUS_TILES * REVEAL_RADIUS_TILES:
				continue
			var revealed_cell := cell + Vector2i(x, y)
			if not world_rect.has_point(revealed_cell):
				continue
			var block := Vector2i(floori(float(revealed_cell.x) / DRAW_BLOCK_TILES), floori(float(revealed_cell.y) / DRAW_BLOCK_TILES))
			if not explored_blocks.has(block):
				var source_id := int(map_provider.call("get_source_id", revealed_cell))
				if source_id < 0:
					continue
				explored_blocks[block] = TERRAIN_COLORS.get(source_id, Color("46525a"))
				changed = true
	if changed and map_canvas != null:
		map_canvas.queue_redraw()


func _build_ui() -> void:
	map_root = Control.new()
	map_root.name = "ExplorationMap"
	map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.visible = false
	add_child(map_root)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -370
	panel.offset_top = -330
	panel.offset_right = 370
	panel.offset_bottom = 330
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("091218f4")
	style.border_color = Color("54bfd8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	map_root.add_child(panel)

	map_canvas = MapCanvas.new()
	map_canvas.map_ui = self
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.offset_left = 18
	map_canvas.offset_top = 42
	map_canvas.offset_right = -18
	map_canvas.offset_bottom = -48
	map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(map_canvas)

	var title := Label.new()
	title.text = "// CARTA TOPOGRAFICA //"
	title.position = Vector2(22, 12)
	title.size = Vector2(400, 22)
	title.add_theme_color_override("font_color", Color("91e5f4"))
	title.add_theme_font_size_override("font_size", 15)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	var hint := Label.new()
	hint.text = "M · chiudi     Rotella · zoom"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(370, 13)
	hint.size = Vector2(345, 20)
	hint.add_theme_color_override("font_color", Color("c3ccd2"))
	hint.add_theme_font_size_override("font_size", 11)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)
	var legend := Label.new()
	legend.text = "Le aree non esplorate restano oscurate · scansione a 10 tile"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -33
	legend.offset_bottom = -10
	legend.add_theme_color_override("font_color", Color("8998a2"))
	legend.add_theme_font_size_override("font_size", 11)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(legend)


func _draw_map(canvas: Control) -> void:
	var available := canvas.size - Vector2(22, 10)
	var map_size := maxf(80.0, minf(available.x, available.y))
	var map_rect := Rect2((canvas.size - Vector2.ONE * map_size) * 0.5, Vector2.ONE * map_size)
	canvas.draw_rect(map_rect.grow(3), Color("020608"), true)
	canvas.draw_rect(map_rect, Color("10181d"), true)
	if map_provider == null or world_rect.size.x <= 0 or world_rect.size.y <= 0:
		return
	var visible_tiles := maxi(1, roundi(float(world_rect.size.x) / map_zoom))
	var player_cell := world_rect.get_center()
	if player != null:
		player_cell = map_provider.call("world_to_cell", player.global_position)
	var max_top_left := world_rect.end - Vector2i.ONE * visible_tiles
	var visible_rect := Rect2i(
		Vector2i(
			clampi(player_cell.x - visible_tiles / 2, world_rect.position.x, max_top_left.x),
			clampi(player_cell.y - visible_tiles / 2, world_rect.position.y, max_top_left.y)
		),
		Vector2i.ONE * visible_tiles
	)
	var pixels_per_tile := map_size / float(visible_tiles)
	for block in explored_blocks:
		var cell := Vector2i(block) * DRAW_BLOCK_TILES
		var block_rect := Rect2i(cell, Vector2i.ONE * DRAW_BLOCK_TILES)
		if not visible_rect.intersects(block_rect):
			continue
		var color: Color = explored_blocks[block]
		var relative := Vector2(cell - visible_rect.position) * pixels_per_tile
		var block_size := Vector2.ONE * (pixels_per_tile * DRAW_BLOCK_TILES + 0.35)
		var draw_block := Rect2(map_rect.position + relative, block_size).intersection(map_rect)
		canvas.draw_rect(draw_block, color, true)
	if player != null:
		var marker_pos := map_rect.position + Vector2(player_cell - visible_rect.position) * pixels_per_tile
		canvas.draw_circle(marker_pos, 3.5, Color("ffd56b"))
		canvas.draw_arc(marker_pos, 5.0, 0.0, TAU, 12, Color("fff2bd"), 1.0)
	canvas.draw_rect(map_rect, Color("6bd8ed"), false, 1.5)


func get_explored_block_count() -> int:
	return explored_blocks.size()
