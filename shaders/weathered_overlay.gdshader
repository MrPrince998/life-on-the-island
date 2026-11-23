shader_type spatial;
// Drawn on top of a building's own material (material_overlay) while it is run-down:
// patchy grime and moss, heavier near the ground. Removed when the building is restored.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_disabled;

uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec4 grime : source_color = vec4(0.25, 0.21, 0.16, 1.0);
uniform vec4 moss : source_color = vec4(0.33, 0.42, 0.20, 1.0);
uniform float strength = 0.72;
// World height of the building's base and how tall the dirty band is.
uniform float base_y = 0.0;
uniform float grime_height = 4.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 blend = abs(world_normal);
	blend /= (blend.x + blend.y + blend.z);
	float n = texture(noise_tex, world_pos.zy * 0.35).r * blend.x
		+ texture(noise_tex, world_pos.xz * 0.35).r * blend.y
		+ texture(noise_tex, world_pos.xy * 0.35).r * blend.z;
	float fine = texture(noise_tex, world_pos.xz * 1.7 + world_pos.y * 0.9).r;
	float low = 1.0 - smoothstep(base_y, base_y + grime_height, world_pos.y);
	float mossy = smoothstep(0.45, 0.75, fine) * (0.35 + 0.65 * clamp(world_normal.y, 0.0, 1.0));
	ALBEDO = mix(grime.rgb, moss.rgb, mossy);
	ROUGHNESS = 1.0;
	ALPHA = strength * clamp(smoothstep(0.3, 0.7, n) * 0.75 + low * 0.45, 0.0, 1.0);
}
