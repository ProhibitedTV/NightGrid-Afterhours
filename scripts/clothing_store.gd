extends RefCounted
## Fixed public retail parcels, stable across world seeds.
const ID="vesper_threadline"
const NAME="THREADLINE"
const BLOCK=Vector2i(-3,-2)
const LOT=1
const COUNTER=Vector3(-2.25,1.15,2.8)
const Plan=preload("res://scripts/world_plan.gd")
const Wardrobe=preload("res://scripts/wardrobe_catalog.gd")
const THRIFT="second_signal"
const IDS=["vesper_threadline","quay_standard","vesper_line","nocturne","obscura",THRIFT]
const STORES={
	"vesper_threadline":{"name":"THREADLINE","district":"VESPER MARKET","block":Vector2i(-3,-2),"lot":1,"style":"STREETWEAR","stock":["dispatch","tideline","rustline","threadline_basics","night_shift","jacket_ash","jacket_oxide","pants_charcoal","pants_sand","glasses_night","glasses_clear","watch_shift","threadline_concrete","threadline_copper","threadline_rain","jacket_concrete","pants_olive","jacket_copper","glasses_metro","watch_commute"]},
	"quay_standard":{"name":"QUAY STANDARD","district":"NORTH QUAY","block":Vector2i(0,-4),"lot":0,"style":"WORKWEAR","stock":["dispatch","quay_basic","quay_dock","rustline","jacket_ash","pants_sand","pants_teal","watch_shift","glasses_clear","quay_breakwater","quay_forge","quay_silt","jacket_breakwater","pants_forge","jacket_silt","glasses_harbor","watch_tide"]},
	"vesper_line":{"name":"VESPER LINE","district":"VESPER MARKET","block":Vector2i(-1,-2),"lot":1,"style":"TAILORING","stock":["dispatch","vesper_tailored","vesper_ink","jacket_ink","pants_charcoal","pants_teal","glasses_clear","watch_brass","vesper_meridian","vesper_oxblood","vesper_pearl","jacket_meridian","pants_pearl","jacket_oxblood","glasses_meridian","watch_ink"]},
	"nocturne":{"name":"NOCTURNE","district":"AFTERHOURS","block":Vector2i(0,2),"lot":0,"style":"NIGHTLIFE","stock":["dispatch","nocturne_atelier","nocturne_veil","jacket_midnight","pants_charcoal","glasses_night","watch_brass","nocturne_afterimage","nocturne_eclipse","nocturne_ember","jacket_afterimage","pants_eclipse","jacket_ember","glasses_afterimage","watch_pulse"]},
	"obscura":{"name":"OBSCURA","district":"GLASSLINE","block":Vector2i(1,-3),"lot":0,"style":"DESIGNER","stock":["dispatch","obscura_signature","obscura_sable","jacket_midnight","pants_charcoal","glasses_clear","watch_brass","obscura_archivist","obscura_porcelain","obscura_monolith","jacket_archivist","pants_porcelain","jacket_monolith","glasses_porcelain","watch_monolith"]},
	"second_signal":{"name":"SECOND SIGNAL","district":"BRICKWATER","block":Vector2i(-3,1),"lot":1,"style":"THRIFT / DIY","stock":["dispatch","signal_reclaimed","jacket_ash","pants_charcoal","signal_rivet","signal_static","signal_union","jacket_patch","jacket_signal","pants_salvage","pants_indigo","patch_deadcarrier","patch_voltage","patch_ghostshift","patch_nightgrid","signal_overprint","signal_scrapyard","signal_deadstock","jacket_overprint","pants_scrapyard","jacket_deadstock","glasses_deadstock","watch_salvage"]}
}
const EXCLUSIVE=["quay_dock","vesper_ink","nocturne_veil","obscura_sable","jacket_ink","signal_reclaimed","signal_rivet","signal_static","signal_union","jacket_patch","jacket_signal","pants_salvage","pants_indigo","patch_deadcarrier","patch_voltage","patch_ghostshift","patch_nightgrid","threadline_concrete","threadline_copper","threadline_rain","jacket_concrete","pants_olive","jacket_copper","quay_breakwater","quay_forge","quay_silt","jacket_breakwater","pants_forge","jacket_silt","vesper_meridian","vesper_oxblood","vesper_pearl","jacket_meridian","pants_pearl","jacket_oxblood","nocturne_afterimage","nocturne_eclipse","nocturne_ember","jacket_afterimage","pants_eclipse","jacket_ember","obscura_archivist","obscura_porcelain","obscura_monolith","jacket_archivist","pants_porcelain","jacket_monolith","signal_overprint","signal_scrapyard","signal_deadstock","jacket_overprint","pants_scrapyard","jacket_deadstock","glasses_metro","watch_commute","glasses_harbor","watch_tide","glasses_meridian","watch_ink","glasses_afterimage","watch_pulse","glasses_porcelain","watch_monolith","glasses_deadstock","watch_salvage"]
const THRIFT_ROTATIONS=[["signal_rivet","jacket_patch","pants_salvage","signal_overprint","jacket_overprint"],["signal_static","jacket_signal","pants_indigo","signal_scrapyard","pants_scrapyard"],["signal_union","jacket_patch","pants_indigo","signal_deadstock","jacket_deadstock"]]
const THRIFT_STAPLES=["dispatch","signal_reclaimed","jacket_ash","pants_charcoal","patch_deadcarrier","patch_voltage","patch_ghostshift","patch_nightgrid","glasses_deadstock","watch_salvage"]

