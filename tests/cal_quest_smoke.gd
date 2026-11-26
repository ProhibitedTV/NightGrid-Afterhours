extends SceneTree
const Ledger=preload("res://scripts/progression_ledger.gd")
const SceneCred=preload("res://scripts/scene_reputation.gd")
func _initialize()->void:
	var ledger:=Ledger.new()
	ledger.set_balance(20)
	if ledger.collect_cal_gift() or ledger.complete_cal_quest() or not ledger.accept_cal_quest() or ledger.accept_cal_quest():
		quit(1)
		return
	if ledger.balance!=20 or not ledger.collect_cal_gift() or ledger.collect_cal_gift():
		quit(1)
		return
	if SceneCred.scores(ledger)!={"music":0,"community":0,"underground":0}:
		quit(1)
		return
	var restored:=Ledger.new()
	if not restored.restore(ledger.balance,JSON.parse_string(JSON.stringify(ledger.snapshot()))) or restored.cal_quest!=2:
		quit(1)
		return
	if not restored.complete_cal_quest() or restored.complete_cal_quest() or restored.balance!=105 or restored.street_cred()!=25 or not restored.has_receipt(Ledger.CAL_RECEIPT):
		quit(1)
		return
	if SceneCred.scores(restored)!={"music":0,"community":12,"underground":0} or SceneCred.rank(12)!="New face":
		quit(1)
		return
	var completed:=Ledger.new()
	if not completed.restore(restored.balance,JSON.parse_string(JSON.stringify(restored.snapshot()))) or SceneCred.scores(completed)!=SceneCred.scores(restored) or completed.balance!=105:
		quit(1)
		return
	var invalid:=restored.snapshot()
	invalid["cal_quest"]=1
	if Ledger.valid_snapshot(invalid):
		quit(1)
		return
	var old:=ledger.snapshot()
	old.erase("cal_quest")
	if not restored.restore(20,old) or restored.cal_quest!=0:
		quit(1)
		return
	print("CAL_QUEST PASS: ordered transitions, save round trip, old saves and once-only reward")
	quit(0)
