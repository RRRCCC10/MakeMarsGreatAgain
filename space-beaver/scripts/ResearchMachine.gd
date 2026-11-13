class_name ResearchMachine
extends Node2D

## Strumenti scientifici trasportati in qualunque cupola abitativa. Ogni analisi consuma
## un singolo campione di roccia e genera un rapporto da trasmettere alla Terra.

const TILE_SIZE := 16
const ROCK_RESOURCE := preload("res://scripts/rock.gd")
const INTERACTION_DISTANCE := 58.0
const ANIMATION_FRAME_SECONDS := 0.16
const REPORT_TRANSMISSION_SECONDS := 4.0
const MAX_UPGRADE_LEVEL := 5
const FINAL_UPGRADED_ANALYSIS_SECONDS := 40.0
const ANALYSIS_POWER_DEMAND_KW := 240.0
const ANCIENT_LIFE_REPORT_BONUS := 10_000_000_000
const UPGRADE_COSTS: Array[int] = [175_000_000, 250_000_000, 350_000_000, 500_000_000, 700_000_000]

const DEFINITIONS := {
	"xrd_diffractometer": {
		"name": "Diffrattometro a raggi X",
		"short_name": "DIFFRATTOMETRO XRD",
		"size": Vector2i(32, 16),
		"seconds": 150.0,
		"reward": 450_000_000,
		"biosignature_chance": 0.20,
		"principle": "La diffrazione dei raggi X identifica le fasi cristalline del campione dalla geometria del reticolo atomico.",
	},
	"raman_spectrometer": {
		"name": "Spettrometro Raman",
		"short_name": "SPETTROMETRO RAMAN",
		"size": Vector2i(32, 16),
		"seconds": 180.0,
		"reward": 600_000_000,
		"biosignature_chance": 0.35,
		"principle": "Lo scattering Raman del laser rivela i legami molecolari e la composizione mineralogica senza distruggere il campione.",
	},
	"icp_ms": {
		"name": "Spettrometro ICP-MS",
		"short_name": "ICP-MS",
		"size": Vector2i(48, 16),
		"seconds": 240.0,
		"reward": 900_000_000,
		"biosignature_chance": 0.55,
		"principle": "Il plasma accoppiato induttivamente ionizza il campione; lo spettrometro di massa misura gli elementi e le loro abbondanze.",
	},
}

enum State { IDLE, ANALYZING, COMPLETE }

static var texture_cache: Dictionary = {}

var machine_id := ""
var is_preview := false
var placement_rotation := 0
var state := State.IDLE
var upgrade_level := 0
var network_enabled := true
var powered := false
var study_elapsed := 0.0
var report_elapsed := 0.0
var animation_elapsed := 0.0
var animation_frame := 0
var sample_name := ""
var sample_id := ""
var sample_biome := ""
var sample_rarity := ""
var sample_research_multiplier := 1.0
var sample_is_primordial_ice := false
var biosignature_chance := 0.0
var ancient_life_detected := false
var last_report_reward := 0
var sprite: Sprite2D
var physics_body: StaticBody2D
var interaction_label: Label
var _life_rng := RandomNumberGenerator.new()


func setup(new_machine_id: String, preview: bool = false, new_placement_rotation: int = 0) -> void:
	machine_id = new_machine_id
	is_preview = preview
	placement_rotation = posmod(new_placement_rotation, 4)
	if is_node_ready():
		_apply_placement_rotation()
		_refresh_visual()


static func get_definition(new_machine_id: String) -> Dictionary:
	return DEFINITIONS.get(new_machine_id, {}).duplicate(true)


static func get_icon_texture(machine_id_value: String) -> Texture2D:
	return _texture_for_state(machine_id_value, State.IDLE)


static func _texture_for_state(machine_id_value: String, machine_state: State) -> Texture2D:
	var state_key := "idle"
	if machine_state == State.ANALYZING:
		state_key = "active"
	elif machine_state == State.COMPLETE:
		state_key = "complete"
	var resource_path := "res://assets/research/%s_%s.png" % [_asset_prefix_for(machine_id_value), state_key]
	if texture_cache.has(resource_path):
		return texture_cache[resource_path] as Texture2D
	# Gli sprite vengono letti direttamente dal PNG: il gioco non dipende dalla
	# cache .godot/imported, che può non esistere alla prima apertura del progetto.
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		push_error("Impossibile caricare lo sprite di ricerca: %s" % resource_path)
		return null
	var texture := ImageTexture.create_from_image(image)
	texture_cache[resource_path] = texture
	return texture


