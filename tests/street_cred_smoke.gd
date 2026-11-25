extends SceneTree
const Ledger=preload("res://scripts/progression_ledger.gd")
const Cred=preload("res://scripts/street_cred.gd")

func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("STREET_CRED: "+message)
		quit(1)
	return ok

func _initialize()->void:
	var p:=Ledger.new()
	p.set_balance(20)
	if not _check(p.street_cred()==0 and p.street_cred_rank()["name"]=="Unknown","initial rank"):
		return
	if not _check(not p.settle_street_activity("fake",1) and not p.settle_street_activity("busking",2) and not p.settle_street_activity("busking",0),"reject unknown or out-of-order runs"):
		return
	if not _check(p.accept_cal_quest() and p.collect_cal_gift() and p.complete_cal_quest() and not p.complete_cal_quest() and p.street_cred()==25 and p.balance==105,"one-time favor and wallet"):
		return
	if not _check(p.street_cred_rank()["name"]=="Local Face" and p.street_cred_rank()["next"]==100,"rank transition"):
		return
	if not _check(p.settle_street_activity("busking",1) and not p.settle_street_activity("busking",1) and p.settle_street_activity("live_gig",1) and p.settle_street_activity("skate_session",1) and p.street_cred()==44 and p.balance==105,"separate monotonic activity credits"):
		return
	var saved:=p.snapshot()
	var q:=Ledger.new()
	if not _check(q.restore(p.balance,JSON.parse_string(JSON.stringify(saved))) and q.street_cred()==44 and q.street_activity_runs("busking")==1,"save round trip"):
		return
	saved.erase("street_activity_runs")
	if not _check(q.restore(105,saved) and q.street_cred()==25,"legacy completed favor derives cred"):
		return
	for invalid in [{"unknown":1},{"busking":-1},{"busking":1.25},{"busking":100001},{"busking":"1"}]:
		var bad:=p.snapshot()
		bad["street_activity_runs"]=invalid
		if not _check(not q.restore(999,bad) and q.street_cred()==25 and q.balance==105,"invalid save fails atomically"):
			return
	# Existing playable social contracts count by exact receipt, including
	# completed legacy saves; unrelated or invented venue IDs do not.
	var local:=Ledger.new()
	for id in ["midnight_thermos","dead_frequency","glass_invoice","last_shift_recipe"]:
		if not _check(local.credit_once("venue:"+id,10) and not local.credit_once("venue:"+id,10),"existing venue settlement remains idempotent"):
			return
	if not _check(local.street_cred()==80 and local.street_cred_sources().size()==4 and local.balance==40,"four existing social contracts award 80 cred"):
		return
	if not _check(local.credit_once("venue:unknown",10) and local.street_cred()==80,"unknown receipt does not award reputation"):
		return
	if not _check(local.accept_cal_quest() and local.collect_cal_gift() and local.complete_cal_quest() and local.street_cred()==105 and local.street_cred_rank()["name"]=="Recognized","social path reaches second earned rank"):
		return
	var old:=local.snapshot()
	old.erase("street_activity_runs")
	if not _check(q.restore(local.balance,old) and q.street_cred()==105 and q.street_cred_sources().size()==5,"existing favor receipts migrate without another payout"):
		return
	var cap:=Cred.new()
	if not _check(cap.restore({"live_gig":Cred.MAX_RUNS}) and cap.total({})==Cred.MAX_CRED and Cred.rank(1000)["name"]=="Street Legend" and Cred.rank(1000)["next"]==0,"bounded total and terminal rank"):
		return
	print("STREET_CRED PASS: ranks, receipt migration, monotonic counters, atomic validation and independent cash")
	quit(0)
