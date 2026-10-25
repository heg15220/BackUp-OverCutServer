shader_type spatial;
render_mode cull_disabled;
// Grandstand seating: rows of spectators as coloured dots.
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 cell = floor(world.xz * 2.2 + vec2(0.0, world.y * 2.2));
	float h = hash(cell);
	vec3 shirt = vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
	vec3 seat = vec3(0.18, 0.22, 0.32);
	ALBEDO = mix(seat, shirt * 0.9 + 0.1, step(0.25, h));
	ROUGHNESS = 0.9;
}
