shader_type spatial;
render_mode cull_disabled;
// Gravel trap: speckled stones on a sandy base.
uniform vec4 base_color : source_color = vec4(0.78, 0.70, 0.52, 1.0);
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float stones = hash(floor(world.xz * 9.0));
	float grit = hash(floor(world.xz * 25.0));
	ALBEDO = base_color.rgb * (0.76 + 0.24 * stones) * (0.92 + 0.08 * grit);
	ROUGHNESS = 1.0;
}
