shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Morrow Bay's opaque harbor: fixed geometry, analytic water normals and
// shallow-to-deep tint. No screen/depth copies, transparency or vertex waves.
uniform vec4 deep_water : source_color = vec4(0.025,0.095,0.13,1.0);
uniform vec4 shore_water : source_color = vec4(0.10,0.24,0.25,1.0);
uniform float quay_edge = 246.0;
uniform float wave_strength : hint_range(0.0,1.0) = 0.65;
varying vec3 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 p = world_at.xz;
	// Oriented long swell and two independent finer capillary wave bands.
	vec2 d1 = normalize(vec2(0.87,0.49));
	vec2 d2 = normalize(vec2(-0.38,0.92));
	vec2 d3 = normalize(vec2(0.69,-0.72));
	float a = dot(p,d1)*0.72 + TIME*0.96;
	float b = dot(p,d2)*2.15 - TIME*1.36;
	float c = dot(p,d3)*5.4 + TIME*2.1;
	float fine = 1.0-smoothstep(45.0,160.0,length(VERTEX));
	vec2 slope = d1*cos(a)*0.12 + d2*cos(b)*0.055 + d3*cos(c)*0.028*fine;
	vec3 world_normal = normalize(vec3(-slope.x*wave_strength,1.0,-slope.y*wave_strength));
	NORMAL = normalize(mat3(VIEW_MATRIX)*world_normal);
	// Continuous world-space shading on both meshes, even at the corner.
	float offshore = max(max(-p.x-quay_edge,-p.y-quay_edge),0.0);
	float shallows = 1.0-smoothstep(1.0,24.0,offshore);
	float variation = sin(a)*0.025 + sin(b)*0.015;
	ALBEDO = mix(deep_water.rgb,shore_water.rgb,shallows)* (1.0+variation);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = clamp(0.17+0.12*abs(sin(b))+0.06*shallows,0.14,0.38);
}
