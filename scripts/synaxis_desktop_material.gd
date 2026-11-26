extends RefCounted
## Original static desktop art: no Viewports, live UI or animation per monitor.
const TEXTURES={
	"desktopblue":preload("res://assets/synaxis/desktop_access.svg"),
	"desktopsignal":preload("res://assets/synaxis/desktop_tickets.svg"),
	"desktopamber":preload("res://assets/synaxis/desktop_validation.svg")
}
static var _materials:Dictionary={}
static func material(key:String) -> StandardMaterial3D:
	if not _materials.has(key):
		var m:=StandardMaterial3D.new()
		m.albedo_texture=TEXTURES[key]
		m.roughness=.48
		m.metallic_specular=.16
		m.emission_enabled=true
		m.emission=Color.WHITE
		m.emission_texture=TEXTURES[key]
		m.emission_energy_multiplier=.22
		_materials[key]=m
	return _materials[key]
