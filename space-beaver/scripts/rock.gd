extends Node2D

const BASE_ROCK_TEXTURE := preload("res://assets/sprites/rock.png")
const ROCK_TEXTURES: Dictionary = {
	"roccia_base": BASE_ROCK_TEXTURE,
	"roccia_ghiacciata": preload("res://assets/sprites/rocks/roccia_ghiacciata.png"),
	"roccia_scura": preload("res://assets/sprites/rocks/roccia_scura.png"),
	"roccia_basaltica": preload("res://assets/sprites/rocks/roccia_basaltica.png"),
	"roccia_grigia": preload("res://assets/sprites/rocks/roccia_grigia.png"),
	"ghiaccio_profondo": preload("res://assets/sprites/rocks/ghiaccio_profondo.png"),
	"roccia_rossa": preload("res://assets/sprites/rocks/roccia_rossa.png"),
	"pietra_rossastra": preload("res://assets/sprites/rocks/pietra_rossastra.png"),
	"ghiaccio_leggero": preload("res://assets/sprites/rocks/ghiaccio_leggero.png"),
	"ghiaccio_blu": preload("res://assets/sprites/rocks/ghiaccio_blu.png"),
	"basalto": preload("res://assets/sprites/rocks/basalto.png"),
}

## New minerals intentionally reuse existing silhouettes: at this pixel-art
## scale, name, rarity, and scientific value convey geological provenance
## without introducing inconsistent sprites.
const ROCK_TEXTURE_VARIANTS: Dictionary = {
	"andesite_marziana": "roccia_grigia",
	"shoshonite_olivinica": "basalto",
	"ematite_nodulare": "pietra_rossastra",
	"goethite_idrata": "roccia_ghiacciata",
	"breccia_da_impatto": "roccia_grigia",
	"impactite_vetrosa": "roccia_scura",
	"regolite_perclorata": "roccia_ghiacciata",
	"sali_solfati_idrati": "ghiaccio_profondo",
	"ghiaccio_laminato": "ghiaccio_leggero",
	"ghiaccio_salmastro": "ghiaccio_blu",
	"ghiaccio_profondo_primordiale": "ghiaccio_profondo",
	"basalto_vescicolare": "roccia_basaltica",
	"olivina_ferrifera": "basalto",
}
static var base_rock_material: ShaderMaterial

## Every pair is tied to a concrete geological formation on the map. Item IDs
## remain distinct: identical samples stack together while rare ones stay apart.
const ROCK_DEFINITIONS: Dictionary = {
	"roccia_base": {
		"item_id": "rock", "name": "Martian Stone", "biome": "Landing Sand", "rarity": "common", "research_multiplier": 0.55, "drill_biome": 0,
	},
	"roccia_rossa": {
		"item_id": "rock_roccia_rossa", "name": "Red Regolith", "biome": "Ares Plain", "rarity": "common", "research_multiplier": 0.80, "drill_biome": 1,
	},
	"pietra_rossastra": {
		"item_id": "rock_pietra_rossastra", "name": "Ferric Stone", "biome": "Ares Plain", "rarity": "rare", "research_multiplier": 1.35,
	},
	"ghiaccio_leggero": {
		"item_id": "rock_ghiaccio_leggero", "name": "Dusty Ice", "biome": "Polar Core", "rarity": "common", "research_multiplier": 1.00, "drill_biome": 4,
	},
	"ghiaccio_blu": {
		"item_id": "rock_ghiaccio_blu", "name": "Compact Blue Ice", "biome": "Polar Core", "rarity": "rare", "research_multiplier": 1.70,
	},
	"roccia_grigia": {
		"item_id": "rock_roccia_grigia", "name": "Crater Stone", "biome": "Impact Craters", "rarity": "common", "research_multiplier": 0.95, "drill_biome": 2,
	},
	"roccia_scura": {
		"item_id": "rock_roccia_scura", "name": "Impact Glass", "biome": "Impact Craters", "rarity": "rare", "research_multiplier": 1.85,
	},
	"roccia_basaltica": {
		"item_id": "rock_roccia_basaltica", "name": "Basaltic Rock", "biome": "Basalt Formation", "rarity": "common", "research_multiplier": 1.10, "drill_biome": 5,
	},
	"basalto": {
		"item_id": "rock_basalto", "name": "Black Basalt", "biome": "Basalt Formation", "rarity": "rare", "research_multiplier": 1.65,
	},
	"roccia_ghiacciata": {
		"item_id": "rock_roccia_ghiacciata", "name": "Cryogenic Rock", "biome": "Ice-Cap Edge", "rarity": "common", "research_multiplier": 1.20, "drill_biome": 3,
	},
	"ghiaccio_profondo": {
		"item_id": "rock_ghiaccio_profondo", "name": "Deep Ice", "biome": "Ice-Cap Edge", "rarity": "rare", "research_multiplier": 1.90,
	},
	"ghiaccio_profondo_primordiale": {
		"item_id": "rock_ghiaccio_profondo_primordiale", "name": "Primordial Deep-Ice Sample (model)", "biome": "Deep Martian Layers", "rarity": "ultra_rare", "research_multiplier": 4.50, "deep_ice": true,
	},
	# New mining-drill samples: two common samples and a 5% discovery for each
	# of the map's six biomes.
	"andesite_marziana": {
		"item_id": "rock_andesite_marziana", "name": "Martian Andesite", "biome": "Landing Plain", "rarity": "common", "research_multiplier": 0.70, "drill_biome": 0,
	},
	"shoshonite_olivinica": {
		"item_id": "rock_shoshonite_olivinica", "name": "Olivine Shoshonite", "biome": "Landing Plain", "rarity": "rare", "research_multiplier": 1.60, "drill_biome": 0,
	},
	"ematite_nodulare": {
		"item_id": "rock_ematite_nodulare", "name": "Nodular Hematite", "biome": "Dark Regolith", "rarity": "common", "research_multiplier": 1.00, "drill_biome": 1,
	},
	"goethite_idrata": {
		"item_id": "rock_goethite_idrata", "name": "Hydrated Goethite", "biome": "Dark Regolith", "rarity": "rare", "research_multiplier": 1.95, "drill_biome": 1,
	},
	"breccia_da_impatto": {
		"item_id": "rock_breccia_da_impatto", "name": "Impact Breccia", "biome": "Rocky Crater", "rarity": "common", "research_multiplier": 1.15, "drill_biome": 2,
	},
	"impactite_vetrosa": {
		"item_id": "rock_impactite_vetrosa", "name": "Glassy Impactite", "biome": "Rocky Crater", "rarity": "rare", "research_multiplier": 2.15, "drill_biome": 2,
	},
	"regolite_perclorata": {
		"item_id": "rock_regolite_perclorata", "name": "Perchlorate Regolith", "biome": "Ice-Cap Edge", "rarity": "common", "research_multiplier": 1.30, "drill_biome": 3,
	},
	"sali_solfati_idrati": {
		"item_id": "rock_sali_solfati_idrati", "name": "Hydrated Sulfate Salts", "biome": "Ice-Cap Edge", "rarity": "rare", "research_multiplier": 2.25, "drill_biome": 3,
	},
	"ghiaccio_laminato": {
		"item_id": "rock_ghiaccio_laminato", "name": "Layered Ice", "biome": "Polar Ice", "rarity": "common", "research_multiplier": 1.45, "drill_biome": 4,
	},
	"ghiaccio_salmastro": {
		"item_id": "rock_ghiaccio_salmastro", "name": "Briny Ice", "biome": "Polar Ice", "rarity": "rare", "research_multiplier": 2.45, "drill_biome": 4,
	},
	"basalto_vescicolare": {
		"item_id": "rock_basalto_vescicolare", "name": "Vesicular Basalt", "biome": "Basaltic Plateau", "rarity": "common", "research_multiplier": 1.50, "drill_biome": 5,
	},
	"olivina_ferrifera": {
		"item_id": "rock_olivina_ferrifera", "name": "Ferric Olivine", "biome": "Basaltic Plateau", "rarity": "rare", "research_multiplier": 2.55, "drill_biome": 5,
	},
}

