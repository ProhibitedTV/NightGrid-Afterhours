extends SceneTree
const Office = preload("res://scripts/synaxis_office.gd")
const Arrival = preload("res://scripts/synaxis_arrival.gd")
const Exec = preload("res://scripts/synaxis_executive_floor.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var arrival := Arrival.new()
	var badge := Arrival.new()
	badge.advance(float(Arrival.SHOTS[0]["duration"]))
	if not badge.sample()["badge_presented"] or badge.sample()["badge_authorized"] or badge.sample()["gate_open"]:
		_fail("Badge presentation must precede authorization and gate opening")
		return
	badge.advance(1.2)
	if not badge.sample()["badge_authorized"] or badge.sample()["gate_open"]:
		_fail("Badge authorization must precede gate traversal")
		return
	var surveillance_count := 0
	for shot in Arrival.SHOTS:
		var sample := arrival.sample()
		if sample["surveillance"]:
			surveillance_count += 1
			if sample["fov"] <= 60.0 or not sample["gate_open"] or not sample["badge_authorized"] or shot.has("camera_end"):
				_fail("Surveillance insert must be fixed, wide and cover ingress")
				return
		elif sample["fov"] != 60.0:
			_fail("Conventional arrival lens must remain unchanged")
			return
		arrival.advance(float(shot["duration"]))
	if surveillance_count != 1 or not arrival.sample().is_empty():
		_fail("Arrival must have one surveillance insert and terminate normally")
		return
	var office := Office.new()
	office.position = Office.ORIGIN
	root.add_child(office)
	office.begin_prologue()
	var badge_events: Array[String] = []
	office.arrival_badge_presented.connect(func(): badge_events.append("presented"))
	office.arrival_badge_authorized.connect(func(): badge_events.append("authorized"))
	office.arrival_badge_reset.connect(func(): badge_events.append("reset"))
	var indicators := office.get_node("ArchitecturalFinish/reader_red_box") as MultiMeshInstance3D
	var idle_material := indicators.material_override
	var authorized_sample := {"badge_presented":false,"badge_authorized":true}
	office.call("_update_arrival_badge",authorized_sample)
	if indicators.material_override == idle_material:
		_fail("Authorization must change physical reader indicator material")
		return
	office.call("_update_arrival_badge",authorized_sample)
	office.call("_reset_arrival_badge")
	if indicators.material_override != idle_material:
		_fail("Reset must restore reader indicator material")
		return
	office.call("_update_arrival_badge",authorized_sample)
	if badge_events != ["presented","authorized","reset","presented","authorized"]:
		_fail("Badge events must catch up in order, emit once and reset for replay")
		return
	office.call("_reset_arrival_badge")
	office.call("_select_floor",Exec.FLOOR)
	if not Exec.blocks_staff_sight(Vector2(4,-1.5),Vector2(4,.5)) or Exec.blocks_staff_sight(Vector2(0,-1.5),Vector2(0,.5)):
		_fail("Executive wall blocks attention while doorway stays open")
		return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 68.0
	await physics_frame
	var glazing := office.find_children("ExecutiveGlazing*", "Node3D", true, false)
	if glazing.size() != Exec.WALL_EDGES.size():
		_fail("Each executive partition must have the dimensioned glazing assembly")
		return
	var space := office.get_world_3d().direct_space_state
	for x in [0.0,4.0]:
		var from := office.to_global(Vector3(x,Exec.BASE+1.15,.3))
		var to := office.to_global(Vector3(x,Exec.BASE+1.15,-1.4))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
		if hit.is_empty() != is_zero_approx(x):
			_fail("Partition fit-out must preserve collision at glazing and clearance at the main opening")
			return
	var story_staff: Dictionary=office.get("_staff")
	var dev:Node3D=story_staff["dev"]
	dev.call("attend",dev.global_position+Vector3.FORWARD,true)
	office.update_staff_attention(2,Vector3.INF)
	if dev.call("get_staff_state")["attention"]:
		_fail("Invalid target must clear previously held attention")
		return
	office.dialogue_camera(camera,2,0)
	var first := camera.global_position
	var ceo: Node3D = office.get("_ceo")
	var hr: Node3D = office.get("_hr")
	if camera.fov>=68.0 or not ceo.call("get_staff_state")["attention"] or office.get("_intro_canvas").visible:
		_fail("Opening shot or HUD state")
		return
	paused = true
	await create_timer(.8,true).timeout
	if absf(camera.fov-58.0)>.1:
		_fail("Lens transition must run while menu pauses world")
		return
	office.dialogue_camera(camera,2,1)
	if camera.global_position.distance_to(first)<.5 or ceo.call("get_staff_state")["attention"]:
		_fail("Assistant cut or founder reaction")
		return
	office.dialogue_camera(camera,2,2)
	var decision := camera.global_position
	office.dialogue_camera(camera,3,2)
	if camera.global_position.distance_to(decision)>.01 or camera.fov>=53.0:
		_fail("Reporting outcome should remain in the room")
		return
	office.dialogue_camera(camera,4,2)
	if not hr.call("get_staff_state")["attention"] or ceo.call("get_staff_state")["attention"]:
		_fail("Offboarding attention")
		return
	office.end_dialogue()
	if camera.fov!=68.0 or not office.get("_intro_canvas").visible or hr.call("get_staff_state")["attention"]:
		_fail("Gameplay lens, HUD and actor restoration")
		return
	paused=false
	office.queue_free()
	camera.queue_free()
	await process_frame
	print("SYNAXIS_CINEMATIC PASS: distinct coverage, paused lens, reactions and cleanup")
	quit(0)

func _fail(reason: String) -> void:
	push_error("SYNAXIS_CINEMATIC "+reason)
	quit(1)
