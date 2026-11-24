shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Original soft underbody occlusion mask. Transparent edges avoid a hard
// silhouette and the depth test remains enabled against road geometry.
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float footprint = pow(p.x, 4.0) + pow(p.y, 4.0);
	float coverage = 1.0 - smoothstep(0.18, 0.98, footprint);
	ALBEDO = vec3(0.015, 0.018, 0.022);
	ALPHA = coverage * 0.32;
}
