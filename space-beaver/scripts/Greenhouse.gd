extends BaseDome
class_name Greenhouse

## Martian greenhouse: inherits the base dome airlock but uses two blocking
## beds and one synchronized crop of 16 potatoes.

const GREENHOUSE_RADIUS := 80.0
const BASE_TEXTURE := preload("res://assets/sprites/greenhouse/greenhouse_base.jpg")
const GLASS_TEXTURE := preload("res://assets/sprites/greenhouse/greenhouse_glass.jpg")
const BED_TEXTURE := preload("res://assets/sprites/greenhouse/potato_bed.png")
const FIRST_GROWTH_SHEET := preload("res://assets/sprites/greenhouse/potato_first_cycle.jpg")
const REGROWTH_SHEET := preload("res://assets/sprites/greenhouse/potato_regrowth.jpg")
const PIPE_SHEET := preload("res://assets/sprites/machines/pipe-spritesheet.png")
const TRANSPARENCY := preload("res://scripts/TextureTransparency.gd")

const FIRST_CYCLE_SECONDS := 5.0 * 60.0
const REGROWTH_SECONDS := 3.0 * 60.0
const POWERED_TIME_MULTIPLIER := 1.60 # +60% growth speed while powered
const WATER_L_PER_GAME_HOUR := 16.0
const POWER_DEMAND_KW := 10.0
const POWERED_EXTRA_DEMAND_KW := 15.0 # greenhouse heating and lights
const PLOT_COUNT := 16
const HARVEST_FOOD := 5
const WALL_COLLISION_RADIUS := 70.0
const GREENHOUSE_OXYGEN_CAPACITY := 60.0
const GREENHOUSE_INITIAL_OXYGEN := 36.0
const GREENHOUSE_OXYGEN_PASSIVE_LOSS_PER_SECOND := 0.035
const GREENHOUSE_OXYGEN_OCCUPANT_LOSS_PER_SECOND := 0.30
const POTATO_OXYGEN_PER_SECOND := 0.010

var _glass_sprite: Sprite2D
var _bed_sprites: Array[Sprite2D] = []
var _crop_sprites: Array[Sprite2D] = []
var _beds_collision: StaticBody2D
var _water_input_cell := Vector2i.ZERO
var _water_port_marker: Sprite2D
var _night_light: Polygon2D
var _night_point_light: PointLight2D
var _planted := false
var _ready_to_harvest := false
var _completed_cycles := 0
var _growth_seconds := 0.0
# Persistent timer for the current lot. It is separate from network state:
# removing power cannot recalculate or restore time already earned.
var _remaining_growth_seconds := 0.0
var _water_consumed_liters := 0.0
var _oxygen_produced_units := 0.0
var _visual_asset_revision := 0
var _power_refresh_queued := false
var _system_incident_faulted := false
var _sand_accumulation := 0
var _crop_seed_yield_level := 0
var _crop_seed_speed_level := 0
var _harvest_food := HARVEST_FOOD
var _rng := RandomNumberGenerator.new()
const VISUAL_ASSET_REVISION := 2


func setup_greenhouse(direction: int = 1, preview: bool = false) -> void:
	# dome_medium is used only as a neutral airlock configuration; radius, sprite,
	# water port, and logic are redefined by this class.
	super.setup("dome_medium", direction, preview, {})
	# Greenhouse electrical power is always a manual choice.
	network_enabled = false
	powered = false


static func world_position_for(cell: Vector2i) -> Vector2:
	return BaseDome.world_position_for(cell)


func _ready() -> void:
	super._ready()
	if is_preview:
		return
	_rng.randomize()
	oxygen_reserve = GREENHOUSE_INITIAL_OXYGEN
	add_to_group("greenhouses")
	var registry := get_node_or_null("/root/BuildableRegistry")
	if registry != null:
		registry.call("unregister_buildable", self, false)
		registry.call("register_buildable", self, "POTATO GREENHOUSE", "building", Callable(self, "_destroy"))
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("register_target", self, "greenhouse_system", "GREENHOUSE SYSTEM")
	var sandstorms := get_node_or_null("/root/SandstormManager")
	if sandstorms != null:
		sandstorms.call("register_target", self, "POTATO GREENHOUSE")


