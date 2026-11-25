extends RefCounted
## Shared weather response for existing photographic dielectric ground materials.
## Mutates material parameters only, not meshes, textures or collision.
static func apply(material: StandardMaterial3D, film: float, tint: Color,
		base_roughness: float, base_normal: float, drainage: float,
		base_coat: float = 0.0, base_coat_roughness: float = .22) -> void:
	var water := clampf(film, 0.0, 1.0)
	var wet := water * clampf(drainage, 0.0, 1.0)
	material.albedo_color = tint.lerp(Color(tint.r * .57, tint.g * .60, tint.b * .63, tint.a), wet)
	# Photo roughness remains bound. Gutter film is stronger than the crown.
	material.roughness = lerpf(base_roughness, minf(base_roughness, .29), wet)
	material.normal_scale = lerpf(base_normal, base_normal * .48, wet)
	material.clearcoat = lerpf(base_coat, .72, wet)
	material.clearcoat_roughness = lerpf(base_coat_roughness, .12, wet)
	# Keep the feature enabled at zero coat so weather changes never force a
	# new material shader variant. No additional light or screen-copy pass.
