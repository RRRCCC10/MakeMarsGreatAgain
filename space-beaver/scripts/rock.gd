extends Node2D

const BASE_ROCK_TEXTURE := preload("res://assets/sprites/rock.png")
const ROCK_TEXTURES: Dictionary = {
	"baseline_stone": BASE_ROCK_TEXTURE,
	"cryogenic_rock": preload("res://assets/sprites/rocks/cryogenic_rock.png"),
	"impact_glass": preload("res://assets/sprites/rocks/impact_glass.png"),
	"basaltic_rock": preload("res://assets/sprites/rocks/basaltic_rock.png"),
	"crater_stone": preload("res://assets/sprites/rocks/crater_stone.png"),
	"deep_ice": preload("res://assets/sprites/rocks/deep_ice.png"),
	"red_regolith": preload("res://assets/sprites/rocks/red_regolith.png"),
	"ferric_stone": preload("res://assets/sprites/rocks/ferric_stone.png"),
	"dusty_ice": preload("res://assets/sprites/rocks/dusty_ice.png"),
	"blue_ice": preload("res://assets/sprites/rocks/blue_ice.png"),
	"black_basalt": preload("res://assets/sprites/rocks/black_basalt.png"),
}

## New minerals intentionally reuse existing silhouettes: at this pixel-art
## scale, name, rarity, and scientific value convey geological provenance
## without introducing inconsistent sprites.
const ROCK_TEXTURE_VARIANTS: Dictionary = {
	"martian_andesite": "crater_stone",
	"olivine_shoshonite": "black_basalt",
	"nodular_hematite": "ferric_stone",
	"hydrated_goethite": "cryogenic_rock",
	"impact_breccia": "crater_stone",
	"glassy_impactite": "impact_glass",
	"perchlorate_regolith": "cryogenic_rock",
	"hydrated_sulfate_salts": "deep_ice",
	"layered_ice": "dusty_ice",
	"briny_ice": "blue_ice",
	"primordial_deep_ice": "deep_ice",
	"vesicular_basalt": "basaltic_rock",
	"ferric_olivine": "black_basalt",
}
static var base_rock_material: ShaderMaterial

