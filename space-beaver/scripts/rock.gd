extends Node2D

@onready var pickup_marker: Label = $PickupMarker


func _ready() -> void:
	add_to_group("collectible_rocks")


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	pickup_marker.visible = player != null and global_position.distance_to(player.global_position) < 70.0
