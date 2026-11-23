shader_type spatial;
// Hand-painted foliage: original Tripo albedo texture, per-instance tint and gentle wind.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wind_strength = 0.04;
uniform float wind_speed = 1.1;
uniform float sway_start = 0.3;
uniform float mesh_min_y = 0.0;
uniform float mesh_height = 1.0;
uniform float backlight_strength = 0.25;
// Ground-cover models (flowers, grass) carry a grassy base. Its green pixels are
// blended toward the terrain grass colour so the patch melts into the meadow.
uniform vec4 ground_tint : source_color = vec4(0.52, 0.74, 0.27, 0.0);
uniform float ground_tint_height = 0.35;
// 1 = leaves turn in autumn (broadleaf, blossom, bushes); 0 = evergreen (pines, palms).
uniform float seasonal_leaves = 1.0;
global uniform float season_summer;
global uniform float season_autumn;
global uniform float season_winter;

varying float local_height;
varying float instance_seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	instance_seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h = clamp((VERTEX.y - mesh_min_y) / max(mesh_height, 0.001), 0.0, 1.0);
	local_height = h;
	float bend = max(h - sway_start, 0.0) / max(1.0 - sway_start, 0.001);
	bend *= bend;
	float phase = origin.x * 0.13 + origin.z * 0.09;
	float gust = sin(TIME * wind_speed + phase) * 0.65 + sin(TIME * wind_speed * 2.7 + phase * 1.9) * 0.2;
	float flutter = sin(TIME * wind_speed * 5.0 + VERTEX.x * 9.0 + VERTEX.z * 7.0) * 0.12;
	vec3 offset = vec3(gust + flutter, 0.0, (gust - flutter) * 0.45) * wind_strength * bend * mesh_height;
	VERTEX += offset;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 albedo = tex.rgb * COLOR.rgb;
	float greenness = smoothstep(-0.04, 0.05, tex.g - max(tex.r, tex.b));
	float low = 1.0 - smoothstep(0.0, ground_tint_height, local_height);
	float tint_amount = ground_tint.a * greenness * low;
	vec3 shaded = ground_tint.rgb * (0.75 + 0.5 * dot(tex.rgb, vec3(0.333)) / max(dot(ground_tint.rgb, vec3(0.333)), 0.01) * 0.5);
	vec3 col = mix(albedo, shaded, tint_amount);
	float lum = dot(col, vec3(0.333));
	// Summer: a touch more lush.
	col = mix(col, col * vec3(0.9, 1.05, 0.85), season_summer * greenness);
	// Autumn: each tree picks its own warm colour (orange, red or gold).
	vec3 warm = instance_seed < 0.4 ? vec3(0.92, 0.46, 0.14) : (instance_seed < 0.7 ? vec3(0.8, 0.24, 0.14) : vec3(0.93, 0.72, 0.2));
	col = mix(col, warm * (0.55 + lum * 1.1), season_autumn * seasonal_leaves * greenness * 0.9);
	// Winter: muted leaves, with snow resting on top.
	col = mix(col, vec3(lum) * vec3(0.92, 0.96, 1.0), season_winter * 0.35 * greenness);
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow = season_winter * smoothstep(0.3, 0.8, up) * (0.45 + 0.55 * local_height);
	col = mix(col, vec3(0.93, 0.95, 0.98), clamp(snow, 0.0, 0.9));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	BACKLIGHT = tex.rgb * backlight_strength;
}
