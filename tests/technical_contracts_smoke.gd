extends SceneTree
const Cases = preload("res://scripts/technical_contracts.gd")
const Wallet = preload("res://scripts/progression_ledger.gd")

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("TECHNICAL_CONTRACTS: "+detail)
		quit(1)
	return ok

func _verify() -> void:
	var wallet := Wallet.new()
	for site in Cases.CASES:
		var job: Dictionary = Cases.CASES[site]
		var correct: int = job["correct"]
		var initial: int = wallet.balance
		if not check(Cases.available(site,wallet) and Cases.resolve(site,1-correct,wallet)["status"]=="incorrect" and wallet.balance==initial,"incorrect diagnosis never pays"):
			return
		wallet.set_balance(Wallet.MAX_CASH)
		if not check(Cases.resolve(site,correct,wallet)["status"]=="blocked" and Cases.available(site,wallet),"full wallet retains contract"):
			return
		wallet.set_balance(initial)
		if not check(Cases.resolve(site,correct,wallet)["status"]=="complete" and wallet.balance==initial+int(job["reward"]) and wallet.has_receipt(job["id"]),"settled through authoritative ledger"):
			return
		if not check(not Cases.available(site,wallet) and Cases.resolve(site,correct,wallet)["status"]=="unavailable","one-time payout"):
			return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var ledger: RefCounted = world.get("progression")
	var listings: Array = world.call("_phone_workboard")
	var found := 0
	for listing in listings:
		if str(listing["id"]).begins_with("technical:"):
			found += 1
	if not check(found==2,"both independent cases appear on actual Workboard"):
		return
	var civic: Node = world.get("civic_services")
	var player: CharacterBody3D = world.get("player")
	world.get("day_night").call("set_hour",12.0)
	civic.call("set_hour",12.0)
	player.global_position = civic.call("position_for","crane_supply")
	world.call("_toggle_civic")
	world.call("_civic_action",3)
	if not check(bool(world.get("_technical_case_open")),"real counter opens diagnostic"):
		return
	var balance: int = ledger.get("balance")
	world.call("_civic_action",1)
	if not check(ledger.get("balance")==balance and bool(world.get("_technical_case_open")),"wrong choice remains retryable"):
		return
	player.global_position += Vector3(20,0,0)
	world.call("_civic_action",2)
	if not check(ledger.get("balance")==balance and not bool(world.get("_technical_case_open")),"remote payout rejected"):
		return
	player.global_position = civic.call("position_for","crane_supply")
	world.call("_toggle_civic")
	world.call("_civic_action",3)
	world.call("_civic_action",2)
	if not check(ledger.call("has_receipt","technical:crane_interlock") and ledger.get("balance")==balance+480,"real correct choice pays once"):
		return
	world.queue_free()
	await process_frame
	print("TECHNICAL_CONTRACTS PASS")
	quit(0)
