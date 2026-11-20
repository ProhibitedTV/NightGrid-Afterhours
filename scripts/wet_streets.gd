extends Node3D
## Stable, shallow polygon puddles with asymmetric edges rather than raised boxes.
const Materials = preload("res://scripts/material_library.gd")
const SEGMENTS = 20
const PATCHES = [
	Vector3(-174.0, 0.0, -145.0), Vector3(-116.0, 0.0, -88.0),
	Vector3(-58.0, 0.0, -23.0), Vector3(0.0, 0.0, -34.0),
	Vector3(58.0, 0.0, -88.0), Vector3(116.0, 0.0, -33.0),
	Vector3(174.0, 0.0, -88.0), Vector3(-174.0, 0.0, 88.0),
	Vector3(-116.0, 0.0, 145.0), Vector3(-58.0, 0.0, 88.0),
	Vector3(0.0, 0.0, 91.0), Vector3(58.0, 0.0, 146.0),
	Vector3(116.0, 0.0, 88.0), Vector3(174.0, 0.0, 147.0),
	Vector3(-34.0, 0.0, -116.0), Vector3(91.0, 0.0, 116.0)
]
var _count := 0

func _ready() -> void:
	for idx in range(PATCHES.size()):
		var mesh := MeshInstance3D.new()
		mesh.name = "WetStreet_%02d" % idx
		var radius_x := 1.75 if idx % 2 == 0 else 2.35
		var radius_z := 3.65 if idx % 3 == 0 else 2.45
		mesh.mesh = _make_puddle(idx, radius_x, radius_z)
		# Nine millimeters above the road top avoids z-fighting.
		mesh.position = PATCHES[idx] + Vector3.UP * 0.014
		mesh.material_override = Materials.surface("WET", Color("576575"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		_count += 1

func _shoreline(angle: float, index: int, radius_x: float, radius_z: float) -> Vector3:
	var wave := 0.84 + sin(angle * 3.0 + float(index) * 0.83) * 0.095
	wave += sin(angle * 7.0 - float(index) * 0.47) * 0.047
	wave += cos(angle * 11.0 + float(index) * 0.19) * 0.025
	return Vector3(cos(angle) * radius_x * wave, 0.0, sin(angle) * radius_z * wave)

func _make_puddle(index: int, radius_x: float, radius_z: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	for segment in range(SEGMENTS):
		var first := _shoreline(TAU * float(segment) / float(SEGMENTS), index, radius_x, radius_z)
		var second := _shoreline(TAU * float(segment + 1) / float(SEGMENTS), index, radius_x, radius_z)
		# Clockwise winding in XZ faces up, allowing normal-map specular highlights.
		for point in [Vector3.ZERO, second, first]:
			vertices.append(point)
			normals.append(Vector3.UP)
			uvs.append(Vector2(point.x / (radius_x * 2.0) + 0.5, point.z / (radius_z * 2.0) + 0.5))
			tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func patch_count() -> int:
	return _count
