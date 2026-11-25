extends RefCounted
## Recreational music state. All funds still belong to the existing wallet.
const PRICE = 85
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
const StreetCred = preload("res://scripts/street_cred.gd")
const GIG = "dock_nine"
const GIG_RECEIPT = "music:dock_nine_debut"
const SET_SECONDS = 24.0
const GIG_SECONDS = 40.0
const MAX_SETS = 100000
var owned := false
var completed_sets := 0
var elapsed := 0.0
var mode := ""
var cooldown := 0.0
var members: Array[String] = []
var rehearsals := 0
var encores := 0

func buy(wallet: RefCounted) -> bool:
	if owned or not wallet.call("spend",PRICE):
		return false
	owned = true
	return true

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

func can_encore(wallet: RefCounted) -> bool:
	return owned and band_ready() and wallet.call("has_receipt",BAND_RECEIPT) and int(StreetCred.scores(wallet,self)["music"])>=50

func start(kind: String, wallet: RefCounted) -> bool:
	if not owned or not mode.is_empty() or cooldown > 0.0 or kind not in ["busk","gig","rehearse","band","encore"]:
		return false
	if kind == "gig" and not can_gig(wallet):
		return false
	if kind == "rehearse" and not band_ready():
		return false
	if kind == "band" and not can_band_gig(wallet):
		return false
	if kind=="encore" and not can_encore(wallet):
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
	var duration := GIG_SECONDS if mode=="gig" else (BAND_SECONDS if mode in ["band","encore"] else (REHEARSAL_SECONDS if mode=="rehearse" else SET_SECONDS))
	if elapsed < duration:
		return {}
	var kind := mode
	var amount := 95 if kind=="gig" else (BAND_PAY if kind=="band" else (ENCORE_PAY if kind=="encore" else (0 if kind=="rehearse" else 8+mini(completed_sets,8))))
	var paid := false
	if kind=="rehearse":
		rehearsals = mini(rehearsals+1,MAX_SETS)
		paid = true
	elif kind in ["gig","band"]:
		paid = wallet.call("credit_once",GIG_RECEIPT if kind=="gig" else BAND_RECEIPT,amount)
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
	return {"owned":owned,"sets":completed_sets,"members":members.duplicate(),"rehearsals":rehearsals,"encores":encores}

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("owned") is bool:
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
	return (seen.is_empty() or (data["owned"] and n>=3)) and (count==0 or seen.size()==MEMBERS.size())

func restore(data: Variant) -> void:
	stop()
	cooldown = 0.0
	owned = false
	completed_sets = 0
	members.clear()
	rehearsals = 0
	encores = 0
	if valid_snapshot(data):
		owned = data["owned"]
		completed_sets = int(data["sets"])
		members.assign(data.get("members",[]))
		rehearsals = int(data.get("rehearsals",0))
		encores = int(data.get("encores",0))
