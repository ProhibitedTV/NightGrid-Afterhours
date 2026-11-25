extends SceneTree
const Rhythm=preload("res://scripts/rhythm_rehearsal.gd")
const Ledger=preload("res://scripts/progression_ledger.gd")
func _initialize()->void:
	var rhythm:=Rhythm.new()
	rhythm.start(1)
	if rhythm.strike(0) or rhythm.claim():
		quit(1)
		return
	for lane in rhythm.pattern:
		rhythm.advance(rhythm.target_time()-rhythm.elapsed)
		if not rhythm.strike(lane) or rhythm.strike(lane):
			quit(1)
			return
	if not rhythm.passed() or not rhythm.claim() or rhythm.claim():
		quit(1)
		return
	rhythm.start(2)
	rhythm.advance(20.0)
	if rhythm.passed() or rhythm.claim():
		quit(1)
		return
	rhythm.start(3)
	rhythm.cancel()
	if rhythm.claim():
		quit(1)
		return
	var p:=Ledger.new()
	if p.settle_blue_hour_set(1):
		quit(1)
		return
	p.credit_once("venue:soundcheck_pass",125)
	if not p.settle_blue_hour_set(1) or p.settle_blue_hour_set(1) or p.settle_blue_hour_set(3) or p.balance!=170 or p.street_cred()!=42:
		quit(1)
		return
	var restored:=Ledger.new()
	if not restored.restore(p.balance,JSON.parse_string(JSON.stringify(p.snapshot()))) or restored.settle_blue_hour_set(1) or not restored.settle_blue_hour_set(2) or restored.street_activity_runs("live_gig")!=2:
		quit(1)
		return
	restored.set_balance(Ledger.MAX_CASH)
	if restored.settle_blue_hour_set(3) or restored.street_activity_runs("live_gig")!=2:
		quit(1)
		return
	print("RHYTHM_REHEARSAL PASS: timing, cancellation, once-only claims, sequence and atomic payout")
	quit(0)
