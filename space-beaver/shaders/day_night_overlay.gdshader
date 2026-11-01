shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint_color : source_color = vec4(1.0, 0.45, 0.25, 1.0);
uniform float intensity : hint_range(0.0, 0.35) = 0.0;
uniform float direction : hint_range(0.0, 1.0) = 0.0;

float bayer4(vec2 pixel_position) {
	vec2 cell = mod(floor(pixel_position), 4.0);
	float value = 0.0;
	if (cell.y < 1.0) {
		value = cell.x < 1.0 ? 0.0 : (cell.x < 2.0 ? 8.0 : (cell.x < 3.0 ? 2.0 : 10.0));
	} else if (cell.y < 2.0) {
		value = cell.x < 1.0 ? 12.0 : (cell.x < 2.0 ? 4.0 : (cell.x < 3.0 ? 14.0 : 6.0));
	} else if (cell.y < 3.0) {
		value = cell.x < 1.0 ? 3.0 : (cell.x < 2.0 ? 11.0 : (cell.x < 3.0 ? 1.0 : 9.0));
	} else {
		value = cell.x < 1.0 ? 15.0 : (cell.x < 2.0 ? 7.0 : (cell.x < 3.0 ? 13.0 : 5.0));
	}
	return value / 16.0;
}

void fragment() {
	float horizontal = mix(1.0 - UV.x, UV.x, step(0.5, direction));
	float gradient = mix(0.28, 1.0, smoothstep(0.0, 1.0, horizontal));
	float raw_alpha = intensity * gradient * tint_color.a;
	float alpha = floor(raw_alpha * 16.0 + bayer4(FRAGCOORD.xy)) / 16.0;
	COLOR = vec4(tint_color.rgb, clamp(alpha, 0.0, 0.35));
}
