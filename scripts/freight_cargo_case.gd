extends Node3D
## Original compact hard-shell container secured in the rear cabin.
## Visual payload only: no collision, lighting or processing.
var _manifest:="FREIGHT"
func configure(manifest:String)->void:
	_manifest=manifest
func _ready()->void:
	_box(Vector3.ZERO,Vector3(.56,.48,.53),Color("344954"))
	_box(Vector3(0,.235,0),Vector3(.58,.055,.55),Color("58666b"))
	for x in [-.18,.18]:
		_box(Vector3(x,.27,0),Vector3(.055,.025,.56),Color("d1a55c"))
		_box(Vector3(x,0,.272),Vector3(.055,.48,.025),Color("d1a55c"))
	for x in [-.19,.19]:
		_box(Vector3(x,.16,.277),Vector3(.09,.07,.035),Color("b8c5c6"))
	var label:=Label3D.new()
	label.text=_manifest.to_upper()+"\nSEALED / MB CO-OP"
	label.position=Vector3(0,.04,.282)
	label.pixel_size=.0017
	label.font_size=16
	label.modulate=Color("e7ecdf")
	label.double_sided=false
	add_child(label)

func _box(at:Vector3,size:Vector3,tint:Color)->void:
	var part:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	part.mesh=mesh
	part.position=at
	var material:=StandardMaterial3D.new()
	material.albedo_color=tint
	material.roughness=.68
	part.material_override=material
	add_child(part)
