shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

global uniform float cinder_surface_film;
uniform sampler2D rain_beads : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Same per-instance damage slot as the paint shader on mixed-material meshes.
instance uniform float impact = 0.0;

vec2 crack_seed(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1,311.7)), dot(cell,vec2(269.5,183.3)))) * 43758.5453);
}

float crack_edges(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 10.0;
	float second = 10.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 delta = offset + crack_seed(cell + offset) - local;
			float dist = dot(delta, delta);
			if (dist < first) { second = first; first = dist; }
			else { second = min(second, dist); }
		}
	}
	return sqrt(second) - sqrt(first);
}

void fragment() {
	float grazing = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.65);
	float film = smoothstep(.06, .92, cinder_surface_film);
	// Laminated glass transmits the seats straight on and gains reflected sky
	// and local light at shallow angles. The ceramic edge is separate geometry.
	ALBEDO = vec3(.016, .033, .041);
	METALLIC = .0;
	SPECULAR = .77;
	ROUGHNESS = mix(.092, .049, film);
	CLEARCOAT = .86;
	CLEARCOAT_ROUGHNESS = mix(.095, .046, film);
	ALPHA = mix(.57, .94, grazing) + film * .029;
	// Cracked laminated glass stays in the frame; no fake detached glass bodies.
	if (impact > .48) {
		vec2 grid = UV * vec2(23.0, 17.0);
		float aa = max(fwidth(grid.x) + fwidth(grid.y), .018);
		float edge = 1.0 - smoothstep(.015, .015 + aa * .65, crack_edges(grid));
		float mask = smoothstep(.48, .88, impact) * edge * (1.0 - smoothstep(.20, .85, aa));
		ALBEDO = mix(ALBEDO, vec3(.58,.66,.69), mask);
		ROUGHNESS = mix(ROUGHNESS, .48, mask);
		ALPHA = mix(ALPHA, .97, mask);
	}
	float near_view = 1.0 - smoothstep(5.0, 13.0, length(VERTEX));
	if (film * near_view > .01) {
		NORMAL_MAP = texture(rain_beads, UV * vec2(12.5, 8.0)).rgb;
		NORMAL_MAP_DEPTH = film * near_view * .31;
	}
}