func _exit_tree() -> void:
	if not is_preview:
		var sandstorms := get_node_or_null("/root/SandstormManager")
		if sandstorms != null:
			sandstorms.call("unregister_target", self)
	super._exit_tree()


func get_radius() -> float:
	return GREENHOUSE_RADIUS


func contains_world_point(world_position: Vector2) -> bool:
	# Art is 160 px wide, but the actual passage must remain inside the ring.
	return global_position.distance_to(world_position) <= WALL_COLLISION_RADIUS


func can_place_greenhouse_at(world_position: Vector2) -> bool:
	# Instance wrapper for previews: avoids reliance on static global-class binding
	# during the editor's first import.
	var tree := Engine.get_main_loop() as SceneTree
	var map_provider: Node = tree.get_first_node_in_group("world_map_provider") if tree != null else null
	if map_provider != null and map_provider.has_method("clamp_world_position"):
		var clamped: Vector2 = map_provider.call("clamp_world_position", world_position, GREENHOUSE_RADIUS + 58.0)
		if clamped.distance_to(world_position) > 0.1:
			return false
	if not BaseDome.is_placement_clear_of_player_and_rocks(world_position, GREENHOUSE_RADIUS, entrance_direction):
		return false
	var registry: Node = tree.root.get_node_or_null("BuildableRegistry") if tree != null else null
	if registry == null:
		return true
	for entry: Dictionary in registry.call("get_entries"):
		var other := entry.get("node") as Node2D
		if other == null or not is_instance_valid(other):
			continue
		if other.has_method("get_radius") and world_position.distance_to(other.global_position) < GREENHOUSE_RADIUS + float(other.call("get_radius")) + 8.0:
			return false
		if other.has_method("contains_world_point") and bool(other.call("contains_world_point", world_position)):
			return false
	return true


func get_thermal_shelter_bonus_c() -> float:
	# This is a greenhouse, not a habitat module: it provides only slight shelter.
	return 5.0 if powered and not _system_incident_faulted else 3.0


func get_power_demand_kw() -> float:
	return POWER_DEMAND_KW + (POWERED_EXTRA_DEMAND_KW if powered else 0.0)


func has_breathable_atmosphere() -> bool:
	return oxygen_reserve > 0.05


func get_oxygen_loss_rate() -> float:
	return GREENHOUSE_OXYGEN_PASSIVE_LOSS_PER_SECOND + (GREENHOUSE_OXYGEN_OCCUPANT_LOSS_PER_SECOND if _player_is_inside() else 0.0)


func get_oxygen_reserve_percent() -> float:
	return clampf(oxygen_reserve / GREENHOUSE_OXYGEN_CAPACITY, 0.0, 1.0)


func get_water_input_cell() -> Vector2i:
	return _water_input_cell


func is_water_connected() -> bool:
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager == null or _water_input_cell == Vector2i.ZERO:
		return false
	# The connector is an external cell. The network can remain gray until it
	# reaches the drill; color must not prevent detection.
	var pipe := pipe_manager.call("get_pipe", _water_input_cell) as PipeSegment
	return pipe != null and pipe.has_opening(Vector2i.RIGHT)


func has_water_source() -> bool:
	return _ensure_water_network_category()


