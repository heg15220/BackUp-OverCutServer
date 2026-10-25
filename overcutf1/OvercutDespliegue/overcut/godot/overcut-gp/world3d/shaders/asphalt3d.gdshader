shader_type spatial;
render_mode cull_disabled;
// Asphalt: aggregate grain, patches and a darker rubbered racing line.
// UV.x = distance along the track (m), UV.y = lateral offset (m, + = left),
// UV2.x = lateral offset of the racing line at this point.
uniform vec4 base_color : source_color = vec4(0.21, 0.21, 0.22, 1.0);
uniform float rubber_strength = 0.22;
varying vec3 world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float grain = hash(floor(world.xz * 14.0));
	float patches = noise(world.xz * 0.12);
	vec3 c = base_color.rgb * (0.86 + 0.10 * grain + 0.14 * patches);
	float rubber = 1.0 - smoothstep(0.6, 1.9, abs(UV.y - UV2.x));
	c *= 1.0 - rubber_strength * rubber;
	ALBEDO = c;
	ROUGHNESS = 0.82 - 0.2 * rubber;
}
