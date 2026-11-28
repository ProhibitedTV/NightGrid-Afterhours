extends SceneTree
## Strict creator-only check: count actual NPC actors, not candidate files.
const Bank = preload("res://scripts/character_bank.gd")
const Office = preload("res://scripts/synaxis_office.gd")
const Cafe = preload("res://scripts/lantern_cup_hero.gd")
const Human = preload("res://scripts/humanoid_visual.gd")
const Pool = preload("res://scripts/pedestrian_pool.gd")

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CHARACTER_SCENE FAIL: " + reason)
	quit(1)

func _has_rig(actor: Node3D) -> bool:
	for name in ["CharacterBankVisual", "CreatorCastVisual"]:
		var rig := actor.get_node_or_null(name)
		if rig != null and rig.call("is_pedestrian_visual_ready"):
			return true
	return false

func _run() -> void:
	if not Bank.available():
		_fail("Complete staged bank required")
		return
	var office := Office.new()
	office.position = Office.ORIGIN
	root.add_child(office)
	office.begin_prologue()
	await physics_frame
	var staff: Dictionary = office.get("_staff")
	if staff.size() != 8:
		_fail("Expected eight named prologue staff")
		return
	var count := 0
	var missing: Array[String] = []
	for node in office.find_children("*", "Node3D", true, false):
		var actor := node as Node3D
		if not actor.has_method("get_staff_state"):
			continue
		count += 1
		if not _has_rig(actor):
			var state: Dictionary = actor.call("get_staff_state")
			missing.append(str(state.get("id", actor.name)))
	print("CHARACTER_SCENE office: ", count - missing.size(), "/", count, " staff rigged")
	if count < 40 or not missing.is_empty():
		_fail("Office missing imported actors: " + str(missing))
		return
	if not _has_rig(office.get("_assistant") as Node3D):
		_fail("Lin Xue still uses a primitive visual")
		return
	office.finish_prologue()
	root.remove_child(office)
	office.free()
	var cafe := Cafe.new()
	root.add_child(cafe)
	await process_frame
	var patrons: Array = cafe.get("_patrons")
	if patrons.size() != 5:
		_fail("Cafe roster changed")
		return
	for actor in patrons:
		if not _has_rig(actor):
			_fail("Cafe patron missing rig: " + str(actor.name))
			return
	if not _has_rig(cafe.get_node("MaraHero") as Node3D):
		_fail("Mara still uses primitive visual")
		return
	root.remove_child(cafe)
	cafe.free()
	for role in ["ARCADE", "GROCERY", "DISPATCH"]:
		var host := Human.new()
		host.configure(1, role)
		root.add_child(host)
		if not _has_rig(host):
			_fail("Generic role missing imported visual: " + role)
			return
		root.remove_child(host)
		host.free()
	var pool := Pool.new()
	root.add_child(pool)
	var visual := load("res://scenes/pedestrian_visual.tscn") as PackedScene
	if not pool.build(visual, 12, Bank.street_models()) or pool.capacity() != 12:
		_fail("Twelve-slot imported street pool failed")
		return
	root.remove_child(pool)
	pool.free()
	print("CHARACTER_SCENE PASS: office, cafe, generic hosts and street pool")
	quit(0)
