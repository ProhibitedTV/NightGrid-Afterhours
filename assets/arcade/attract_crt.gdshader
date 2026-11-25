shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float vignette = 1.0 - 0.22 * dot(p,p);
	float line = 0.94 + 0.06 * cos(UV.y * 720.0);
	vec3 image = texture(art, UV).rgb * tint.rgb;
	ALBEDO = image * vignette * line;
	EMISSION = image * 0.25;
}
