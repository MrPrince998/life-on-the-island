shader_type sky;

// Seamless directional noise: soft gouache-like masses, not a flat sky card.
uniform vec3 sky_top_color : source_color = vec3(0.36, 0.6, 0.86);
uniform vec3 sky_horizon_color : source_color = vec3(0.74, 0.86, 0.93);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.3, 0.38);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 cloud_shadow : source_color = vec3(0.65, 0.75, 0.85);
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float sky_energy : hint_range(0.0, 2.0) = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec3 background = mix(sky_horizon_color, sky_top_color, pow(elevation, 0.55));
	vec3 p = direction * vec3(7.0, 10.0, 7.0) + vec3(3.2, 1.7, 8.4);
	float broad = noise3(p);
	float detail = noise3(p * 2.1 + 5.0);
	float brush = noise3(p * vec3(8.0, 23.0, 8.0));
	float body = broad * 0.78 + detail * 0.212 + brush * 0.008;
	float threshold = mix(0.53, 0.29, overcast);
	float edge = smoothstep(threshold, threshold + 0.095, body);
	// Broad, slightly stepped pigment washes suggest volume inside the silhouette.
	float wash = smoothstep(0.28, 0.78, broad * 0.55 + detail * 0.45);
	wash = mix(wash, smoothstep(0.25, 0.7, wash), 0.45);
	vec3 pigment = mix(cloud_shadow, cloud_light, 0.3 + wash * 0.7);
	pigment *= 0.985 + brush * 0.03;
	float horizon_fade = smoothstep(0.005, 0.13, elevation);
	COLOR = mix(background, pigment, edge * horizon_fade);
	if (direction.y < 0.0) {
		COLOR = mix(sky_horizon_color, ground_bottom_color, sqrt(-direction.y));
	}
	COLOR *= sky_energy;
}
