shader_type spatial;
render_mode cull_disabled;
// Lake: deep blue with moving ripples and sky reflections.
uniform vec4 deep : source_color = vec4(0.10, 0.27, 0.40, 1.0);
uniform vec4 shallow : source_color = vec4(0.22, 0.45, 0.55, 1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float r = sin(world.x * 0.35 + TIME * 0.9) * sin(world.z * 0.29 - TIME * 0.7);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.5 + 0.25 * r);
	NORMAL_MAP = vec3(0.5 + 0.08 * r, 0.5 - 0.08 * r, 1.0);
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
}
