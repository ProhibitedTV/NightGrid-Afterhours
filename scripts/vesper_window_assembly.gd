extends RefCounted
## Original 3D upper-floor window assembly for the Moon Noodles block.
## Window glazing is recessed relative to the projecting frame, NOT an
## opening into the existing opaque collision shell. Three shared surfaces
## per whole building; no individual window nodes, lights, or collisions.
const HALF_HEIGHT = 0.74
const BORDER = 0.075
const FRAME_Z = -0.22
const GLASS_Z = -0.065
static var _materials: Array[StandardMaterial3D] = []

static func _material(color:Color,rough:float,metal:float,energy:float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy>0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
	return m

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	var points := [a,b,c,a,c,d]
	var uv := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]
	for i in range(6):
		st.set_normal(normal)
		st.set_uv(uv[i])
		st.add_vertex(points[i])

static func _face(st:SurfaceTool,x0:float,x1:float,y0:float,y1:float,z:float) -> void:
	_quad(st,Vector3(x0,y0,z),Vector3(x0,y1,z),Vector3(x1,y1,z),Vector3(x1,y0,z))

static func _window(frame:SurfaceTool,glass:SurfaceTool,x:float,y:float,width:float) -> void:
	var l := x-width*0.5
	var r := x+width*0.5
	var b := y-HALF_HEIGHT
	var t := y+HALF_HEIGHT
	var il := l+BORDER
	var ir := r-BORDER
	var ib := b+BORDER
	var it := t-BORDER
	# Front frame ring and four actual beveled inner reveal faces.
	_face(frame,l,il,b,t,FRAME_Z)
	_face(frame,ir,r,b,t,FRAME_Z)
	_face(frame,il,ir,b,ib,FRAME_Z)
	_face(frame,il,ir,it,t,FRAME_Z)
	_quad(frame,Vector3(il,b,FRAME_Z),Vector3(il,t,FRAME_Z),Vector3(il+0.025,it,GLASS_Z),Vector3(il+0.025,ib,GLASS_Z))
	_quad(frame,Vector3(ir,b,FRAME_Z),Vector3(ir-0.025,ib,GLASS_Z),Vector3(ir-0.025,it,GLASS_Z),Vector3(ir,t,FRAME_Z))
	_quad(frame,Vector3(il,ib,FRAME_Z),Vector3(il+0.025,ib,GLASS_Z),Vector3(ir-0.025,ib,GLASS_Z),Vector3(ir,ib,FRAME_Z))
	_quad(frame,Vector3(il,it,FRAME_Z),Vector3(ir,it,FRAME_Z),Vector3(ir-0.025,it,GLASS_Z),Vector3(il+0.025,it,GLASS_Z))
	# Frontal glazing, slim mullion and transom; modest sill projection.
	_face(glass,il+0.025,ir-0.025,ib,it,GLASS_Z)
	_face(frame,x-0.027,x+0.027,ib,it,GLASS_Z-0.025)
	_face(frame,il,ir,y+0.21,y+0.26,GLASS_Z-0.025)
	_face(frame,l-0.035,r+0.035,b-0.07,b,FRAME_Z-0.035)
	_quad(frame,Vector3(l-0.035,b,FRAME_Z-0.035),Vector3(r+0.035,b,FRAME_Z-0.035),Vector3(r+0.035,b,-0.005),Vector3(l-0.035,b,-0.005))

static func build(specs:Array[Dictionary]) -> MeshInstance3D:
	if _materials.is_empty():
		_materials = [_material(Color("39434b"),0.36,0.72,0.0),
			_material(Color("293b46"),0.19,0.0,0.0),
			_material(Color("9c7859"),0.25,0.0,0.20)]
	var surfaces: Array[SurfaceTool] = []
	var counts: Array[int] = [0,0,0]
	for i in range(3):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(_materials[i])
		surfaces.append(st)
	for item in specs:
		var index := 2 if bool(item["lit"]) else 1
		_window(surfaces[0],surfaces[index],float(item["x"]),float(item["y"]),float(item["width"]))
		counts[0] += 1
		counts[index] += 1
	var mesh := ArrayMesh.new()
	for i in range(3):
		if counts[i]>0:
			surfaces[i].commit(mesh)
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.set_meta("window_count",specs.size())
	result.set_meta("warm_windows",counts[2])
	return result