## The return manifest requires one aliquot of every lithology collectible in
## the game. This intentional order matches the rocket and mission board and
## never depends on Dictionary iteration order.
const RETURN_MISSION_VARIANTS: Array[String] = [
	"roccia_base", "roccia_rossa", "pietra_rossastra",
	"roccia_grigia", "roccia_scura", "roccia_basaltica", "basalto",
	"roccia_ghiacciata", "ghiaccio_profondo", "ghiaccio_leggero", "ghiaccio_blu",
	"andesite_marziana", "shoshonite_olivinica", "ematite_nodulare", "goethite_idrata",
	"breccia_da_impatto", "impactite_vetrosa", "regolite_perclorata", "sali_solfati_idrati",
	"ghiaccio_laminato", "ghiaccio_salmastro", "basalto_vescicolare", "olivina_ferrifera",
	"ghiaccio_profondo_primordiale",
]

@export_enum("roccia_base", "roccia_ghiacciata", "roccia_scura", "roccia_basaltica", "roccia_grigia", "ghiaccio_profondo", "ghiaccio_profondo_primordiale", "roccia_rossa", "pietra_rossastra", "ghiaccio_leggero", "ghiaccio_blu", "basalto", "andesite_marziana", "shoshonite_olivinica", "ematite_nodulare", "goethite_idrata", "breccia_da_impatto", "impactite_vetrosa", "regolite_perclorata", "sali_solfati_idrati", "ghiaccio_laminato", "ghiaccio_salmastro", "basalto_vescicolare", "olivina_ferrifera") var rock_variant := "roccia_rossa"
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
	return ROCK_DEFINITIONS.get(variant, ROCK_DEFINITIONS["roccia_rossa"]).duplicate(true)


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
		return ROCK_TEXTURES.get(texture_variant, ROCK_TEXTURES["roccia_rossa"])
	return ROCK_TEXTURES["roccia_rossa"]


static func drill_variant_for_biome(source_id: int, roll_percent: float, common_roll: float) -> String:
	## Primordial deep ice is a drill sample that can appear everywhere (1%) but
	## rises to 10% at the poles. It is checked before the local rare sample: at
	## the cap the player trades some variety for a better biological discovery chance.
	if roll_percent < deep_ice_probability_for_biome(source_id):
		return "ghiaccio_profondo_primordiale"
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
		return "roccia_base"
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
	sprite.texture = ROCK_TEXTURES.get(texture_variant, ROCK_TEXTURES["roccia_rossa"])
	if rock_variant == "roccia_base":
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
