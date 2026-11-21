extends SceneTree
const Logical = preload("res://scripts/logical_traffic.gd")
const Traffic = preload("res://scripts/traffic_system.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("LOGICAL_TRAFFIC: "+message)
		quit(1)
	return ok

func _verify() -> void:
	var traffic = Traffic.new()
	var paths: Array[Dictionary] = []
	for spec in [["perimeter",232.0,8],["outer",174.0,7],["inner",116.0,6],["core",58.0,4]]:
		var span: float = spec[1]
		paths.append({"id":spec[0],"path":traffic.loop_route(-span,span,-span,span,1.0),"count":spec[2]})
	var a = Logical.new()
	var b = Logical.new()
	a.configure(834726,paths)
	b.configure(834726,paths)
	if not _check(a.ids().size()==25 and a.ids()==b.ids() and a.sample("inner-00")==b.sample("inner-00"),"stable population"):
		return
	var id := "inner-00"
	var before: Dictionary = a.sample(id)
	var active: Array = [id]
	a.advance(10.0,active)
	if not _check(a.sample(id)==before and a.sample("core-00")!=b.sample("core-00"),"only background agents advance"):
		return
	var position: Vector3 = before["position"]
	if not _check(a.capture_live(id,position,int(before["next_index"])) and not a.capture_live(id,position+Vector3(0,0,2000),int(before["next_index"])),"physical handoff validation"):
		return
	b.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
	if not _check(a.sample(id)["position"].distance_to(b.sample(id)["position"])<0.001 and a.sample("core-00")["position"].distance_to(b.sample("core-00")["position"])<0.001,"JSON phase roundtrip"):
		return
	var allow := func(_point: Vector3) -> bool: return true
	var deny := func(_point: Vector3) -> bool: return false
	var empty: Array[Vector3] = []
	var focus := Vector3(0,1,0)
	var plan: Dictionary = a.plan_changes(focus,focus,0.0,false,{},empty,allow,allow)
	if not _check(plan["activate"].size()>0 and plan["activate"].size()<=Logical.MAX_CHANGES,"bounded activation"):
		return
	var first: Dictionary = plan["activate"][0]
	var blocked: Array[Vector3] = [first["position"]]
	var alternative: Dictionary = a.plan_changes(focus,focus,0.0,false,{},blocked,allow,allow)
	for entry in alternative["activate"]:
		if not _check(entry["id"]!=first["id"],"occupied lane rejection"):
			return
	if not _check(a.plan_changes(focus,focus,0.0,true,{},empty,allow,allow)["activate"].is_empty() and a.plan_changes(focus,focus,0.0,false,{},empty,deny,allow)["activate"].is_empty(),"indoor and visibility/geometry callback guards"):
		return
	var far := {id:Vector3(220,1,220)}
	if not _check(a.plan_changes(focus,focus,0.0,false,far,empty,deny,allow)["recycle"]==[id] and a.plan_changes(focus,focus,0.0,false,far,empty,deny,deny)["recycle"].is_empty(),"live position and visibility guard for release"):
		return
	var full := {}
	for i in range(Logical.MAX_ACTIVE):
		full[a.ids()[i]]=focus
	if not _check(a.plan_changes(focus,focus,0.0,false,full,empty,allow,allow)["activate"].is_empty(),"active budget"):
		return
	traffic.free()
	print("LOGICAL_TRAFFIC_SMOKE PASS: deterministic population, phase continuity, JSON, occupancy/visibility, active cap and bounded work")
	quit(0)
