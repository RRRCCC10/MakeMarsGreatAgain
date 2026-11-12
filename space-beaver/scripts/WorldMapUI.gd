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
var map_view_center_cell := Vector2.ZERO
var map_was_panned := false
var is_panning := false
var last_pan_mouse_position := Vector2.ZERO

const MIN_MAP_ZOOM := 1.0
const MAX_MAP_ZOOM := 8.0
const MAP_ZOOM_FACTOR := 1.25
const STRUCTURE_ICON_SIZE := 15.0
const AIRDROP_ICON_SIZE := 14.0


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
		# Finche' il giocatore non trascina la carta, questa continua a seguirlo
		# anche mentre resta aperta e il personaggio si muove.
		if not map_was_panned and player != null and map_provider != null:
			map_view_center_cell = Vector2(map_provider.call("world_to_cell", player.global_position))
		map_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		# Il pan e' utile solo dopo lo zoom: a zoom 1 l'intero mondo e' gia'
		# visibile e non c'e' una visuale da traslare.
		if event.pressed and map_zoom > MIN_MAP_ZOOM:
			is_panning = true
			last_pan_mouse_position = event.position
			get_viewport().set_input_as_handled()
		elif not event.pressed and is_panning:
			is_panning = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and is_panning:
		_pan_map(event.position - last_pan_mouse_position)
		last_pan_mouse_position = event.position
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
		map_was_panned = false
		is_panning = false
		if player != null and map_provider != null:
			map_view_center_cell = Vector2(map_provider.call("world_to_cell", player.global_position))
		map_canvas.queue_redraw()
	else:
		is_panning = false


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
				var achievements := get_node_or_null("/root/AchievementManager")
				if achievements != null and achievements.has_method("record_exploration_source"):
					achievements.call("record_exploration_source", source_id)
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
	panel.name = "ResponsiveMapPanel"
	# Carta elastica: i margini percentuali mantengono leggibile la mappa sia
	# nella finestra iniziale sia dopo un ingrandimento libero della finestra.
	panel.anchor_left = 0.05
	panel.anchor_top = 0.05
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.95
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
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
	hint.text = "M · chiudi     Rotella · zoom     Trascina rotella · sposta"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -365.0
	hint.offset_top = 13.0
	hint.offset_right = -18.0
	hint.offset_bottom = 33.0
	hint.add_theme_color_override("font_color", Color("c3ccd2"))
	hint.add_theme_font_size_override("font_size", 11)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)
	var legend := Label.new()
	legend.text = "Aree inesplorate oscurate · △ AirDrop lampeggiante · strutture con sprite"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -33
	legend.offset_bottom = -10
	legend.add_theme_color_override("font_color", Color("8998a2"))
	legend.add_theme_font_size_override("font_size", 11)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(legend)


func _draw_map(canvas: Control) -> void:
	var map_size := _get_map_size(canvas)
	var map_rect := Rect2((canvas.size - Vector2.ONE * map_size) * 0.5, Vector2.ONE * map_size)
	canvas.draw_rect(map_rect.grow(3), Color("020608"), true)
	canvas.draw_rect(map_rect, Color("10181d"), true)
	if map_provider == null or world_rect.size.x <= 0 or world_rect.size.y <= 0:
		return
	var visible_tiles := _get_visible_tiles()
	var visible_rect := _get_visible_rect(visible_tiles)
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
	_draw_structure_markers(canvas, map_rect, visible_rect, pixels_per_tile)
	_draw_airdrop_markers(canvas, map_rect, visible_rect, pixels_per_tile)
	if player != null:
		var player_cell: Vector2i = map_provider.call("world_to_cell", player.global_position)
		if visible_rect.has_point(player_cell):
			var marker_pos := map_rect.position + Vector2(player_cell - visible_rect.position) * pixels_per_tile
			canvas.draw_circle(marker_pos, 3.5, Color("ffd56b"))
			canvas.draw_arc(marker_pos, 5.0, 0.0, TAU, 12, Color("fff2bd"), 1.0)
	canvas.draw_rect(map_rect, Color("6bd8ed"), false, 1.5)


