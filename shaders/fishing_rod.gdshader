shader_type spatial;
// The Tripo fishing rod with its own textures, plus a bend toward the line.
// Model space: +Y runs from butt to tip, +Z is the reel side (hangs underneath).
//
// Lengthening: the model is short and chunky. The handle is stretched a little (room
// for two hands), the reel section is left as modelled (so the reel stays round and
// close to the hand), and the thin rod above the reel is stretched to full length.
// FishingTackle.remap_model_y() must match remap_y() below.
//
// `bend` (0..1) curves the rod toward +Z, more strongly toward the tip; the handle stays straight.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal_map = true;
uniform float bend = 0.0;
uniform float bend_amount = 0.18;
uniform float rod_height = 0.976;
uniform float bend_start = 0.3;
uniform float handle_end = 0.17;
uniform float reel_end = 0.36;
uniform float handle_stretch = 1.0;
uniform float blank_stretch = 1.0;

float remap_y(float y) {
	float handle = min(y, handle_end) * handle_stretch;
	float reel = clamp(y - handle_end, 0.0, reel_end - handle_end);
	float blank = max(y - reel_end, 0.0) * blank_stretch;
	return handle + reel + blank;
}

void vertex() {
	float h = clamp((VERTEX.y / rod_height - bend_start) / (1.0 - bend_start), 0.0, 1.0);
	float curve = bend * bend_amount * h * h;
	VERTEX.y = remap_y(VERTEX.y) - curve * 0.35 * h;
	VERTEX.z += curve;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ROUGHNESS = 0.75;
	SPECULAR = 0.35;
}
