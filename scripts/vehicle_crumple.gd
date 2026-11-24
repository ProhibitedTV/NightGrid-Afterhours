extends RefCounted
## Bounded, deterministic deformation of the original authored ArrayMesh.
## Rebuild on damage events, never each physics/render frame.
## Keep source topology, UVs, materials and the collision envelope intact.
static func vertex_delta(p: Vector3, end_sign: float, damage: float, end_offset: float = 0.0) -> Vector3:
	var strength := clampf(damage, 0.0, 1.0)
	var tip := smoothstep(1.80, 2.34, p.z * end_sign - end_offset)
	var fold := 0.72 + 0.28 * cos(p.x * 7.2 + p.y * 5.0)
	var crease := sin(p.x * 10.0 + p.y * 6.3)
	return Vector3(0.018 * crease, 0.065 * crease, -end_sign * 0.24 * fold) * tip * strength

static func build(source: ArrayMesh, end_sign: float, damage: float, end_offset: float = 0.0) -> ArrayMesh:
	if damage <= 0.001:
		return source
	var result := ArrayMesh.new()
	for i in source.get_surface_count():
		var arrays := source.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for j in vertices.size():
			var p := vertices[j]
			if p.z * end_sign <= 1.799 + end_offset:
				continue
			vertices[j] = p + vertex_delta(p, end_sign, damage, end_offset)
			# Approximate the inverse-transpose normal transform using local
			# Jacobian columns of the same smooth displacement field.
			if j < normals.size():
				var h := 0.001
				var d := vertex_delta(p, end_sign, damage, end_offset)
				var jac := Basis(
					Vector3.RIGHT + (vertex_delta(p + Vector3.RIGHT * h, end_sign, damage, end_offset) - d) / h,
					Vector3.UP + (vertex_delta(p + Vector3.UP * h, end_sign, damage, end_offset) - d) / h,
					Vector3.BACK + (vertex_delta(p + Vector3.BACK * h, end_sign, damage, end_offset) - d) / h)
				if absf(jac.determinant()) > 0.10:
					normals[j] = (jac.inverse().transposed() * normals[j]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(source.surface_get_primitive_type(i), arrays)
		result.surface_set_material(i, source.surface_get_material(i))
		result.surface_set_name(i, source.surface_get_name(i))
	return result
