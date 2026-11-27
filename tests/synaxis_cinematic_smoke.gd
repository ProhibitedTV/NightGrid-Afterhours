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
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 68.0
	await physics_frame
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
