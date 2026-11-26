extends Node3D
## Imported rig adapter; never generates character geometry or downloads assets.
## Authored scene uses in-place clips, a meter scale, +Z forward, feet at origin.
@export var skeleton_path: NodePath
@export var animation_player_path: NodePath
@export var clothing_mesh_path: NodePath
@export var clothing_surface := -1
@export var idle_clip: StringName = &"idle"
@export var walk_clip: StringName = &"walk"
@export_range(0.5,2.0) var authored_walk_speed := 1.2
const PALETTE = [
	Color("3b4754"),Color("4e5149"),Color("564746"),
	Color("465b5c"),Color("645747"),Color("494554")
]
const START_SPEED = 0.23
const STOP_SPEED = 0.12
const TRANSITION = 0.18
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _clothing: MeshInstance3D
var _variants: Array[BaseMaterial3D] = []
var _valid := false
var _walking := false
var _measured_speed := 0.0
var _filtered_speed := 0.0
var _style := 0
var _model: PackedScene
var _activity := "WALK"
var _animation_elapsed := 0.0
const MusicPose = preload("res://scripts/music_performance_pose.gd")
var _music_bindings: Array[Dictionary] = []
var _music_role := ""
var _music_phase := 0.0
var _music_restore: Dictionary = {}
var _attention_bone:=-1
var _attention_goal:=0.0
var _attention_yaw:=0.0
var _attention_saved:=Quaternion.IDENTITY
var _attention_applied:=false
# Office-only opt-in. Existing street actors keep their original gaze behavior.
var office_conversation_gestures:=false
var _conversation_phase:=0.0
var _attention_target_active:=false
static var _materials_by_source := {}
static var _street_surface_by_source := {}

func set_pedestrian_model(model: PackedScene) -> void:
	_model = model

func _ready() -> void:
	if _model != null:
		var instance := _model.instantiate()
		add_child(instance)
		var skeletons := find_children("*", "Skeleton3D", true, false)
		var players := find_children("*", "AnimationPlayer", true, false)
		if not skeletons.is_empty() and not players.is_empty():
			_skeleton = skeletons[0] as Skeleton3D
			_player = players[0] as AnimationPlayer
		if is_instance_valid(_player):
			# Godot's imported clips default to one shot. Share the already
			# imported resources and only set playback metadata.
			for name in [idle_clip, walk_clip, &"look_around", &"wave"]:
				if _player.has_animation(name):
					_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	else:
		_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
		_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_clothing = get_node_or_null(clothing_mesh_path) as MeshInstance3D
	if not _validate():
		set_process(false)
		return
	if _model != null:
		_apply_street_surface()
	_build_variants()
	_valid = true
	_music_bindings = MusicPose.bind(_skeleton)
	for i in _skeleton.get_bone_count():
		var bone_name:=str(_skeleton.get_bone_name(i)).to_lower()
		if bone_name=="head" or bone_name.ends_with(":head") or bone_name.ends_with("_head") or bone_name=="mixamorighead":
			_attention_bone=i
			break
	set_pedestrian_style(_style)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.play(idle_clip)
	set_process(true)

func _validate() -> bool:
	if not is_instance_valid(_skeleton) or _skeleton.get_bone_count()<2 or not is_instance_valid(_player):
		return false
	if idle_clip==walk_clip or not _player.has_animation(idle_clip) or not _player.has_animation(walk_clip):
		return false
	if not is_finite(authored_walk_speed) or authored_walk_speed<=0.0:
		return false
	for clip in [idle_clip,walk_clip]:
		var anim := _player.get_animation(clip)
		if anim.length<=0.0 or anim.loop_mode==Animation.LOOP_NONE or anim.get_track_count()==0:
			return false
	var weighted := false
	for node in find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh==null or instance.skin==null or instance.get_node_or_null(instance.skeleton)!=_skeleton:
			continue
		for surface in range(mesh.get_surface_count()):
			var format := mesh.surface_get_format(surface)
			if format & Mesh.ARRAY_FORMAT_BONES and format & Mesh.ARRAY_FORMAT_WEIGHTS:
				weighted = true
	return weighted

