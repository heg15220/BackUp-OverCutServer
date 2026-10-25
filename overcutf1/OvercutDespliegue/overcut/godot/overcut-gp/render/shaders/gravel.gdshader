shader_type canvas_item;
// Gravel trap: coarse speckled stones over a sandy base.

uniform vec4 base_color : source_color = vec4(0.76, 0.68, 0.50, 1.0);

varying vec2 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	float stones = hash(floor(world * 9.0));
	float grit = hash(floor(world * 23.0));
	vec3 c = base_color.rgb * (0.78 + 0.22 * stones) * (0.93 + 0.07 * grit);
	COLOR = vec4(c, 1.0);
}
