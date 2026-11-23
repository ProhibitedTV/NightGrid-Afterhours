shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

global uniform float cinder_surface_film;
uniform vec4 enamel : source_color = vec4(0.24, 0.34, 0.39, 1.0);
uniform float flake_content : hint_range(0.0, 1.0) = 0.28;
uniform sampler2D rain_beads : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
instance uniform float impact = 0.0;
instance uniform float panel_origin_y = 0.0;
varying vec3 panel_position;

void vertex() {
	panel_position = VERTEX;
}

float patch_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	vec4 offsets = vec4(0.0, 127.1, 311.7, 438.8);
	vec4 samples = fract(sin(dot(i, vec2(127.1, 311.7)) + offsets) * 43758.54);
	return mix(mix(samples.x, samples.y, s.x), mix(samples.z, samples.w, s.x), s.y);
}

void fragment() {
	float chips = 0.0;
	if (impact > 0.001) {
		vec2 area = vec2(panel_position.x + panel_position.z * .39,
			panel_position.y + panel_position.z * .30);
		float abrasion = patch_noise(area * vec2(4.6, 12.0)) * .72 + patch_noise(area * 28.0) * .28;
		float scrape_zone = smoothstep(.55, .87, abrasion + impact * .20);
		float track = patch_noise(area * vec2(3.8, 97.0) + vec2(8.2, -2.3));
		float scratches = smoothstep(.62, .91, track) * scrape_zone;
		chips = impact * (scrape_zone * .52 + scratches * .48);
	}
	// The colour coat still scatters light under the polished dielectric clearcoat.
	// Only the exposed surface roughness changes when a water film forms.
	float film = smoothstep(.06, .91, cinder_surface_film);
	vec2 flake_uv = UV * 1660.0;
	float close_flake = 1.0 - smoothstep(.25, 1.22, length(fwidth(flake_uv)));
	float flake = .5 + (patch_noise(flake_uv) - .5) * close_flake;
	float rocker_film = 1.0 - smoothstep(.15, .43, panel_position.y + panel_origin_y);
	vec3 base = enamel.rgb * mix(1.0, .91, film) * mix(.93, 1.07, flake);
	base = mix(base, base * .79 + vec3(.012, .010, .008), rocker_film * .43);
	ALBEDO = mix(base, vec3(.058, .059, .064), chips);
	METALLIC = mix(flake_content + (flake - .5) * .22, .66, chips);
	ROUGHNESS = mix(mix(.184, .085, film) + (flake - .5) * .055 + rocker_film * .07, .63, chips);
	SPECULAR = .65;
	CLEARCOAT = mix(.86, 1.0, film) * (1.0 - chips * .87 - rocker_film * .12);
	CLEARCOAT_ROUGHNESS = mix(.104, .05, film) + chips * .28 + rocker_film * .05;
	float near_view = 1.0 - smoothstep(6.0, 15.0, length(VERTEX));
	if (film * near_view > .01) {
		vec3 beads = texture(rain_beads, UV * 11.5).rgb;
		NORMAL_MAP = beads;
		NORMAL_MAP_DEPTH = film * near_view * .24;
	}
}
