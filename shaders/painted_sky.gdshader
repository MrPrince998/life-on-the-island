shader_type sky;

// Seamless directional noise: soft gouache-like masses, not a flat sky card.
uniform vec3 sky_top_color : source_color = vec3(0.24, 0.48, 0.75);
uniform vec3 sky_horizon_color : source_color = vec3(0.74, 0.86, 0.93);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.3, 0.38);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 cloud_shadow : source_color = vec3(0.65, 0.75, 0.85);
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float twilight : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_direction = vec3(0.0, 0.7, -0.7);
uniform float sun_visible : hint_range(0.0, 1.0) = 1.0;
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
	// A turquoise middle wash adds depth between the pale horizon and blue zenith.
	vec3 middle = mix(sky_horizon_color, sky_top_color, 0.52);
	middle = mix(middle, vec3(0.22, 0.48, 0.57), daylight * (1.0 - overcast) * 0.12);
	vec3 background = mix(sky_horizon_color, middle, smoothstep(0.0, 0.3, elevation));
	background = mix(background, sky_top_color, smoothstep(0.22, 1.0, elevation));
	float clear_sky = 1.0 - overcast;
	float sun_dot = max(dot(direction, normalize(sun_direction)), 0.0);
	vec3 sunlight = mix(vec3(1.0, 0.86, 0.62), vec3(1.0, 0.48, 0.23), twilight);
	// Wide atmospheric glow and a small feathered disc, occluded by clouds below.
	background += sunlight * pow(sun_dot, 12.0) * 0.16 * clear_sky * sun_visible;
	background += sunlight * pow(sun_dot, 180.0) * 0.28 * clear_sky * sun_visible;
	float sun_disc = smoothstep(0.99965, 0.99985, sun_dot);
	background = mix(background, sunlight * 1.6, sun_disc * clear_sky * sun_visible);
	// Fixed stars use 3D directional cells, avoiding a seam at the sky wrap.
	vec3 star_position = direction * 210.0;
	vec3 star_cell = floor(star_position);
	vec3 star_center = vec3(hash(star_cell), hash(star_cell + 19.2), hash(star_cell + 73.1));
	float star_distance = length(fract(star_position) - star_center);
	float star = (1.0 - smoothstep(0.04, 0.19, star_distance)) * step(0.9, hash(star_cell + 42.0));
	float night = (1.0 - daylight) * (1.0 - twilight) * clear_sky;
	background += vec3(0.72, 0.81, 1.0) * star * night * smoothstep(0.02, 0.2, elevation) * 1.5;
	vec3 moon_direction = normalize(vec3(-0.3, 0.6, -0.7));
	float moon_dot = max(dot(direction, moon_direction), 0.0);
	background += vec3(0.3, 0.4, 0.65) * pow(moon_dot, 90.0) * night * 0.1;
	float moon = smoothstep(0.9994, 0.9996, moon_dot);
	background = mix(background, vec3(0.78, 0.85, 0.96), moon * night);
	vec3 p = direction * vec3(7.0, 10.0, 7.0) + vec3(3.2, 1.7, 8.4);
	// Layered pigment: large forms, smaller lobes and directional brush grain.
	float broad = noise3(p);
	float detail = noise3(p * 2.1 + 5.0);
	float lobes = noise3(p * 4.3 + vec3(7.0, 1.0, 3.0));
	float brush = noise3(p * vec3(12.0, 32.0, 12.0));
	float body = broad * 0.66 + detail * 0.25 + lobes * 0.09;
	float threshold = mix(0.52, 0.28, overcast);
	float edge = smoothstep(threshold, threshold + 0.065, body);
	// An offset density sample gives the cloud a lit upper edge and cool underside.
	float upper = noise3(p + vec3(-0.18, 0.32, 0.12));
	float sculpt = clamp(0.55 + (broad - upper) * 2.6, 0.0, 1.0);
	float wash = smoothstep(0.22, 0.8, detail * 0.65 + lobes * 0.35);
	float light_amount = clamp(sculpt * 0.72 + wash * 0.28, 0.0, 1.0);
	vec3 pigment = mix(cloud_shadow, cloud_light, light_amount);
	// Low-contrast dry-brush marks stay inside clouds, keeping silhouettes calm.
	pigment *= 0.94 + brush * 0.12;
	float horizon_fade = smoothstep(0.005, 0.13, elevation);
	COLOR = mix(background, pigment, edge * horizon_fade);
	if (direction.y < 0.0) {
		COLOR = mix(sky_horizon_color, ground_bottom_color, sqrt(-direction.y));
	}
	COLOR *= sky_energy;
}
