extends Control
## Local north-up HUD radar. The interactive atlas remains separate.
const Nav = preload("res://scripts/navigation_waypoint.gd")
const Plan = preload("res://scripts/world_plan.gd")
const Restrooms = preload("res://scripts/synaxis_restrooms.gd")
const Arrival = preload("res://scripts/synaxis_arrival.gd")
const RANGE_METRES = 116.0
const BORDER = 9.0
var world_node: Node3D
var _redraw_clock := 1.0
var _center := Vector2.ZERO
var _radius := 0.0
var _scale := 1.0
var _origin := Vector2.ZERO
const Workfloor = preload("res://scripts/synaxis_workfloor.gd")
const ExecutiveFloor = preload("res://scripts/synaxis_executive_floor.gd")
const Basement = preload("res://scripts/synaxis_basement.gd")
var _office_floor:=0
var _office_mode := false
var _office_actor := Vector2.ZERO
var _office_target := Vector2.ZERO

func set_office_state(actor: Vector2,target: Vector2,floor: int=0) -> void:
	_office_floor=floor
	_office_mode=true
	_office_actor=actor
	_office_target=target

func _process(delta: float) -> void:
	_redraw_clock += delta
	if _redraw_clock >= 0.1:
		_redraw_clock = 0.0
		if is_visible_in_tree():
			queue_redraw()

