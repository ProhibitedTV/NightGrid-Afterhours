shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D art : source_color, filter_linear_mipmap;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = p * (1.0 + 0.055 * dot(p,p));
	vec2 uv = q * 0.5 + 0.5;
	float inside = step(max(abs(q.x),abs(q.y)),1.0);
	vec3 picture = texture(art,clamp(uv,vec2(0.0),vec2(1.0))).rgb;
	float scan = 0.95 + 0.05 * cos(uv.y * 950.0);
	float edge = max(0.0,1.0 - 0.24 * dot(p,p));
	float sweep = 0.035 * exp(-pow((uv.y - fract(TIME * 0.10))*12.0,2.0));
	vec3 glass = vec3(0.035,0.055,0.065) * (1.0 - smoothstep(0.0,0.16,abs(p.x+p.y*0.32+0.61)));
	ALBEDO = picture * edge * scan * inside + glass;
	EMISSION = picture * (0.18 + sweep) * inside;
}