static func _asset_prefix_for(machine_id_value: String) -> String:
	match machine_id_value:
		"xrd_diffractometer":
			return "xrd"
		"raman_spectrometer":
			return "raman"
		"icp_ms":
			return "icp_ms"
	return "xrd"


static func rotated_size_for(machine_id_value: String, new_placement_rotation: int = 0) -> Vector2i:
	var size: Vector2i = get_definition(machine_id_value).get("size", Vector2i(TILE_SIZE, TILE_SIZE))
	return Vector2i(size.y, size.x) if posmod(new_placement_rotation, 2) == 1 else size


static func world_position_for(machine_id_value: String, cell: Vector2i, new_placement_rotation: int = 0) -> Vector2:
	var size := rotated_size_for(machine_id_value, new_placement_rotation)
	return Vector2(cell * TILE_SIZE) + Vector2(float(size.x) * 0.5, float(size.y) * 0.5)


static func footprint_rect_for(machine_id_value: String, world_position: Vector2, new_placement_rotation: int = 0) -> Rect2:
	var size := rotated_size_for(machine_id_value, new_placement_rotation)
	var dimensions := Vector2(size)
	return Rect2(world_position - dimensions * 0.5, dimensions)


static func can_place_at(machine_id_value: String, world_position: Vector2, new_placement_rotation: int = 0) -> bool:
	if not DEFINITIONS.has(machine_id_value):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var footprint := footprint_rect_for(machine_id_value, world_position, new_placement_rotation)
	var host_dome: Node2D
	for dome in tree.get_nodes_in_group("base_domes"):
		# Tutte le cupole abitative sono locali tecnici validi. La serra usa la
		# stessa infrastruttura della cupola, ma le aiuole non devono venire
		# occupate da laboratori o macchinari.
		if not dome is Node2D or dome.is_in_group("greenhouses"):
			continue
		var dome_node := dome as Node2D
		if _footprint_is_inside_dome(footprint, dome_node):
			host_dome = dome_node
			break
	if host_dome == null:
		return false
	var player := tree.get_first_node_in_group("player") as Node2D
	if player != null and footprint.grow(12.0).has_point(player.global_position):
		return false
	for rock in tree.get_nodes_in_group("collectible_rocks"):
		if rock is Node2D and footprint.grow(13.0).has_point((rock as Node2D).global_position):
			return false
	var registry := tree.root.get_node_or_null("BuildableRegistry")
	if registry == null:
		return true
	for entry in registry.call("get_entries"):
		var other := entry.get("node") as Node2D
		if other == null or not is_instance_valid(other) or other == host_dome:
			continue
		if other.has_method("get_footprint_rect") and footprint.intersects(other.call("get_footprint_rect")):
			return false
		if other.has_method("contains_world_point"):
			for point in _footprint_samples(footprint):
				if bool(other.call("contains_world_point", point)):
					return false
	return true


static func _footprint_is_inside_dome(footprint: Rect2, dome: Node2D) -> bool:
	if not dome.has_method("contains_world_point"):
		return false
	for point in _footprint_samples(footprint):
		if not bool(dome.call("contains_world_point", point)):
			return false
	return true


static func _footprint_samples(footprint: Rect2) -> Array[Vector2]:
	var inset := Vector2(1.0, 1.0)
	return [
		footprint.get_center(),
		footprint.position + inset,
		Vector2(footprint.end.x, footprint.position.y) - inset,
		Vector2(footprint.position.x, footprint.end.y) + Vector2(1.0, -1.0),
		footprint.end - inset,
	]


static func place(parent: Node, new_machine_id: String, cell: Vector2i, new_placement_rotation: int = 0) -> Node2D:
	var target := world_position_for(new_machine_id, cell, new_placement_rotation)
	if not can_place_at(new_machine_id, target, new_placement_rotation):
		return null
	var machine := ResearchMachine.new()
	machine.setup(new_machine_id, false, new_placement_rotation)
	parent.add_child(machine)
	machine.global_position = target
	var achievements := parent.get_node_or_null("/root/AchievementManager")
	if achievements != null:
		achievements.call("record", "first_lab")
	return machine


