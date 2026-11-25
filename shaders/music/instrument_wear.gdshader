shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_map : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
void fragment() {
	vec3 base = texture(color_map, UV).rgb;
	vec3 surface = texture(surface_map, UV).rgb;
	ALBEDO = base;
	ROUGHNESS = clamp(surface.r, 0.25, 0.92);
	METALLIC = surface.g;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = 0.4;
	EMISSION = base * surface.b * 1.25;
}