## Every pair is tied to a concrete geological formation on the map. Item IDs
## remain distinct: identical samples stack together while rare ones stay apart.
const ROCK_DEFINITIONS: Dictionary = {
	"baseline_stone": {
		"item_id": "rock", "name": "Martian Stone", "biome": "Landing Sand", "rarity": "common", "research_multiplier": 0.55, "drill_biome": 0,
	},
	"red_regolith": {
		"item_id": "rock_red_regolith", "name": "Red Regolith", "biome": "Ares Plain", "rarity": "common", "research_multiplier": 0.80, "drill_biome": 1,
	},
	"ferric_stone": {
		"item_id": "rock_ferric_stone", "name": "Ferric Stone", "biome": "Ares Plain", "rarity": "rare", "research_multiplier": 1.35,
	},
	"dusty_ice": {
		"item_id": "rock_dusty_ice", "name": "Dusty Ice", "biome": "Polar Core", "rarity": "common", "research_multiplier": 1.00, "drill_biome": 4,
	},
	"blue_ice": {
		"item_id": "rock_blue_ice", "name": "Compact Blue Ice", "biome": "Polar Core", "rarity": "rare", "research_multiplier": 1.70,
	},
	"crater_stone": {
		"item_id": "rock_crater_stone", "name": "Crater Stone", "biome": "Impact Craters", "rarity": "common", "research_multiplier": 0.95, "drill_biome": 2,
	},
	"impact_glass": {
		"item_id": "rock_impact_glass", "name": "Impact Glass", "biome": "Impact Craters", "rarity": "rare", "research_multiplier": 1.85,
	},
	"basaltic_rock": {
		"item_id": "rock_basaltic_rock", "name": "Basaltic Rock", "biome": "Basalt Formation", "rarity": "common", "research_multiplier": 1.10, "drill_biome": 5,
	},
	"black_basalt": {
		"item_id": "rock_black_basalt", "name": "Black Basalt", "biome": "Basalt Formation", "rarity": "rare", "research_multiplier": 1.65,
	},
	"cryogenic_rock": {
		"item_id": "rock_cryogenic_rock", "name": "Cryogenic Rock", "biome": "Ice-Cap Edge", "rarity": "common", "research_multiplier": 1.20, "drill_biome": 3,
	},
	"deep_ice": {
		"item_id": "rock_deep_ice", "name": "Deep Ice", "biome": "Ice-Cap Edge", "rarity": "rare", "research_multiplier": 1.90,
	},
	"primordial_deep_ice": {
		"item_id": "rock_primordial_deep_ice", "name": "Primordial Deep-Ice Sample (model)", "biome": "Deep Martian Layers", "rarity": "ultra_rare", "research_multiplier": 4.50, "deep_ice": true,
	},
	# New mining-drill samples: two common samples and a 5% discovery for each
	# of the map's six biomes.
	"martian_andesite": {
		"item_id": "rock_martian_andesite", "name": "Martian Andesite", "biome": "Landing Plain", "rarity": "common", "research_multiplier": 0.70, "drill_biome": 0,
	},
	"olivine_shoshonite": {
		"item_id": "rock_olivine_shoshonite", "name": "Olivine Shoshonite", "biome": "Landing Plain", "rarity": "rare", "research_multiplier": 1.60, "drill_biome": 0,
	},
	"nodular_hematite": {
		"item_id": "rock_nodular_hematite", "name": "Nodular Hematite", "biome": "Dark Regolith", "rarity": "common", "research_multiplier": 1.00, "drill_biome": 1,
	},
	"hydrated_goethite": {
		"item_id": "rock_hydrated_goethite", "name": "Hydrated Goethite", "biome": "Dark Regolith", "rarity": "rare", "research_multiplier": 1.95, "drill_biome": 1,
	},
	"impact_breccia": {
		"item_id": "rock_impact_breccia", "name": "Impact Breccia", "biome": "Rocky Crater", "rarity": "common", "research_multiplier": 1.15, "drill_biome": 2,
	},
	"glassy_impactite": {
		"item_id": "rock_glassy_impactite", "name": "Glassy Impactite", "biome": "Rocky Crater", "rarity": "rare", "research_multiplier": 2.15, "drill_biome": 2,
	},
	"perchlorate_regolith": {
		"item_id": "rock_perchlorate_regolith", "name": "Perchlorate Regolith", "biome": "Ice-Cap Edge", "rarity": "common", "research_multiplier": 1.30, "drill_biome": 3,
	},
	"hydrated_sulfate_salts": {
		"item_id": "rock_hydrated_sulfate_salts", "name": "Hydrated Sulfate Salts", "biome": "Ice-Cap Edge", "rarity": "rare", "research_multiplier": 2.25, "drill_biome": 3,
	},
	"layered_ice": {
		"item_id": "rock_layered_ice", "name": "Layered Ice", "biome": "Polar Ice", "rarity": "common", "research_multiplier": 1.45, "drill_biome": 4,
	},
	"briny_ice": {
		"item_id": "rock_briny_ice", "name": "Briny Ice", "biome": "Polar Ice", "rarity": "rare", "research_multiplier": 2.45, "drill_biome": 4,
	},
	"vesicular_basalt": {
		"item_id": "rock_vesicular_basalt", "name": "Vesicular Basalt", "biome": "Basaltic Plateau", "rarity": "common", "research_multiplier": 1.50, "drill_biome": 5,
	},
	"ferric_olivine": {
		"item_id": "rock_ferric_olivine", "name": "Ferric Olivine", "biome": "Basaltic Plateau", "rarity": "rare", "research_multiplier": 2.55, "drill_biome": 5,
	},
}

## The return manifest requires one aliquot of every lithology collectible in
## the game. This intentional order matches the rocket and mission board and
## never depends on Dictionary iteration order.
const RETURN_MISSION_VARIANTS: Array[String] = [
	"baseline_stone", "red_regolith", "ferric_stone",
	"crater_stone", "impact_glass", "basaltic_rock", "black_basalt",
	"cryogenic_rock", "deep_ice", "dusty_ice", "blue_ice",
	"martian_andesite", "olivine_shoshonite", "nodular_hematite", "hydrated_goethite",
	"impact_breccia", "glassy_impactite", "perchlorate_regolith", "hydrated_sulfate_salts",
	"layered_ice", "briny_ice", "vesicular_basalt", "ferric_olivine",
	"primordial_deep_ice",
]

@export_enum("baseline_stone", "cryogenic_rock", "impact_glass", "basaltic_rock", "crater_stone", "deep_ice", "primordial_deep_ice", "red_regolith", "ferric_stone", "dusty_ice", "blue_ice", "black_basalt", "martian_andesite", "olivine_shoshonite", "nodular_hematite", "hydrated_goethite", "impact_breccia", "glassy_impactite", "perchlorate_regolith", "hydrated_sulfate_salts", "layered_ice", "briny_ice", "vesicular_basalt", "ferric_olivine") var rock_variant := "red_regolith"
@export var is_authored := true
var resource_key := ""

