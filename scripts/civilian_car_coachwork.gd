extends RefCounted
## Original fixed compact sedan geometry. One mesh per existing paint color.
## Physics, vehicle IDs and save data remain owned by TrafficVehicle.
const AXLES = [-1.36,1.36]
const AXLE_Y = -0.64
const TIRE_RADIUS = 0.35
const ARCH_RADIUS = 0.43
const SILL = -0.48
const BELT = 0.08
const WIDTH = 1.06
const WELL = 0.75
static var _cache: Dictionary = {}

static func _mat(c:Color,rough:float,metal:float,emission:float=0.0)->StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=rough
	m.metallic=metal
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	if emission>0.0:
		m.emission_enabled=true
		m.emission=c
		m.emission_energy_multiplier=emission
	return m

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3)->void:
	var n := (b-a).cross(c-a).normalized()
	if n.dot(normal)<0.0:
		n=-n
	var points: Array[Vector3]=[a,b,c,a,c,d]
	var uv: Array[Vector2]=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]
	for i in range(6):
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(points[i])

static func _side(st:SurfaceTool,s:float,z0:float,z1:float,y0:float,y1:float)->void:
	_quad(st,Vector3(s*WIDTH,y0,z0),Vector3(s*WIDTH,y1,z1),
		Vector3(s*WIDTH,BELT,z1),Vector3(s*WIDTH,BELT,z0),Vector3(s,0,0))

static func _under(st:SurfaceTool,s:float,z0:float,z1:float)->void:
	_quad(st,Vector3(s*WELL,SILL,z0),Vector3(s*WIDTH,SILL,z0),
		Vector3(s*WIDTH,SILL,z1),Vector3(s*WELL,SILL,z1),Vector3.DOWN)

static func _body(paint:SurfaceTool,trim:SurfaceTool)->void:
	var span := sqrt(ARCH_RADIUS*ARCH_RADIUS-pow(SILL-AXLE_Y,2))
	for s in [-1.0,1.0]:
		var last := -1.98
		for axle in AXLES:
			var lo:float=axle-span
			var hi:float=axle+span
			_side(paint,s,last,lo,SILL,SILL)
			_under(trim,s,last,lo)
			for i in range(12):
				var z0:=lerpf(lo,hi,float(i)/12.0)
				var z1:=lerpf(lo,hi,float(i+1)/12.0)
				var y0:=AXLE_Y+sqrt(maxf(0.0,ARCH_RADIUS*ARCH_RADIUS-pow(z0-axle,2.0)))
				var y1:=AXLE_Y+sqrt(maxf(0.0,ARCH_RADIUS*ARCH_RADIUS-pow(z1-axle,2.0)))
				_side(paint,s,z0,z1,y0,y1)
				_quad(trim,Vector3(s*WIDTH,y0,z0),Vector3(s*WELL,y0,z0),
					Vector3(s*WELL,y1,z1),Vector3(s*WIDTH,y1,z1),Vector3.DOWN)
				_quad(trim,Vector3(s*WELL,y0,z0),Vector3(s*WELL,SILL,z0),
					Vector3(s*WELL,SILL,z1),Vector3(s*WELL,y1,z1),Vector3(s,0,0))
			last=hi
		_side(paint,s,last,1.98,SILL,SILL)
		_under(trim,s,last,1.98)
		for e in [-1.0,1.0]:
			_quad(paint,Vector3(s*WIDTH,SILL,e*1.98),Vector3(s*0.88,SILL,e*2.19),
				Vector3(s*0.88,-0.02,e*2.19),Vector3(s*WIDTH,BELT,e*1.98),Vector3(s,0,e))
			_quad(trim,Vector3(s*WELL,SILL,e*1.98),Vector3(s*WIDTH,SILL,e*1.98),
				Vector3(s*0.88,SILL,e*2.19),Vector3(s*WELL,SILL,e*2.19),Vector3.DOWN)
	_quad(trim,Vector3(-WELL,SILL,-2.19),Vector3(WELL,SILL,-2.19),
		Vector3(WELL,SILL,2.19),Vector3(-WELL,SILL,2.19),Vector3.DOWN)
	for e in [-1.0,1.0]:
		_quad(paint,Vector3(-0.88,SILL,e*2.19),Vector3(0.88,SILL,e*2.19),
			Vector3(0.88,-0.02,e*2.19),Vector3(-0.88,-0.02,e*2.19),Vector3(0,0,e))
		_quad(paint,Vector3(-0.88,-0.02,e*2.19),Vector3(0.88,-0.02,e*2.19),
			Vector3(WIDTH,BELT,e*1.98),Vector3(-WIDTH,BELT,e*1.98),Vector3.UP)
	_quad(paint,Vector3(-WIDTH,BELT,-1.98),Vector3(WIDTH,BELT,-1.98),
		Vector3(WIDTH,BELT,1.98),Vector3(-WIDTH,BELT,1.98),Vector3.UP)

