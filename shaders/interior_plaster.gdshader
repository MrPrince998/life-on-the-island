shader_type spatial;
// Warm lime plaster walls with a wooden panel along the bottom (wainscot), in the
// cottage's hand-painted style. World-space, so any box works without UVs.

uniform vec3 plaster_color : source_color = vec3(0.93, 0.86, 0.72);
uniform vec3 plaster_shade : source_color = vec3(0.82, 0.72, 0.58);
uniform vec3 panel_color : source_color = vec3(0.5, 0.32, 0.19);
uniform vec3 panel_dark : source_color = vec3(0.33, 0.2, 0.12);
// World height of the top of the wooden panel (set by the room script).
uniform float wainscot_top = 0.95;
uniform float panel_board_width = 0.16;

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
	vec3 n = abs(world_normal);
	float across = n.x > n.z ? world_pos.z : world_pos.x;
	if (world_pos.y < wainscot_top && n.y < 0.5) {
		// Vertical boards with a darker rail on top.
		float board = floor(across / panel_board_width);
		float id = hash(vec2(board, 1.7));
		vec3 c = mix(panel_color, panel_color * 1.15, id);
		float grain = noise(vec2(across * 30.0, world_pos.y * 2.0 + id * 10.0));
		c = mix(c, panel_dark, grain * 0.25);
		float seam = smoothstep(0.0, 0.06, fract(across / panel_board_width)) * smoothstep(1.0, 0.94, fract(across / panel_board_width));
		c = mix(panel_dark, c, seam);
		float rail = smoothstep(wainscot_top - 0.09, wainscot_top - 0.07, world_pos.y);
		ALBEDO = mix(c, panel_dark * 1.1, rail);
		ROUGHNESS = 0.8;
	} else {
		// Soft, slightly blotchy plaster.
		float blotch = noise(vec2(across, world_pos.y) * 1.3) * 0.6 + noise(vec2(across, world_pos.y) * 5.0) * 0.4;
		ALBEDO = mix(plaster_color, plaster_shade, blotch * 0.55);
		ROUGHNESS = 0.95;
	}
}
