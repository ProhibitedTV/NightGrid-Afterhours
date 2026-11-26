extends RefCounted
const SceneReputation = preload("res://scripts/scene_reputation.gd")

## Read-only presentation model. World actions are dispatched by the existing
## menu/world adapter; no duplicated wallet, delivery, property or save state.

const APPS = [
	{"id":"work","name":"QuotaDrop","mark":"QD","color":"ffbb80"},
	{"id":"wallet","name":"Wallet","mark":"$","color":"81e0d4"},
	{"id":"contacts","name":"Contacts","mark":"@","color":"c5a9ee"},
	{"id":"housing","name":"Housing","mark":"H","color":"e2bba0"},
	{"id":"transit","name":"Transit","mark":"M","color":"8ebce8"},
	{"id":"messages","name":"Messages","mark":"••","color":"b4c9cb"},
	{"id":"opportunities","name":"Workboard","mark":"W","color":"e5ce89"},
	{"id":"music","name":"Music","mark":"♪","color":"e6a8cf"},
	{"id":"cred","name":"Street cred","mark":"★","color":"e9a45e"}
]

const ICONS = {
	"work": preload("res://assets/phone/work.svg"),
	"wallet": preload("res://assets/phone/wallet.svg"),
	"contacts": preload("res://assets/phone/contacts.svg"),
	"housing": preload("res://assets/phone/housing.svg"),
	"transit": preload("res://assets/phone/transit.svg"),
	"messages": preload("res://assets/phone/messages.svg"),
	"opportunities": preload("res://assets/phone/opportunities.svg"),
	"music": preload("res://assets/phone/music.svg"),
	"cred": preload("res://assets/phone/cred.svg")
}

static func app(id: String) -> Dictionary:
	for entry in APPS:
		if entry["id"] == id:
			return entry
	return {}

