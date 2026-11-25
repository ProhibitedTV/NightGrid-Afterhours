extends RefCounted
## Fixed geometry, two size classes. Existing tire/rim drawables are reused;
## no additional drawables, dynamic lights, or every-frame mesh generation.
static var _tires: Dictionary = {}
static var _rims: Dictionary = {}
const HALF_DEPTH = 0.149
const SEGMENTS = 24

static func tire(radius:float)->CylinderMesh:
	if not _tires.has(radius):
		var mesh := CylinderMesh.new()
		mesh.top_radius=radius
		mesh.bottom_radius=radius
		mesh.height=0.28
		mesh.radial_segments=SEGMENTS
		_tires[radius]=mesh
	return _tires[radius]

static func _point(radius:float,angle:float,depth:float)->Vector3:
	return Vector3(cos(angle)*radius,depth,sin(angle)*radius)

static func _tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->void:
	# Godot clockwise front faces; explicitly orient both visible sides.
	if (b-a).cross(c-a).dot(normal)>0.0:
		var swap:=b
		b=c
		c=swap
	for v in [a,b,c]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x,v.z)*0.5+Vector2(0.5,0.5))
		st.add_vertex(v)

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3)->void:
	_tri(st,a,b,c,normal)
	_tri(st,a,c,d,normal)

static func rim(radius:float)->ArrayMesh:
	if _rims.has(radius):
		return _rims[radius]
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		var n:=Vector3(0,side,0)
		var face:float=side*HALF_DEPTH
		for i in range(SEGMENTS):
			var a:=TAU*float(i)/float(SEGMENTS)
			var b:=TAU*float(i+1)/float(SEGMENTS)
			# Visible machined ring; the tire remains outside it.
			_quad(st,_point(radius*0.69,a,face),_point(radius*0.80,a,face),
				_point(radius*0.80,b,face),_point(radius*0.69,b,face),n)
			_tri(st,Vector3(0,face,0),_point(radius*0.26,a,face),_point(radius*0.26,b,face),n)
		for i in range(6):
			var angle:=TAU*float(i)/6.0
			var a:=angle-0.20
			var b:=angle+0.20
			_quad(st,_point(radius*0.19,a,face),_point(radius*0.73,angle-0.085,face),
				_point(radius*0.73,angle+0.085,face),_point(radius*0.19,b,face),n)
	var mesh:=st.commit()
	_rims[radius]=mesh
	return mesh
