extends SceneTree
const Menu = preload("res://scripts/game_menu.gd")
const Interviews = preload("res://scripts/synaxis_interviews.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)

func _verify() -> void:
	var menu := Menu.new()
	root.add_child(menu)
	menu.open_staff_interview(Interviews.conversation("worker_1_0",0))
	await process_frame
	await process_frame
	var buttons: Dictionary = menu.get_buttons()
	var left := buttons.get("interview_0") as Button
	var right := buttons.get("interview_1") as Button
	check(left != null and right != null,"existing topic IDs")
	if left != null and right != null:
		check(left.get_parent().name=="DialogueWheel" and left.get_parent()==right.get_parent(),"radial parent")
		check(left.position.x<right.position.x,"stable left/right placement")
		check(left.get_node_or_null(left.focus_neighbor_right)==right,"directional focus")
		check(left.tooltip_text==Interviews.conversation("worker_1_0",0)["topics"][0]["question"],"canonical question preview")
		check(menu.get("_interview_topic")==-1,"focus never commits")
		left.pressed.emit()
		check(menu.get("_interview_topic")==0 and menu.get_buttons().has("interview_back"),"confirmed topic follows existing dispatcher")
		check((menu.get("_investigation_notes") as Dictionary).size()==1,"recorded canonical note")
		menu.call("_choice","interview_back")
		menu.call("_choice","interview_0")
		check((menu.get("_investigation_notes") as Dictionary).size()==1,"no duplicate consequence")
		menu.call("_choice","interview_leave")
		check(not paused and not menu.is_open(),"leave unpauses world")
	menu.open_breakroom()
	check(menu.get_buttons().has("breakroom_photo") and menu.get_buttons().has("breakroom_decline"),"party actions preserved")
	menu.get_buttons()["breakroom_decline"].pressed.emit()
	check(menu.get("_breakroom_choice")=="breakroom_decline","party intent maps to canonical choice")
	menu.call("_choice","breakroom_leave")
	menu.queue_free()
	if not failures.is_empty():
		for failure in failures:
			push_error("DIALOGUE_WHEEL: "+failure)
		quit(1)
		return
	print("DIALOGUE_WHEEL PASS: stable slots, preview, focus, existing actions and consequences")
	quit(0)