func _apply_street_surface() -> void:
	# The publisher's packed roughness map has a white blue channel. Keep
	# the green roughness channel and disable the unused metal sample.
	for child in find_children("*", "MeshInstance3D", true, false):
		var model := child as MeshInstance3D
		if model.mesh == null:
			continue
		for surface in range(model.mesh.get_surface_count()):
			var source := model.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			if not _street_surface_by_source.has(source):
				var material := source.duplicate() as BaseMaterial3D
				material.metallic = 0.0
				material.metallic_texture = null
				material.metallic_specular = 0.18
				material.normal_scale = 0.55
				_street_surface_by_source[source] = material
			model.set_surface_override_material(surface, _street_surface_by_source[source])

func _build_variants() -> void:
	if not is_instance_valid(_clothing) or _clothing.mesh==null or clothing_surface<0 or clothing_surface>=_clothing.mesh.get_surface_count():
		return
	var original := _clothing.get_active_material(clothing_surface) as BaseMaterial3D
	if original==null:
		return
	if _materials_by_source.has(original):
		_variants.assign(_materials_by_source[original])
		return
	for tint: Color in PALETTE:
		var material := original.duplicate() as BaseMaterial3D
		material.albedo_color = tint
		_variants.append(material)
	_materials_by_source[original] = _variants

func is_pedestrian_visual_ready() -> bool:
	return _valid

func set_pedestrian_style(style: int) -> void:
	_style = posmod(style,PALETTE.size())
	if _variants.size()==PALETTE.size():
		_clothing.set_surface_override_material(clothing_surface,_variants[_style])

func set_locomotion(speed: float) -> void:
	_measured_speed = clampf(speed,0.0,3.0) if is_finite(speed) else 0.0

func set_activity(activity: String) -> void:
	_activity = activity

# Optional gaze overlay for a named actor. No global player lookup, so
# pooled pedestrians retain their existing idle/walk behavior by default.
func set_attention_target(target:Vector3,active:bool) -> void:
	_attention_goal=0.0
	_attention_target_active=false
	if not _valid or _attention_bone<0 or not active or not target.is_finite():
		return
	var local:=to_local(target)
	if Vector2(local.x,local.z).length_squared()<.0025:
		return
	_attention_target_active=true
	_attention_goal=clampf(atan2(local.x,maxf(.10,local.z)),-.60,.60)

func _restore_attention() -> void:
	if _attention_applied and is_instance_valid(_skeleton) and _attention_bone>=0:
		_skeleton.set_bone_pose_rotation(_attention_bone,_attention_saved)
	_attention_applied=false

func _apply_attention(delta:float) -> void:
	_attention_yaw=move_toward(_attention_yaw,0.0 if _walking else _attention_goal,delta*2.8)
	var nod:=0.0
	if office_conversation_gestures and not _walking and _attention_target_active:
		_conversation_phase=fposmod(_conversation_phase+delta,4.2)
		nod=.075*pow(maxf(0.0,sin(_conversation_phase*TAU/4.2)),8.0)
	else:
		_conversation_phase=0.0
	if _attention_bone<0 or (absf(_attention_yaw)<.001 and absf(nod)<.001):
		return
	# Convert actor-local up to the head parent's coordinates. Keep the
	# imported clip's original quaternion; never accumulate frame offsets.
	var axis:=(_skeleton.global_basis.inverse()*global_basis*Vector3.UP).normalized()
	var parent:=_skeleton.get_bone_parent(_attention_bone)
	if parent>=0:
		axis=(_skeleton.get_bone_global_pose(parent).basis.inverse()*axis).normalized()
	if not axis.is_finite() or axis.length_squared()<.001:
		return
	_attention_saved=_skeleton.get_bone_pose_rotation(_attention_bone)
	var pitch_axis:=(_skeleton.global_basis.inverse()*global_basis*Vector3.RIGHT).normalized()
	if parent>=0:
		pitch_axis=(_skeleton.get_bone_global_pose(parent).basis.inverse()*pitch_axis).normalized()
	var nod_rotation:=Quaternion.IDENTITY
	if pitch_axis.is_finite() and pitch_axis.length_squared()>.001:
		nod_rotation=Quaternion(pitch_axis,nod)
	_skeleton.set_bone_pose_rotation(_attention_bone,(Quaternion(axis,_attention_yaw)*nod_rotation*_attention_saved).normalized())
	_attention_applied=true

