shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// One opaque surface. No transparent puddle planes, screen-texture reads,
// additional reflection cameras or altered physics.
// Shared weather film also drives the Cinder's paint and glass. Local
// authored drainage retains damp depressions even after a clear spell.
global uniform float cinder_surface_film;
uniform sampler2D concrete_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wetness_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D grime_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D repair_emitter : filter_linear_mipmap, repeat_disable;
uniform sampler2D laundry_emitter : filter_linear_mipmap, repeat_disable;
instance uniform vec3 repair_plane;
instance uniform vec3 laundry_plane;
instance uniform float neon_night = 0.0;
varying vec2 local_metres;

void vertex() {
	local_metres = VERTEX.xz;
}

float emitter_on_reflected_ray(sampler2D emitter, vec3 sign_center, vec3 ray, float direction) {
	float travel = (sign_center.z + 0.071 * direction - local_metres.y) / ray.z;
	vec2 hit = vec2(local_metres.x, 0.0) + ray.xy * travel;
	vec2 uv = vec2(0.5 + (hit.x - sign_center.x) * direction / 0.88,
		0.5 - (hit.y - sign_center.y) / 1.10);
	if (travel <= 0.0 || travel >= 19.0 || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	// Low-resolution silhouette of the installed glass tubes, broadened
	// by the shallow film. The receiver follows the true mirror ray.
	return textureLod(emitter, uv, 2.25).r;
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
	float film = clamp(cinder_surface_film, 0.0, 1.0);
	// Rain first wets porous aggregate, then expands the existing low spots.
	// A dry island cannot become an unbroken mirror even during a storm.
	float drainage = smoothstep(0.20, 0.82, mask);
	float wet_mask = mask * mix(0.68, 1.0, film) + film * (0.15 + 0.19 * drainage);
	float damp = smoothstep(0.10, 0.68, wet_mask);
	float standing_water = smoothstep(0.56, 0.91, wet_mask);
	// Settlement joints cross the actual cast-in-place slab. Photographic
	// aggregate roughens their edges, and the fine groove disappears under water.
	float cross_joint = abs(fract((local_metres.y + sin(local_metres.x * 1.7) * 0.036) / 2.54 + 0.30) - 0.5) * 2.54;
	float aa = max(fwidth(cross_joint), 0.002);
	float joint = (1.0 - smoothstep(0.012 - aa, 0.012 + aa, cross_joint)) * (1.0 - standing_water * 0.85);
	// Preserve the photographic grain and broad roughness variation.
	// Wet surface darkens; only pooled cores approach mirror-like roughness.
	vec3 stained = mix(concrete, grime.rgb, grime.a * 0.58);
	ALBEDO = stained * mix(vec3(0.62, 0.60, 0.57), vec3(0.27, 0.29, 0.29), damp) * (1.0 - joint * 0.49);
	ROUGHNESS = mix(clamp(packed.g * 0.90, 0.45, 0.94), 0.31, damp);
	ROUGHNESS = mix(ROUGHNESS, mix(0.115, 0.065, film) + 0.031 * packed.g, standing_water);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	vec3 stone_normal = texture(concrete_normal, tiled).rgb;
	// Keep ripples coherent in ground space, with no added textures or
	// render passes. Band-limit detail before it turns into distant shimmer.
	float detail = 1.0 - smoothstep(0.025, 0.11, length(fwidth(local_metres)));
	vec2 ripple = vec2(sin(dot(local_metres, vec2(19.0, 13.0))),
		sin(dot(local_metres, vec2(-8.0, 27.0))));
	ripple *= detail * mix(0.55, 1.0, film);
	NORMAL_MAP = mix(stone_normal, vec3(0.5 + ripple * 0.017, 1.0), standing_water);
	NORMAL_MAP_DEPTH = mix(0.76, 0.78, standing_water);
	AO = packed.r;
	CLEARCOAT = mix(0.05, 0.33, damp) + 0.42 * standing_water;
	CLEARCOAT_ROUGHNESS = mix(0.50, 0.10, standing_water);
	if (standing_water > 0.015 && neon_night > 0.001) {
		vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 film_normal = normalize(vec3(ripple.x * 0.021, 1.0, ripple.y * 0.021));
		vec3 ray = reflect(-eye, film_normal);
		if (abs(ray.z) > 0.012) {
			float magenta = emitter_on_reflected_ray(repair_emitter, repair_plane, ray, sign(eye.z));
			float cyan = emitter_on_reflected_ray(laundry_emitter, laundry_plane, ray, sign(eye.z));
			float fresnel = 0.05 + 0.95 * pow(1.0 - clamp(dot(eye, film_normal), 0.0, 1.0), 5.0);
			EMISSION = (vec3(1.0, 0.055, 0.19) * magenta + vec3(0.025, 0.62, 1.0) * cyan)
				* (mix(2.1, 3.5, film) * standing_water * fresnel * neon_night);
		}
	}
}
