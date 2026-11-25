extends RefCounted
## Authored original low-poly accessory geometry. No extra skeleton or collision.
## Use the same skeleton-space rest axes as the courier's existing food poses.
static func build(rig:Skeleton3D,id:String) -> Node3D:
	if rig==null:
		return null
	var glasses:=id in ["glasses_night","glasses_clear"]
	if not glasses and id not in ["watch_shift","watch_brass"]:
		return null
	var bone:=rig.find_bone("Head" if glasses else "LeftHand")
	if bone<0:
		return null
	var rest:=rig.get_bone_global_rest(bone)
	var anchor:=BoneAttachment3D.new()
	anchor.name=id
	anchor.bone_name=rig.get_bone_name(bone)
	rig.add_child(anchor)
	var geometry:=Node3D.new()
	geometry.name="AccessoryGeometry"
	anchor.add_child(geometry)
	if glasses:
		# Align to skeleton-space face axes, independent of bone local orientation.
		geometry.transform=rest.affine_inverse()*Transform3D(Basis.IDENTITY,rest.origin+Vector3(0,.005,.116))
		_glasses(geometry,id=="glasses_night")
	else:
		var parent:=rig.get_bone_parent(bone)
		if parent<0:
			anchor.free()
			return null
		var toward_elbow:Vector3=(rig.get_bone_global_rest(parent).origin-rest.origin).normalized()
		if toward_elbow.length_squared()<.5:
			anchor.free()
			return null
		var outward:=Vector3(0,0,1)-toward_elbow*toward_elbow.dot(Vector3(0,0,1))
		if outward.length_squared()<.01:
			outward=Vector3.UP-toward_elbow*toward_elbow.dot(Vector3.UP)
		outward=outward.normalized()
		var basis:=Basis(toward_elbow.cross(outward).normalized(),toward_elbow,outward)
		geometry.transform=rest.affine_inverse()*Transform3D(basis,rest.origin+toward_elbow*.045)
		_watch(geometry,id=="watch_brass")
	return anchor

static func _material(color:Color,metal:float=0.0,rough:float=.65) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.metallic=metal
	material.roughness=rough
	return material

static func _box(root:Node3D,id:String,at:Vector3,size:Vector3,mat:Material) -> void:
	var node:=MeshInstance3D.new()
	node.name=id
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=at
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

static func _glasses(root:Node3D,dark:bool) -> void:
	var frame:=_material(Color("171c23") if dark else Color("8b8e86"),.38,.28)
	var lens:=_material(Color(.06,.10,.15,.72) if dark else Color(.78,.90,.98,.15),.0,.16)
	lens.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1.0,1.0]:
		var x:float=side*.037
		_box(root,"Lens",Vector3(x,0,0),Vector3(.061,.035,.006),lens)
		for y in [-.019,.019]:
			_box(root,"Rim",Vector3(x,y,.002),Vector3(.069,.005,.009),frame)
		for edge in [-1.0,1.0]:
			_box(root,"Rim",Vector3(x+edge*.033,0,.002),Vector3(.005,.039,.009),frame)
		_box(root,"Temple",Vector3(side*.072,.012,-.056),Vector3(.007,.008,.112),frame)
	_box(root,"Bridge",Vector3(0,.009,.001),Vector3(.016,.006,.009),frame)

static func _watch(root:Node3D,brass:bool) -> void:
	var band:=_material(Color("634932") if brass else Color("20252a"))
	var metal:=_material(Color("c2a36c") if brass else Color("64757b"),.75,.3)
	var dial:=_material(Color("171e24"),.15,.35)
	var ring:=MeshInstance3D.new()
	ring.name="WristBand"
	var torus:=TorusMesh.new()
	torus.inner_radius=.025
	torus.outer_radius=.034
	torus.rings=24
	torus.ring_segments=8
	ring.mesh=torus
	ring.material_override=band
	ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	_box(root,"Case",Vector3(0,0,.035),Vector3(.042,.046,.014),metal)
	_box(root,"Dial",Vector3(0,0,.044),Vector3(.034,.036,.004),dial)
	var ink:=_material(Color("e3cf9e") if brass else Color("8dd4d3"))
	if brass:
		_box(root,"HourHand",Vector3(0,.006,.047),Vector3(.002,.013,.002),ink)
		_box(root,"MinuteHand",Vector3(.006,0,.047),Vector3(.014,.002,.002),ink)
	else:
		for x in [-.009,0.0,.009]:
			_box(root,"Digit",Vector3(x,0,.047),Vector3(.004,.012,.002),ink)