func _ready() -> void:
	z_index = 3
	_life_rng.randomize()
	sprite = Sprite2D.new()
	sprite.name = "ResearchSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_apply_placement_rotation()
	_refresh_visual()
	if is_preview:
		return
	add_to_group("research_machines")
	_setup_collision()
	_setup_interaction_label()
	var registry := get_node_or_null("/root/BuildableRegistry")
	if registry != null:
		registry.call("register_buildable", self, get_display_name(), "research", Callable(self, "pickup"))
	call_deferred("_register_power_consumer")


func _exit_tree() -> void:
	if not is_preview:
		var power_grid := get_node_or_null("/root/PowerGrid")
		if power_grid != null:
			power_grid.call("unregister_consumer", self)
		var registry := get_node_or_null("/root/BuildableRegistry")
		if registry != null:
			registry.call("unregister_buildable", self)


func _process(delta: float) -> void:
	if is_preview:
		return
	if state == State.ANALYZING:
		# I laboratori ad alta precisione lavorano soltanto con la rete attiva:
		# mentre analizzano richiedono 240 kW, più di due pannelli solari.
		if powered:
			study_elapsed = minf(get_analysis_seconds(), study_elapsed + maxf(delta, 0.0))
		if study_elapsed >= get_analysis_seconds():
			state = State.COMPLETE
			report_elapsed = 0.0
			animation_elapsed = 0.0
			animation_frame = 0
			_refresh_visual()
			_register_power_consumer()
	elif state == State.COMPLETE:
		_animation_step(delta)
		report_elapsed += maxf(delta, 0.0)
		if report_elapsed >= REPORT_TRANSMISSION_SECONDS:
			_deliver_report()
	_update_interaction_label()
	if state == State.ANALYZING:
		if powered:
			_animation_step(delta)


func _animation_step(delta: float) -> void:
	animation_elapsed += delta
	if animation_elapsed < ANIMATION_FRAME_SECONDS:
		return
	animation_elapsed = 0.0
	animation_frame = (animation_frame + 1) % 4
	_refresh_visual()


func _setup_collision() -> void:
	physics_body = StaticBody2D.new()
	physics_body.name = "ResearchMachineCollision"
	physics_body.collision_layer = 1
	physics_body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = get_footprint_rect().size
	collision.shape = shape
	physics_body.add_child(collision)
	add_child(physics_body)


func _setup_interaction_label() -> void:
	interaction_label = Label.new()
	interaction_label.name = "ResearchPrompt"
	interaction_label.position = Vector2(-86.0, -35.0)
	interaction_label.size = Vector2(172.0, 28.0)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_label.add_theme_font_size_override("font_size", 10)
	interaction_label.add_theme_color_override("font_color", Color("dff7ff"))
	interaction_label.add_theme_color_override("font_outline_color", Color("071118"))
	interaction_label.add_theme_constant_override("outline_size", 3)
	add_child(interaction_label)


func _update_interaction_label() -> void:
	if interaction_label == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var nearby := player != null and player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE
	interaction_label.visible = nearby and not _is_modal_ui_open()
	if interaction_label.visible:
		interaction_label.text = get_prompt_for_player(player)


func get_display_name() -> String:
	return str(get_definition(machine_id).get("name", "Laboratorio scientifico"))


func get_footprint_rect() -> Rect2:
	return footprint_rect_for(machine_id, global_position, placement_rotation)


func contains_world_point(world_position: Vector2) -> bool:
	return get_footprint_rect().grow(4.0).has_point(world_position)


func get_occupied_power_cells() -> Array[Vector2i]:
	var rect := get_footprint_rect()
	var cells: Array[Vector2i] = []
	var min_cell := Vector2i(floori(rect.position.x / TILE_SIZE), floori(rect.position.y / TILE_SIZE))
	var max_cell := Vector2i(floori((rect.end.x - 0.1) / TILE_SIZE), floori((rect.end.y - 0.1) / TILE_SIZE))
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func get_analysis_seconds() -> float:
	var base_seconds := float(get_definition(machine_id).get("seconds", 180.0))
	return lerpf(base_seconds, FINAL_UPGRADED_ANALYSIS_SECONDS, float(upgrade_level) / float(MAX_UPGRADE_LEVEL))


func get_base_analysis_seconds() -> float:
	return float(get_definition(machine_id).get("seconds", 180.0))


