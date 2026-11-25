extends RefCounted
const FashionMeshes=preload("res://scripts/fashion_meshes.gd")
## Authored original low-poly accessory geometry. No extra skeleton or collision.
## Use the same skeleton-space rest axes as the courier's existing food poses.
const STYLES={
	"glasses_metro":{"slot":"glasses","primary":"a56d42","secondary":"b68139","shape":"round","accent":0.32},
	"watch_commute":{"slot":"watch","primary":"473d38","secondary":"5f6269","shape":"digital","accent":"e58b6f"},
	"glasses_harbor":{"slot":"glasses","primary":"405f60","secondary":"708f92","shape":"wide","accent":0.44},
	"watch_tide":{"slot":"watch","primary":"465344","secondary":"829395","shape":"round","accent":"d2d9bc"},
	"glasses_meridian":{"slot":"glasses","primary":"b1b5b9","secondary":"b6d5df","shape":"round","accent":0.12},
	"watch_ink":{"slot":"watch","primary":"303748","secondary":"858d9a","shape":"round","accent":"b9cadc"},
	"glasses_afterimage":{"slot":"glasses","primary":"59466d","secondary":"a36fd2","shape":"wide","accent":0.57},
	"watch_pulse":{"slot":"watch","primary":"372a44","secondary":"8c6bae","shape":"digital","accent":"d89afa"},
	"glasses_porcelain":{"slot":"glasses","primary":"d6caba","secondary":"807978","shape":"round","accent":0.33},
	"watch_monolith":{"slot":"watch","primary":"292b30","secondary":"777369","shape":"round","accent":"d2b678"},
	"glasses_deadstock":{"slot":"glasses","primary":"846849","secondary":"b29559","shape":"round","accent":0.42},
	"watch_salvage":{"slot":"watch","primary":"52543b","secondary":"686b60","shape":"digital","accent":"9eb77b"},
	"hat_thread_cap":{"slot":"hat","shape":"cap","primary":"303b42","secondary":"c9a66b"},
	"hat_thread_beanie":{"slot":"hat","shape":"beanie","primary":"46515d","secondary":"a4aeb8"},
	"hat_quay_cap":{"slot":"hat","shape":"cap","primary":"59634e","secondary":"bbab79"},
	"hat_quay_bucket":{"slot":"hat","shape":"bucket","primary":"395a5b","secondary":"789395"},
	"hat_vesper_fedora":{"slot":"hat","shape":"fedora","primary":"484853","secondary":"93818a"},
	"hat_vesper_cap":{"slot":"hat","shape":"cap","primary":"303445","secondary":"a4a5b8"},
	"hat_nocturne_bucket":{"slot":"hat","shape":"bucket","primary":"342940","secondary":"78628d"},
	"hat_nocturne_beanie":{"slot":"hat","shape":"beanie","primary":"493656","secondary":"ac78b4"},
	"hat_obscura_fedora":{"slot":"hat","shape":"fedora","primary":"282a2e","secondary":"b6a078"},
	"hat_obscura_bucket":{"slot":"hat","shape":"bucket","primary":"c7c0b2","secondary":"928a81"},
	"hat_signal_cap":{"slot":"hat","shape":"cap","primary":"755e44","secondary":"a08a64"},
	"hat_signal_beanie":{"slot":"hat","shape":"beanie","primary":"5b5147","secondary":"a78353"}
}

static func build(rig:Skeleton3D,id:String) -> Node3D:
	if rig==null:
		return null
	var style:Dictionary=STYLES.get(id,{})
	var glasses:bool=id in ["glasses_night","glasses_clear"] or str(style.get("slot",""))=="glasses"
	var hat:bool=style.get("slot","")=="hat"
	if not glasses and not hat and id not in ["watch_shift","watch_brass"] and style.get("slot","")!="watch":
		return null
	var bone:=rig.find_bone("Head" if glasses or hat else "LeftHand")
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
	if hat:
		# Provisional head-relative fit, shared with the live skeleton.
		geometry.transform=rest.affine_inverse()*Transform3D(Basis.IDENTITY,rest.origin+Vector3(0,.09,.006))
		_hat(geometry,style)
	elif glasses:
		# Align to skeleton-space face axes, independent of bone local orientation.
		geometry.transform=rest.affine_inverse()*Transform3D(Basis.IDENTITY,rest.origin+Vector3(0,.005,.116))
		if style.is_empty():
			_glasses(geometry,id=="glasses_night")
		else:
			_collection_glasses(geometry,style)
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
		if style.is_empty():
			_watch(geometry,id=="watch_brass")
		else:
			_collection_watch(geometry,style)
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

