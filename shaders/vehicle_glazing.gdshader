shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

global uniform float cinder_surface_film;
uniform sampler2D rain_beads : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

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
	float near_view = 1.0 - smoothstep(5.0, 13.0, length(VERTEX));
	if (film * near_view > .01) {
		NORMAL_MAP = texture(rain_beads, UV * vec2(12.5, 8.0)).rgb;
		NORMAL_MAP_DEPTH = film * near_view * .31;
	}
}
