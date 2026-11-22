shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D concrete_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 lane_size = vec2(5.5,20.0);
uniform float tile_metres : hint_range(0.5,5.0) = 2.0;
uniform float wetness : hint_range(0.0,1.0) = 0.88;
// Fixed local drainage catchments. No animation or camera-relative masks.
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float value_noise(vec2 p) {
	vec2 i=floor(p);
	vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),
		mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float basin(vec2 p, vec2 center, vec2 radii) {
	float n=value_noise(p*3.1)*0.30 + value_noise(p*7.8)*0.12;
	float d=length((p-center)/radii)+n;
	return 1.0-smoothstep(0.66,1.04,d);
}
void fragment() {
	vec2 p=(UV-vec2(0.5))*lane_size;
	vec2 photo_uv=p/tile_metres;
	vec3 photo=texture(concrete_albedo,photo_uv).rgb;
	vec3 arm=texture(concrete_arm,photo_uv).rgb;
	vec3 detail_normal=texture(concrete_normal,photo_uv).rgb;
	float gutter=1.0-smoothstep(0.22,0.92,lane_size.x*0.5-abs(p.x));
	float damp=clamp((0.22+gutter*0.58+value_noise(p*0.45)*0.26)*wetness,0.0,1.0);
	float pool=max(basin(p,vec2(-0.65,-6.6),vec2(0.92,2.05)),
		basin(p,vec2(0.64,0.2),vec2(1.12,1.65)));
	pool=max(pool,basin(p,vec2(-0.94,5.85),vec2(0.78,1.78)));
	pool=max(pool,basin(p,vec2(lane_size.x*0.5-0.57,-1.1),vec2(0.46,1.38)));
	pool*=wetness;
	float standing=smoothstep(0.24,0.8,pool);
	// Real photo channels remain visible under a thin water film. No metallic
	// pavement, fake colored reflections or screen-copy refraction.
	ALBEDO=photo*mix(vec3(0.83,0.81,0.77),vec3(0.39,0.43,0.45),max(damp,standing));
	ROUGHNESS=mix(clamp(arm.g,0.38,1.0),0.29,damp);
	ROUGHNESS=mix(ROUGHNESS,0.075,standing);
	NORMAL_MAP=mix(detail_normal,vec3(0.5,0.5,1.0),standing*0.91);
	NORMAL_MAP_DEPTH=0.68;
	AO=mix(arm.r,1.0,standing*0.6);
	METALLIC=0.0;
	SPECULAR=0.5;
}
