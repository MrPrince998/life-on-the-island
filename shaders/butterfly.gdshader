shader_type spatial;
// A tiny butterfly for particles: a camera-facing quad with two rounded wings that
// flap. Colour comes from the particle colour.
render_mode unshaded, cull_disabled;

uniform float flap_speed = 15.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float phase = dot(MODEL_MATRIX[3].xyz, vec3(1.7, 3.1, 2.3));
	VERTEX.x *= 0.2 + 0.8 * abs(sin(TIME * flap_speed + phase));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Two wings either side of a thin body.
	vec2 wing = vec2((abs(p.x) - 0.48) / 0.5, (p.y + 0.1) / 0.8);
	float w = 1.0 - smoothstep(0.85, 1.0, length(wing));
	float body = (1.0 - smoothstep(0.06, 0.1, abs(p.x))) * (1.0 - smoothstep(0.6, 0.7, abs(p.y)));
	if (max(w, body) < 0.5) {
		discard;
	}
	ALBEDO = mix(COLOR.rgb, vec3(0.2, 0.14, 0.1), body);
}
