shader_type spatial;
render_mode cull_disabled;
// Ground: mown parkland (COLOR.r = 1) fading to worn urban verges (COLOR.r = 0).
uniform vec4 grass_light : source_color = vec4(0.23, 0.38, 0.15, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.19, 0.32, 0.12, 1.0);
uniform vec4 urban : source_color = vec4(0.36, 0.37, 0.33, 1.0);
uniform float stripe_width = 10.0;
varying vec3 world;
varying float park;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; park = COLOR.r; }
void fragment() {
	float band = step(0.5, fract((world.x + world.z) / (2.0 * stripe_width)));
	vec3 g = mix(grass_light.rgb, grass_dark.rgb, band) * (0.88 + 0.16 * noise(world.xz * 0.35));
	vec3 u = urban.rgb * (0.85 + 0.2 * noise(world.xz * 0.08));
	ALBEDO = mix(u, g, park);
	ROUGHNESS = 0.95;
}
