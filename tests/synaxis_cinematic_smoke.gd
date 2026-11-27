extends SceneTree
const Office = preload("res://scripts/synaxis_office.gd")
const Exec = preload("res://scripts/synaxis_executive_floor.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var office := Office.new()
	office.position = Office.ORIGIN
	root.add_child(office)
	office.begin_prologue()
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