func get_power_connection_cell() -> Vector2i:
	# I laboratori stanno dentro una cupola abitativa, dove i cavi non devono
	# attraversare pavimento e pareti. Usano perciò il raccordo elettrico esterno
	# della cupola che li ospita: il loro assorbimento resta comunque separato.
	var host_dome := _get_host_base_dome()
	if host_dome != null and host_dome.has_method("get_power_connection_cell"):
		return Vector2i(host_dome.call("get_power_connection_cell"))
	var footprint := get_footprint_rect()
	return Vector2i(floori((footprint.position.x - TILE_SIZE * 0.5) / TILE_SIZE), floori(global_position.y / TILE_SIZE))


func get_power_attach_direction() -> Vector2i:
	var host_dome := _get_host_base_dome()
	if host_dome != null and host_dome.has_method("get_power_attach_direction"):
		return Vector2i(host_dome.call("get_power_attach_direction"))
	return Vector2i.RIGHT


func get_power_demand_kw() -> float:
	return ANALYSIS_POWER_DEMAND_KW if state == State.ANALYZING else 0.0


func set_network_enabled(value: bool) -> void:
	if is_preview or network_enabled == value:
		return
	network_enabled = value
	if not network_enabled:
		set_powered(false)
	_register_power_consumer()


func is_network_enabled() -> bool:
	return network_enabled


func set_powered(value: bool) -> void:
	powered = value and network_enabled


func get_power_connection_label() -> String:
	if not network_enabled:
		return "RETE DISATTIVATA"
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid == null:
		return "RETE NON DISPONIBILE"
	return "COLLEGATO ALLA RETE" if bool(power_grid.get("connection_ok").get(self, false)) else "CAVO ELETTRICO NON COLLEGATO"


func get_reward() -> int:
	# Dopo la consegna la UI e i chiamanti possono ancora chiedere quale fosse il
	# valore del rapporto appena spedito: non perdiamo quel dato azzerando il
	# campione nella transizione allo stato IDLE.
	if state == State.IDLE and sample_id.is_empty() and last_report_reward > 0:
		return last_report_reward
	var multiplier := 1.0
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("get_research_reward_multiplier"):
		multiplier = float(achievements.call("get_research_reward_multiplier", machine_id, sample_rarity))
	# Il valore della ricerca appartiene al campione, non soltanto alla macchina:
	# una scoperta rara estratta in un bioma remoto genera un rapporto più utile.
	var reward := roundi(float(get_definition(machine_id).get("reward", 0)) * sample_research_multiplier * multiplier)
	if sample_is_primordial_ice and ancient_life_detected:
		reward += ANCIENT_LIFE_REPORT_BONUS
	return reward


func get_biosignature_chance() -> float:
	return float(get_definition(machine_id).get("biosignature_chance", 0.20)) if sample_is_primordial_ice else 0.0


func get_remaining_seconds() -> float:
	return maxf(0.0, get_analysis_seconds() - study_elapsed)


func get_prompt_for_player(_player: Node2D) -> String:
	if state == State.ANALYZING:
		var analysis_status := "%s · analisi %s" % [str(get_definition(machine_id).get("short_name", "RICERCA")), _format_time(get_remaining_seconds())]
		if sample_is_primordial_ice:
			analysis_status += "\nSCANSIONE BIOSIGNATURE · probabilità %.0f%%" % (biosignature_chance * 100.0)
		return analysis_status if powered else analysis_status + "\nIN PAUSA · COLLEGA 240 kW"
	if state == State.COMPLETE:
		var report_header := "BIOSIGNATURA RILEVATA" if sample_is_primordial_ice and ancient_life_detected else "RAPPORTO PRONTO"
		return "%s · invio Terra %s\nE · INVIA ORA · %s" % [report_header, _format_time(maxf(0.0, REPORT_TRANSMISSION_SECONDS - report_elapsed)), _format_money(get_reward())]
	if upgrade_level >= MAX_UPGRADE_LEVEL:
		return "E · ANALIZZA UNA PIETRA\nUPGRADE MASSIMO · 40 s"
	var inventory := get_node_or_null("/root/Inventory")
	var upgrade_line := "U · UPGRADE %d→%d · %s" % [upgrade_level, upgrade_level + 1, _format_money(get_next_upgrade_cost())]
	if inventory != null:
		var available_sample: Dictionary = inventory.call("get_first_rock_sample")
		if not available_sample.is_empty():
			return "E · ANALIZZA UNA PIETRA\n" + upgrade_line
	return "PORTA UNA PIETRA AL LABORATORIO\n" + upgrade_line


