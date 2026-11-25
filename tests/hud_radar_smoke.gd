extends SceneTree
const Radar = preload("res://scripts/hud_radar.gd")
func _initialize() -> void:
	create_timer(35.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("HUD_RADAR: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var across := Radar.clip_segment(Vector2(-20,0),Vector2(20,0),10)
	if not check(across.size()==2 and across[0].is_equal_approx(Vector2(-10,0)) and across[1].is_equal_approx(Vector2(10,0)),"diameter clipping"):
		return
	if not check(Radar.clip_segment(Vector2(-20,12),Vector2(20,12),10).is_empty(),"offscreen road rejected"):
		return
	var inside := Radar.clip_segment(Vector2.ZERO,Vector2(20,0),10)
	if not check(inside.size()==2 and inside[0]==Vector2.ZERO and inside[1].is_equal_approx(Vector2(10,0)),"outgoing route clipped"):
		return
	if not check(Radar.clip_segment(Vector2.INF, Vector2.ZERO, 10).is_empty(), "nonfinite segment rejected"):
		return
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var radar: Control = world.get_node("HUD/Minimap")
	if not check(radar.get_script()==Radar and radar.anchor_left==0.0 and radar.anchor_right==0.0 and radar.anchor_top==1.0 and radar.anchor_bottom==1.0,"HUD bottom left radar"):
		return
	if not check(radar.offset_left==24.0 and radar.offset_bottom==-24.0 and radar.size.is_equal_approx(Vector2(240,240)) and radar.mouse_filter==Control.MOUSE_FILTER_IGNORE,"inset and passive input"):
		return
	var status: PanelContainer = world.get_node("HUD/PlayerStatus")
	var health: ProgressBar = world.get("hud_health")
	var stamina: ProgressBar = world.get("hud_stamina")
	var context: PanelContainer = world.get("hud_prompt_card")
	var notice: PanelContainer = world.get("hud_notice_card")
	if not check(status.custom_minimum_size.x == 390.0 and health.get_theme_stylebox("fill").get_minimum_size().y == 0.0 and stamina.get_theme_stylebox("fill").get_minimum_size().y == 0.0,"compact status and independent meter style"):
		return
	if not check(context.offset_left == -320.0 and context.offset_right == 320.0 and context.offset_bottom == -24.0 and notice.anchor_left == 1.0,"reserved context and notice positions"):
		return
	var state: Dictionary = world.call("get_map_state")
	if not check(state.has("player_heading") and (state["player_heading"] as Vector2).is_finite(),"live actor heading"):
		return
	var player: Node3D = world.get("player")
	var visual: Node3D = player.get("visual")
	visual.global_rotation = Vector3(0, PI * 0.5, 0)
	state = world.call("get_map_state")
	if not check((state["player_heading"] as Vector2).normalized().is_equal_approx(Vector2.RIGHT), "player arrow follows actual visual heading"):
		return
	var car: CharacterBody3D = (world.get("cars") as Array)[0]
	world.set("current_car", car)
	car.global_rotation = Vector3(0, -PI * 0.5, 0)
	state = world.call("get_map_state")
	if not check((state["player_heading"] as Vector2).normalized().is_equal_approx(Vector2.RIGHT), "vehicle arrow follows vehicle forward axis"):
		return
	world.set("current_car", null)
	var dialogue: Control = world.get("venue_panel")
	dialogue.show()
	if not check(not radar.visible,"dialogue no radar overlap"):
		return
	dialogue.hide()
	if not check(radar.visible,"restore radar"):
		return
	radar.queue_redraw()
	await process_frame
	print("HUD_RADAR_SMOKE PASS: circle segment clipping, actual HUD anchors, heading and dialogue")
	quit(0)
