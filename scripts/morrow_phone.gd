extends RefCounted
## Read-only presentation model. World actions are dispatched by the existing
## menu/world adapter; no duplicated wallet, delivery, property or save state.
const APPS = [
	{"id":"work","name":"QuotaDrop","mark":"QD","color":"ffbb80"},
	{"id":"wallet","name":"Wallet","mark":"$","color":"81e0d4"},
	{"id":"contacts","name":"Contacts","mark":"@","color":"c5a9ee"},
	{"id":"housing","name":"Housing","mark":"H","color":"e2bba0"},
	{"id":"transit","name":"Transit","mark":"M","color":"8ebce8"},
	{"id":"messages","name":"Messages","mark":"••","color":"b4c9cb"},
	{"id":"opportunities","name":"Workboard","mark":"W","color":"e5ce89"}
]

const ICONS = {
	"work": preload("res://assets/phone/work.svg"),
	"wallet": preload("res://assets/phone/wallet.svg"),
	"contacts": preload("res://assets/phone/contacts.svg"),
	"housing": preload("res://assets/phone/housing.svg"),
	"transit": preload("res://assets/phone/transit.svg"),
	"messages": preload("res://assets/phone/messages.svg"),
	"opportunities": preload("res://assets/phone/opportunities.svg")
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
			if gig and not bool(state.get("on_duty",true)):
				rows.append({"label":"Status","value":"Offline · No active delivery"})
				actions.append({"label":"Go online","action":"phone_toggle_duty"})
			elif gig:
				rows.append({"label":"Current order","value":str(state.get("order",""))})
				rows.append({"label":"Status","value":"Deliver to customer" if state.get("carrying",false) else "Collect from restaurant"})
				rows.append({"label":"Estimated payout","value":"$%d" % int(state.get("payout",0))})
				rows.append({"label":"Completed deliveries","value":str(state.get("deliveries",0))})
				actions.append({"label":"Navigate to current order" if state.get("carrying",false) else "Take offer / navigate","action":"phone_route_order"})
				if not bool(state.get("carrying",false)):
					actions.append({"label":"Decline / see another offer","action":"phone_decline_offer"})
					actions.append({"label":"Go offline","action":"phone_toggle_duty"})
			else:
				rows.append({"label":"QuotaDrop","value":"Available after your Synaxis offboarding."})
		"opportunities":
			subtitle = "Independent work · Morrow Bay"
			var listings: Array = state.get("workboard",[])
			if listings.is_empty():
				rows.append({"label":"No contracts remaining","value":"Explore the city or return to QuotaDrop for repeatable income."})
			for listing in listings:
				var status := "Turn in" if listing["active"] else "Ask about contract"
				rows.append({
					"label":"%s · $%d" % [listing["title"],int(listing["reward"])],
					"value":"%s / %s / %s\n%s" % [listing["category"],listing["site"],"Open" if listing["open"] else "Closed",listing["brief"]],
					"action":"phone_route_contract:"+str(listing["id"]),
					"action_label":str(listing.get("action_label",status))+" · navigate"
				})
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