func try_interact(player: Node2D) -> bool:
	if is_preview or player == null or player.global_position.distance_to(global_position) > INTERACTION_DISTANCE:
		return false
	if state == State.COMPLETE:
		_deliver_report()
		return true
	if state != State.IDLE:
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null:
		return false
	var sample: Dictionary = inventory.call("take_first_rock_sample")
	if sample.is_empty():
		return false
	sample_id = str(sample.get("id", ""))
	sample_name = str(sample.get("name", "Pietra"))
	var sample_definition: Dictionary = ROCK_RESOURCE.definition_for_item_id(sample_id)
	sample_biome = str(sample_definition.get("biome", "Provenienza non catalogata"))
	sample_rarity = str(sample_definition.get("rarity", "common"))
	sample_research_multiplier = maxf(0.1, float(sample_definition.get("research_multiplier", 1.0)))
	sample_is_primordial_ice = bool(sample_definition.get("deep_ice", false))
	biosignature_chance = get_biosignature_chance()
	ancient_life_detected = sample_is_primordial_ice and _life_rng.randf() < biosignature_chance
	if sample_is_primordial_ice:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null and achievements.has_method("record_deep_ice_study"):
			achievements.call("record_deep_ice_study")
	state = State.ANALYZING
	study_elapsed = 0.0
	animation_elapsed = 0.0
	animation_frame = 0
	_refresh_visual()
	_register_power_consumer()
	return true


func get_next_upgrade_cost() -> int:
	if upgrade_level < 0 or upgrade_level >= MAX_UPGRADE_LEVEL:
		return 0
	return UPGRADE_COSTS[upgrade_level]


func try_upgrade(player: Node2D) -> bool:
	if is_preview or player == null or player.global_position.distance_to(global_position) > INTERACTION_DISTANCE:
		return false
	# Non cambiamo la calibrazione nel mezzo di un esperimento già avviato.
	if state != State.IDLE or upgrade_level >= MAX_UPGRADE_LEVEL:
		return false
	var economy := get_node_or_null("/root/Economy")
	var cost := get_next_upgrade_cost()
	if economy == null or cost <= 0 or not bool(economy.call("spend", cost)):
		return false
	upgrade_level += 1
	if upgrade_level >= MAX_UPGRADE_LEVEL:
		var achievements := get_node_or_null("/root/AchievementManager")
		if achievements != null:
			match machine_id:
				"xrd_diffractometer":
					achievements.call("record", "xrd_master")
				"raman_spectrometer":
					achievements.call("record", "raman_master")
				"icp_ms":
					achievements.call("record", "icp_master")
	return true


func _deliver_report() -> void:
	if state != State.COMPLETE:
		return
	var report_reward := get_reward()
	var economy := get_node_or_null("/root/Economy")
	if economy != null:
		economy.call("add_funds", report_reward)
	last_report_reward = report_reward
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null:
		# Un rapporto non è solo una vendita: alimenta le campagne scientifiche
		# della tavola obiettivi (biomi, rarità, strumenti e trasmissioni).
		if achievements.has_method("record_research_report"):
			achievements.call("record_research_report", machine_id, sample_id, sample_biome, sample_rarity)
		else:
			achievements.call("record", "first_report")
		if ancient_life_detected and achievements.has_method("record_ancient_life_discovery"):
			achievements.call("record_ancient_life_discovery")
	state = State.IDLE
	study_elapsed = 0.0
	report_elapsed = 0.0
	animation_elapsed = 0.0
	animation_frame = 0
	sample_id = ""
	sample_name = ""
	sample_biome = ""
	sample_rarity = ""
	sample_research_multiplier = 1.0
	sample_is_primordial_ice = false
	biosignature_chance = 0.0
	ancient_life_detected = false
	_refresh_visual()
	_register_power_consumer()


func pickup() -> bool:
	if state != State.IDLE:
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not bool(inventory.call("add_item", machine_id, get_display_name(), 1, true)):
		return false
	queue_free()
	return true


