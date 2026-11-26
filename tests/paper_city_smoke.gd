extends SceneTree
const Case = preload("res://scripts/independent_investigation.gd")
const Wallet = preload("res://scripts/progression_ledger.gd")

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("PAPER_CITY: "+detail)
		quit(1)
	return ok

func _verify() -> void:
	var wallet := Wallet.new()
	var dossier := Case.new()
	if not check(not dossier.available(wallet),"prerequisite required"):
		return
	wallet.credit_once("technical:crane_interlock",480)
	if not check(dossier.available(wallet) and dossier.advance("dock_watch",0,wallet)["status"]=="unavailable","wrong location rejected"):
		return
	if not check(not dossier.case_review(wallet).contains("June 11"),"unearned evidence is not exposed"):
		return
	var lead_copy:=dossier.current(wallet)
	lead_copy["site"]="invalid"
	if not check(dossier.current(wallet)["site"]=="harbor_library","returned lead cannot mutate authored case"):
		return
	for i in range(3):
		if not check(dossier.advance(Case.STAGES[i]["site"],0,wallet)["status"]=="advanced","evidence step"):
			return
		if not check(dossier.case_review(wallet).contains(Case.EVIDENCE[i]),"earned evidence appears in journal"):
			return
	if not check(dossier.case_review(wallet).contains("May 19") and dossier.case_review(wallet).contains("June 11"),"review includes conflicting dates before decision"):
		return
	var copy := Case.new()
	copy.restore(dossier.stage,wallet)
	if not check(copy.stage==3 and copy.advance("harbor_library",1,wallet)["status"]=="incorrect","unsupported accusation rejected after restore"):
		return
	wallet.set_balance(Wallet.MAX_CASH)
	if not check(copy.advance("harbor_library",0,wallet)["status"]=="blocked" and copy.stage==3,"wallet cap retains final stage"):
		return
	wallet.set_balance(0)
	if not check(copy.advance("harbor_library",0,wallet)["status"]=="complete" and wallet.balance==Case.REWARD and not copy.available(wallet),"one-time reward"):
		return
	copy.restore(0,wallet)
	if not check(copy.case_review(wallet).contains("COMPLETE") and copy.case_review(wallet).contains("June 11") and copy.journal(wallet).is_empty(),"completed review survives receipt restore without cluttering HUD"):
		return
	if not check(copy.stage==4 and copy.advance("harbor_library",0,wallet)["status"]=="unavailable","receipt prevents replay"):
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var ledger: RefCounted = world.get("progression")
	ledger.call("credit_once","technical:crane_interlock",480)
	var civic: Node = world.get("civic_services")
	var player: CharacterBody3D = world.get("player")
	world.get("day_night").call("set_hour",12.0)
	civic.call("set_hour",12.0)
	for i in range(Case.STAGES.size()):
		var site: String = Case.STAGES[i]["site"]
		var listings: Array = world.call("_phone_workboard")
		var found := false
		for listing in listings:
			if listing["id"]==Case.ID and listing["position"]==Vector2((civic.call("position_for",site) as Vector3).x,(civic.call("position_for",site) as Vector3).z):
				found = true
		if not check(found,"Workboard follows actual evidence destination"):
			return
		player.global_position = civic.call("position_for",site)
		world.call("_toggle_civic")
		world.call("_civic_action",3)
		if not check(bool(world.get("_investigation_open")),"actual counter opens evidence"):
			return
		world.call("_civic_action",1)
		if not check(int(world.get("investigation").stage)==i+1,"counter advances exactly once"):
			return
	if not check(str((world.call("_journal_context") as Dictionary).get("investigation","")).contains("COMPLETE"),"actual journal receives completed case review"):
		return
	var snap: Dictionary = world.call("_capture_snapshot")
	var session: Node = world.get("session")
	var save: Dictionary = session.call("make_snapshot",snap)
	if not check(session.call("is_valid_snapshot",save),"completed evidence save valid"):
		return
	save["investigation_stage"]=3
	if not check(not session.call("is_valid_snapshot",save),"paid receipt and stage mismatch rejected"):
		return
	world.queue_free()
	await process_frame
	print("PAPER_CITY PASS")
	quit(0)
