shader_type canvas_item;
// Round minimap window: shows the part of the painted island map around the player.
// UV (0..1) covers the minimap; centre_uv / span pick the part of the map texture.

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 center_uv = vec2(0.5);
uniform float span = 0.27;
uniform bool map_ready = false;
uniform vec4 sea_color : source_color = vec4(0.243, 0.561, 0.69, 1.0);
uniform vec4 blank_color : source_color = vec4(0.965, 0.918, 0.824, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec2 uv = center_uv + d * span;
	vec4 c = sea_color;
	if (!map_ready) {
		c = blank_color;
	} else if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		c = texture(map_tex, uv);
	}
	// Soft darkening toward the rim, and a clean round edge.
	c.rgb *= mix(1.0, 0.8, smoothstep(0.34, 0.5, r));
	c.a = 1.0 - smoothstep(0.492, 0.5, r);
	COLOR = c;
}
