shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap;
uniform vec4 neon_tint : source_color = vec4(0.15,0.8,0.95,1.0);
instance uniform float dispense_flash = 0.0;
void fragment() {
	vec3 ink = texture(artwork, UV).rgb;
	float band = 1.0 - smoothstep(0.0,0.055,abs(UV.y-fract(TIME*0.12)));
	float header = 1.0-smoothstep(0.22,0.29,UV.y);
	float pulse = 0.86 + 0.14*sin(TIME*2.0);
	ALBEDO = ink*0.65;
	ROUGHNESS = 0.42;
	METALLIC = 0.12;
	EMISSION = ink*(0.55 + header*pulse*1.1) + neon_tint.rgb*(band*0.18 + dispense_flash*0.8);
}