static func view(id: String, state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	var actions: Array[Dictionary] = []
	var subtitle := ""
	var gig := bool(state.get("gig", false))
	match id:
		"work":
			subtitle = "Independent contractor dashboard" if gig else "Account not activated"
			if gig:
				var duty := bool(state.get("on_duty",true))
				var carrying := bool(state.get("carrying",false))
				rows.append({"label":"Status","value":("Deliver to customer" if carrying else "Collect from restaurant") if duty else "Off duty / no active order"})
				rows.append({"label":"Completed deliveries","value":str(state.get("deliveries",0))})
				if duty:
					rows.append({"label":"Current order","value":str(state.get("order",""))})
					rows.append({"label":"Estimated payout","value":"$%d" % int(state.get("payout",0))})
					actions.append({"label":"Navigate to current order","action":"phone_route_order"})
					if bool(state.get("can_decline_order",false)) and not carrying:
						actions.append({"label":"Decline / next offer","action":"phone_work_decline"})
				if not carrying:
					actions.append({"label":"Go off duty" if duty else "Go on duty","action":"phone_work_off" if duty else "phone_work_on"})
			else:
				rows.append({"label":"QuotaDrop","value":"Available after your Synaxis offboarding."})
		"opportunities":
			subtitle = "Independent work · Morrow Bay"
			var listings: Array = state.get("workboard",[])
			var best_ms:=int(state.get("circuit_best_ms",0))
			var record_text:="Personal best: %.3fs"%(float(best_ms)/1000.0) if best_ms>0 else "No personal record"
			rows.append({"label":"Southworks Circuit","value":"Driving challenge / 8 checkpoints / 90 seconds / ghost pace 34s\n"+("Practice replay / first prize claimed" if bool(state.get("circuit_completed",false)) else "First finish $90")+"\n"+record_text,"action":"phone_route_circuit","action_label":"Navigate to circuit start"})
			var brick_ms:=int(state.get("brickwater_best_ms",0))
			var brick_record:="Personal best: %.3fs"%(float(brick_ms)/1000.0) if brick_ms>0 else "No personal record"
			rows.append({"label":"Brickwater Loop","value":"Driving challenge / 9 checkpoints / 120 seconds / ghost pace 48s\n"+("Practice replay / first prize claimed" if bool(state.get("brickwater_completed",false)) else "First finish $140")+"\n"+brick_record,"action":"phone_route_brickwater","action_label":"Navigate to loop start"})
			if listings.is_empty():
				rows.append({"label":"No contracts remaining","value":"Explore the city or return to QuotaDrop for repeatable income."})
			for listing in listings:
				var status: String = "Turn in" if bool(listing["active"]) else "Ask about contract"
				rows.append({
					"label":"%s · $%d" % [listing["title"],int(listing["reward"])],
					"value":"%s / %s / %s\n%s" % [listing["category"],listing["site"],"Open" if listing["open"] else "Closed",listing["brief"]],
					"action":"phone_route_contract:"+str(listing["id"]),
					"action_label":str(listing.get("action_label",status))+" · navigate"
				})
		"cred":
			subtitle = "Reputation belongs to the streets."
			rows.append({"label":"Citywide reputation","value":str(state.get("global_street_cred","Unknown"))})
			var scores: Dictionary = state.get("scene_scores",{})
			if scores.is_empty():
				rows.append({"label":"Neighborhood scenes","value":str(state.get("scene_reputation",""))})
			else:
				for scene in SceneReputation.SCENES:
					var score := clampi(int(scores.get(scene,0)),0,SceneReputation.MAX_CRED)
					rows.append({"label":SceneReputation.LABELS[scene],"value":"%d / %d · %s" % [score,SceneReputation.MAX_CRED,SceneReputation.rank(score)]})
				rows.append({"label":"Reputation","value":"Earn recognition through performances, local work and investigations."})
			for source in state.get("cred_sources",[]):
				rows.append({"label":str(source["name"]),"value":"+%d earned" % int(source["points"])})
		"music":
			subtitle = "Morrow Bay music scene"
			rows.append({"label":"Instrument","value":str(state.get("instrument_status",""))})
			rows.append({"label":"Contacts","value":str(state.get("music_contact",""))})
			rows.append({"label":"Street sets","value":str(state.get("music_sets",0))})
			rows.append({"label":"Live gigs","value":str(state.get("live_sets",0))})
			var merch := str(state.get("music_merch",""))
			if not merch.is_empty():
				rows.append({"label":"Band merchandise","value":merch})
			actions.append({"label":"Route to Copper Cup music desk","action":"phone_route_music_shop"})
			if bool(state.get("music_recruit_milo",false)):
				actions.append({"label":"Meet Milo Static at Dock Nine","action":"phone_route_music_milo"})
			if bool(state.get("music_showcase",false)):
				actions.append({"label":"Route to Static Room headline showcase","action":"phone_route_music_showcase"})
			if bool(state.get("music_unlocked",false)):
				actions.append({"label":"Route to Blue Hour","action":"phone_route_music_gig"})
			elif bool(state.get("music_contact_available",false)):
				actions.append({"label":"Deliver demo to Blue Hour" if bool(state.get("music_demo_active",false)) else "Route to Static Room","action":"phone_route_music_contact"})
		"wallet":
			subtitle = "Available funds"
			rows.append({"label":"Cash on hand","value":"$%d" % int(state.get("cash",0))})
			rows.append({"label":"Bitcoin holdings","value":"%d sats" % int(state.get("bitcoin_sats",0))})
			rows.append({"label":"Account services","value":"Exchange cash and BTC in person at your capsule." if state.get("home_owned",false) else "Exchange services unlock with your capsule."})
		"contacts":
			subtitle = "Local contacts"
			rows.append({"label":"Mara · Lantern Cup","value":str(state.get("story","Meet Mara at Lantern Cup."))})
			actions.append({"label":"Route to Lantern Cup","action":"phone_route_mara"})
			if bool(state.get("offboarded",false)):
				rows.append({"label":"Synaxis People Operations","value":"Corporate access revoked"})
		"housing":
			subtitle = "Lantern Court"
			rows.append({"label":"Capsule 01","value":"Rented" if state.get("home_owned",false) else "Move-in deposit $%d" % int(state.get("deposit",0))})
			if not bool(state.get("home_owned",false)):
				rows.append({"label":"Deposit progress","value":"$%d / $%d" % [mini(int(state.get("cash",0)),int(state.get("deposit",0))),int(state.get("deposit",0))]})
				rows.append({"label":"Access","value":"Pay at the entrance" if state.get("home_access",false) else "Speak to Mara and complete her contact mission."})
			actions.append({"label":"Route to Lantern Court","action":"phone_route_home"})
		"transit":
			subtitle = "M-Line / City Loop"
			rows.append({"label":"Nearest rail station","value":str(state.get("rail_name","Unavailable"))})
			if bool(state.get("rail_available",false)):
				actions.append({"label":"Route to rail station","action":"phone_route_rail"})
			rows.append({"label":"Nearest bus stop","value":str(state.get("bus_name","Unavailable"))})
			if bool(state.get("bus_available",false)):
				actions.append({"label":"Route to bus stop","action":"phone_route_bus"})
		"messages":
			subtitle = "Inbox · system notices"
			if bool(state.get("offboarded",false)):
				rows.append({"label":"Synaxis · People Operations","value":"Your corporate access has expired. Severance processed."})
			if gig:
				rows.append({"label":"QuotaDrop · Platform notice","value":str(state.get("notice",""))})
			rows.append({"label":"Lantern Court","value":"Your capsule is ready." if state.get("home_owned",false) else "Budget accommodation. Ask Mara about availability."})
	return {"subtitle":subtitle,"rows":rows,"actions":actions}