func _draw_structure_markers(canvas: Control, map_rect: Rect2, visible_rect: Rect2i, pixels_per_tile: float) -> void:
	for marker in get_structure_map_markers():
		var point := _marker_point(marker.get("world_position", Vector2.ZERO), map_rect, visible_rect, pixels_per_tile)
		if point == Vector2.INF:
			continue
		var icon_size := clampf(STRUCTURE_ICON_SIZE + map_zoom * 1.5, 12.0, 26.0)
		canvas.draw_circle(point, icon_size * 0.62, Color("06151adf"), true)
		var icon := marker.get("texture") as Texture2D
		if icon != null:
			canvas.draw_texture_rect(icon, Rect2(point - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false)
		else:
			canvas.draw_rect(Rect2(point - Vector2.ONE * 3.0, Vector2.ONE * 6.0), Color("8ee7f2"), true)
		canvas.draw_circle(point, icon_size * 0.62, Color("72d6e5"), false, 1.0)


func _draw_airdrop_markers(canvas: Control, map_rect: Rect2, visible_rect: Rect2i, pixels_per_tile: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
	for marker in get_airdrop_map_markers():
		var point := _marker_point(marker.get("world_position", Vector2.ZERO), map_rect, visible_rect, pixels_per_tile)
		if point == Vector2.INF:
			continue
		var ring_size := AIRDROP_ICON_SIZE * (0.72 + pulse * 0.42)
		canvas.draw_circle(point, ring_size, Color(1.0, 0.67, 0.20, 0.22 + pulse * 0.35), false, 1.8)
		canvas.draw_circle(point, 5.0 + pulse * 1.8, Color("ffae3d"), true)
		var icon := marker.get("texture") as Texture2D
		if icon != null:
			canvas.draw_texture_rect(icon, Rect2(point - Vector2.ONE * AIRDROP_ICON_SIZE * 0.5, Vector2.ONE * AIRDROP_ICON_SIZE), false)
		canvas.draw_arc(point, ring_size + 3.0, 0.0, TAU, 12, Color("ffe4a4"), 1.0)


func _marker_point(world_position: Vector2, map_rect: Rect2, visible_rect: Rect2i, pixels_per_tile: float) -> Vector2:
	if map_provider == null:
		return Vector2.INF
	var cell: Vector2i = map_provider.call("world_to_cell", world_position)
	if not visible_rect.has_point(cell):
		return Vector2.INF
	return map_rect.position + (Vector2(cell - visible_rect.position) + Vector2.ONE * 0.5) * pixels_per_tile


func get_structure_map_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for entry in BuildableRegistry.get_entries():
		if str(entry.get("kind", "")) == "pipe":
			continue
		var structure := entry.get("node") as Node2D
		if structure == null or not is_instance_valid(structure):
			continue
		markers.append({
			"node": structure,
			"world_position": structure.global_position,
			"texture": _find_sprite_texture(structure),
		})
	return markers


func get_airdrop_map_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for capsule in get_tree().get_nodes_in_group("delivery_capsules"):
		if not capsule is Node2D or not is_instance_valid(capsule):
			continue
		var world_position: Vector2 = capsule.global_position
		if capsule.has_method("get_map_marker_world_position"):
			world_position = capsule.call("get_map_marker_world_position")
		markers.append({
			"node": capsule,
			"world_position": world_position,
			"texture": _find_sprite_texture(capsule),
		})
	return markers


func get_map_marker_counts() -> Dictionary:
	return {
		"structures": get_structure_map_markers().size(),
		"airdrops": get_airdrop_map_markers().size(),
	}


func _find_sprite_texture(root: Node) -> Texture2D:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_front()
		if current is Sprite2D:
			var sprite := current as Sprite2D
			if sprite.texture != null:
				return sprite.texture
		for child in current.get_children():
			pending.append(child)
	return null


func get_explored_block_count() -> int:
	return explored_blocks.size()


func get_map_view_center_cell() -> Vector2:
	return map_view_center_cell


func _get_visible_tiles() -> int:
	return maxi(1, roundi(float(world_rect.size.x) / map_zoom))


func _get_map_size(canvas: Control) -> float:
	var available := canvas.size - Vector2(22, 10)
	return maxf(80.0, minf(available.x, available.y))


func _get_visible_rect(visible_tiles: int) -> Rect2i:
	var center := _clamp_map_view_center(map_view_center_cell, visible_tiles)
	var max_top_left := world_rect.end - Vector2i.ONE * visible_tiles
	return Rect2i(
		Vector2i(
			clampi(roundi(center.x - visible_tiles * 0.5), world_rect.position.x, max_top_left.x),
			clampi(roundi(center.y - visible_tiles * 0.5), world_rect.position.y, max_top_left.y)
		),
		Vector2i.ONE * visible_tiles
	)


func _pan_map(mouse_delta: Vector2) -> void:
	if map_canvas == null or world_rect.size.x <= 0 or map_zoom <= MIN_MAP_ZOOM:
		return
	var visible_tiles := _get_visible_tiles()
	var pixels_per_tile := _get_map_size(map_canvas) / float(visible_tiles)
	if pixels_per_tile <= 0.0:
		return
	# La carta segue il trascinamento: spostando il mouse a destra si guarda
	# verso ovest, come in una mappa cartacea.
	map_view_center_cell = _clamp_map_view_center(map_view_center_cell - mouse_delta / pixels_per_tile, visible_tiles)
	map_was_panned = true
	map_canvas.queue_redraw()


func _clamp_map_view_center(center: Vector2, visible_tiles: int) -> Vector2:
	var half_visible := float(visible_tiles) * 0.5
	var min_center := Vector2(world_rect.position) + Vector2.ONE * half_visible
	var max_center := Vector2(world_rect.end) - Vector2.ONE * half_visible
	if min_center.x > max_center.x:
		min_center.x = float(world_rect.get_center().x)
		max_center.x = min_center.x
	if min_center.y > max_center.y:
		min_center.y = float(world_rect.get_center().y)
		max_center.y = min_center.y
	return Vector2(clampf(center.x, min_center.x, max_center.x), clampf(center.y, min_center.y, max_center.y))