static func for_lot(block:Vector2i,lot:int) -> String:
	for id in IDS:
		if STORES[id]["block"]==block and STORES[id]["lot"]==lot:
			return id
	return ""

static func entry(id:String=ID) -> Vector3:
	var store:Dictionary=STORES.get(id,{})
	if store.is_empty():
		return Vector3.INF
	var block:Vector2i=store["block"]
	return Vector3((block.x+.5)*58.0+(-10.5 if store["lot"]==0 else 10.5),1.15,(block.y+.5)*58.0-Plan.PUBLIC_FACADE_SETBACK-1.5)

static func carries(id:String,item:String) -> bool:
	return STORES.has(id) and (item in STORES[id]["stock"] or item in Wardrobe.RESET_IDS)

static func stock_for_day(id:String,day:int) -> Array:
	if id==THRIFT:
		return THRIFT_STAPLES+THRIFT_ROTATIONS[posmod(day,THRIFT_ROTATIONS.size())]
	return (STORES.get(id,{}).get("stock",[]) as Array).duplicate()

static func directory() -> String:
	var lines:PackedStringArray=[]
	for id in IDS:
		var site:Dictionary=STORES[id]
		lines.append("%s / %s" % [site["name"],site["district"]])
	return "\n".join(lines)

const THEMES={
  "vesper_threadline": {
    "clerk": "Tess Vale",
    "hair": "bun",
    "palette": 3,
    "base": "252c33",
    "wood": "8e7660",
    "trim": "b9a277",
    "light": "f4d9b0",
    "tag": "EVERYDAY. EVERYWHERE.",
    "music": "retail",
    "coat": "4d4641",
    "greet": "Try anything on. The mirror does not charge rent.",
    "receipt": "Good choice. See you out there.",
    "feature": "PATCH WALL / INDEPENDENT SINCE 2028",
    "featured": "threadline_basics"
  },
  "quay_standard": {
    "clerk": "Ren Ives",
    "hair": "cropped",
    "palette": 1,
    "base": "324b49",
    "wood": "80735e",
    "trim": "719e92",
    "light": "c6e0d8",
    "tag": "BUILT FOR THE SHIFT.",
    "music": "retail_quay",
    "coat": "435b55",
    "greet": "Good gear lasts longer than a shift. What are you working in?",
    "receipt": "That should survive the docks. Wear it well.",
    "feature": "SHIFT TESTED / REPAIR. REUSE. REPEAT.",
    "featured": "quay_dock"
  },
  "vesper_line": {
    "clerk": "Mina Chen",
    "hair": "parted",
    "palette": 2,
    "base": "403d46",
    "wood": "95857b",
    "trim": "c0b4cc",
    "light": "ede0d3",
    "tag": "AFTER THE ORDINARY.",
    "music": "retail_vesper",
    "coat": "646075",
    "greet": "A clean line changes how you carry yourself. Take your time.",
    "receipt": "The fit is yours. No corporate dress code required.",
    "feature": "FABRIC LIBRARY / INK COLLECTION",
    "featured": "vesper_ink"
  },
  "nocturne": {
    "clerk": "Jules Venn",
    "hair": "dark",
    "palette": 4,
    "base": "211c2b",
    "wood": "514357",
    "trim": "a89acb",
    "light": "d9b8eb",
    "tag": "DRESSED FOR THE DARK.",
    "music": "retail_nocturne",
    "coat": "392d4a",
    "greet": "The city looks different after midnight. So should you.",
    "receipt": "See how that catches the club lights tonight.",
    "feature": "VIOLET VEIL / AFTER MIDNIGHT",
    "featured": "nocturne_veil"
  },
  "obscura": {
    "clerk": "Dorian Kade",
    "hair": "silver",
    "palette": 0,
    "base": "24282d",
    "wood": "b4a18b",
    "trim": "d4bd83",
    "light": "f4e5ca",
    "tag": "BEYOND ACCESS.",
    "music": "retail_obscura",
    "coat": "30363b",
    "greet": "Welcome to Obscura. Every piece has a point of view.",
    "receipt": "An excellent selection. It is exclusively yours to wear.",
    "feature": "SABLE / PRIVATE COLLECTION",
    "featured": "obscura_sable"
  },
  "second_signal": {
  "clerk": "Rook Serrano",
  "hair": "cropped",
  "palette": 4,
  "base": "343b32",
  "wood": "665548",
  "trim": "d9bd58",
  "light": "d8dbb5",
  "tag": "REPAIR THE FUTURE.",
  "music": "retail_thrift",
  "coat": "4a4b35",
  "greet": "Someone else paid full price. You get to make it yours.",
  "receipt": "Another good piece saved from the landfill.",
  "feature": "NO REFUNDS TO THE MEGACORP / FIX IT YOURSELF",
  "featured": "signal_reclaimed"
}
}