func get_machine_specs() -> Dictionary:
	var status := "PRONTO AD ANALIZZARE"
	var detail := "in attesa di un campione"
	var color := Color("8cd9ff")
	if state == State.ANALYZING:
		status = "ANALISI IN CORSO" if powered else "ANALISI IN PAUSA · RETE ASSENTE"
		detail = "%s · %s · %s · restano %s" % [sample_name, sample_biome, _rarity_label(), _format_time(get_remaining_seconds())]
		if sample_is_primordial_ice:
			detail += " · biosignature %.0f%%" % (biosignature_chance * 100.0)
		color = Color("ffe38a")
	elif state == State.COMPLETE:
		status = "BIOSIGNATURA RILEVATA" if ancient_life_detected else "RAPPORTO PRONTO"
		detail = "%s · %s · %s · invio Terra tra %s · %s" % [sample_name, sample_biome, _rarity_label(), _format_time(maxf(0.0, REPORT_TRANSMISSION_SECONDS - report_elapsed)), _format_money(get_reward())]
		color = Color("7fffd4") if ancient_life_detected else Color("72eda0")
	var research_multiplier := 1.0
	var contracts := "in attesa del primo rapporto"
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null:
		if achievements.has_method("get_research_reward_multiplier"):
			research_multiplier = float(achievements.call("get_research_reward_multiplier", machine_id, sample_rarity))
		if achievements.has_method("get_research_contract_summary"):
			contracts = str(achievements.call("get_research_contract_summary", machine_id))
	return {
		"title": get_display_name().to_upper(),
		"category": "RICERCA SCIENTIFICA · CUPOLA ABITATIVA",
		"status": status,
		"status_color": color,
		"principle": str(get_definition(machine_id).get("principle", "")),
		"specs": ["Campione: %s" % detail, "Valore campione: ×%.2f · contratti: ×%.2f" % [sample_research_multiplier, research_multiplier], "Biosignature: %s" % ("RILEVATA · bonus %s" % _format_money(ANCIENT_LIFE_REPORT_BONUS) if ancient_life_detected else ("possibilità %.0f%%" % (biosignature_chance * 100.0) if sample_is_primordial_ice else "non applicabile")), "Contratti Terra: %s" % contracts, "Upgrade: livello %d/%d" % [upgrade_level, MAX_UPGRADE_LEVEL], "Durata analisi: %s (base %s, massimo upgrade: 0:40)" % [_format_time(get_analysis_seconds()), _format_time(get_base_analysis_seconds())], "Prossimo upgrade: %s" % ("MASSIMO" if upgrade_level >= MAX_UPGRADE_LEVEL else _format_money(get_next_upgrade_cost())), "Assorbimento analisi: %.0f kW" % ANALYSIS_POWER_DEMAND_KW, "Rete: %s" % get_power_connection_label(), "Ricompensa rapporto: %s" % _format_money(get_reward()), "E: pietra / rapporto · U: upgrade"],
	}


func _rarity_label() -> String:
	if sample_rarity == "ultra_rare":
		return "ULTRA RARO"
	return "RARO" if sample_rarity == "rare" else "COMUNE"


func _refresh_visual() -> void:
	if sprite == null:
		return
	var definition := get_definition(machine_id)
	if definition.is_empty():
		return
	if state == State.IDLE:
		sprite.texture = _texture_for_state(machine_id, State.IDLE)
		return
	var sheet := _texture_for_state(machine_id, state)
	if sheet == null:
		return
	var footprint_size: Vector2i = definition.get("size", Vector2i(TILE_SIZE, TILE_SIZE))
	var frame_width := footprint_size.x
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(animation_frame * frame_width, 0.0, frame_width, TILE_SIZE)
	sprite.texture = frame


func _apply_placement_rotation() -> void:
	rotation = float(placement_rotation) * PI * 0.5


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _format_money(amount: int) -> String:
	var economy := get_node_or_null("/root/Economy")
	if economy != null and economy.has_method("format_money"):
		return str(economy.call("format_money", amount))
	return "$ %d" % amount


func _is_modal_ui_open() -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and bool(ui_state.call("blocks_world_actions")):
		return true
	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and bool(inventory.get("is_open")):
		return true
	var shop := get_node_or_null("/root/Shop")
	if shop != null and bool(shop.get("is_open")):
		return true
	var registry := get_node_or_null("/root/BuildableRegistry")
	return registry != null and bool(registry.get("is_modal_open"))


func _register_power_consumer() -> void:
	if is_preview or not is_inside_tree():
		return
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("register_consumer", self, get_power_connection_cell(), get_power_demand_kw(), get_power_attach_direction())


func _get_host_base_dome() -> Node2D:
	if not is_inside_tree():
		return null
	for dome in get_tree().get_nodes_in_group("base_domes"):
		if dome is Node2D and not dome.is_in_group("greenhouses") and dome.has_method("contains_world_point"):
			if bool(dome.call("contains_world_point", global_position)):
				return dome as Node2D
	return null
