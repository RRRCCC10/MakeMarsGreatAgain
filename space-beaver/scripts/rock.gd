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

## I nuovi minerali riutilizzano volutamente le silhouette già presenti: nella
## pixel art a questa scala la provenienza geologica è comunicata da nome,
## rarità e valore scientifico, senza introdurre sprite incoerenti.
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

## Ogni coppia e' legata a una formazione geologica concreta della mappa.
## L'id dell'oggetto resta distinto: due campioni uguali si accumulano insieme,
## mentre un campione raro non si confonde con quello comune.
const ROCK_DEFINITIONS: Dictionary = {
	"roccia_base": {
		"item_id": "rock", "name": "Pietra marziana", "biome": "Sabbia di atterraggio", "rarity": "common", "research_multiplier": 0.55, "drill_biome": 0,
	},
	"roccia_rossa": {
		"item_id": "rock_roccia_rossa", "name": "Regolite rossa", "biome": "Pianura di Ares", "rarity": "common", "research_multiplier": 0.80, "drill_biome": 1,
	},
	"pietra_rossastra": {
		"item_id": "rock_pietra_rossastra", "name": "Pietra ferrica", "biome": "Pianura di Ares", "rarity": "rare", "research_multiplier": 1.35,
	},
	"ghiaccio_leggero": {
		"item_id": "rock_ghiaccio_leggero", "name": "Ghiaccio polveroso", "biome": "Nucleo polare", "rarity": "common", "research_multiplier": 1.00, "drill_biome": 4,
	},
	"ghiaccio_blu": {
		"item_id": "rock_ghiaccio_blu", "name": "Ghiaccio blu compatto", "biome": "Nucleo polare", "rarity": "rare", "research_multiplier": 1.70,
	},
	"roccia_grigia": {
		"item_id": "rock_roccia_grigia", "name": "Pietra da cratere", "biome": "Crateri d'impatto", "rarity": "common", "research_multiplier": 0.95, "drill_biome": 2,
	},
	"roccia_scura": {
		"item_id": "rock_roccia_scura", "name": "Vetro d'impatto", "biome": "Crateri d'impatto", "rarity": "rare", "research_multiplier": 1.85,
	},
	"roccia_basaltica": {
		"item_id": "rock_roccia_basaltica", "name": "Roccia basaltica", "biome": "Formazione basaltica", "rarity": "common", "research_multiplier": 1.10, "drill_biome": 5,
	},
	"basalto": {
		"item_id": "rock_basalto", "name": "Basalto nero", "biome": "Formazione basaltica", "rarity": "rare", "research_multiplier": 1.65,
	},
	"roccia_ghiacciata": {
		"item_id": "rock_roccia_ghiacciata", "name": "Roccia criogenica", "biome": "Bordo della calotta", "rarity": "common", "research_multiplier": 1.20, "drill_biome": 3,
	},
	"ghiaccio_profondo": {
		"item_id": "rock_ghiaccio_profondo", "name": "Ghiaccio profondo", "biome": "Bordo della calotta", "rarity": "rare", "research_multiplier": 1.90,
	},
	"ghiaccio_profondo_primordiale": {
		"item_id": "rock_ghiaccio_profondo_primordiale", "name": "Ghiaccio profondo primordiale", "biome": "Strati profondi marziani", "rarity": "ultra_rare", "research_multiplier": 4.50, "deep_ice": true,
	},
	# Nuovi campioni della trivella mineraria: due comuni e una scoperta al 5%
	# per ciascuno dei sei biomi della mappa.
	"andesite_marziana": {
		"item_id": "rock_andesite_marziana", "name": "Andesite marziana", "biome": "Pianura di atterraggio", "rarity": "common", "research_multiplier": 0.70, "drill_biome": 0,
	},
	"shoshonite_olivinica": {
		"item_id": "rock_shoshonite_olivinica", "name": "Shoshonite olivinica", "biome": "Pianura di atterraggio", "rarity": "rare", "research_multiplier": 1.60, "drill_biome": 0,
	},
	"ematite_nodulare": {
		"item_id": "rock_ematite_nodulare", "name": "Ematite nodulare", "biome": "Regolite scura", "rarity": "common", "research_multiplier": 1.00, "drill_biome": 1,
	},
	"goethite_idrata": {
		"item_id": "rock_goethite_idrata", "name": "Goethite idrata", "biome": "Regolite scura", "rarity": "rare", "research_multiplier": 1.95, "drill_biome": 1,
	},
	"breccia_da_impatto": {
		"item_id": "rock_breccia_da_impatto", "name": "Breccia da impatto", "biome": "Cratere roccioso", "rarity": "common", "research_multiplier": 1.15, "drill_biome": 2,
	},
	"impactite_vetrosa": {
		"item_id": "rock_impactite_vetrosa", "name": "Impactite vetrosa", "biome": "Cratere roccioso", "rarity": "rare", "research_multiplier": 2.15, "drill_biome": 2,
	},
	"regolite_perclorata": {
		"item_id": "rock_regolite_perclorata", "name": "Regolite perclorata", "biome": "Bordo della calotta", "rarity": "common", "research_multiplier": 1.30, "drill_biome": 3,
	},
	"sali_solfati_idrati": {
		"item_id": "rock_sali_solfati_idrati", "name": "Sali solfati idrati", "biome": "Bordo della calotta", "rarity": "rare", "research_multiplier": 2.25, "drill_biome": 3,
	},
	"ghiaccio_laminato": {
		"item_id": "rock_ghiaccio_laminato", "name": "Ghiaccio laminato", "biome": "Ghiaccio polare", "rarity": "common", "research_multiplier": 1.45, "drill_biome": 4,
	},
	"ghiaccio_salmastro": {
		"item_id": "rock_ghiaccio_salmastro", "name": "Ghiaccio salmastro", "biome": "Ghiaccio polare", "rarity": "rare", "research_multiplier": 2.45, "drill_biome": 4,
	},
	"basalto_vescicolare": {
		"item_id": "rock_basalto_vescicolare", "name": "Basalto vescicolare", "biome": "Altopiano basaltico", "rarity": "common", "research_multiplier": 1.50, "drill_biome": 5,
	},
	"olivina_ferrifera": {
		"item_id": "rock_olivina_ferrifera", "name": "Olivina ferrifera", "biome": "Altopiano basaltico", "rarity": "rare", "research_multiplier": 2.55, "drill_biome": 5,
	},
}

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


