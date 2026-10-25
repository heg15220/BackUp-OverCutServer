shader_type canvas_item;
// Asphalt with fine aggregate noise, larger patches and a darker rubbered band.
// UV.x = distance along the track (m), UV.y = lateral offset (m, + = left).

uniform vec4 base_color : source_color = vec4(0.25, 0.26, 0.28, 1.0);
uniform float racing_line_offset = 0.0;
uniform float rubber_strength = 0.18;

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
	float grain = hash(floor(world * 12.0));
	float patches = noise(world * 0.15);
	vec3 c = base_color.rgb * (0.88 + 0.10 * grain + 0.12 * patches);
	float rubber = 1.0 - smoothstep(0.7, 1.8, abs(UV.y - racing_line_offset));
	c *= 1.0 - rubber_strength * rubber;
	COLOR = vec4(c, 1.0);
}
