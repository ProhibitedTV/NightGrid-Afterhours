extends Node3D
## Authored static breakroom art within the existing Synaxis ground floor.
const ROOM = preload("res://assets/models/nightgrid/synaxis_breakroom/breakroom.glb")
const SCANS = "res://assets/pbr/synaxis_breakroom/"
const METAL = "res://assets/models/nightgrid/central_exchange_storefront/textures/"
const AGGREGATE = "res://assets/models/nightgrid/central_exchange_curb/textures/"
const PHOTO_MAPS = {
	"Terrazzo": [SCANS + "terrazzo_tiles_diff_1k.jpg", SCANS + "terrazzo_tiles_nor_gl_1k.jpg", SCANS + "terrazzo_tiles_arm_1k.jpg", Color("dedcda"), 0.0, 0.75],
	"Walnut": [SCANS + "black_walnut_veneer_02_diff_1k.jpg", SCANS + "black_walnut_veneer_02_nor_gl_1k.jpg", SCANS + "black_walnut_veneer_02_arm_1k.jpg", Color.WHITE, 0.0, 0.66],
	"Tile": [SCANS + "long_white_tiles_diff_1k.jpg", SCANS + "long_white_tiles_nor_gl_1k.jpg", SCANS + "long_white_tiles_arm_1k.jpg", Color("ebeddf"), 0.0, 0.56],
	"Steel": [METAL + "steel_base_1k.jpg", METAL + "steel_normal_1k.jpg", METAL + "steel_arm_1k.png", Color("dddfe0"), 0.82, 0.38],
	"Counter": [AGGREGATE + "concrete_base_1k.jpg", AGGREGATE + "concrete_normal_1k.jpg", AGGREGATE + "concrete_arm_1k.png", Color("8a9294"), 0.0, 0.26],
}
const LIGHT_POSITIONS = [Vector3(-6.15,3.16,6.97), Vector3(-3.66,3.16,8.95)]
static var _surfaces: Dictionary = {}

func _ready() -> void:
	var kit := ROOM.instantiate()
	kit.name = "AuthoredRoom"
	add_child(kit)
	for child in kit.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for slot in view.mesh.get_surface_count():
			var authored := view.mesh.surface_get_material(slot)
			if authored == null:
				continue
			var replacement := material_for(authored.resource_name)
			if replacement != null:
				view.set_surface_override_material(slot, replacement)
	for at: Vector3 in LIGHT_POSITIONS:
		var light := SpotLight3D.new()
		light.name = "CeilingPanelLight"
		light.position = at
		light.rotation.x = -PI * 0.5
		light.light_color = Color("f1f6f2")
		light.light_energy = 0.7
		light.spot_range = 4.1
		light.spot_angle = 62.0
		light.spot_attenuation = 1.2
		light.shadow_enabled = at == LIGHT_POSITIONS[0]
		light.shadow_blur = 1.35
		add_child(light, true)

static func material_for(label: String) -> StandardMaterial3D:
	if _surfaces.has(label):
		return _surfaces[label]
	var mat: StandardMaterial3D
	if label == "Diffuser":
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color("d6e2dc")
		mat.roughness = 0.48
		mat.emission_enabled = true
		mat.emission = Color("e0eee7")
		mat.emission_energy_multiplier = 1.05
	elif PHOTO_MAPS.has(label):
		var maps: Array = PHOTO_MAPS[label]
		mat = StandardMaterial3D.new()
		mat.albedo_texture = load(maps[0])
		mat.albedo_color = maps[3]
		mat.normal_enabled = true
		mat.normal_texture = load(maps[1])
		mat.normal_scale = maps[5]
		mat.roughness_texture = load(maps[2])
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.ao_enabled = true
		mat.ao_texture = mat.roughness_texture
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.metallic = maps[4]
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if mat != null:
		_surfaces[label] = mat
	return mat
