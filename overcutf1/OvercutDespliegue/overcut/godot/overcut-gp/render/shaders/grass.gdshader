shader_type canvas_item;
// Mown grass: alternating cut stripes plus soft noise.

uniform vec4 light_color : source_color = vec4(0.27, 0.46, 0.20, 1.0);
uniform vec4 dark_color : source_color = vec4(0.23, 0.40, 0.17, 1.0);
uniform float stripe_width = 12.0;

varying vec2 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	float band = step(0.5, fract(world.x / (2.0 * stripe_width)));
	vec3 c = mix(light_color.rgb, dark_color.rgb, band);
	c *= 0.9 + 0.12 * noise(world * 0.5) + 0.04 * hash(floor(world * 6.0));
	COLOR = vec4(c, 1.0);
}
