extends Node2D

const BASE_ROCK_TEXTURE := preload("res://sprites/rock.png")
const ROCK_TEXTURES: Dictionary = {
	"roccia_base": BASE_ROCK_TEXTURE,
	"roccia_ghiacciata": preload("res://sprites/rocks/roccia_ghiacciata.png"),
	"roccia_scura": preload("res://sprites/rocks/roccia_scura.png"),
	"roccia_basaltica": preload("res://sprites/rocks/roccia_basaltica.png"),
	"roccia_grigia": preload("res://sprites/rocks/roccia_grigia.png"),
	"ghiaccio_profondo": preload("res://sprites/rocks/ghiaccio_profondo.png"),
	"roccia_rossa": preload("res://sprites/rocks/roccia_rossa.png"),
	"pietra_rossastra": preload("res://sprites/rocks/pietra_rossastra.png"),
	"ghiaccio_leggero": preload("res://sprites/rocks/ghiaccio_leggero.png"),
	"ghiaccio_blu": preload("res://sprites/rocks/ghiaccio_blu.png"),
	"basalto": preload("res://sprites/rocks/basalto.png"),
}
static var base_rock_material: ShaderMaterial

## Ogni coppia e' legata a una formazione geologica concreta della mappa.
## L'id dell'oggetto resta distinto: due campioni uguali si accumulano insieme,
## mentre un campione raro non si confonde con quello comune.
const ROCK_DEFINITIONS: Dictionary = {
	"roccia_base": {
		"item_id": "rock", "name": "Pietra marziana", "biome": "Sabbia di atterraggio", "rarity": "common",
	},
	"roccia_rossa": {
		"item_id": "rock_roccia_rossa", "name": "Regolite rossa", "biome": "Pianura di Ares", "rarity": "common",
	},
	"pietra_rossastra": {
		"item_id": "rock_pietra_rossastra", "name": "Pietra ferrica", "biome": "Pianura di Ares", "rarity": "rare",
	},
	"ghiaccio_leggero": {
		"item_id": "rock_ghiaccio_leggero", "name": "Ghiaccio polveroso", "biome": "Nucleo polare", "rarity": "common",
	},
	"ghiaccio_blu": {
		"item_id": "rock_ghiaccio_blu", "name": "Ghiaccio blu compatto", "biome": "Nucleo polare", "rarity": "rare",
	},
	"roccia_grigia": {
		"item_id": "rock_roccia_grigia", "name": "Pietra da cratere", "biome": "Crateri d'impatto", "rarity": "common",
	},
	"roccia_scura": {
		"item_id": "rock_roccia_scura", "name": "Vetro d'impatto", "biome": "Crateri d'impatto", "rarity": "rare",
	},
	"roccia_basaltica": {
		"item_id": "rock_roccia_basaltica", "name": "Roccia basaltica", "biome": "Formazione basaltica", "rarity": "common",
	},
	"basalto": {
		"item_id": "rock_basalto", "name": "Basalto nero", "biome": "Formazione basaltica", "rarity": "rare",
	},
	"roccia_ghiacciata": {
		"item_id": "rock_roccia_ghiacciata", "name": "Roccia criogenica", "biome": "Bordo della calotta", "rarity": "common",
	},
	"ghiaccio_profondo": {
		"item_id": "rock_ghiaccio_profondo", "name": "Ghiaccio profondo", "biome": "Bordo della calotta", "rarity": "rare",
	},
}

@export_enum("roccia_base", "roccia_ghiacciata", "roccia_scura", "roccia_basaltica", "roccia_grigia", "ghiaccio_profondo", "roccia_rossa", "pietra_rossastra", "ghiaccio_leggero", "ghiaccio_blu", "basalto") var rock_variant := "roccia_rossa"
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


func resource_definition() -> Dictionary:
	return definition_for(rock_variant)


func get_display_name() -> String:
	return str(resource_definition().get("name", "Pietra"))


func collect() -> bool:
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not bool(inventory.call("add_rock", rock_variant)):
		return false
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
	sprite.texture = ROCK_TEXTURES.get(rock_variant, ROCK_TEXTURES["roccia_rossa"])
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
