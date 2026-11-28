extends RefCounted
## Private creator assets are ordinary imported scenes, cached once per identity.
## No runtime inference, GLTF parsing, network or per-frame file reads.
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")
const ROOT = "res://assets/creator_character_bank/"
const NAMED = {
	"dev": "dev_rao", "rina": "rina_vale", "people_ops": "dana_mercer",
	"jetson_wang": "jetson_wang", "mika": "mika_torres", "eli": "eli_brooks",
	"security": "owen_pike", "reception": "nina_bell",
}
const STREET = [
	"brickwater_resident_01", "brickwater_night_worker_01",
	"vesper_market_visitor_01", "afterhours_patron_01", "dock_worker_01",
	"horizon_visitor_01", "brickwater_resident_02", "brickwater_night_worker_02",
	"vesper_market_visitor_02", "afterhours_patron_02", "dock_worker_02",
	"horizon_visitor_02",
]
const SECURITY = ["security_base_01", "security_base_02"]
const SERVICE = ["service_staff_01", "service_staff_02"]
const OFFICE = ["mika_torres", "eli_brooks", "nina_bell", "rina_vale", "dev_rao", "dana_mercer", "jetson_wang"]
static var _scenes: Dictionary = {}
static var _checked := false
static var _available := false

static func ids() -> Array:
	return NAMED.values() + STREET + SECURITY + SERVICE

static func available() -> bool:
	if _checked:
		return _available
	_checked = true
	if not FileAccess.file_exists(ROOT + "bank.json"):
		return false
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "bank.json"))
	if not manifest is Dictionary or manifest.get("schema") != 1:
		return false
	var records = manifest.get("actors", {})
	if not records is Dictionary or records.size() != ids().size():
		return false
	for id in ids():
		if not records.has(id) or not ResourceLoader.exists(ROOT + str(id) + ".glb", "PackedScene"):
			return false
	_available = true
	return true

static func model(id: String) -> PackedScene:
	if not available() or not ids().has(id):
		return null
	if not _scenes.has(id):
		_scenes[id] = load(ROOT + id + ".glb") as PackedScene
	return _scenes[id] as PackedScene

static func street_models() -> Array[PackedScene]:
	var models: Array[PackedScene] = []
	if available():
		for id in STREET:
			var scene := model(id)
			if scene == null:
				models.clear()
				break
			models.append(scene)
	return models

static func choose(id: String, outfit: String = "", office: bool = false) -> String:
	if NAMED.has(id):
		return str(NAMED[id])
	var options: Array = STREET
	if outfit == "security":
		options = SECURITY
	elif outfit in ["retail", "service", "technician"]:
		options = SERVICE
	elif office:
		options = OFFICE
	return str(options[posmod(id.hash(), options.size())])

static func install(actor: Node3D, id: String, seated: bool = false) -> Node3D:
	var packed := model(id)
	if packed == null:
		return null
	var legacy := actor.get_children()
	var rig := Rig.new()
	rig.name = "CharacterBankVisual"
	rig.set_pedestrian_model(packed)
	rig.scale = Vector3.ONE / actor.scale
	actor.add_child(rig)
	if not rig.is_pedestrian_visual_ready():
		actor.remove_child(rig)
		rig.queue_free()
		return null
	if seated:
		var players := rig.find_children("*", "AnimationPlayer", true, false)
		var skeletons := rig.find_children("*", "Skeleton3D", true, false)
		if players.size() != 1 or skeletons.size() != 1:
			actor.remove_child(rig)
			rig.queue_free()
			return null
		var player := players[0] as AnimationPlayer
		var skeleton := skeletons[0] as Skeleton3D
		var hips := skeleton.find_bone("Hips")
		if player.has_animation(&"Sit idle (chair)") and hips >= 0:
			var clip := player.get_animation(&"Sit idle (chair)")
			clip.loop_mode = Animation.LOOP_LINEAR
			player.play(&"Sit idle (chair)")
			player.seek(clip.length * .4, true)
			skeleton.force_update_all_bone_transforms()
			var anchor := actor.global_position + actor.global_basis.orthonormalized() * Vector3(0, .56, -.045)
			rig.global_position += anchor - skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
			rig.enable_authored_office_pose()
		else:
			# Existing skeletal seated-pose adapter; authored seated clips
			# are preferable and remain a production follow-up.
			var pose := rig.pose_taxi_seated()
			if pose.is_empty():
				actor.remove_child(rig)
				rig.queue_free()
				return null
			var hip: Vector3 = pose["hip"]
			var anchor := actor.global_position + actor.global_basis.orthonormalized() * Vector3(0, .56, -.045)
			rig.global_position += anchor - rig.to_global(hip)
	for child in legacy:
		if child is Node3D:
			child.hide()
	return rig
