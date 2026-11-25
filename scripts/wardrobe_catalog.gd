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
