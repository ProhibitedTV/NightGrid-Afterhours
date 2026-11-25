extends RefCounted
## Original baked local meshes. No generation, loading of network data or collision.
const MODELS={
	"cap":preload("res://assets/models/nightgrid/fashion/cap.gltf"),
	"beanie":preload("res://assets/models/nightgrid/fashion/beanie.gltf"),
	"bucket":preload("res://assets/models/nightgrid/fashion/bucket.gltf"),
	"fedora":preload("res://assets/models/nightgrid/fashion/fedora.gltf"),
	"display_jacket":preload("res://assets/models/nightgrid/fashion/display_jacket.gltf"),
	"display_cargo":preload("res://assets/models/nightgrid/fashion/display_cargo.gltf"),
	"display_tee":preload("res://assets/models/nightgrid/fashion/display_tee.gltf"),
	"display_boot":preload("res://assets/models/nightgrid/fashion/display_boot.gltf")
}

static func build(id:String,primary:Color,trim:Color,scale_factor:float=1.0)->Node3D:
	if not MODELS.has(id):
		return null
	var scene:PackedScene=MODELS[id]
	var instance:=scene.instantiate() as Node3D
	if instance==null:
		return null
	instance.scale=Vector3.ONE*scale_factor
	var palette:Dictionary={}
	for slot in ["Primary","Trim","Seam","Hardware"]:
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=primary if slot=="Primary" else (trim if slot=="Trim" else (primary.darkened(.32) if slot=="Seam" else trim.lightened(.24)))
		mat.roughness=.88 if slot!="Hardware" else .38
		mat.metallic=.55 if slot=="Hardware" else 0.0
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		palette[slot]=mat
	for node in instance.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		var key:=str(mesh.name)
		if not palette.has(key):
			key="Primary"
		mesh.material_override=palette[key]
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
