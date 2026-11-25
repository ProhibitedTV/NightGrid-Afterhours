extends RefCounted
## Recreational music state. All funds still belong to the existing wallet.
const PRICE = 85
const GEAR_IDS = ["acoustic_guitar","punk_bass","portable_synth"]
const GEAR = {
	"acoustic_guitar":{"name":"Copper Strings used acoustic","price":85,"style":"Warm fingerpicked street folk"},
	"punk_bass":{"name":"Coilback plum bass","price":165,"style":"Low-end post-punk groove"},
	"portable_synth":{"name":"Switchboard portable synth","price":230,"style":"Analog underground electronics"}
}
const SHOP = "copper_cup"
const SPOTS = ["copper_cup","lantern_cup","dock_nine","blue_hour"]
const MEMBERS = {
	"rhea":{"name":"Rhea Vale","role":"Bass","site":"copper_cup","line":"I play low strings and keep time. Heard about your Dock Nine debut."},
	"milo":{"name":"Milo Static","role":"Synth","site":"dock_nine","line":"I have a battered synth and a lot of unfinished ideas. Let’s make something weird."}
}
const BAND_SITE = "blue_hour"
const BAND_RECEIPT = "music:blue_hour_debut"
const REHEARSAL_SECONDS = 24.0
const BAND_SECONDS = 60.0
const BAND_PAY = 240
const ENCORE_PAY = 120
const SHOWCASE_SITE = "static_room"
const SHOWCASE_RECEIPT = "music:static_room_showcase"
const SHOWCASE_PAY = 480
const SHOWCASE_SECONDS = 75.0
const BAND_NAMES = ["Signal Rot","Layoff Choir","Dead Air Union","Rust Cathedral","No Future Lease","Static Saints"]
const StreetCred = preload("res://scripts/street_cred.gd")
const GIG = "dock_nine"
const GIG_RECEIPT = "music:dock_nine_debut"
const SET_SECONDS = 24.0
const GIG_SECONDS = 40.0
const MAX_SETS = 100000
var owned := false
var gear: Array[String] = []
var equipped := ""
var completed_sets := 0
var elapsed := 0.0
var mode := ""
var cooldown := 0.0
var members: Array[String] = []
var rehearsals := 0
var encores := 0
var band_name := ""

func buy(wallet: RefCounted) -> bool:
	return buy_gear("acoustic_guitar",wallet)

func buy_gear(id: String, wallet: RefCounted) -> bool:
	if not mode.is_empty() or not GEAR.has(id) or gear.has(id) or not wallet.call("spend",int(GEAR[id]["price"])):
		return false
	gear.append(id)
	owned = true
	equipped = id
	return true

func equip(id: String) -> bool:
	if not mode.is_empty() or not gear.has(id):
		return false
	equipped = id
	return true

func gear_context() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in GEAR_IDS:
		result.append({"id":id,"name":GEAR[id]["name"],"style":GEAR[id]["style"],"price":GEAR[id]["price"],"owned":gear.has(id),"equipped":equipped==id})
	return result

func can_gig(wallet: RefCounted) -> bool:
	return owned and completed_sets >= 3 and not wallet.call("has_receipt",GIG_RECEIPT)

func recruit(id: String, wallet: RefCounted) -> bool:
	if not owned or not MEMBERS.has(id) or members.has(id) or not wallet.call("has_receipt",GIG_RECEIPT):
		return false
	members.append(id)
	return true

func band_ready() -> bool:
	return members.size() == MEMBERS.size()

func can_band_gig(wallet: RefCounted) -> bool:
	return owned and band_ready() and rehearsals >= 2 and not wallet.call("has_receipt",BAND_RECEIPT)

func display_band_name() -> String:
	return band_name if not band_name.is_empty() else "Unsigned Trio"

func choose_band_name(id: int) -> bool:
	if not band_ready() or not mode.is_empty() or id<0 or id>=BAND_NAMES.size() or not band_name.is_empty():
		return false
	band_name = BAND_NAMES[id]
	return true

func can_showcase(wallet: RefCounted) -> bool:
	return owned and band_ready() and wallet.call("has_receipt",BAND_RECEIPT) and encores>=2 and int(StreetCred.scores(wallet,self)["music"])>=65 and not wallet.call("has_receipt",SHOWCASE_RECEIPT)

func can_encore(wallet: RefCounted) -> bool:
	return owned and band_ready() and wallet.call("has_receipt",BAND_RECEIPT) and int(StreetCred.scores(wallet,self)["music"])>=50

