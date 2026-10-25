shader_type canvas_item;
// Painted kerb stripes along the track. UV.x = distance along the track (m).

uniform vec4 color_a : source_color = vec4(0.82, 0.10, 0.10, 1.0);
uniform vec4 color_b : source_color = vec4(0.94, 0.94, 0.94, 1.0);
uniform float stripe_length = 1.2;

void fragment() {
	float k = step(0.5, fract(UV.x / (2.0 * stripe_length)));
	vec3 c = mix(color_a.rgb, color_b.rgb, k);
	// Slight shading towards the outer edge suggests the kerb's ramp.
	c *= 0.92 + 0.08 * fract(abs(UV.y));
	COLOR = vec4(c, 1.0);
}
