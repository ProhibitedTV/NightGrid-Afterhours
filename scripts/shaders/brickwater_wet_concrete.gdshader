shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// One opaque surface. No transparent puddle planes, screen-texture reads,
// additional reflection cameras or altered physics.
uniform sampler2D concrete_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wetness_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D grime_atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec2 local_metres;

void vertex() {
	local_metres = VERTEX.xz;
}

void fragment() {
	vec2 tiled = local_metres * 0.5;
	vec3 concrete = texture(concrete_color, tiled).rgb;
	vec3 packed = texture(concrete_arm, tiled).rgb;
	vec4 grime = texture(grime_atlas, UV);
	vec2 waterline = UV + vec2(sin(local_metres.y * 8.0) * 0.006,
		cos(local_metres.x * 13.0 + local_metres.y * 5.0) * 0.002);
	float mask = texture(wetness_atlas, waterline).r;
	// Aggregate displaces the waterline and leaves rough islands inside
	// the authored catchments. Keep dry and wet roughness continuous.
	mask += (packed.g - 0.55) * 0.21 + (concrete.r - 0.34) * 0.09;
	float damp = smoothstep(0.06, 0.60, mask);
	float standing_water = smoothstep(0.61, 0.94, mask);
	// Preserve the photographic grain and broad roughness variation.
	// Wet surface darkens; only pooled cores approach mirror-like roughness.
	vec3 stained = mix(concrete, grime.rgb, grime.a * 0.58);
	ALBEDO = stained * mix(vec3(0.64, 0.62, 0.59), vec3(0.35, 0.37, 0.36), damp);
	ROUGHNESS = mix(clamp(packed.g * 0.90, 0.45, 0.94), 0.38, damp);
	ROUGHNESS = mix(ROUGHNESS, 0.16, standing_water);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	NORMAL_MAP = texture(concrete_normal, tiled).rgb;
	NORMAL_MAP_DEPTH = mix(0.72, 0.09, standing_water);
	AO = packed.r;
	CLEARCOAT = mix(0.05, 0.42, damp) + 0.27 * standing_water;
	CLEARCOAT_ROUGHNESS = mix(0.50, 0.12, standing_water);
}
