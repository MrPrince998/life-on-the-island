shader_type spatial;
// Hand-painted wooden planks for floors, beams and furniture trim. Uses world-space
// coordinates, so any box gets planks without UVs. Planks run along `plank_axis`.

uniform vec3 base_color : source_color = vec3(0.55, 0.36, 0.22);
uniform vec3 dark_color : source_color = vec3(0.36, 0.22, 0.13);
uniform float plank_width = 0.24;
uniform float plank_length = 1.8;
uniform float plank_variation = 0.18;
// 0 = planks run along x, 1 = along z (for floors); 2 = along y (posts).
uniform int plank_axis = 0;
uniform float roughness_value = 0.82;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Pick the two coordinates across the face.
	vec3 n = abs(world_normal);
	vec2 p;
	if (n.y > n.x && n.y > n.z) {
		p = plank_axis == 1 ? world_pos.zx : world_pos.xz;
	} else if (n.x > n.z) {
		p = plank_axis == 2 ? world_pos.yz : world_pos.zy;
	} else {
		p = plank_axis == 2 ? world_pos.yx : world_pos.xy;
	}
	float row = floor(p.y / plank_width);
	float along = p.x / plank_length + hash(vec2(row, 3.1)) * 7.0;
	float plank = floor(along);
	float id = hash(vec2(row, plank));
	vec3 color = mix(base_color, base_color * (1.0 + plank_variation), id);
	// Grain: stretched noise along the plank.
	float grain = noise(vec2(p.x * 1.6, p.y * 26.0 + id * 40.0));
	color = mix(color, dark_color, grain * 0.28);
	// Dark seams between planks.
	float seam_across = smoothstep(0.0, 0.035, fract(p.y / plank_width)) * smoothstep(1.0, 0.965, fract(p.y / plank_width));
	float seam_along = smoothstep(0.0, 0.012, fract(along)) * smoothstep(1.0, 0.994, fract(along));
	color = mix(dark_color * 0.7, color, seam_across * seam_along);
	ALBEDO = color;
	ROUGHNESS = roughness_value;
}
