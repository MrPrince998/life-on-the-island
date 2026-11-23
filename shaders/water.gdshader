shader_type spatial;
// Stylized water: depth-tinted colour, soft shoreline foam and gentle waves.
// Clear near the surface (fish, stones and the lake bed show through) and deeper-coloured
// further down: depth_curve > 1 keeps the first metre or so see-through.
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.36, 0.8, 0.8, 0.55);
uniform vec4 deep_color : source_color = vec4(0.07, 0.33, 0.52, 0.95);
uniform float depth_distance = 5.0;
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform float foam_distance = 0.7;
uniform float wave_height = 0.12;
uniform float wave_speed = 0.6;
uniform float ripple_strength = 0.35;
// > 1 keeps shallow water clear for longer before it takes on the deep colour.
uniform float depth_curve = 1.0;
// Strength of the surface reflection (lower = easier to see into the water).
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += (sin(wp.x * 0.07 + t) + cos(wp.z * 0.09 + t * 0.8)) * wave_height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 uv_a = world_pos.xz * 0.05 + vec2(t * 0.03, t * 0.02);
	vec2 uv_b = world_pos.xz * 0.08 - vec2(t * 0.02, t * 0.035);
	float n_a = texture(noise_tex, uv_a).r;
	float n_b = texture(noise_tex, uv_b).r;

	// Depth of the scene behind the water surface (Godot 4.3+ reversed-Z NDC).
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	vec4 world_behind = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * ndc;
	world_behind.xyz /= world_behind.w;
	float water_depth = max(world_pos.y - world_behind.y, 0.0);

	float depth_t = pow(clamp(water_depth / depth_distance, 0.0, 1.0), depth_curve);
	vec4 water = mix(shallow_color, deep_color, depth_t);

	float foam_edge = 1.0 - smoothstep(0.0, foam_distance * (0.6 + 0.8 * n_a), water_depth);
	float foam = step(0.45, foam_edge * (0.6 + 0.6 * n_b));

	ALBEDO = mix(water.rgb, foam_color.rgb, foam);
	ALPHA = mix(water.a, 0.95, foam);
	ROUGHNESS = mix(0.08, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = specular_amount;
	vec3 ripple = normalize(vec3((n_a - n_b) * ripple_strength, 1.0, (n_a + n_b - 1.0) * ripple_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
}