static func drill_variant_for_biome(source_id: int, roll_percent: float, common_roll: float) -> String:
	## Il ghiaccio profondo primordiale è una carota che può comparire ovunque
	## (1%), ma sui poli sale al 10%. Viene controllato prima del raro locale:
	## nella calotta il giocatore rinuncia a un po' di varietà in cambio della
	## migliore probabilità di una scoperta biologica straordinaria.
	if roll_percent < deep_ice_probability_for_biome(source_id):
		return "ghiaccio_profondo_primordiale"
	## Ogni altro bioma possiede il proprio campione raro al 5%. I due campioni
	## comuni dividono il resto della produzione.
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
	return str(resource_definition().get("name", "Pietra"))


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
		# La pietra originale ha un fondo bianco: lo stesso mascheramento della
		# scena storica la conserva visivamente nella sabbia di atterraggio.
		if base_rock_material == null:
			var shader := Shader.new()
			shader.code = "shader_type canvas_item;\nvoid fragment() {\n    vec4 pixel = texture(TEXTURE, UV);\n    if (pixel.r > 0.90 && pixel.g > 0.90 && pixel.b > 0.90) { pixel.a = 0.0; }\n    COLOR = pixel;\n}"
			base_rock_material = ShaderMaterial.new()
			base_rock_material.shader = shader
		sprite.material = base_rock_material
	else:
		# Le nuove sprite hanno già la trasparenza: il vecchio shader serviva
		# soltanto a rimuovere il fondo bianco della roccia provvisoria.
		sprite.material = null
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
