extends Node3D
## Hand-placed rainwater/polished asphalt. These are authored reflective accents,
## not an expensive fullscreen mirror or a randomly scattered texture.
const Materials = preload("res://scripts/material_library.gd")
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
		var slab := BoxMesh.new()
		slab.size = Vector3(3.2 if idx % 2 == 0 else 4.1, 0.025, 7.0 if idx % 3 == 0 else 4.0)
		mesh.mesh = slab
		mesh.position = PATCHES[idx] + Vector3.UP * 0.035
		mesh.material_override = Materials.surface("WET", Color("435466"))
		add_child(mesh)
		_count += 1

func patch_count() -> int:
	return _count
