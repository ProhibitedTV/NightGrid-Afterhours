extends RefCounted
## Original static city coachwork, authored cross sections and panel layout.
## No added collisions, runtime downloads, lights or per-frame generation.
## -Z is the existing vehicle front. Mesh shared by route livery.
static var _cache: Dictionary = {}

static func _material(c:Color,roughness:float,metal:float=0.0,emission:float=0.0)->StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission>0:
		m.emission_enabled=true
		m.emission=c
		m.emission_energy_multiplier=emission
	return m

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3)->void:
	var points: Array[Vector3] = [a,b,c,a,c,d]
	var uv: Array[Vector2] = [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]
	for i in range(6):
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(points[i])

static func _ring(y:float,width:float,length:float,bevel:float)->Array[Vector3]:
	# Clockwise plan perimeter; clipped corners are modeled, not textures.
	return [Vector3(-width+bevel,y,-length),Vector3(width-bevel,y,-length),
		Vector3(width,y,-length+bevel),Vector3(width,y,length-bevel),
		Vector3(width-bevel,y,length),Vector3(-width+bevel,y,length),
		Vector3(-width,y,length-bevel),Vector3(-width,y,-length+bevel)]

static func _join(st:SurfaceTool,lo:Array[Vector3],hi:Array[Vector3])->void:
	for i in range(8):
		var j := (i+1)%8
		var normal := (lo[j]-lo[i]).cross(hi[i]-lo[i]).normalized()
		# Orient normal away from the coach center.
		var middle := (lo[i]+lo[j]+hi[i]+hi[j])*0.25
		if normal.dot(Vector3(middle.x,0,middle.z))<0:
			normal=-normal
		_quad(st,lo[i],lo[j],hi[j],hi[i],normal)

static func _cap(st:SurfaceTool,ring:Array[Vector3],normal:Vector3)->void:
	var center := Vector3(0,ring[0].y,0)
	for i in range(8):
		for p in [center,ring[i],ring[(i+1)%8]]:
			st.set_normal(normal)
			st.set_uv(Vector2(p.x,p.z))
			st.add_vertex(p)

static func _side(st:SurfaceTool,side:float,y0:float,y1:float,z0:float,z1:float,x:float)->void:
	_quad(st,Vector3(side*x,y0,z0),Vector3(side*x,y1,z0),Vector3(side*x,y1,z1),Vector3(side*x,y0,z1),Vector3(side,0,0))

static func _end(st:SurfaceTool,side:float,y0:float,y1:float,x0:float,x1:float,z:float)->void:
	_quad(st,Vector3(x0,y0,side*z),Vector3(x0,y1,side*z),Vector3(x1,y1,side*z),Vector3(x1,y0,side*z),Vector3(0,0,side))

static func build(tint:Color)->MeshInstance3D:
	var key := tint.to_html(false)
	if not _cache.has(key):
		var materials: Array[StandardMaterial3D] = [
			_material(tint,0.39,0.14),
			_material(Color("273139"),0.80),
			_material(Color("334c58"),0.16),
			_material(Color("a7afb2"),0.38,0.50),
			_material(Color("f7dec2"),0.25,0.0,0.55),
			_material(Color("db4550"),0.27,0.0,0.55)]
		var tools: Array[SurfaceTool] = []
		for material in materials:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(material)
			tools.append(st)
		var skirt := _ring(-1.18,1.17,3.99,0.22)
		var waist := _ring(-0.72,1.29,4.04,0.19)
		var shoulder := _ring(0.96,1.29,4.04,0.19)
		var roof := _ring(1.37,1.13,3.87,0.25)
		_join(tools[1],skirt,waist)
		_join(tools[0],waist,shoulder)
		_join(tools[0],shoulder,roof)
		_cap(tools[0],roof,Vector3.UP)
		_cap(tools[1],skirt,Vector3.DOWN)
		for side in [-1.0,1.0]:
			# Dark glazing band; subdivided windows with separate pillars.
			_side(tools[1],side,-0.03,0.91,-3.63,3.68,1.296)
			for bay in range(6):
				var z := -3.55+float(bay)*1.20
				_side(tools[2],side,0.055,0.83,z,z+1.04,1.305)
			_side(tools[3],side,-0.17,-0.10,-3.73,3.73,1.305)
			_side(tools[0],side,-0.47,-0.29,-3.70,3.70,1.302)
			# Curb-side doors are visible panel artwork, not openable geometry.
			if side>0:
				for z in [-3.35,0.35]:
					_side(tools[1],side,-0.67,0.84,z,z+0.91,1.311)
					_side(tools[2],side,-0.25,0.80,z+0.08,z+0.40,1.318)
					_side(tools[2],side,-0.25,0.80,z+0.51,z+0.83,1.318)
			for z in [-3.0,3.0]:
				_side(tools[3],side,-0.64,-0.52,z,z+0.17,1.307)
		_end(tools[1],-1,0.01,0.91,-1.03,1.03,4.046)
		_end(tools[2],-1,0.09,0.83,-0.96,0.96,4.054)
		_end(tools[1],-1,0.09,0.83,-0.021,0.021,4.060)
		_end(tools[2],1,0.12,0.74,-0.86,0.86,4.052)
		for side in [-1.0,1.0]:
			_end(tools[4],-1,-0.53,-0.32,side*0.80-0.23,side*0.80+0.23,4.052)
			_end(tools[5],1,-0.54,-0.28,side*0.82-0.13,side*0.82+0.13,4.052)
		for end in [-1.0,1.0]:
			_end(tools[3],end,-0.69,-0.59,-1.04,1.04,4.052)
		var mesh := ArrayMesh.new()
		for st in tools:
			st.commit(mesh)
		_cache[key]=mesh
	var model := MeshInstance3D.new()
	model.mesh=_cache[key]
	return model
