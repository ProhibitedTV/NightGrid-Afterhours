extends RefCounted
## Synaxis Omnisystems — original, source-controlled brand system.
const NAVY = Color("152e40")
const INK = Color("12232f")
const PAPER = Color("e8e8df")
const AQUA = Color("95e3d6")
const GOLD = Color("f1c879")
const RED = Color("ad4040")
const WHITE = Color("f3f5f0")
const BLUE = Color("355969")
const LIGHT = preload("res://assets/art/synaxis/synaxis_lockup_light.svg")
const DARK = preload("res://assets/art/synaxis/synaxis_lockup_dark.svg")
const MARK = preload("res://assets/art/synaxis/synaxis_mark.svg")
static var _materials: Dictionary = {}

static func wall_logo(parent: Node3D,id: String,at: Vector3,yaw: float,width: float,dark: bool=false,mark_only: bool=false) -> MeshInstance3D:
	var texture: Texture2D = MARK if mark_only else (DARK if dark else LIGHT)
	var key := "mark" if mark_only else ("dark" if dark else "light")
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture=texture
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold=.35
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key]=mat
	var quad:=QuadMesh.new()
	quad.size=Vector2(width,width if mark_only else width*.25)
	var instance:=MeshInstance3D.new()
	instance.name=id
	instance.mesh=quad
	instance.material_override=_materials[key]
	instance.position=at
	instance.rotation.y=yaw
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func ui_lockup(parent: Control) -> TextureRect:
	var logo:=TextureRect.new()
	logo.name="SynaxisBrandLockup"
	logo.texture=LIGHT
	logo.custom_minimum_size=Vector2(240,60)
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(logo)
	return logo
