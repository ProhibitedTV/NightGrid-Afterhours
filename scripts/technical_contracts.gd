extends RefCounted
## Fictional maintenance puzzles. One-time payouts use the existing progression
## ledger. No real system access, new wallet, or mutable saved puzzle state.
const CASES = {
	"crane_supply":{
		"id":"technical:crane_interlock","title":"THE SILENT CRANE","reward":480,
		"brief":"Vik's cargo hoist refuses to start. Diagnose the simulated controller at Crane & Gear.",
		"evidence":"Motor: ready. Load: within rating. Guard-door switch: OPEN with door closed. Controller reports safety inhibit.",
		"options":["Replace the motor","Inspect and repair the guard-door switch"],
		"correct":1,"success":"The replacement switch passes its self-test. Vik releases the hoist for inspection.",
		"wrong":"The motor tests healthy. The safety interlock still inhibits movement."
	},
	"power_annex":{
		"id":"technical:grid_telemetry","title":"GHOST IN THE GRID","reward":620,
		"brief":"Lin needs an independent review of a faulty read-only telemetry display at Grid Annex Four.",
		"evidence":"Local meter: 220 units. Remote display: 440 units. Sample timestamps match. Scaling coefficient: 2.0; calibration sheet specifies 1.0.",
		"options":["Restore the documented display scaling","Increase the actual power output"],
		"correct":0,"success":"The display agrees with the local meter. Lin signs off the audit.",
		"wrong":"The local meter was already correct. Changing the supply would not repair the display."
	}
}

static func available(site: String, wallet: RefCounted) -> bool:
	return CASES.has(site) and not wallet.call("has_receipt",CASES[site]["id"])

static func resolve(site: String, choice: int, wallet: RefCounted) -> Dictionary:
	if not available(site,wallet) or choice < 0 or choice > 1:
		return {"status":"unavailable"}
	var job: Dictionary = CASES[site]
	if choice != int(job["correct"]):
		return {"status":"incorrect","message":job["wrong"]}
	if not wallet.call("credit_once",job["id"],int(job["reward"])):
		return {"status":"blocked"}
	return {"status":"complete","reward":job["reward"],"message":job["success"]}
