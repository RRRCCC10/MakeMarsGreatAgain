class_name DayNightController
extends Node2D

const OVERLAY_SHADER := preload("res://shaders/day_night_overlay.gdshader")
const COLOR_STEPS := 16.0
const KEY_HOURS: Array[float] = [0.0, 5.0, 5.5, 6.0, 7.0, 12.0, 17.0, 17.5, 18.0, 19.0, 24.0]
const KEY_COLORS: Array[Color] = [
	Color("465078"),
	Color("514b76"),
	Color("8b5869"),
	Color("f1a66f"),
	Color("ffe6c2"),
	Color("fff4de"),
	Color("f0a064"),
	Color("d57c5e"),
	Color("554869"),
	Color("465078"),
	Color("465078"),
]

var ambient_modulate: CanvasModulate
var overlay_material: ShaderMaterial


func _ready() -> void:
	process_priority = 50
	ambient_modulate = CanvasModulate.new()
	ambient_modulate.name = "AmbientLight"
	add_child(ambient_modulate)
	_build_directional_overlay()
	_apply_environment()


func _process(_delta: float) -> void:
	_apply_environment()


func get_ambient_color_for_hour(hour: float) -> Color:
	var wrapped_hour := fposmod(hour, 24.0)
	for index in range(KEY_HOURS.size() - 1):
		var start_hour := KEY_HOURS[index]
		var end_hour := KEY_HOURS[index + 1]
		if wrapped_hour < start_hour or wrapped_hour > end_hour:
			continue
		var duration := maxf(0.001, end_hour - start_hour)
		var amount := clampf((wrapped_hour - start_hour) / duration, 0.0, 1.0)
		amount = floorf(amount * COLOR_STEPS) / COLOR_STEPS
		amount = amount * amount * (3.0 - 2.0 * amount)
		return KEY_COLORS[index].lerp(KEY_COLORS[index + 1], amount)
	return KEY_COLORS[0]


func _build_directional_overlay() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "HorizonLightLayer"
	overlay_layer.layer = 0
	add_child(overlay_layer)
	var overlay := ColorRect.new()
	overlay.name = "HorizonLight"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color.WHITE
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = OVERLAY_SHADER
	overlay.material = overlay_material
	overlay_layer.add_child(overlay)
	# Reapply the preset after insertion into the CanvasLayer, when the viewport is known.
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _apply_environment() -> void:
	if ambient_modulate == null or overlay_material == null:
		return
	ambient_modulate.color = get_ambient_color_for_hour(WorldClock.game_hour)
	var phase := WorldClock.get_phase()
	var progress := WorldClock.get_phase_progress()
	var intensity := 0.0
	var tint := Color("ff8a52")
	var direction := 0.0
	if phase == WorldClock.Phase.DAWN:
		intensity = sin(progress * PI) * 0.18
		tint = Color("ff9b62")
		direction = 0.0
	elif phase == WorldClock.Phase.DUSK:
		intensity = sin(progress * PI) * 0.12
		tint = Color("f0784c")
		direction = 1.0
	overlay_material.set_shader_parameter("tint_color", tint)
	overlay_material.set_shader_parameter("intensity", intensity)
	overlay_material.set_shader_parameter("direction", direction)
