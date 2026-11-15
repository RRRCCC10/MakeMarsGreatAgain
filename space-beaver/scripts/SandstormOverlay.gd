class_name SandstormOverlay
extends Control

## Lightweight full-screen layer: sand is drawn procedurally, staying sharp and
## adapting to every resolution without huge textures.

var intensity := 0.0
var elapsed := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	visible = intensity > 0.001
	queue_redraw()


func _process(delta: float) -> void:
	if intensity <= 0.001:
		return
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if intensity <= 0.001 or size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.27, 0.08, 0.10 + intensity * 0.20))
	var streak_count := roundi(48.0 + intensity * 82.0)
	for index in streak_count:
		var speed := 90.0 + float(index % 9) * 31.0 + intensity * 120.0
		var x := fposmod(float(index * 137 + 19) + elapsed * speed, size.x + 180.0) - 90.0
		var y := fposmod(float(index * 71 + 37) + elapsed * (18.0 + float(index % 5) * 9.0), size.y + 42.0) - 21.0
		var length := 14.0 + float(index % 6) * 8.0 + intensity * 24.0
		var alpha := (0.10 + float(index % 4) * 0.035) * intensity
		draw_line(Vector2(x - length, y + length * 0.18), Vector2(x, y), Color(1.0, 0.72, 0.42, alpha), 1.0 + intensity)
	if intensity > 0.45:
		for index in 34:
			var x := fposmod(float(index * 211 + 7) + elapsed * (150.0 + float(index % 7) * 18.0), size.x + 26.0) - 13.0
			var y := fposmod(float(index * 97 + 13) + elapsed * 24.0, size.y + 26.0) - 13.0
			draw_circle(Vector2(x, y), 1.0 + float(index % 3) * 0.45, Color(0.95, 0.54, 0.26, intensity * 0.24))
