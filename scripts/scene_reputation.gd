extends RefCounted
## Scene reputation is a read-only projection of successful gameplay, not cash,
## purchases, elapsed time or a second mutable XP ledger.
const MAX_CRED = 100
const SCENES = ["music","community","underground"]
const LABELS = {"music":"Music scene","community":"Community","underground":"Underground"}
const COMMUNITY_RECEIPTS = ["civic:cold_chain","civic:lifeline","civic:after_sparks","civic:grid_audit","technical:crane_interlock","technical:grid_telemetry","venue:midnight_thermos","venue:last_shift_recipe"]
const UNDERGROUND_RECEIPTS = ["venue:dead_frequency","venue:glass_invoice","investigation:paper_city"]

static func scores(wallet: RefCounted, career: RefCounted) -> Dictionary:
	var music := 3*mini(int(career.get("completed_sets")),MAX_CRED)+4*mini(int(career.get("encores")),MAX_CRED)
	if wallet.call("has_receipt","music:dock_nine_debut"):
		music += 16
	if wallet.call("has_receipt","music:blue_hour_debut"):
		music += 30
	if wallet.call("has_receipt","music:static_room_showcase"):
		music += 20
	var community := 0
	for id in COMMUNITY_RECEIPTS:
		if wallet.call("has_receipt",id):
			community += 12
	var underground := 0
	for id in UNDERGROUND_RECEIPTS:
		if wallet.call("has_receipt",id):
			underground += 40 if id=="investigation:paper_city" else 20
	return {"music":mini(music,MAX_CRED),"community":mini(community,MAX_CRED),"underground":mini(underground,MAX_CRED)}

static func rank(score: int) -> String:
	if score>=85:
		return "Scene icon"
	if score>=50:
		return "Respected"
	if score>=20:
		return "Recognized"
	if score>0:
		return "New face"
	return "Unknown"

static func summary(scores_now: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in SCENES:
		parts.append("%s %d / %s" % [LABELS[id],scores_now.get(id,0),rank(int(scores_now.get(id,0)))])
	return "  •  ".join(parts)

static func community_price(price: int, scores_now: Dictionary) -> int:
	return maxi(0,price-floori(price*.10)) if int(scores_now.get("community",0))>=20 else price
