extends Node

## Mission background score. Its volume intentionally remains low so it does
## not cover effects, warnings, or interface dialogue.

const OST_STREAM := preload("res://assets/audio/OST_1.wav")
const BACKGROUND_VOLUME_DB := -20.0

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundOST"
	_player.stream = OST_STREAM
	_player.volume_db = BACKGROUND_VOLUME_DB
	_player.bus = &"Master"
	_player.finished.connect(_restart_track)
	add_child(_player)
	_player.play()


func _restart_track() -> void:
	if is_instance_valid(_player) and not _player.playing:
		_player.play()
