shader_type spatial;
// A Tripo model's own textures, with parts of the model hidden: any pixel inside one of
// the cut boxes (in the mesh's own coordinates) is not drawn. Used to remove a closed gate
// from a model so the gateway can be walked through. Set up by scripts/world/model_cutout.gd.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal_map = false;
uniform float roughness_value = 0.85;
// Up to 4 boxes: min corner and max corner, in mesh units.
uniform int cut_count = 0;
uniform vec3 cut_min[4];
uniform vec3 cut_max[4];
// Inverted: draw ONLY what is inside the boxes (the turning sails of a windmill).
uniform bool keep_inside = false;
// Windmill sails: a region shaped like the sails instead of boxes: the hub disc (within
// sail_depth = min/max distance along sail_normal from sail_hub) and four arms, each in
// its own depth range (directions sail_arms, radians in the plane, measured from
// sail_u towards sail_w). Anything in sail_exclude (u min, u max, w max) is left out:
// for a door arch that juts into the slab below the hub. All in mesh units.
uniform bool sail_mode = false;
uniform vec3 sail_hub = vec3(0.0);
uniform vec3 sail_normal = vec3(0.0, 0.0, 1.0);
uniform vec3 sail_u = vec3(1.0, 0.0, 0.0);
uniform vec3 sail_w = vec3(0.0, 1.0, 0.0);
uniform vec2 sail_depth = vec2(-0.03, 0.05);
uniform float sail_hub_radius = 0.1;
uniform float sail_arm_length = 0.5;
uniform float sail_arm_half_width = 0.09;
uniform vec4 sail_arms = vec4(0.0);
// Each arm's own depth range (the blades are not quite in one plane): min and max.
uniform vec4 sail_arm_depth_min = vec4(-0.03);
uniform vec4 sail_arm_depth_max = vec4(0.05);
// Out past the wall (beyond sail_tip_from along the arm), each arm reaches this much
// further back, for the back of the blade frames.
uniform vec4 sail_tip_extra = vec4(0.0);
uniform float sail_tip_from = 0.3;
uniform vec3 sail_exclude = vec3(0.0, 0.0, -10.0);

varying vec3 mesh_pos;

void vertex() {
	mesh_pos = VERTEX;
}

bool in_sails(vec3 p) {
	vec3 rel = p - sail_hub;
	float d = dot(rel, sail_normal);
	vec2 q = vec2(dot(rel, sail_u), dot(rel, sail_w));
	if (q.x > sail_exclude.x && q.x < sail_exclude.y && q.y < sail_exclude.z) {
		return false;
	}
	if (length(q) < sail_hub_radius) {
		return d >= sail_depth.x && d <= sail_depth.y;
	}
	for (int i = 0; i < 4; i++) {
		vec2 dir = vec2(cos(sail_arms[i]), sin(sail_arms[i]));
		float along = dot(q, dir);
		float depth_min = sail_arm_depth_min[i] - sail_tip_extra[i] * step(sail_tip_from, along);
		if (d < depth_min || d > sail_arm_depth_max[i]) {
			continue;
		}
		float across = abs(q.x * dir.y - q.y * dir.x);
		if (along > 0.0 && along < sail_arm_length && across < sail_arm_half_width) {
			return true;
		}
	}
	return false;
}

void fragment() {
	bool inside = false;
	for (int i = 0; i < cut_count; i++) {
		if (all(greaterThanEqual(mesh_pos, cut_min[i])) && all(lessThanEqual(mesh_pos, cut_max[i]))) {
			inside = true;
		}
	}
	if (sail_mode) {
		inside = inside || in_sails(mesh_pos);
	}
	if ((cut_count > 0 || sail_mode) && inside != keep_inside) {
		discard;
	}
	ALBEDO = texture(albedo_tex, UV).rgb;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
}
