extends RefCounted
## Recreational music state. All funds still belong to the existing wallet.
const PRICE = 85
const SHOP = "copper_cup"
const SPOTS = ["copper_cup","lantern_cup","dock_nine"]
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

func buy(wallet: RefCounted) -> bool:
	if owned or not wallet.call("spend",PRICE):
		return false
	owned = true
	return true

func can_gig(wallet: RefCounted) -> bool:
	return owned and completed_sets >= 3 and not wallet.call("has_receipt",GIG_RECEIPT)

func start(kind: String, wallet: RefCounted) -> bool:
	if not owned or not mode.is_empty() or cooldown > 0.0 or kind not in ["busk","gig"]:
		return false
	if kind == "gig" and not can_gig(wallet):
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
	if elapsed < (GIG_SECONDS if mode=="gig" else SET_SECONDS):
		return {}
	var kind := mode
	var amount := 95 if kind=="gig" else 8+mini(completed_sets,8)
	var paid: bool = wallet.call("credit_once",GIG_RECEIPT,amount) if kind=="gig" else wallet.call("credit",amount)
	if paid and kind=="busk":
		completed_sets = mini(completed_sets+1,MAX_SETS)
	stop()
	cooldown = 15.0
	return {"paid":paid,"amount":amount if paid else 0,"kind":kind}

func snapshot() -> Dictionary:
	return {"owned":owned,"sets":completed_sets}

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("owned") is bool:
		return false
	var n: Variant = data.get("sets")
	return (n is int or n is float) and is_finite(float(n)) and floor(float(n))==float(n) and n>=0 and n<=MAX_SETS and (data["owned"] or n==0)

func restore(data: Variant) -> void:
	stop()
	cooldown = 0.0
	owned = false
	completed_sets = 0
	if valid_snapshot(data):
		owned = data["owned"]
		completed_sets = int(data["sets"])
