extends SceneTree
const Lane = preload("res://scripts/lane_detour.gd")
const Restrictions = preload("res://scripts/road_restrictions.gd")
func _initialize() -> void:
	call_deferred("_verify")
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("LANE_DETOUR: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var registry = Restrictions.new()
	var direct := Lane.plan(registry,Vector2i.ZERO,Vector2i(2,0))
	if not _check(direct==[Vector3(0,1,3.25),Vector3(116,1,3.25)],"right-hand eastbound lane"):
		return
	var reverse := Lane.plan(registry,Vector2i(2,0),Vector2i.ZERO)
	if not _check(reverse==[Vector3(116,1,-3.25),Vector3(0,1,-3.25)],"opposing direction uses separate lane"):
		return
	var turn: Array[Vector2] = [Vector2.ZERO,Vector2(58,0),Vector2(58,58)]
	if not _check(Lane.from_centerline(turn,1.0)==[Vector3(0,1,3.25),Vector3(54.75,1,3.25),Vector3(54.75,1,58)],"right-turn lane join"):
		return
	turn[2]=Vector2(58,-58)
	if not _check(Lane.from_centerline(turn,1.0)==[Vector3(0,1,3.25),Vector3(61.25,1,3.25),Vector3(61.25,1,-58)],"left-turn lane join"):
		return
	if not _check(registry.add(Vector2i.ZERO,Vector2i.RIGHT,"TEST","street works",10.0),"register closed block"):
		return
	var detour := Lane.plan(registry,Vector2i.ZERO,Vector2i.RIGHT)
	if not _check(detour.size()==4 and detour==Lane.plan(registry,Vector2i.ZERO,Vector2i.RIGHT) and absf(detour[1].z)>=54.75 and absf(detour[2].z)>=54.75,"deterministic detour avoids closed block"):
		return
	registry.advance(10)
	if not _check(Lane.plan(registry,Vector2i.ZERO,Vector2i(2,0))==direct,"expiry restores baseline"):
		return
	var bad: Array[Vector2] = [Vector2.ZERO,Vector2(58,58)]
	if not _check(Lane.from_centerline(bad,1.0).is_empty(),"diagonal rejected"):
		return
	bad = [Vector2.ZERO,Vector2(58,0),Vector2.ZERO]
	if not _check(Lane.from_centerline(bad,1.0).is_empty(),"U-turn rejected"):
		return
	if not _check(Lane.plan(registry,Vector2i.ZERO,Vector2i(9,0)).is_empty() and Lane.plan(registry,Vector2i.ZERO,Vector2i.RIGHT,INF).is_empty() and Lane.plan(registry,Vector2i.ZERO,Vector2i.ZERO).is_empty(),"invalid endpoint and height"):
		return
	print("LANE_DETOUR_SMOKE PASS: right-hand lanes, turns, closed-block detour, expiry and invalid geometry")
	quit(0)
