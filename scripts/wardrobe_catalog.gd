extends RefCounted
## Original NightGrid colorways over the existing weighted garment materials.
## No new body, geometry, skeleton, texture or collision assets.
const Economy = preload("res://scripts/economy.gd")
const DEFAULT = "dispatch"
const IDS = ["dispatch","tideline","rustline","quay_basic","vesper_tailored","nocturne_atelier","obscura_signature","threadline_basics","night_shift"]
const ITEMS = {
	"dispatch":{"name":"Morrow Dispatch","rarity":"COMMON","tier":0,"price":45,"jacket":Color.WHITE,"pants":Color.WHITE,"finish":1.0},
	"tideline":{"name":"Tideline","rarity":"COMMON","tier":0,"price":35,"jacket":Color(.55,.88,1.0),"pants":Color(.65,.83,.95),"finish":1.0},
	"rustline":{"name":"Rustline","rarity":"COMMON","tier":0,"price":45,"jacket":Color(1.0,.72,.48),"pants":Color(.92,.80,.65),"finish":1.0},
	"quay_basic":{"name":"Quay Standard / Streetwear","rarity":"UNCOMMON","tier":1,"price":75,"jacket":Color(.90,.72,1.0),"pants":Color(.75,.74,.90),"finish":.94},
	"vesper_tailored":{"name":"Vesper Line / Tailored","rarity":"RARE","tier":2,"price":300,"jacket":Color(.74,1.0,.80),"pants":Color(.52,.60,.55),"finish":.82},
	"nocturne_atelier":{"name":"Nocturne Atelier / Midnight","rarity":"LUXURY","tier":3,"price":950,"jacket":Color(.46,.48,.76),"pants":Color(.40,.42,.55),"finish":.70},
	"obscura_signature":{"name":"Obscura / Signature Edition","rarity":"EXCLUSIVE","tier":4,"price":2400,"jacket":Color(1.0,.59,.82),"pants":Color(.48,.38,.46),"finish":.62},
	"threadline_basics":{"name":"Threadline / Everyday","rarity":"COMMON","tier":0,"price":20,"jacket":Color(.78,.81,.76),"pants":Color(.80,.81,.78),"finish":1.0},
	"night_shift":{"name":"Threadline / Night Shift","rarity":"UNCOMMON","tier":1,"price":65,"jacket":Color(.62,.73,.86),"pants":Color(.48,.53,.64),"finish":.90}
}

# Catalog values are estimated 2026 USD anchors, not final shelf prices.
static func price(id: String) -> int:
	return Economy.price_2036(int(ITEMS[id]["price"])) if valid_id(id) else 0

static func valid_id(value: Variant) -> bool:
	return value is String and ITEMS.has(value)

static func garment_slot(name: String) -> String:
	var normalized := name.to_lower()
	if normalized.contains("jacket"):
		return "jacket"
	if normalized.contains("cargo") or normalized.contains("pants"):
		return "pants"
	return ""

# Individual material-compatible pieces. Future mesh pieces use the same
# stable slot/item identities, with a separate validated visual asset contract.
const SLOTS=["jacket","pants","glasses","watch"]
const RESET_IDS=["reset_jacket","reset_pants","reset_glasses","reset_watch"]
const PIECE_IDS=["jacket_ash","jacket_oxide","jacket_midnight","pants_charcoal","pants_sand","pants_teal","glasses_night","glasses_clear","watch_shift","watch_brass"]
const PIECES={
	"jacket_ash":{"name":"Ash work jacket","slot":"jacket","price":18,"tint":Color(.73,.77,.79),"finish":1.0},
	"jacket_oxide":{"name":"Oxide street jacket","slot":"jacket","price":32,"tint":Color(1.0,.53,.38),"finish":.9},
	"jacket_midnight":{"name":"Midnight jacket","slot":"jacket","price":65,"tint":Color(.43,.48,.68),"finish":.82},
	"pants_charcoal":{"name":"Charcoal cargo trousers","slot":"pants","price":15,"tint":Color(.42,.45,.49),"finish":1.0},
	"pants_sand":{"name":"Sand cargo trousers","slot":"pants","price":24,"tint":Color(1.0,.89,.72),"finish":1.0},
	"pants_teal":{"name":"Deep teal cargo trousers","slot":"pants","price":35,"tint":Color(.52,.87,.79),"finish":.92},
	"glasses_night":{"name":"Nightline smoke shades","slot":"glasses","price":26},
	"glasses_clear":{"name":"Threadline clear frames","slot":"glasses","price":19},
	"watch_shift":{"name":"Quay Shift digital watch","slot":"watch","price":38},
	"watch_brass":{"name":"Nocturne brass watch","slot":"watch","price":110}
}

static func piece_valid(id:Variant) -> bool:
	return id is String and PIECES.has(id)

static func piece_price(id:String) -> int:
	return Economy.price_2036(int(PIECES[id]["price"])) if piece_valid(id) else 0

static func valid_slots(value:Variant) -> bool:
	if not value is Dictionary or value.size()>SLOTS.size():
		return false
	for slot in value:
		if slot not in SLOTS or not piece_valid(value[slot]) or PIECES[value[slot]]["slot"]!=slot:
			return false
	return true

static func browse_ids() -> Array:
	return IDS+PIECE_IDS+RESET_IDS

static func reset_slot(id:String) -> String:
	return id.trim_prefix("reset_") if id in RESET_IDS else ""

static func listing(id:String) -> Dictionary:
	if valid_id(id):
		return {"name":ITEMS[id]["name"],"rarity":ITEMS[id]["rarity"],"price":price(id),"type":"OUTFIT"}
	if piece_valid(id):
		return {"name":PIECES[id]["name"],"rarity":"INDIVIDUAL","price":piece_price(id),"type":str(PIECES[id]["slot"]).to_upper()}
	var slot:=reset_slot(id)
	if not slot.is_empty():
		return {"name":"Restore base "+slot if slot in ["jacket","pants"] else "Remove "+slot,"rarity":"NO CHARGE","price":0,"type":"RESET"}
	return {}
