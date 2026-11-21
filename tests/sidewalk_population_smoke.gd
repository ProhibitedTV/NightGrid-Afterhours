extends SceneTree
const Population = preload("res://scripts/sidewalk_population.gd")
func _initialize() -> void:
	call_deferred("_verify")
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("SIDEWALK_POPULATION: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var links: Array[Dictionary] = []
	for ix in range(-4,4):
		for iz in range(-4,4):
			links.append_array(Population.block_candidates(ix,iz))
	if not _check(links.size()==256 and Population.block_candidates(4,0).is_empty(),"parcel bounds"):
		return
	var a = Population.new()
	var b = Population.new()
	a.configure(123,links)
	links.reverse()
	b.configure(123,links)
	if not _check(a.ids().size()==Population.MAX_LOGICAL and a.ids()==b.ids(),"stable bounded IDs"):
		return
	var id: String = a.ids()[0]
	var before: Dictionary = a.sample(id)
	if not _check(before==b.sample(id),"seed and input ordering"):
		return
	var active: Array = [id]
	a.advance(20.0,active)
	if not _check(a.sample(id)==before and a.sample(a.ids()[1])!=b.sample(a.ids()[1]),"active phase frozen"):
		return
	if not _check(a.capture_live(id,before["position"],before["heading"]) and not a.capture_live(id,Vector3(999,999,999),Vector3.LEFT),"handoff validation"):
		return
	b.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
	if not _check(a.sample(id)["position"].distance_to(b.sample(id)["position"])<0.001,"JSON save continuity"):
		return
	var focus := Vector3(-170,0,0)
	var empty: Array[Vector3] = []
	var allow := func(_entry: Dictionary) -> bool: return true
	var deny := func(_entry: Dictionary) -> bool: return false
	var hide := func(_at: Vector3) -> bool: return true
	var plan: Dictionary = a.plan_changes(focus,focus,false,{},empty,allow,hide)
	if not _check(plan["activate"].size()>0 and plan["activate"].size()<=Population.MAX_CHANGES,"bounded activation"):
		return
	var first: Dictionary = plan["activate"][0]
	var blocked: Array[Vector3] = [first["position"]]
	for entry in a.plan_changes(focus,focus,false,{},blocked,allow,hide)["activate"]:
		if not _check(entry["id"]!=first["id"],"occupied spawn rejected"):
			return
	if not _check(a.plan_changes(focus,focus,false,{},empty,deny,hide)["activate"].is_empty() and a.plan_changes(focus,focus,true,{},empty,allow,hide)["activate"].is_empty(),"fail closed and indoor"):
		return
	var full := {}
	for i in range(Population.MAX_ACTIVE):
		full[a.ids()[i]]=focus
	if not _check(a.plan_changes(focus,focus,false,full,empty,allow,hide)["activate"].is_empty(),"active ceiling"):
		return
	print("SIDEWALK_POPULATION_SMOKE PASS: candidate bounds, seeded identities, phase handoff, save and guarded activation")
	quit(0)