func _ensure_water_network_category() -> bool:
	# A direct drill → pipe → greenhouse link can appear while pipes are still
	# gray. Search for the source in the same physical network and classify it as
	# water only when no incompatible fluid exists.
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager == null or not is_water_connected():
		return false
	var network: Array = pipe_manager.call("get_network", _water_input_cell)
	if network.is_empty():
		return false
	for member in network:
		var pipe := member as PipeSegment
		if pipe != null and pipe.category != PipeSegment.Category.GENERIC and pipe.category != PipeSegment.Category.WATER:
			return false
	var reachable_source := false
	for definition_variant in Array(pipe_manager.get("fluid_sources")):
		var definition: Dictionary = definition_variant
		if int(definition.get("category", PipeSegment.Category.GENERIC)) != PipeSegment.Category.WATER:
			continue
		var source_node := definition.get("node") as Node
		var source_cell := Vector2i(definition.get("cell", Vector2i.ZERO))
		var source_pipe := pipe_manager.call("get_pipe", source_cell) as PipeSegment
		var source_opening := Vector2i(definition.get("required_opening", Vector2i.LEFT))
		if is_instance_valid(source_node) and source_pipe != null and source_pipe in network and source_pipe.has_opening(source_opening):
			reachable_source = true
			break
	if not reachable_source:
		return false
	var input_pipe := pipe_manager.call("get_pipe", _water_input_cell) as PipeSegment
	if input_pipe == null:
		return false
	# Do not rebuild or notify the network every UI frame: once it inherits water
	# blue, the connection is already classified.
	if input_pipe.category != PipeSegment.Category.WATER:
		pipe_manager.call("set_pipe_category", _water_input_cell, PipeSegment.Category.WATER)
	return bool(pipe_manager.call("is_input_connected", _water_input_cell, Vector2i.RIGHT, PipeSegment.Category.WATER))


func get_interaction_summary() -> String:
	if _system_incident_faulted:
		return "GREENHOUSE SYSTEM FAULT · approach and repair"
	var water_label := "water available" if has_water_source() else ("pipe attached" if is_water_connected() else "water pipe missing")
	var power_label := "network active" if powered else ("network disabled" if not network_enabled else "unpowered")
	return "%s · %s" % [water_label, power_label]


func get_display_name() -> String:
	return "POTATO GREENHOUSE"


func get_connection_label() -> String:
	if _system_incident_faulted:
		return "FAULT — approach and repair"
	var power_grid := get_node_or_null("/root/PowerGrid")
	var cable_connected := power_grid != null and bool(power_grid.get("connection_ok").get(self, false))
	if not network_enabled:
		return "GREENHOUSE NETWORK DISABLED"
	return "CONNECTED TO GRID" if cable_connected else "POWER CABLE NOT CONNECTED"


func set_network_enabled(value: bool) -> void:
	var changed := network_enabled != value
	network_enabled = value
	if not network_enabled:
		set_powered(false)
	elif changed:
		# Rebuild the network after updating the flag without rebuilding inside the
		# PowerGrid distribution loop.
		_queue_power_consumer_refresh()


func set_powered(value: bool) -> void:
	var changed := powered != (value and not _system_incident_faulted)
	powered = value and not _system_incident_faulted
	if changed:
		_queue_power_consumer_refresh()


func _queue_power_consumer_refresh() -> void:
	if _power_refresh_queued or is_preview or not is_inside_tree():
		return
	_power_refresh_queued = true
	call_deferred("_refresh_power_consumer")


func _refresh_power_consumer() -> void:
	_power_refresh_queued = false
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("register_consumer", self, get_power_connection_cell(), get_power_demand_kw(), get_power_attach_direction())


func is_planted() -> bool:
	return _planted


func is_crop_ready() -> bool:
	return _ready_to_harvest


func get_remaining_growth_seconds() -> float:
	if _ready_to_harvest:
		return 0.0
	if _remaining_growth_seconds > 0.0:
		return _remaining_growth_seconds
	# Compatibility for a crop that existed before the persistent timer: derive
	# its remaining work only once.
	return maxf(0.0, _cycle_duration() - _growth_seconds)


func get_crop_stage() -> int:
	if not _planted:
		return -1
	if _ready_to_harvest:
		return 4 if _completed_cycles == 0 else 3
	var frame_count := 5 if _completed_cycles == 0 else 4
	var completed_work := _cycle_duration() - get_remaining_growth_seconds()
	return clampi(floori((completed_work / maxf(_cycle_duration(), 0.001)) * frame_count), 0, frame_count - 1)


