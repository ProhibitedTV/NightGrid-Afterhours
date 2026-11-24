extends RefCounted
## Stable consumable IDs; saves contain quantities, never prices or effects.
const ITEMS = {
	"water":{"name":"QUAY WATER","price":3,"health":0.0,"stamina":25.0},
	"soda":{"name":"VOLT COLA","price":5,"health":5.0,"stamina":15.0},
	"energy":{"name":"NIGHTSHIFT ENERGY","price":8,"health":0.0,"stamina":60.0},
	"protein":{"name":"DOCK BAR","price":7,"health":15.0,"stamina":20.0},
	"sandwich":{"name":"METRO SANDWICH","price":12,"health":30.0,"stamina":0.0}
}
const MAX_ITEMS = 12
static func count(inventory: Dictionary) -> int:
	var total := 0
	for id in ITEMS:
		total += int(inventory.get(id,0))
	return total
static func restore(data: Variant) -> Dictionary:
	var result := {}
	if not data is Dictionary:
		return result
	var remaining := MAX_ITEMS
	for id in ITEMS:
		var raw: Variant = data.get(id,0)
		if not (raw is int or raw is float) or not is_finite(float(raw)):
			continue
		var quantity := int(clampf(float(raw),0.0,float(remaining)))
		if quantity > 0:
			result[id] = quantity
			remaining -= quantity
	return result
static func best_item(inventory: Dictionary, health: float, stamina: float) -> String:
	var best := ""
	var score := 0.0
	for id in ITEMS:
		if int(inventory.get(id,0)) < 1:
			continue
		var item: Dictionary = ITEMS[id]
		var useful := minf(100.0-health,item["health"])*1.4+minf(100.0-stamina,item["stamina"])
		if useful > score:
			best = id
			score = useful
	return best
