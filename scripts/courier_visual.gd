extends Node3D
## Presentation only. The character controller still owns the capsule and motion.
const Model = preload("res://assets/models/nightgrid/courier/morrow_courier.glb")
const Materials = preload("res://scripts/material_library.gd")
const FOOT_OFFSET = -0.95
const DRIVER_SEAT = Vector3(-0.52, -0.23, -0.43)
const LOOPS = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right",
	&"jump_air", &"weapon_idle", &"aim", &"aim_walk", &"aim_run", &"aim_left", &"aim_right", &"drive_car", &"sit"]

static var _courier_library: AnimationLibrary
var skeleton: Skeleton3D
var animations: AnimationPlayer
var current_pose: StringName
var _action: StringName
var _equipment := "holstered"
var _aiming := false
var _seat := false
var _grounded := true
var _horizontal := Vector3.ZERO
var _sprinting := false
var _reverse_playback := false
var _entry_ground_y := 0.0
var _weapon_display: Node3D

func _ready() -> void:
	var courier := Model.instantiate()
	add_child(courier)
	skeleton = courier.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	animations = courier.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	animations.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	# Prepare the clips once. Save/load can reuse them with independent playback.
	if _courier_library == null:
		_courier_library = animations.get_animation_library(&"").duplicate(true) as AnimationLibrary
		_prepare_library()
	animations.remove_animation_library(&"")
	animations.add_animation_library(&"", _courier_library)
	animations.animation_finished.connect(_finish_action)
	_build_equipment_display()
	_play(&"idle", 0.0)
	set_physics_process(false)

func _prepare_library() -> void:
	for clip in LOOPS:
		_courier_library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var alight := _courier_library.get_animation(&"alight_car")
	for track in range(alight.get_track_count()):
		if alight.track_get_type(track) != Animation.TYPE_POSITION_3D or alight.track_get_path(track).get_subname(0) != &"Hips":
			continue
		var count := alight.track_get_key_count(track)
		var end: Vector3 = alight.track_get_key_value(track, count - 1)
		for key in range(count):
			var at: Vector3 = alight.track_get_key_value(track, key)
			alight.track_set_key_value(track, key, Vector3(at.x - end.x, at.y, at.z))

func set_weapon_pose(id: String, aiming: bool) -> void:
	if _equipment == id and _aiming == aiming:
		return
	_equipment = id
	_aiming = aiming
	_weapon_display.visible = id != "holstered" and not _seat
	_weapon_display.get_node("Pulse").visible = id == "pulse"
	_weapon_display.get_node("Arc").visible = id == "arc"
	if id == "holstered" and _action in [&"fire", &"reload"]:
		_action = &""
	_choose_pose()

func update_motion(local_velocity: Vector3, on_floor: bool, jumped: bool,
		landed: bool, sprinting: bool) -> void:
	if _seat:
		return
	_horizontal = Vector3(local_velocity.x, 0.0, local_velocity.z)
	_grounded = on_floor
	_sprinting = sprinting
	if jumped:
		play_action(&"jump_start")
	elif landed and current_pose in [&"jump_start", &"jump_air"]:
		play_action(&"jump_land")
	elif not on_floor and _action not in [&"jump_start", &"alight_car"]:
		_action = &""
	elif _horizontal.length_squared() > 1.2 and _action in [&"interact", &"stand_up", &"alight_car"]:
		_action = &""
	_choose_pose()

func play_action(clip: StringName) -> void:
	if _seat or (clip == &"interact" and (_horizontal.length_squared() > 0.8 or not _grounded)):
		return
	_action = clip
	if current_pose == clip:
		animations.seek(0.0)
	var rate := 1.85 if clip == &"jump_start" else 1.0
	_play(clip, 0.08, rate)
	if clip == &"alight_car":
		# The original gameplay exit chooses a safe curb-side placement. Use
		# the authored weight transfer after the feet have cleared the sill.
		animations.seek(animations.current_animation_length * 0.72, true)

func sit_in_vehicle(car: Node3D, play_entry: bool, ground_y: float) -> void:
	if get_parent() != car:
		reparent(car, false)
	position = DRIVER_SEAT
	rotation = Vector3(0.0, PI, 0.0)
	_seat = true
	_horizontal = Vector3.ZERO
	_weapon_display.hide()
	_action = &"board_car" if play_entry else &""
	_entry_ground_y = ground_y
	if play_entry:
		position.y = ground_y
	_play(&"board_car" if play_entry else &"drive_car", 0.0, 1.15 if play_entry else 1.0)
	set_physics_process(play_entry)

