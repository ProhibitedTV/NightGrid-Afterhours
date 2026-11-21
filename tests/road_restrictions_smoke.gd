extends SceneTree
const Restrictions = preload("res://scripts/road_restrictions.gd")
const Route = preload("res://scripts/street_route.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("ROAD_RESTRICTIONS: " + message)
		quit(1)
	return ok

func _verify() -> void:
	var r = Restrictions.new()
	var a := Vector2i.ZERO
	var b := Vector2i.RIGHT
	var start := Vector2.ZERO
	var goal := Vector2(58,0)
	var baseline := Route.plan(start,goal)
	if not _check(r.plan(start,goal) == baseline, "unrestricted baseline"):
		return
	if not _check(r.add(a,b,"CIV-1","traffic service",10.0) and r.is_closed(b,a), "bidirectional restriction"):
		return
	var detour: Dictionary = r.plan(start,goal)
	if not _check(not detour.is_empty() and is_equal_approx(float(detour["road_m"]),174.0) and detour == r.plan(start,goal), "deterministic alternate route"):
		return
	if not _check(is_equal_approx(float(r.plan(goal,start)["road_m"]),174.0) and r.plan(Vector2(20,0),goal).is_empty(), "reverse detour and closed edge fallback"):
		return
	var same: Dictionary = r.plan(Vector2(10,58),Vector2(43,58))
	if not _check(is_equal_approx(float(same["road_m"]),33.0), "same open edge"):
		return
	if not _check(not r.add(a,Vector2i(2,0),"bad","bad",10.0) and not r.add(b,a,"duplicate","bad",10.0), "invalid and duplicate edges"):
		return
	var corner := Vector2i(-4,-4)
	if not _check(r.add(corner,corner+Vector2i.RIGHT,"CIV-2","service",20.0), "first corner edge"):
		return
	var rev: int = r.revision
	if not _check(not r.add(corner,corner+Vector2i.DOWN,"CIV-3","service",20.0) and r.revision == rev, "reject disconnected network"):
		return
	var copy: Dictionary = r.catalog()
	copy.clear()
	if not _check(r.catalog().size() == 2, "defensive catalog"):
		return
	r.advance(10.0)
	if not _check(not r.is_closed(a,b) and r.is_closed(corner,corner+Vector2i.RIGHT), "expiration"):
		return
	r.advance(10.0)
	if not _check(r.catalog().is_empty() and r.plan(start,goal) == baseline, "restore baseline"):
		return
	print("ROAD_RESTRICTIONS_SMOKE PASS: edge validation, deterministic detours, safe rejection, expiry and fallback")
	quit(0)
