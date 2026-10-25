shader_type spatial;
render_mode cull_disabled;
// Red/white painted kerb stripes along the track (UV.x = distance in metres).
uniform vec4 color_a : source_color = vec4(0.80, 0.08, 0.08, 1.0);
uniform vec4 color_b : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float stripe_length = 1.2;
void fragment() {
	float k = step(0.5, fract(UV.x / (2.0 * stripe_length)));
	ALBEDO = mix(color_a.rgb, color_b.rgb, k);
	ROUGHNESS = 0.55;
}
