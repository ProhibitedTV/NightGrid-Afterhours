extends SceneTree
const Director = preload("res://scripts/courier_mission.gd")
const Wallet = preload("res://scripts/progression_ledger.gd")
const Story = preload("res://scripts/story_mission.gd")

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("COURIER_MISSION: " + message)
		quit(1)
	return ok

func _verify() -> void:
	var job := Director.new()
	var wallet := Wallet.new()
	var pickup := job.target()
	if not check(job.objective()["id"] == "collect" and job.advance("deliver", pickup, wallet).is_empty(), "wrong objective cannot advance"):
		return
	if not check(job.advance("collect", pickup + Vector3(10,0,0), wallet).is_empty(), "remote pickup refused"):
		return
	if not check(job.advance("collect", pickup, wallet).get("event") == "collected" and job.has_package(), "pickup advances one step"):
		return
	var dropoff := job.target()
	if not check(job.advance("collect", dropoff, wallet).is_empty() and job.restart() and job.target() == pickup and wallet.balance == 0, "abandon and retry preserves route and cash"):
		return
	job.advance("collect", pickup, wallet)
	var restored := Director.new()
	if not check(restored.restore(0.0, true) and restored.target() == dropoff and not restored.restore(-1, false) and restored.has_package(), "mid-route restore and invalid rollback"):
		return
	wallet.set_balance(Wallet.MAX_CASH)
	if not check(restored.advance("deliver", dropoff, wallet).get("event") == "blocked" and restored.has_package() and restored.completed_runs == 0, "full wallet leaves delivery retryable"):
		return
	wallet.set_balance(0)
	if not check(restored.advance("deliver", dropoff, wallet).get("reward") == 250 and wallet.balance == 250 and restored.completed_runs == 1, "reward and run advance together"):
		return
	if not check(restored.advance("deliver", dropoff, wallet).is_empty() and wallet.balance == 250 and restored.payout() == 300, "duplicate event rejected and next payout preserved"):
		return
	var story := Story.new()
	if not check(story.event("courier_delivered", wallet).is_empty() and story.event("mara_talk", wallet) == "started", "contact must precede delivery"):
		return
	if not check(story.event("mara_talk", wallet).is_empty() and story.interrupt("failed") and story.step == 0 and story.event("mara_talk", wallet) == "started", "failure requires retry at contact"):
		return
	if not check(story.interrupt("abandoned") and story.event("mara_talk", wallet) == "started" and story.event("courier_delivered", wallet) == "delivered", "abandon and retry"):
		return
	var copy := Story.new()
	if not check(copy.restore(JSON.parse_string(JSON.stringify(story.snapshot()))) and copy.step == 2 and not copy.restore({"version":1,"id":Story.ID,"status":"active","step":3}), "validated story restore"):
		return
	wallet.set_balance(Wallet.MAX_CASH)
	if not check(copy.event("mara_talk", wallet) == "blocked" and copy.step == 2, "failed settlement retains objective"):
		return
	wallet.set_balance(0)
	if not check(copy.event("mara_talk", wallet) == "complete" and copy.event("mara_talk", wallet).is_empty() and wallet.balance == Story.REWARD, "one-time contact reward"):
		return
	print("COURIER_MISSION PASS: route validation, restart, restore, rollback and payout")
	quit(0)
