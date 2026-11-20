shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Original lightweight Morrow Bay harbor water. Opaque, low-geometry and
// Forward+/OpenGL-compatible: no screen reads, no SSR or depth buffer probes.
// Long-wavelength displacement is deliberately tiny to preserve shore edges.
uniform vec4 deep_harbor : source_color = vec4(0.022, 0.080, 0.112, 1.0);
uniform vec4 wavecrest_tint : source_color = vec4(0.058, 0.157, 0.170, 1.0);
uniform float wave_height : hint_range(0.0, 0.12) = 0.055;
uniform float surface_detail : hint_range(0.0, 1.0) = 0.45;
varying vec2 world_water_xz;

void vertex() {
    world_water_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    float slow_swell = sin(world_water_xz.x * 0.065 + TIME * 0.46);
    float cross_swell = sin(world_water_xz.y * 0.105 - TIME * 0.38);
    VERTEX.y += (slow_swell * 0.6 + cross_swell * 0.4) * wave_height;
}

void fragment() {
    float ripple_x = sin(dot(world_water_xz, vec2(0.22, 0.07)) + TIME * 0.65);
    float ripple_z = sin(dot(world_water_xz, vec2(-0.095, 0.17)) - TIME * 0.49);
    float gentle = sin(dot(world_water_xz, vec2(0.049, 0.056)) + TIME * 0.19);
    float variation = clamp(0.50 + (ripple_x * 0.23 +
        ripple_z * 0.21 + gentle * 0.18) * surface_detail, 0.0, 1.0);
    ALBEDO = mix(deep_harbor.rgb, wavecrest_tint.rgb, variation);
    ROUGHNESS = mix(0.17, 0.33, variation);
    METALLIC = 0.13;
    SPECULAR = 0.65;
}
