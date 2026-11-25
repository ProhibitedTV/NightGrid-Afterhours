extends RefCounted
## Original NightGrid colorways over the existing weighted garment materials.
## No new body, geometry, skeleton, texture or collision assets.
const DEFAULT = "dispatch"
const IDS = ["dispatch","tideline","rustline"]
const ITEMS = {
	"dispatch":{"name":"Morrow Dispatch","jacket":Color.WHITE,"pants":Color.WHITE},
	"tideline":{"name":"Tideline","jacket":Color(.55,.88,1.0),"pants":Color(.65,.83,.95)},
	"rustline":{"name":"Rustline","jacket":Color(1.0,.72,.48),"pants":Color(.92,.80,.65)}
}

static func valid_id(value: Variant) -> bool:
	return value is String and ITEMS.has(value)

static func garment_slot(name: String) -> String:
	var normalized := name.to_lower()
	if normalized.contains("jacket"):
		return "jacket"
	if normalized.contains("cargo") or normalized.contains("pants"):
		return "pants"
	return ""
