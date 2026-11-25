extends RefCounted
## Fixed public retail parcels, stable across world seeds.
const ID="vesper_threadline"
const NAME="THREADLINE"
const BLOCK=Vector2i(-3,-2)
const LOT=1
const COUNTER=Vector3(-2.25,1.15,2.8)
const Plan=preload("res://scripts/world_plan.gd")
const Wardrobe=preload("res://scripts/wardrobe_catalog.gd")
const IDS=["vesper_threadline","quay_standard","vesper_line","nocturne","obscura"]
const STORES={
	"vesper_threadline":{"name":"THREADLINE","district":"VESPER MARKET","block":Vector2i(-3,-2),"lot":1,"style":"STREETWEAR","stock":["dispatch","tideline","rustline","threadline_basics","night_shift","jacket_ash","jacket_oxide","pants_charcoal","pants_sand","glasses_night","glasses_clear","watch_shift"]},
	"quay_standard":{"name":"QUAY STANDARD","district":"NORTH QUAY","block":Vector2i(0,-4),"lot":0,"style":"WORKWEAR","stock":["dispatch","quay_basic","quay_dock","rustline","jacket_ash","pants_sand","pants_teal","watch_shift","glasses_clear"]},
	"vesper_line":{"name":"VESPER LINE","district":"VESPER MARKET","block":Vector2i(-1,-2),"lot":1,"style":"TAILORING","stock":["dispatch","vesper_tailored","vesper_ink","jacket_ink","pants_charcoal","pants_teal","glasses_clear","watch_brass"]},
	"nocturne":{"name":"NOCTURNE","district":"AFTERHOURS","block":Vector2i(0,2),"lot":0,"style":"NIGHTLIFE","stock":["dispatch","nocturne_atelier","nocturne_veil","jacket_midnight","pants_charcoal","glasses_night","watch_brass"]},
	"obscura":{"name":"OBSCURA","district":"GLASSLINE","block":Vector2i(1,-3),"lot":0,"style":"DESIGNER","stock":["dispatch","obscura_signature","obscura_sable","jacket_midnight","pants_charcoal","glasses_clear","watch_brass"]}
}
const EXCLUSIVE=["quay_dock","vesper_ink","nocturne_veil","obscura_sable","jacket_ink"]

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

static func directory() -> String:
	var lines:PackedStringArray=[]
	for id in IDS:
		var site:Dictionary=STORES[id]
		lines.append("%s / %s" % [site["name"],site["district"]])
	return "\n".join(lines)
