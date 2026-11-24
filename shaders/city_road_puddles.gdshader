shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

global uniform float cinder_surface_film;
uniform sampler2D bitumen_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bitumen_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bitumen_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 road_tint : source_color = vec4(.5686, .5843, .6039, 1.0);
uniform vec4 rain_tint : source_color = vec4(.3241, .3506, .3805, 1.0);

void fragment() {
	float film = clamp(cinder_surface_film, 0.0, 1.0);
	float crown = film * .72;
	// The patch shrinks inward as the shared weather film dries.
	float radius = mix(.14, 1.0, film);
	float pool = (1.0 - smoothstep(max(radius - .22, 0.0), radius, UV2.x))
		* smoothstep(.06, .28, film);
	if (pool <= .002) {
		discard;
	}
	vec3 photo = texture(bitumen_color, UV).rgb;
	float grit = texture(bitumen_roughness, UV).r;
	// Shoreline returns continuously to the underlying photographic road.
	vec3 road = photo * mix(road_tint.rgb, rain_tint.rgb, crown);
	ALBEDO = road * mix(1.0, .56, pool);
	ROUGHNESS = mix(grit * mix(1.0, .29, crown), .075 + .055 * grit, pool);
	METALLIC = 0.0;
	SPECULAR = .5;
	vec3 n = texture(bitumen_normal, UV).rgb;
	NORMAL_MAP = mix(n, vec3(.5, .5, 1.0), pool);
	NORMAL_MAP_DEPTH = mix(mix(.75, .36, crown), .22, pool);
	CLEARCOAT = mix(.72 * crown, .92, pool);
	CLEARCOAT_ROUGHNESS = mix(mix(.22, .12, crown), .07, pool);
}