func get_prompt_for_player(player: Node2D) -> String:
	var airlock_prompt := super.get_prompt_for_player(player)
	if not airlock_prompt.is_empty():
		return airlock_prompt
	if is_preview or player == null or not is_instance_valid(player) or not contains_world_point(player.global_position):
		return ""
	if not _planted:
		var inventory := _inventory()
		if inventory != null and int(inventory.call("count_item", "potato_seeds")) > 0:
			return "E  ·  PLANT 16 POTATOES IN THE BEDS"
		return "EMPTY BEDS · buy POTATO SEEDS in the shop"
	if _ready_to_harvest:
		return "E  ·  HARVEST %d RATIONS" % get_harvest_food()
	var inventory := _inventory()
	if inventory != null and inventory.has_method("get_best_potato_seed_lot"):
		var stronger_lot: Dictionary = inventory.call("get_best_potato_seed_lot", _crop_seed_yield_level, _crop_seed_speed_level)
		if not stronger_lot.is_empty():
			return "STRONGER GM SEEDS AVAILABLE · E  ·  REPLACE LOT"
	var water_status := "WATER OK" if has_water_source() else ("PIPE CONNECTED · no flow" if is_water_connected() else "CONNECT WATER ON THE LEFT")
	var power_status := " · growth +60% · increased power use" if powered else " · no power"
	return "POTATOES: ready in %s\n%s%s" % [_format_crop_time(get_remaining_growth_seconds()), water_status, power_status]


func handle_airlock_key(player: Node2D, keycode: int) -> bool:
	if super.handle_airlock_key(player, keycode):
		return true
	if keycode != KEY_E or is_preview or player == null or not contains_world_point(player.global_position):
		return false
	var inventory := _inventory()
	if inventory == null or not inventory.has_method("take_best_potato_seed_lot"):
		return false
	if _ready_to_harvest:
		return _try_harvest_nearby()
	if not _planted:
		var seed_lot: Dictionary = inventory.call("take_best_potato_seed_lot")
		if not seed_lot.is_empty():
			_plant_crop(seed_lot)
			return true
		return false
	var replacement_lot: Dictionary = inventory.call("take_best_potato_seed_lot", _crop_seed_yield_level, _crop_seed_speed_level)
	if not replacement_lot.is_empty():
		_plant_crop(replacement_lot, true)
		return true
	return false


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "GreenhouseBase"
	_sprite.texture = TRANSPARENCY.without_white_background(BASE_TEXTURE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Like the base dome: above TileMap but below the player (z 1).
	_sprite.z_index = 0
	add_child(_sprite)
	_glass_sprite = Sprite2D.new()
	_glass_sprite.name = "GreenhouseGlass"
	_glass_sprite.texture = TRANSPARENCY.without_white_background(GLASS_TEXTURE)
	_glass_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glass_sprite.z_index = 0
	add_child(_glass_sprite)
	for position in [Vector2(-40.0, 0.0), Vector2(40.0, 0.0)]:
		var bed := Sprite2D.new()
		bed.name = "PotatoBed%d" % _bed_sprites.size()
		bed.texture = TRANSPARENCY.without_white_background(BED_TEXTURE)
		bed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bed.position = position
		bed.z_index = 0
		add_child(bed)
		_bed_sprites.append(bed)
	_build_crop_sprites()
	_build_night_lighting()
	# Explicit airlock construction with corridor and two doors, like the base dome.
	_corridor_sprite = Sprite2D.new()
	_corridor_sprite.name = "AirlockCorridor"
	_corridor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corridor_sprite.z_index = 0
	add_child(_corridor_sprite)
	_outer_door_sprite = Sprite2D.new()
	_outer_door_sprite.name = "OuterDoor"
	_outer_door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outer_door_sprite.z_index = 0
	add_child(_outer_door_sprite)
	_inner_door_sprite = Sprite2D.new()
	_inner_door_sprite.name = "InnerDoor"
	_inner_door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_inner_door_sprite.z_index = 0
	add_child(_inner_door_sprite)
	_refresh_visuals()
	_visual_asset_revision = VISUAL_ASSET_REVISION


func _refresh_visuals() -> void:
	if _sprite == null:
		return
	var direction_name: String = DIRECTION_NAMES[entrance_direction]
	var corridor_frame := _sheet_frame(CORRIDOR_SHEETS[direction_name], 0)
	var outward: Vector2 = DIRECTION_VECTORS[entrance_direction]
	var corridor_length := corridor_frame.region.size.x if not is_zero_approx(outward.x) else corridor_frame.region.size.y
	_corridor_sprite.texture = corridor_frame
	# The inner door stays at 72 px. The corridor starts at its outer side (80 px)
	# and the outer door closes its far end (112 px).
	_corridor_sprite.position = outward * (get_radius() + corridor_length * 0.5)
	_outer_door_sprite.position = outward * (get_radius() + corridor_length - _door_depth(direction_name) * 0.5)
	_inner_door_sprite.position = outward * (get_radius() - _door_depth(direction_name) * 0.5)
	_update_interior_art()


func _build_crop_sprites() -> void:
	var bed_positions := [Vector2(-40.0, 0.0), Vector2(40.0, 0.0)]
	for bed_center in bed_positions:
		for row in 4:
			for column in 2:
				var crop := Sprite2D.new()
				crop.name = "PotatoPlant%02d" % _crop_sprites.size()
				crop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				crop.position = bed_center + Vector2(-8.0 + column * 16.0, -24.0 + row * 16.0)
				# The potato sprite is only the plant: above soil but below the player.
				crop.z_index = 0
				crop.visible = false
				add_child(crop)
				_crop_sprites.append(crop)


func _build_night_lighting() -> void:
	_night_light = Polygon2D.new()
	_night_light.name = "GreenhouseNightLight"
	_night_light.z_index = 0
	_night_light.color = Color(1.0, 0.83, 0.46, 0.18)
	var points := PackedVector2Array()
	for index in 32:
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * 65.0)
	_night_light.polygon = points
	_night_light.visible = false
	add_child(_night_light)
	_night_point_light = PointLight2D.new()
	_night_point_light.name = "GreenhouseLampGlow"
	_night_point_light.texture = _make_light_texture()
	_night_point_light.energy = 1.15
	_night_point_light.color = Color(1.0, 0.82, 0.47, 1.0)
	_night_point_light.z_index = 0
	_night_point_light.visible = false
	add_child(_night_point_light)