func _physics_process(_delta: float) -> void:
	if absf(float(get_parent().get("speed"))) > 2.5:
		_finish_action(&"board_car")
		return
	var progress := animations.current_animation_position / animations.current_animation_length
	position.y = lerpf(_entry_ground_y, DRIVER_SEAT.y, smoothstep(0.25, 0.63, progress))

func return_to_player(player: Node3D) -> void:
	var facing := global_rotation.y
	reparent(player, false)
	position = Vector3.UP * FOOT_OFFSET
	rotation = Vector3(0.0, facing, 0.0)
	_seat = false
	_grounded = true
	_action = &""
	_play(&"idle", 0.0)
	set_physics_process(false)

func _finish_action(clip: StringName) -> void:
	if clip != _action:
		return
	_action = &""
	if _seat:
		position = DRIVER_SEAT
		set_physics_process(false)
	_choose_pose()

func _choose_pose() -> void:
	if _action != &"":
		return
	if _seat:
		_play(&"drive_car", 0.18)
		return
	if not _grounded:
		_play(&"jump_air", 0.10)
		return
	var speed := _horizontal.length()
	if speed < 0.28:
		var stance := &"idle"
		if _equipment != "holstered":
			stance = &"aim" if _aiming else &"weapon_idle"
		_play(stance, 0.18)
		return
	var running := speed > 3.3
	var clip := &"run" if running else &"walk"
	var natural_speed := 4.1 if running else 1.75
	var playback_direction := 1.0
	if _aiming:
		if absf(_horizontal.x) > absf(_horizontal.z):
			clip = &"aim_left" if _horizontal.x > 0.0 else &"aim_right"
			natural_speed = 2.85
		elif _horizontal.z < -0.3:
			clip = &"aim_walk"
			natural_speed = 2.85
			playback_direction = -1.0
		else:
			clip = &"aim_run" if running else &"aim_walk"
	elif absf(_horizontal.x) > absf(_horizontal.z) + 0.35:
		clip = &"strafe_left" if _horizontal.x > 0.0 else &"strafe_right"
		natural_speed = 2.85
	elif _horizontal.z < -0.45:
		clip = &"walk_back"
		natural_speed = 1.75
	_play(clip, 0.15, playback_direction * clampf(speed / natural_speed, 0.6, 1.85 if _sprinting else 1.65))

func _play(clip: StringName, blend: float, rate: float = 1.0) -> void:
	var backward := rate < 0.0
	animations.speed_scale = absf(rate)
	if current_pose == clip and backward == _reverse_playback:
		return
	current_pose = clip
	_reverse_playback = backward
	animations.play(clip, blend, -1.0 if backward else 1.0, backward)

func _build_equipment_display() -> void:
	var hand := BoneAttachment3D.new()
	hand.name = "RightHandEquipment"
	hand.bone_name = "RightHand"
	skeleton.add_child(hand)
	_weapon_display = Node3D.new()
	_weapon_display.name = "EquippedWeapon"
	# Barrel and up axes in the authored aim clip's right-hand frame.
	var barrel := Vector3(0.054, 0.936, 0.348)
	var up := Vector3(0.0014, -0.349, 0.937)
	_weapon_display.basis = Basis(up.cross(barrel), up, barrel).orthonormalized()
	_weapon_display.position = barrel * 0.051 + up * 0.012
	hand.add_child(_weapon_display)
	for id in ["Pulse", "Arc"]:
		var item := Node3D.new()
		item.name = id
		_weapon_display.add_child(item)
		var tint := Color("567b83") if id == "Pulse" else Color("926f67")
		_equipment_part(item, Vector3(0, 0.041, 0.075), Vector3(0.069, 0.074, 0.21 if id == "Pulse" else 0.27), tint)
		_equipment_part(item, Vector3(0, -0.022, -0.008), Vector3(0.056, 0.105, 0.062), Color("26353e"))
		_equipment_part(item, Vector3(0, 0.081, 0.084), Vector3(0.047, 0.014, 0.082),
			Color("81d5cd") if id == "Pulse" else Color("e3bb83"))
	_weapon_display.hide()

func _equipment_part(parent: Node3D, at: Vector3, size: Vector3, tint: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = Materials.surface("METAL", tint)
	part.position = at
	parent.add_child(part)