func start(kind: String, wallet: RefCounted) -> bool:
	if not owned or not gear.has(equipped) or not mode.is_empty() or cooldown > 0.0 or kind not in ["busk","gig","rehearse","band","encore","showcase"]:
		return false
	if kind == "gig" and not can_gig(wallet):
		return false
	if kind == "rehearse" and not band_ready():
		return false
	if kind == "band" and not can_band_gig(wallet):
		return false
	if kind=="encore" and not can_encore(wallet):
		return false
	if kind=="showcase" and not can_showcase(wallet):
		return false
	mode = kind
	elapsed = 0.0
	return true

func stop() -> void:
	mode = ""
	elapsed = 0.0

func tick(delta: float, wallet: RefCounted) -> Dictionary:
	if mode.is_empty():
		cooldown = maxf(0.0,cooldown-delta)
		return {}
	elapsed += clampf(delta,0.0,0.25)
	var duration := SHOWCASE_SECONDS if mode=="showcase" else GIG_SECONDS if mode=="gig" else (BAND_SECONDS if mode in ["band","encore"] else (REHEARSAL_SECONDS if mode=="rehearse" else SET_SECONDS))
	if elapsed < duration:
		return {}
	var kind := mode
	var amount := SHOWCASE_PAY if kind=="showcase" else 95 if kind=="gig" else (BAND_PAY if kind=="band" else (ENCORE_PAY if kind=="encore" else (0 if kind=="rehearse" else 8+mini(completed_sets,8))))
	var paid := false
	if kind=="rehearse":
		rehearsals = mini(rehearsals+1,MAX_SETS)
		paid = true
	elif kind in ["gig","band","showcase"]:
		paid = wallet.call("credit_once",SHOWCASE_RECEIPT if kind=="showcase" else (GIG_RECEIPT if kind=="gig" else BAND_RECEIPT),amount)
	else:
		paid = wallet.call("credit",amount)
	if paid and kind=="encore":
		encores = mini(encores+1,MAX_SETS)
	if paid and kind=="busk":
		completed_sets = mini(completed_sets+1,MAX_SETS)
	stop()
	cooldown = 15.0
	return {"paid":paid,"amount":amount if paid else 0,"kind":kind}

func snapshot() -> Dictionary:
	return {"owned":owned,"sets":completed_sets,"members":members.duplicate(),"rehearsals":rehearsals,"encores":encores,"gear":gear.duplicate(),"equipped":equipped,"band_name":band_name}

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("owned") is bool:
		return false
	if data.has("gear") or data.has("equipped"):
		var items: Variant = data.get("gear")
		var selected: Variant = data.get("equipped")
		if not items is Array or not selected is String or items.size()>GEAR_IDS.size() or bool(data["owned"])!=(not items.is_empty()):
			return false
		var unique: Array[String] = []
		for id in items:
			if not id is String or not GEAR.has(id) or unique.has(id):
				return false
			unique.append(id)
		if (items.is_empty() and selected!="") or (not items.is_empty() and not unique.has(selected)):
			return false
	var n: Variant = data.get("sets")
	if not ((n is int or n is float) and is_finite(float(n)) and floor(float(n))==float(n) and n>=0 and n<=MAX_SETS and (data["owned"] or n==0)):
		return false
	var roster: Variant = data.get("members",[])
	var count: Variant = data.get("rehearsals",0)
	if not roster is Array or roster.size()>MEMBERS.size() or not (count is int or count is float) or not is_finite(float(count)) or floor(float(count))!=float(count) or count<0 or count>MAX_SETS:
		return false
	var encore_count: Variant = data.get("encores",0)
	if not (encore_count is int or encore_count is float) or not is_finite(float(encore_count)) or floor(float(encore_count))!=float(encore_count) or encore_count<0 or encore_count>MAX_SETS or (encore_count>0 and count<2):
		return false
	var seen: Array[String] = []
	for id in roster:
		if not id is String or not MEMBERS.has(id) or seen.has(id):
			return false
		seen.append(id)
	var name: Variant = data.get("band_name","")
	if not name is String or (name!="" and (name not in BAND_NAMES or seen.size()!=MEMBERS.size())):
		return false
	return (seen.is_empty() or (data["owned"] and n>=3)) and (count==0 or seen.size()==MEMBERS.size())

func restore(data: Variant) -> void:
	stop()
	cooldown = 0.0
	owned = false
	gear.clear()
	equipped = ""
	completed_sets = 0
	members.clear()
	rehearsals = 0
	encores = 0
	band_name = ""
	if valid_snapshot(data):
		owned = data["owned"]
		if data.has("gear"):
			gear.assign(data["gear"])
			equipped = str(data["equipped"])
		elif owned:
			gear.append("acoustic_guitar")
			equipped = "acoustic_guitar"
		completed_sets = int(data["sets"])
		members.assign(data.get("members",[]))
		rehearsals = int(data.get("rehearsals",0))
		encores = int(data.get("encores",0))
		band_name = str(data.get("band_name",""))
