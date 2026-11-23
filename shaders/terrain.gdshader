shader_type spatial;
// Stylized painted terrain. Vertex colour carries paint weights:
//   r = sand, g = rock, b = dirt/path, remainder = grass.
// Noise breaks up the borders so blends look brushed rather than blurred.
render_mode diffuse_lambert_wrap, specular_disabled;

uniform vec4 grass_light : source_color = vec4(0.53, 0.73, 0.34, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.34, 0.55, 0.25, 1.0);
uniform vec4 sand_color : source_color = vec4(0.91, 0.83, 0.62, 1.0);
uniform vec4 wet_sand_color : source_color = vec4(0.66, 0.6, 0.46, 1.0);
uniform vec4 rock_color : source_color = vec4(0.55, 0.52, 0.48, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.62, 0.47, 0.32, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float edge_breakup = 0.35;
// Seasons (0..1 each, set by DayNightController; spring is all zero).
global uniform float season_summer;
global uniform float season_autumn;
global uniform float season_winter;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float paint(float weight, float noise_value) {
	return smoothstep(0.42, 0.58, weight + (noise_value - 0.5) * edge_breakup);
}

void fragment() {
	float n_large = texture(noise_tex, world_pos.xz * 0.012).r;
	float n_mid = texture(noise_tex, world_pos.xz * 0.06).r;
	float n_fine = texture(noise_tex, world_pos.xz * 0.35).r;

	vec3 grass = mix(grass_dark.rgb, grass_light.rgb, smoothstep(0.3, 0.75, n_large));
	grass *= 0.88 + 0.22 * n_mid;

	vec3 sand = mix(wet_sand_color.rgb, sand_color.rgb, smoothstep(-0.2, 1.2, world_pos.y));
	sand *= 0.95 + 0.1 * n_fine;
	vec3 rock = rock_color.rgb * (0.82 + 0.3 * n_mid) * (0.92 + 0.12 * n_fine);
	vec3 dirt = dirt_color.rgb * (0.88 + 0.2 * n_fine);

	// Summer: deeper, richer green. Autumn: patches of gold and russet.
	// (Colours below are linear: the sRGB golds 0.62/0.52/0.26 and 0.74/0.62/0.30.)
	grass = mix(grass, grass * vec3(0.72, 0.98, 0.55), season_summer);
	vec3 autumn_grass = mix(vec3(0.34, 0.23, 0.055), vec3(0.51, 0.34, 0.074), n_mid) * (0.9 + 0.2 * n_fine);
	grass = mix(grass, autumn_grass, season_autumn * smoothstep(0.15, 0.65, n_large + 0.25));

	vec3 col = grass;
	col = mix(col, dirt, paint(COLOR.b, n_mid));
	col = mix(col, sand, paint(COLOR.r, n_mid));
	col = mix(col, rock, paint(COLOR.g, n_fine));

	// Winter: snow settles on flat ground, thinner on paths and hardly on the beach.
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow = season_winter * smoothstep(0.55, 0.85, up) * smoothstep(0.2, 0.55, n_mid + 0.35);
	snow *= 1.0 - 0.55 * paint(COLOR.b, n_mid);
	snow *= 1.0 - 0.85 * paint(COLOR.r, n_mid);
	col = mix(col, vec3(0.93, 0.95, 0.98) * (0.94 + 0.06 * n_fine), snow);

	ALBEDO = col;
	ROUGHNESS = 0.95;
}