@onready var pickup_marker: Label = $PickupMarker
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_variant()
	add_to_group("collectible_rocks")


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	pickup_marker.visible = player != null and global_position.distance_to(player.global_position) < 70.0
	if pickup_marker.visible:
		pickup_marker.text = "E · %s" % get_display_name().to_upper()


static func definition_for(variant: String) -> Dictionary:
	return ROCK_DEFINITIONS.get(variant, ROCK_DEFINITIONS["red_regolith"]).duplicate(true)


static func definition_for_item_id(item_id: String) -> Dictionary:
	for definition in ROCK_DEFINITIONS.values():
		if str(definition.get("item_id", "")) == item_id:
			return definition.duplicate(true)
	return {}


static func get_return_mission_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for variant in RETURN_MISSION_VARIANTS:
		var definition := definition_for(variant)
		definition["variant"] = variant
		catalog.append(definition)
	return catalog


static func get_icon_texture_for_item_id(item_id: String) -> Texture2D:
	## The laboratory sample picker uses the same thumbnail as the collected
	## world rock, including minerals that reuse a common silhouette.
	for variant_value in ROCK_DEFINITIONS.keys():
		var variant := str(variant_value)
		var definition: Dictionary = ROCK_DEFINITIONS[variant]
		if str(definition.get("item_id", "")) != item_id:
			continue
		var texture_variant := str(ROCK_TEXTURE_VARIANTS.get(variant, variant))
		return ROCK_TEXTURES.get(texture_variant, ROCK_TEXTURES["red_regolith"])
	return ROCK_TEXTURES["red_regolith"]


static func drill_variant_for_biome(source_id: int, roll_percent: float, common_roll: float) -> String:
	## Primordial deep ice is a drill sample that can appear everywhere (1%) but
	## rises to 10% at the poles. It is checked before the local rare sample: at
	## the cap the player trades some variety for a better biological discovery chance.
	if roll_percent < deep_ice_probability_for_biome(source_id):
		return "primordial_deep_ice"
	## Every other biome has its own 5% rare sample. The two common samples share
	## the rest of production.
	var common_variants: Array[String] = []
	var rare_variant := ""
	for variant in ROCK_DEFINITIONS:
		var definition: Dictionary = ROCK_DEFINITIONS[variant]
		if int(definition.get("drill_biome", -1)) != source_id:
			continue
		if str(definition.get("rarity", "common")) == "rare":
			rare_variant = str(variant)
		else:
			common_variants.append(str(variant))
	if not rare_variant.is_empty() and roll_percent < 0.05:
		return rare_variant
	if common_variants.is_empty():
		return "baseline_stone"
	return common_variants[0] if common_variants.size() == 1 or common_roll < 0.5 else common_variants[1]


static func deep_ice_probability_for_biome(source_id: int) -> float:
	return 0.10 if source_id == 4 else 0.01


func resource_definition() -> Dictionary:
	return definition_for(rock_variant)


func get_display_name() -> String:
	return str(resource_definition().get("name", "Stone"))


func collect() -> bool:
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not bool(inventory.call("add_rock", rock_variant)):
		return false
	var achievements := get_node_or_null("/root/AchievementManager")
	if achievements != null and achievements.has_method("record_field_sample"):
		var definition := resource_definition()
		achievements.call("record_field_sample", rock_variant, str(definition.get("rarity", "common")))
	if not resource_key.is_empty():
		var scatter := get_tree().get_first_node_in_group("rock_scatter")
		if scatter != null:
			scatter.call("mark_collected", resource_key)
	queue_free()
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")
	return true


func _apply_variant() -> void:
	var texture_variant := str(ROCK_TEXTURE_VARIANTS.get(rock_variant, rock_variant))
	sprite.texture = ROCK_TEXTURES.get(texture_variant, ROCK_TEXTURES["red_regolith"])
	if rock_variant == "baseline_stone":
		# The original rock has a white background; the historical scene masking
		# keeps it visually embedded in landing sand.
		if base_rock_material == null:
			var shader := Shader.new()
			shader.code = "shader_type canvas_item;\nvoid fragment() {\n    vec4 pixel = texture(TEXTURE, UV);\n    if (pixel.r > 0.90 && pixel.g > 0.90 && pixel.b > 0.90) { pixel.a = 0.0; }\n    COLOR = pixel;\n}"
			base_rock_material = ShaderMaterial.new()
			base_rock_material.shader = shader
		sprite.material = base_rock_material
	else:
		# New sprites already have transparency; the old shader only removed the
		# temporary rock's white background.
		sprite.material = null
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
