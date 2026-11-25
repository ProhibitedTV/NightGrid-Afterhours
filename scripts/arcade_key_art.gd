extends RefCounted
## Shared catalog: optional illustrated WebP masters, existing vector art fallback.
## Static textures only; no live viewports or remote resource dependencies.
const Catalog = preload("res://scripts/arcade_round.gd")
const ART := {
	"grand_delay": preload("res://assets/arcade/grand_delay.svg"),
	"claw_compliance": preload("res://assets/arcade/claw_compliance.svg"),
	"patch_day": preload("res://assets/arcade/patch_day.svg"),
	"indie_dev": preload("res://assets/arcade/indie_dev.svg"),
	"annual_warfare": preload("res://assets/arcade/annual_warfare.svg"),
	"day_one_dlc": preload("res://assets/arcade/day_one_dlc.svg"),
	"open_world_checklist": preload("res://assets/arcade/open_world_checklist.svg"),
	"battle_pass_hero": preload("res://assets/arcade/battle_pass_hero.svg"),
	"starline_patrol": preload("res://assets/arcade/starline_patrol.svg"),
	"neon_rebound": preload("res://assets/arcade/neon_rebound.svg")
}
const ROOT := "res://assets/arcade/key_art/"
static var _cache: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not ART.has(id):
		return null
	if not _cache.has(id):
		var path := ROOT + id + ".webp"
		var asset: Texture2D = null
		if ResourceLoader.exists(path, "Texture2D"):
			asset = ResourceLoader.load(path, "Texture2D") as Texture2D
		_cache[id] = asset if asset != null else ART[id]
	return _cache[id]

static func illustrated_count() -> int:
	var count := 0
	for id in Catalog.IDS:
		if ResourceLoader.exists(ROOT+id+".webp", "Texture2D"):
			count += 1
	return count

static func fit(id: String, bounds: Vector2) -> Vector2:
	var art := texture(id)
	if art == null or art.get_height() <= 0 or art.get_width() <= 0:
		return bounds
	var dims := art.get_size()
	return dims * minf(bounds.x/dims.x,bounds.y/dims.y)
