extends RefCounted
## Imported offline meshes share a single UV atlas and ShaderMaterial. The
## player and NPCs use the same art as stores and venues. No runtime mesh bake.
const MODELS = {
	"acoustic_guitar":preload("res://assets/music/models/acoustic_guitar.obj"),
	"punk_bass":preload("res://assets/music/models/punk_bass.obj"),
	"portable_synth":preload("res://assets/music/models/portable_synth.obj"),
	"combo_amp":preload("res://assets/music/models/combo_amp.obj"),
	"mic_stand":preload("res://assets/music/models/mic_stand.obj"),
	"road_case":preload("res://assets/music/models/road_case.obj")
}
const WEAR = preload("res://shaders/music/instrument_wear.gdshader")
const COLOR = preload("res://assets/music/textures/instrument_color.svg")
const SURFACE = preload("res://assets/music/textures/instrument_surface.svg")
const NORMAL = preload("res://assets/music/textures/instrument_normal.svg")
static var _material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = WEAR
		_material.set_shader_parameter("color_map",COLOR)
		_material.set_shader_parameter("surface_map",SURFACE)
		_material.set_shader_parameter("normal_map",NORMAL)
	return _material

static func build(id: String) -> MeshInstance3D:
	var prop := MeshInstance3D.new()
	prop.name = id
	prop.mesh = MODELS.get(id) as Mesh
	prop.material_override = material()
	return prop

static func place(parent: Node3D, id: String, at: Vector3, rotation_degrees: Vector3 = Vector3.ZERO, range_end: float = 45.0) -> MeshInstance3D:
	var prop := build(id)
	prop.position = at
	prop.rotation_degrees = rotation_degrees
	prop.visibility_range_end = range_end
	prop.visibility_range_end_margin = 3.0 if range_end>0.0 else 0.0
	parent.add_child(prop)
	return prop