# Cylindrical face in XY, with depth along the positive Z face axis.
static func _disc(root:Node3D,id:String,at:Vector3,radius:float,depth:float,mat:Material,flatten:float=1.0) -> void:
	var node:=MeshInstance3D.new()
	node.name=id
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=depth
	mesh.radial_segments=24
	mesh.rings=0
	node.mesh=mesh
	node.rotation.x=PI/2
	node.scale.z=flatten
	node.position=at
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

static func _collection_glasses(root:Node3D,style:Dictionary) -> void:
	var frame:=_material(Color(style["primary"]),.48,.32)
	var tint:=Color(style["secondary"])
	tint.a=float(style["accent"])
	var lens:=_material(tint,0.0,.18)
	lens.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var wide:bool=style["shape"]=="wide"
	for side in [-1.0,1.0]:
		var x:float=side*.037
		if wide:
			_box(root,"Lens",Vector3(x,0,0),Vector3(.065,.038,.006),lens)
			for y in [-.021,.021]:
				_box(root,"Rim",Vector3(x,y,.002),Vector3(.072,.005,.008),frame)
			for edge in [-1.0,1.0]:
				_box(root,"Rim",Vector3(x+edge*.034,0,.002),Vector3(.005,.044,.008),frame)
		else:
			_disc(root,"Lens",Vector3(x,0,0),.029,.004,lens,.88)
			var ring:=MeshInstance3D.new()
			ring.name="RoundRim"
			var torus:=TorusMesh.new()
			torus.inner_radius=.027
			torus.outer_radius=.032
			torus.rings=24
			torus.ring_segments=8
			ring.mesh=torus
			ring.position=Vector3(x,0,.001)
			ring.rotation.x=PI/2
			ring.scale.z=.88
			ring.material_override=frame
			ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ring)
		_box(root,"Temple",Vector3(side*.072,.010,-.056),Vector3(.007,.007,.112),frame)
	_box(root,"Bridge",Vector3(0,.009,.001),Vector3(.017,.005,.008),frame)

static func _collection_watch(root:Node3D,style:Dictionary) -> void:
	var band:=_material(Color(style["primary"]))
	var metal:=_material(Color(style["secondary"]),.72,.33)
	var dial:=_material(Color("171e24"),.12,.37)
	var ink:=_material(Color(style["accent"]))
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
	if style["shape"]=="round":
		_disc(root,"Case",Vector3(0,0,.035),.023,.014,metal)
		_disc(root,"Dial",Vector3(0,0,.044),.019,.004,dial)
		for i in range(12):
			var angle:=float(i)*TAU/12.0
			var at:=Vector3(sin(angle)*.015,cos(angle)*.015,.047)
			_box(root,"Marker",at,Vector3(.0024,.0024,.002),ink)
		_box(root,"HourHand",Vector3(0,.006,.047),Vector3(.002,.013,.002),ink)
		_box(root,"MinuteHand",Vector3(.006,0,.047),Vector3(.014,.002,.002),ink)
	else:
		_box(root,"Case",Vector3(0,0,.035),Vector3(.048,.038,.014),metal)
		_box(root,"Dial",Vector3(0,0,.044),Vector3(.040,.030,.004),dial)
		for x in [-.012,0.0,.012]:
			_box(root,"Digit",Vector3(x,0,.047),Vector3(.005,.012,.002),ink)

# Original bounded accessory meshes, also used by the static store display.
# Hat fit/clearance is a native-review gate; never alter the live hair/body mesh.
static func display_hat(id:String) -> Node3D:
	var style:Dictionary=STYLES.get(id,{})
	if style.get("slot","")!="hat":
		return null
	var root:=Node3D.new()
	root.name=id
	_hat(root,style)
	return root

static func _hat(root:Node3D,style:Dictionary) -> void:
	var mesh:=FashionMeshes.build(str(style["shape"]),Color(style["primary"]),Color(style["secondary"]))
	if mesh!=null:
		root.add_child(mesh)
