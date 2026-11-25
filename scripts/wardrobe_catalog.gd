extends RefCounted
## Original NightGrid colorways over the existing weighted garment materials.
## No new body, geometry, skeleton, texture or collision assets.
const Economy = preload("res://scripts/economy.gd")
const DEFAULT = "dispatch"
const IDS = ["dispatch","tideline","rustline","quay_basic","vesper_tailored","nocturne_atelier","obscura_signature","threadline_basics","night_shift","quay_dock","vesper_ink","nocturne_veil","obscura_sable"]
const ITEMS = {
	"dispatch":{"name":"Morrow Dispatch","rarity":"COMMON","tier":0,"price":45,"jacket":Color.WHITE,"pants":Color.WHITE,"finish":1.0},
	"tideline":{"name":"Tideline","rarity":"COMMON","tier":0,"price":35,"jacket":Color(.55,.88,1.0),"pants":Color(.65,.83,.95),"finish":1.0},
	"rustline":{"name":"Rustline","rarity":"COMMON","tier":0,"price":45,"jacket":Color(1.0,.72,.48),"pants":Color(.92,.80,.65),"finish":1.0},
	"quay_basic":{"name":"Quay Standard / Streetwear","rarity":"UNCOMMON","tier":1,"price":75,"jacket":Color(.90,.72,1.0),"pants":Color(.75,.74,.90),"finish":.94},
	"vesper_tailored":{"name":"Vesper Line / Tailored","rarity":"RARE","tier":2,"price":300,"jacket":Color(.74,1.0,.80),"pants":Color(.52,.60,.55),"finish":.82},
	"nocturne_atelier":{"name":"Nocturne Atelier / Midnight","rarity":"LUXURY","tier":3,"price":950,"jacket":Color(.46,.48,.76),"pants":Color(.40,.42,.55),"finish":.70},
	"obscura_signature":{"name":"Obscura / Signature Edition","rarity":"EXCLUSIVE","tier":4,"price":2400,"jacket":Color(1.0,.59,.82),"pants":Color(.48,.38,.46),"finish":.62},
	"threadline_basics":{"name":"Threadline / Everyday","rarity":"COMMON","tier":0,"price":20,"jacket":Color(.78,.81,.76),"pants":Color(.80,.81,.78),"finish":1.0},
	"night_shift":{"name":"Threadline / Night Shift","rarity":"UNCOMMON","tier":1,"price":65,"jacket":Color(.62,.73,.86),"pants":Color(.48,.53,.64),"finish":.90},
	"quay_dock":{"name":"Quay Standard / Dock Canvas","rarity":"UNCOMMON","tier":1,"price":85,"jacket":Color(.75,.88,.65),"pants":Color(.58,.68,.55),"finish":1.0},
	"vesper_ink":{"name":"Vesper Line / Ink","rarity":"RARE","tier":2,"price":360,"jacket":Color(.50,.59,.83),"pants":Color(.45,.48,.66),"finish":.84},
	"nocturne_veil":{"name":"Nocturne / Violet Veil","rarity":"LUXURY","tier":3,"price":620,"jacket":Color(.82,.49,.94),"pants":Color(.43,.35,.56),"finish":.70},
	"obscura_sable":{"name":"Obscura / Sable Collection","rarity":"EXCLUSIVE","tier":4,"price":1800,"jacket":Color(.44,.43,.46),"pants":Color(.48,.44,.41),"finish":.62}
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
const PIECE_IDS=["jacket_ash","jacket_oxide","jacket_midnight","pants_charcoal","pants_sand","pants_teal","glasses_night","glasses_clear","watch_shift","watch_brass","jacket_ink"]
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
	"watch_brass":{"name":"Nocturne brass watch","slot":"watch","price":110},
	"jacket_ink":{"name":"Vesper ink jacket","slot":"jacket","price":175,"tint":Color(.48,.60,.82),"finish":.8}
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

const CATEGORIES=["ALL","OUTFITS","JACKETS","TROUSERS","GLASSES","WATCHES"]
static func category_ids(category:String) -> Array:
	if category=="ALL":
		return browse_ids()
	if category=="OUTFITS":
		return IDS.duplicate()
	var slot:String={"JACKETS":"jacket","TROUSERS":"pants","GLASSES":"glasses","WATCHES":"watch"}.get(category,"")
	var result:Array=[]
	if slot.is_empty():
		return result
	for id in PIECE_IDS:
		if PIECES[id]["slot"]==slot:
			result.append(id)
	result.append("reset_"+slot)
	return result
