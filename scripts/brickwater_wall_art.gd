extends Node3D
## Five original transparent, wall-flush designs. No collision or lights.
const TIDE = preload("res://assets/models/nightgrid/brickwater_wall_art/tide_tag.svg")
const MOTH = preload("res://assets/models/nightgrid/brickwater_wall_art/moth_mark.svg")
const SHIFT = preload("res://assets/models/nightgrid/brickwater_wall_art/shift_stencil.svg")
const PAPER = preload("res://assets/models/nightgrid/brickwater_wall_art/paper_notices.svg")
const WAVE = preload("res://assets/models/nightgrid/brickwater_wall_art/wave_tag.svg")
const OFFSET = 0.019
static var _materials: Dictionary = {}
static var _quad: QuadMesh

static func _material(texture: Texture2D) -> StandardMaterial3D:
	if not _materials.has(texture):
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.94
		material.metallic = 0.0
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_materials[texture] = material
	return _materials[texture]

func install(left: float, right: float) -> void:
	assert(get_child_count() == 0)
	# Fixed positions below window level, outside service equipment footprints.
	# All art lies within the side walls' guaranteed depth for the fixed parcel.
	_place("TideTag", TIDE, left + OFFSET, -10.6, 1.65, Vector2(2.65, 1.325), true)
	_place("TornServiceNotices", PAPER, left + OFFSET, -3.65, 1.40, Vector2(0.90, 1.20), true)
	_place("LastShiftStencil", SHIFT, left + OFFSET, 3.45, 2.00, Vector2(1.85, 0.70), true)
	_place("MothMark", MOTH, right - OFFSET, -3.65, 1.55, Vector2(1.60, 1.60), false)
	_place("WaveTag", WAVE, right - OFFSET, -7.9, 1.75, Vector2(2.15, 1.075), false)

func _place(label: String, texture: Texture2D, x: float, z: float, y: float, size: Vector2, left: bool) -> void:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var paint := MeshInstance3D.new()
	paint.name = label
	paint.mesh = _quad
	paint.material_override = _material(texture)
	paint.position = Vector3(x, y, z)
	# QuadMesh faces local +Z; turn it toward the walkable lane on each wall.
	paint.rotation.y = PI * 0.5 if left else -PI * 0.5
	paint.scale = Vector3(size.x, size.y, 1.0)
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint.set_meta("surface_art", true)
	add_child(paint)