static func _patch(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3,u0:float,u1:float,v0:float,v1:float)->void:
	# Pane sits on the actual raked cabin plane, inside a painted frame.
	var offset:=n.normalized()*0.008
	_quad(st,a.lerp(b,u0).lerp(d.lerp(c,u0),v0)+offset,
		a.lerp(b,u1).lerp(d.lerp(c,u1),v0)+offset,
		a.lerp(b,u1).lerp(d.lerp(c,u1),v1)+offset,
		a.lerp(b,u0).lerp(d.lerp(c,u0),v1)+offset,n)

static func _cabin(paint:SurfaceTool,glass:SurfaceTool)->void:
	var ground_front:=-1.06
	var ground_back:=1.23
	var roof_front:=-0.55
	var roof_back:=0.62
	var roof_y:=0.73
	for s in [-1.0,1.0]:
		var a:=Vector3(s*0.91,BELT,ground_front)
		var b:=Vector3(s*0.91,BELT,ground_back)
		var c:=Vector3(s*0.70,roof_y,roof_back)
		var d:=Vector3(s*0.70,roof_y,roof_front)
		var n:=(b-a).cross(d-a).normalized()
		if n.x*s<0:
			n=-n
		_quad(paint,a,b,c,d,n)
		_patch(glass,a,b,c,d,n,0.10,0.46,0.14,0.88)
		_patch(glass,a,b,c,d,n,0.51,0.90,0.14,0.88)
	for e in [-1.0,1.0]:
		var z0:=ground_front if e<0 else ground_back
		var z1:=roof_front if e<0 else roof_back
		var a:=Vector3(-0.91,BELT,z0)
		var b:=Vector3(0.91,BELT,z0)
		var c:=Vector3(0.70,roof_y,z1)
		var d:=Vector3(-0.70,roof_y,z1)
		var n:=(b-a).cross(d-a).normalized()
		if n.z*e<0:
			n=-n
		_quad(paint,a,b,c,d,n)
		_patch(glass,a,b,c,d,n,0.06,0.94,0.10,0.90)
	_quad(paint,Vector3(-0.70,roof_y,roof_front),Vector3(0.70,roof_y,roof_front),
		Vector3(0.70,roof_y,roof_back),Vector3(-0.70,roof_y,roof_back),Vector3.UP)

static func _end_panel(st:SurfaceTool,e:float,x0:float,x1:float,y0:float,y1:float)->void:
	_quad(st,Vector3(x0,y0,e*2.198),Vector3(x1,y0,e*2.198),
		Vector3(x1,y1,e*2.198),Vector3(x0,y1,e*2.198),Vector3(0,0,e))

static func build(tint:Color)->MeshInstance3D:
	var key:=tint.to_html(false)
	if not _cache.has(key):
		var materials: Array[StandardMaterial3D]=[_mat(tint,0.32,0.24),_mat(Color("20252a"),0.82,0.0),
			_mat(Color("283d49"),0.16,0.0),_mat(Color("f8e4cb"),0.25,0.0,0.7),
			_mat(Color("b72c45"),0.28,0.0,0.60)]
		materials[0].clearcoat_enabled=true
		materials[0].clearcoat=0.45
		var st: Array[SurfaceTool]=[]
		for material in materials:
			var tool:=SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(material)
			st.append(tool)
		_body(st[0],st[1])
		_cabin(st[0],st[2])
		for e in [-1.0,1.0]:
			_end_panel(st[1],e,-0.87,0.87,-0.43,-0.34)
			for s in [-1.0,1.0]:
				_end_panel(st[3] if e<0 else st[4],e,s*0.60-0.22,s*0.60+0.22,-0.20,-0.07)
		var mesh:=ArrayMesh.new()
		for tool in st:
			tool.commit(mesh)
		_cache[key]=mesh
	var model:=MeshInstance3D.new()
	model.mesh=_cache[key]
	model.set_meta("wheel_wells",4)
	return model