func set_music_performance(role: String) -> bool:
	clear_music_performance()
	if not _valid or not is_processing() or _music_bindings.size()!=2 or role not in MusicPose.ROLES:
		return false
	_music_role=role
	return true

func clear_music_performance() -> void:
	MusicPose.restore(_skeleton,_music_restore)
	_music_restore.clear()
	_music_role=""
	_music_phase=0.0

## Reset pooled animation so previous occupant's stride is not inherited.
func reset_pedestrian_visual() -> void:
	_restore_attention()
	_attention_goal=0.0
	_attention_yaw=0.0
	_attention_target_active=false
	_conversation_phase=0.0
	clear_music_performance()
	_measured_speed = 0.0
	_filtered_speed = 0.0
	_activity = "WALK"
	_animation_elapsed = 0.0
	_walking = false
	if _valid:
		_player.speed_scale = 1.0
		_player.play(idle_clip,0.0)
		_player.seek(0.0,true)

func pose_taxi_seated()->Dictionary:
	if not _valid:
		return {}
	_restore_attention()
	_attention_goal=0.0
	_attention_yaw=0.0
	_attention_target_active=false
	_conversation_phase=0.0
	clear_music_performance()
	_player.stop()
	set_process(false)
	var pose:=preload("res://scripts/taxi_seated_pose.gd").apply(_skeleton,self)
	if pose.is_empty():
		resume_taxi_standing()
	return pose

func resume_taxi_standing()->void:
	if not _valid:
		return
	_skeleton.reset_bone_poses()
	reset_pedestrian_visual()
	set_process(true)

func _process(delta: float) -> void:
	if not _valid or not is_finite(delta) or delta<=0.0:
		return
	_filtered_speed = move_toward(_filtered_speed,_measured_speed,delta*5.0)
	var next_walk := _filtered_speed>STOP_SPEED if _walking else _filtered_speed>START_SPEED
	_walking = next_walk
	var clip := walk_clip if _walking else idle_clip
	if not _walking:
		if _activity in ["ALERT", "YIELD", "STOREFRONT", "WAIT_CROSSING", "ERRAND", "NIGHT_OUT"] and _player.has_animation(&"look_around"):
			clip = &"look_around"
		elif _activity == "SOCIALIZE" and _player.has_animation(&"wave"):
			clip = &"wave"
	if _player.assigned_animation != clip:
		_player.play(clip, TRANSITION)
	_player.speed_scale = clampf(_filtered_speed/authored_walk_speed,0.65,1.45) if _walking else 1.0
	var camera := get_viewport().get_camera_3d()
	var interval := 0.0
	if is_instance_valid(camera):
		var at := global_position + Vector3.UP
		if not camera.is_position_in_frustum(at):
			interval = 1.0 / 12.0
		elif camera.global_position.distance_squared_to(at) > 42.0 * 42.0:
			interval = 1.0 / 24.0
	_animation_elapsed += delta
	if _animation_elapsed >= interval:
		_restore_attention()
		MusicPose.restore(_skeleton,_music_restore)
		_music_restore.clear()
		_player.advance(_animation_elapsed)
		_apply_attention(_animation_elapsed)
		if not _music_role.is_empty() and not _walking:
			_music_phase=fposmod(_music_phase+_animation_elapsed,1.0)
			_music_restore=MusicPose.apply(_skeleton,self,_music_bindings,_music_role,_music_phase)
		_animation_elapsed = 0.0

func animation_state() -> Dictionary:
	return {"ready":_valid,"walking":_walking,"style":_style,"variants":_variants.size(),
		"clip":str(_player.current_animation) if _valid else "","speed_scale":_player.speed_scale if _valid else 0.0}