func _make_light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.92, 0.72, 0.95), Color(1.0, 0.78, 0.42, 0.30), Color(1.0, 0.70, 0.30, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 192
	texture.height = 192
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _is_night_light_active() -> bool:
	var clock := get_node_or_null("/root/WorldClock")
	return powered and clock != null and not bool(clock.call("is_day"))


func _update_night_lighting() -> void:
	var active := _is_night_light_active()
	if _night_light != null:
		_night_light.visible = active
	if _night_point_light != null:
		_night_point_light.visible = active


func get_occupied_power_cells() -> Array[Vector2i]:
	# The building footprint must match real collision without including the
	# external water connector or blocking an edge pipe.
	var cells: Array[Vector2i] = []
	var min_cell := Vector2i(floori((global_position.x - WALL_COLLISION_RADIUS) / TILE_SIZE), floori((global_position.y - WALL_COLLISION_RADIUS) / TILE_SIZE))
	var max_cell := Vector2i(floori((global_position.x + WALL_COLLISION_RADIUS) / TILE_SIZE), floori((global_position.y + WALL_COLLISION_RADIUS) / TILE_SIZE))
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell_center := Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			if global_position.distance_to(cell_center) <= WALL_COLLISION_RADIUS:
				cells.append(Vector2i(x, y))
	return cells


func _build_boundary_and_corridor() -> void:
	# Doors, corridor, gate, and collisions exactly match the base dome; only
	# radius and greenhouse sprites differ.
	super._build_boundary_and_corridor()
	_beds_collision = StaticBody2D.new()
	_beds_collision.name = "GreenhouseBedCollision"
	_beds_collision.collision_layer = 1
	_beds_collision.collision_mask = 0
	add_child(_beds_collision)
	for position in [Vector2(-40.0, 0.0), Vector2(40.0, 0.0)]:
		var collision := CollisionShape2D.new()
		collision.name = "SoilHitbox"
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(32.0, 64.0)
		collision.shape = rectangle
		collision.position = position
		_beds_collision.add_child(collision)


func _build_port_markers() -> void:
	_water_port_marker = Sprite2D.new()
	_water_port_marker.name = "WaterPipeAttachment"
	_water_port_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water_port_marker.z_index = 0
	var pipe_frame := AtlasTexture.new()
	pipe_frame.atlas = PIPE_SHEET
	pipe_frame.region = Rect2(0.0, 16.0, TILE_SIZE, TILE_SIZE)
	_water_port_marker.texture = pipe_frame
	_water_port_marker.position = Vector2(-get_radius(), 0.0)
	add_child(_water_port_marker)


func _register_connections() -> void:
	if is_preview or not is_inside_tree():
		return
	# The pipe occupies the cell directly west; the visible connector fills the
	# final section to the wall without looking detached from the greenhouse.
	var water_position := global_position + Vector2(-get_radius() - 16.0, 0.0)
	_water_input_cell = Vector2i(floori(water_position.x / TILE_SIZE), floori(water_position.y / TILE_SIZE))
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager != null:
		pipe_manager.call("register_fluid_input", self, _water_input_cell, PipeSegment.Category.WATER, Vector2i.RIGHT)
		if _water_port_marker != null:
			_water_port_marker.position = Vector2(pipe_manager.call("cell_to_world", _water_input_cell)) - global_position + Vector2.RIGHT * TILE_SIZE
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("register_consumer", self, get_power_connection_cell(), get_power_demand_kw(), get_power_attach_direction())


func _update_port_markers() -> void:
	if _water_port_marker != null:
		_water_port_marker.modulate = Color.WHITE if has_water_source() else (Color(0.62, 0.84, 1.0, 1.0) if is_water_connected() else Color(0.70, 0.78, 0.80, 1.0))


func _update_interior_art() -> void:
	if _glass_sprite == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var inside := player != null and contains_world_point(player.global_position)
	# Outside, glass visibly protects the dome; inside, it is nearly transparent.
	_glass_sprite.modulate = Color(1.0, 0.96, 0.78, 0.18 if inside else 0.68) if _is_night_light_active() else Color(1.0, 1.0, 1.0, 0.22 if inside else 0.72)


func _refresh_existing_visual_assets() -> void:
	# Greenhouses created before the fix keep ImageTextures made with the old mask.
	# Refresh once to avoid asking the player to rebuild after a hot reload.
	if _visual_asset_revision >= VISUAL_ASSET_REVISION:
		return
	if _sprite != null:
		_sprite.texture = TRANSPARENCY.without_white_background(BASE_TEXTURE)
	if _glass_sprite != null:
		_glass_sprite.texture = TRANSPARENCY.without_white_background(GLASS_TEXTURE)
	var bed_texture := TRANSPARENCY.without_white_background(BED_TEXTURE)
	for bed in _bed_sprites:
		if bed != null:
			bed.texture = bed_texture
	if _planted:
		_refresh_crop_visuals()
	_visual_asset_revision = VISUAL_ASSET_REVISION


func _process(delta: float) -> void:
	if is_preview:
		return
	_refresh_existing_visual_assets()
	_update_interior_art()
	_update_airlock_state()
	_update_night_lighting()
	_update_greenhouse_oxygen(delta)
	if has_water_source():
		_record_achievement("greenhouse")
	if not _system_incident_faulted:
		_update_crop_growth(delta)
	_update_port_markers()
	_update_prompt()


func _update_greenhouse_oxygen(delta: float) -> void:
	if delta <= 0.0:
		return
	var produced := _get_plant_oxygen_per_second() * delta
	var lost := get_oxygen_loss_rate() * delta
	oxygen_reserve = clampf(oxygen_reserve + produced - lost, 0.0, GREENHOUSE_OXYGEN_CAPACITY)
	_oxygen_produced_units += produced


func _get_plant_oxygen_per_second() -> float:
	if not _planted:
		return 0.0
	var clock := get_node_or_null("/root/WorldClock")
	# At night, plants produce only while the greenhouse is grid-lit.
	if clock != null and not bool(clock.call("is_day")) and not powered:
		return 0.0
	var stage_factor: float = float([0.18, 0.42, 0.68, 0.86, 1.0][maxi(0, get_crop_stage())])
	return PLOT_COUNT * POTATO_OXYGEN_PER_SECOND * stage_factor


func _update_crop_growth(delta: float) -> void:
	if _system_incident_faulted or not _planted or _ready_to_harvest or delta <= 0.0 or not _ensure_water_network_category():
		return
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null:
		return
	var game_hours := float(clock.call("get_game_hours_for_real_delta", delta))
	var requested_water := WATER_L_PER_GAME_HOUR * game_hours
	if requested_water <= 0.0:
		return
	var pipe_manager := get_node_or_null("/root/PipeManager")
	if pipe_manager == null:
		return
	var supplied_water := float(pipe_manager.call("consume_connected_resource", _water_input_cell, Vector2i.RIGHT, PipeSegment.Category.WATER, requested_water))
	if supplied_water <= 0.0:
		return
	var supplied_fraction := clampf(supplied_water / requested_water, 0.0, 1.0)
	_water_consumed_liters += supplied_water
	if _remaining_growth_seconds <= 0.0:
		_remaining_growth_seconds = maxf(0.0, _cycle_duration() - _growth_seconds)
	var genetic_speed_multiplier := 1.0 + float(_crop_seed_speed_level) * 0.15
	var growth_work := delta * supplied_fraction * (POWERED_TIME_MULTIPLIER if powered else 1.0) * _get_crop_achievement_multiplier() * genetic_speed_multiplier
	_growth_seconds = minf(_cycle_duration(), _growth_seconds + growth_work)
	_remaining_growth_seconds = maxf(0.0, _remaining_growth_seconds - growth_work)
	if _remaining_growth_seconds <= 0.001:
		_growth_seconds = _cycle_duration()
		_remaining_growth_seconds = 0.0
		_ready_to_harvest = true
	_refresh_crop_visuals()


func _plant_crop(seed_lot: Dictionary = {}, is_replacement: bool = false) -> void:
	_planted = true
	_ready_to_harvest = false
	_completed_cycles = 0
	_growth_seconds = 0.0
	_remaining_growth_seconds = _cycle_duration()
	var configuration: Dictionary = seed_lot.get("configuration", {})
	_crop_seed_yield_level = clampi(int(configuration.get("yield_level", 0)), 0, 5)
	_crop_seed_speed_level = clampi(int(configuration.get("speed_level", 0)), 0, 5)
	_harvest_food = _roll_harvest_food()
	_record_achievement("first_planting")
	if is_replacement:
		_record_achievement("genetic_replacement")
	_refresh_crop_visuals()


func _try_harvest_nearby() -> bool:
	if not _ready_to_harvest:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not contains_world_point(player.global_position) or player.global_position.distance_to(global_position) > 66.0:
		return false
	var inventory := _inventory()
	if inventory != null and bool(inventory.call("add_item", "food_ration", "Potato Rations", get_harvest_food(), false)):
		_ready_to_harvest = false
		_completed_cycles += 1
		_growth_seconds = 0.0
		_remaining_growth_seconds = _cycle_duration()
		_harvest_food = _roll_harvest_food()
		_record_achievement("first_harvest")
		_refresh_crop_visuals()
		return true
	return false


func _cycle_duration() -> float:
	return FIRST_CYCLE_SECONDS if _completed_cycles == 0 else REGROWTH_SECONDS


func get_harvest_food() -> int:
	return _harvest_food


func _roll_harvest_food() -> int:
	# Every base lot yields 4 or 5 rations with equal probability. Genetic bonus
	# applies after the roll, remains tied to that lot, and never retroactively
	# changes when the shop unlocks a new level.
	var base_amount := HARVEST_FOOD if _rng.randi_range(0, 1) == 1 else HARVEST_FOOD - 1
	return maxi(1, roundi(float(base_amount) * (1.0 + float(_crop_seed_yield_level) * 0.20)))


func get_crop_seed_configuration() -> Dictionary:
	return {"yield_level": _crop_seed_yield_level, "speed_level": _crop_seed_speed_level}


func _refresh_crop_visuals() -> void:
	var stage := get_crop_stage()
	# Supplied sprites show only the plant: remove the JPEG background before
	# atlasing so soil and pot always remain visible beneath.
	var sheet: Texture2D = TRANSPARENCY.without_white_background(FIRST_GROWTH_SHEET if _completed_cycles == 0 else REGROWTH_SHEET)
	var frame_count := 5 if _completed_cycles == 0 else 4
	for crop in _crop_sprites:
		crop.visible = _planted
		if _planted and stage >= 0:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(clampi(stage, 0, frame_count - 1) * TILE_SIZE, 0.0, TILE_SIZE, TILE_SIZE)
			crop.texture = frame


func _format_crop_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _inventory() -> Node:
	return get_node_or_null("/root/Inventory")


func _get_crop_achievement_multiplier() -> float:
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("get_crop_growth_multiplier"):
		return float(achievements.call("get_crop_growth_multiplier"))
	return 1.0


func get_machine_specs() -> Dictionary:
	var power_state := "FAULT — REPAIR REQUIRED" if _system_incident_faulted else ("ACTIVE (+60% growth)" if powered else ("enabled, awaiting grid" if network_enabled else "manually disabled"))
	var specs := [
		"Left water pipe: %s" % ("connected" if is_water_connected() else "not connected"),
		"Water source: %s" % ("available" if has_water_source() else "absent or off-grid"),
		"Power: %s · %.0f kW" % [power_state, get_power_demand_kw()],
		"Greenhouse O₂: %.1f / %.0f (plants %.3f units/s)" % [oxygen_reserve, GREENHOUSE_OXYGEN_CAPACITY, _get_plant_oxygen_per_second()],
		"Crop: %s" % ("ready" if _ready_to_harvest else (_format_crop_time(get_remaining_growth_seconds()) if _planted else "needs planting")),
		"Water used: %.1f L" % _water_consumed_liters,
		"Lot genetics: yield %d/5 · speed %d/5" % [_crop_seed_yield_level, _crop_seed_speed_level],
		"Harvest: %d rations" % get_harvest_food(),
	]
	return {
		"title": "POTATO GREENHOUSE",
		"category": "PRESSURIZED AGRICULTURE",
		"status": "FAULT — REPAIR REQUIRED" if _system_incident_faulted else ("HARVEST READY" if _ready_to_harvest else ("GROWING" if _planted else "EMPTY BEDS")),
		"status_color": Color("ff6258") if _system_incident_faulted else (Color("72eda0") if _ready_to_harvest else Color("8cd9ff")),
		"principle": "Two beds of eight plants grow one synchronized potato lot. First growth takes 5 minutes; later cycles take 3 minutes.",
		"specs": specs,
	}


func set_incident_faulted(target_id: String, value: bool) -> void:
	if target_id in ["outer_door", "inner_door"]:
		super.set_incident_faulted(target_id, value)
		return
	if target_id != "greenhouse_system" or _system_incident_faulted == value:
		return
	_system_incident_faulted = value
	if value:
		set_powered(false)
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")


func is_incident_faulted(target_id: String) -> bool:
	if target_id in ["outer_door", "inner_door"]:
		return super.is_incident_faulted(target_id)
	return _system_incident_faulted if target_id == "greenhouse_system" else false


func is_incident_operational() -> bool:
	return not _system_incident_faulted


func can_receive_incident(target_id: String) -> bool:
	if target_id in ["outer_door", "inner_door"]:
		return super.can_receive_incident(target_id)
	return not is_preview and target_id == "greenhouse_system" and not _system_incident_faulted


func get_incident_repair_position(target_id: String) -> Vector2:
	if target_id in ["outer_door", "inner_door"]:
		return super.get_incident_repair_position(target_id)
	return global_position


func get_sand_accumulation() -> int:
	return _sand_accumulation


func set_sand_accumulation(level: int) -> void:
	var clamped := clampi(level, 0, 3)
	if _sand_accumulation == clamped:
		return
	_sand_accumulation = clamped
	var dome_sprite := get_node_or_null("DomeSprite") as Sprite2D
	if dome_sprite != null:
		dome_sprite.modulate = Color.WHITE if clamped <= 0 else Color(1.0, 0.82 - float(clamped) * 0.09, 0.62 - float(clamped) * 0.10)


func get_sand_clean_position() -> Vector2:
	return global_position


func on_sand_buried() -> void:
	var incidents := get_node_or_null("/root/IncidentManager")
	if incidents != null:
		incidents.call("force_incident", self, "greenhouse_system")