static func clip_segment(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	# Solve the segment/circle quadratic in radar-centred coordinates.
	var d := b - a
	var aa := d.length_squared()
	if not a.is_finite() or not b.is_finite() or not is_finite(radius) or radius <= 0.0 or aa < 0.000001:
		return PackedVector2Array()
	var bb := 2.0 * a.dot(d)
	var cc := a.length_squared() - radius * radius
	var disc := bb * bb - 4.0 * aa * cc
	if disc <= 0.0:
		return PackedVector2Array()
	var root_disc := sqrt(disc)
	var low := maxf(0.0, (-bb - root_disc) / (2.0 * aa))
	var high := minf(1.0, (-bb + root_disc) / (2.0 * aa))
	if low >= high:
		return PackedVector2Array()
	return PackedVector2Array([a + d * low, a + d * high])

func _local(point: Vector2) -> Vector2:
	return (point - _origin) * _scale

func _segment(a: Vector2, b: Vector2, color: Color, width: float, dashed: bool = false) -> void:
	var visible := clip_segment(_local(a), _local(b), _radius - width * 0.5 - 1.0)
	if visible.size() != 2:
		return
	if dashed:
		draw_dashed_line(_center + visible[0], _center + visible[1], color, width, 4.0, true, true)
	else:
		draw_line(_center + visible[0], _center + visible[1], color, width, true)

func _point(point: Vector2, color: Color, radius: float, square: bool = false) -> void:
	var p := _local(point)
	if not p.is_finite() or p.length() > _radius - radius * 1.42 - 2.0:
		return
	p += _center
	if square:
		draw_rect(Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
	else:
		draw_circle(p, radius, color, true, -1.0, true)

func _target(point: Vector2, color: Color, diamond: bool = false) -> void:
	var p := _local(point)
	if not p.is_finite():
		return
	var limit := _radius - 10.0
	if p.length() > limit:
		var dir := p.normalized()
		var tip := _center + dir * (_radius - 2.0)
		var tail := _center + dir * (_radius - 12.0)
		var tangent := Vector2(-dir.y, dir.x) * 5.0
		draw_colored_polygon(PackedVector2Array([tip, tail + tangent, tail - tangent]), color)
		return
	p += _center
	if diamond:
		draw_polyline(PackedVector2Array([p+Vector2(0,-6),p+Vector2(6,0),p+Vector2(0,6),p+Vector2(-6,0),p+Vector2(0,-6)]), color, 2.0, true)
	else:
		draw_circle(p, 5.0, color, true, -1.0, true)

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 60.0:
		return
	_center = Vector2.ONE * side * 0.5
	_radius = side * 0.5 - BORDER
	_scale = _radius / RANGE_METRES
	draw_circle(_center, _radius + 4.0, Color(0.025, 0.038, 0.057, 0.88), true, -1.0, true)
	draw_circle(_center, _radius, Color(0.075, 0.095, 0.125, 0.96), true, -1.0, true)
	if _office_mode:
		_draw_office()
	elif is_instance_valid(world_node):
		var state: Dictionary = world_node.call("get_map_state")
		_origin = state["player"]
		var extent: float = float(Plan.GRID_RADIUS) * Plan.BLOCK_SIZE
		for i in range(-Plan.GRID_RADIUS, Plan.GRID_RADIUS + 1):
			var x := float(i) * Plan.BLOCK_SIZE
			_segment(Vector2(x,-extent), Vector2(x,extent), Color("52616e"), 4.0)
			_segment(Vector2(-extent,x), Vector2(extent,x), Color("52616e"), 4.0)
		_segment(Vector2(-223,-58), Vector2(241,-58), Color("47787d"), 2.0)
		var closures: Dictionary = state.get("road_restrictions", {})
		for record in closures.values():
			var edge := Nav.closure_segment(record)
			if edge.size() == 2:
				_segment(edge[0],edge[1],Color("101821"),5.5)
				_segment(edge[0],edge[1],Nav.CLOSURE_COLOR,3.2,true)
				var mid := (edge[0]+edge[1])*0.5
				var crossbar := (edge[1]-edge[0]).orthogonal().normalized()*4.0
				_segment(mid-crossbar,mid+crossbar,Nav.CLOSURE_COLOR,2.3)
		for stop in state.get("bus_stops", []):
			_point(stop, Color("f3cb7a"), 2.2)
		for station in state.get("rail_stations", []):
			_point(station, Color("7fcfd5"), 3.0, true)
		for location in state.get("venues", []):
			var tint := Color("f3b86d")
			match str(location["kind"]):
				"CAFE": tint = Color("86d3df")
				"BAR": tint = Color("e5a1a6")
				"CLUB": tint = Color("e28eec")
				"ARCADE": tint = Color("72d7cf")
			_point(location["point"], tint if bool(location["open"]) else tint.darkened(0.65), 2.8)
		for service in state.get("services", []):
			var tint := Color("77a7e0") if bool(service.get("station", false)) else Color("a6d0c8")
			match str(service["kind"]):
				"GROCERY": tint = Color("dec37e")
				"CLINIC", "FIRE": tint = Color("86ded1")
				"WAREHOUSE", "GARAGE": tint = Color("d59e75")
				"CIVIC", "LIBRARY": tint = Color("aba7d6")
			_point(service["point"], tint if bool(service["open"]) else tint.darkened(0.60), 2.7, true)
		for patrol in state.get("routine_patrols", []):
			_point(patrol, Color("77a7e0"), 2.8)
		for officer in state.get("officers", []):
			_point(officer, Color("f04e59"), 3.5)
		var last: Vector2 = state.get("wanted_last_known", Vector2.INF)
		if int(state.get("wanted_stars", 0)) > 0 and last.is_finite() and not bool(state.get("wanted_seen", false)):
			# Clip search-ring chords too, even when the centre is off screen.
			for i in range(24):
				var a := last + Vector2.from_angle(TAU * float(i) / 24.0) * 16.0
				var b := last + Vector2.from_angle(TAU * float(i+1) / 24.0) * 16.0
				_segment(a,b,Color("edbc83"),1.5)
		if bool(state.get("waypoint_active", false)):
			var goal: Vector2 = state["waypoint"]
			var route: Dictionary = state.get("street_route", {})
			if not route.is_empty():
				var road: Array[Vector2] = route["points"]
				for i in range(road.size()-1):
					_segment(road[i],road[i+1],Color("101821"),5.0)
					_segment(road[i],road[i+1],Nav.COLOR,2.8)
				_segment(_origin,route["entry"],Nav.COLOR,1.4,true)
				_segment(route["exit"],goal,Nav.COLOR,1.4,true)
			# No road route: retain destination marker without a misleading line.
			_target(goal,Nav.COLOR,true)
		if bool(state.get("side_quest_active", false)):
			_target(state["side_quest"],Color("fff0ad"),true)
		if bool(state.get("civic_quest_active", false)):
			_target(state["civic_quest"],Color("95e7bc"),true)
		_target(state["mission"],Color("38e5e4") if state["carrying"] else Color("ffba56"))
		var heading: Vector2 = state.get("player_heading",Vector2.UP)
		if not heading.is_finite() or heading.length_squared() < 0.001:
			heading = Vector2.UP
		heading = heading.normalized()
		var cross := Vector2(-heading.y,heading.x)
		draw_circle(_center,10.0,Color("101821"),true,-1.0,true)
		draw_colored_polygon(PackedVector2Array([_center+heading*10.0,_center-heading*6.0+cross*6.0,_center-heading*3.0,_center-heading*6.0-cross*6.0]),Color("e7edf0"))
	draw_arc(_center,_radius+2.0,0.0,TAU,96,Color("8599a5"),1.8,true)
	# North remains fixed; no atlas/camera rotation or mirrored bearings.
	draw_string(ThemeDB.fallback_font,_center+Vector2(-6.0,-_radius+16.0),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e7edf0"))

# Same radar renderer, tighter indoor scale and authored walls; no street
# routing, hidden mission handholding or false route through the partition.
func _draw_office() -> void:
	_origin=_office_actor
	_scale=_radius/14.0
	var wall := Color("87959d")
	if _office_floor!=0:
		for edge in [[Vector2(-8.5,-10),Vector2(8.5,-10)],[Vector2(8.5,-10),Vector2(8.5,10)],[Vector2(8.5,10),Vector2(-8.5,10)],[Vector2(-8.5,10),Vector2(-8.5,-10)]]:
			if _office_floor==ExecutiveFloor.FLOOR and edge[0]==Vector2(8.5,-10):
				_segment(Vector2(8.5,-10),Vector2(8.5,-5),wall,2.6)
				_segment(Vector2(8.5,-3),Vector2(8.5,10),wall,2.6)
			else:
				_segment(edge[0],edge[1],wall,2.6)
		if _office_floor==Basement.FLOOR:
			for x in Basement.RACK_X:
				_segment(Vector2(x,-8.34),Vector2(x,-1.46),Color("52616e"),6.0)
			_segment(Vector2(-6.3,2.55),Vector2(-3.7,2.55),Color("ad9065"),5.0)
		elif _office_floor==ExecutiveFloor.FLOOR:
			for edge in ExecutiveFloor.BALCONY_EDGES:
				_segment(edge[0],edge[1],Color("ad9065"),2.0)
			for edge in ExecutiveFloor.WALL_EDGES:
				_segment(edge[0],edge[1],wall,2.6)
			for edge in ExecutiveFloor.FURNITURE_EDGES:
				_segment(edge[0],edge[1],Color("ad9065"),4.0)
		else:
			for desk in Workfloor.desk_positions():
				_segment(desk-Vector2(.85,0),desk+Vector2(.85,0),Color("52616e"),3.5)
		_target(_office_target,Color("ffba56"),true)
		draw_circle(_center,5.0,Color("e7edf0"),true,-1.0,true)
		return
	for edge in [
		[Vector2(-8.5,-10),Vector2(-1.3,-10)],
		[Vector2(1.3,-10),Vector2(8.5,-10)],
		[Vector2(-8.5,-10),Vector2(-8.5,3.5)],
		[Vector2(-8.5,5.5),Vector2(-8.5,10)],
		[Vector2(8.5,-10),Vector2(8.5,10)],
		[Vector2(-8.5,10),Vector2(8.5,10)],
		[Vector2(-8.5,-7.65),Vector2(8.5,-7.65)],
		[Vector2(0,Arrival.PARTITION_NEAR_Z),Vector2(0,Arrival.PARTITION_FAR_Z)]
	]:
		_segment(edge[0],edge[1],wall,2.6)
	for edge in Restrooms.WALL_EDGES:
		_segment(edge[0],edge[1],wall,2.6)
	for desk in [Vector2(-5,2.55),Vector2(4.5,1.7),Vector2(-5,-5.4),Vector2(5,-5.4),Vector2(5,6.5),Vector2(-4.2,8.12)]:
		_segment(desk-Vector2(1.1,0),desk+Vector2(1.1,0),Color("52616e"),5.0)
	_target(_office_target,Color("ffba56"),true)
	draw_circle(_center,5.0,Color("e7edf0"),true,-1.0,true)
