extends RefCounted
## Initial instrument catalog: original names, fixed pricing. New instrument
## families require distinct audio and gameplay before they become purchasable.
const STARTER="pocketbeat_m3"
const ITEMS={"pocketbeat_m3":{"name":"PocketBeat M3","price":40,"family":"sampler","description":"Refurbished three-pad battery sampler; Copper Cup consignment desk."}}
const MAX_PRACTICE=1000
const OWNED_SET_PRACTICE=3
const SKILL_NAMES=["Beginner","Steady Hands","Pocket Player","Session Ready"]
const SKILL_THRESHOLDS=[0,3,10,25]
static func valid_id(id:Variant)->bool:
	return id is String and ITEMS.has(id)
static func price(id:String)->int:
	return int(ITEMS[id]["price"]) if valid_id(id) else 0
static func skill(practice:int)->Dictionary:
	var level:=0
	for i in range(SKILL_THRESHOLDS.size()):
		if practice>=SKILL_THRESHOLDS[i]:
			level=i
	return {"name":SKILL_NAMES[level],"level":level,"next":SKILL_THRESHOLDS[level+1] if level+1<SKILL_THRESHOLDS.size() else 0}
