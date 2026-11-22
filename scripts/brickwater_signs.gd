extends Node3D
## Original path-lettered signage, thin manufactured sign housings and
## two restrained non-shadowed practical spill sources. No downloaded fonts.
const DOCK = preload("res://assets/models/nightgrid/brickwater_signs/dock9.svg")
const RADIO = preload("res://assets/models/nightgrid/brickwater_signs/harbor_radio.svg")
static var _housing: StandardMaterial3D
var _faces: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []

func install(left: float,right: float) -> void:
	_sign("Dock9Service",DOCK,Vector3(right-0.006,2.72,-12.0),-PI*0.5,Vector2(2.25,0.75),Color("ff719e"))
	_sign("HarborRadio",RADIO,Vector3(left+0.006,2.77,0.05),PI*0.5,Vector2(2.24,0.56),Color("73ded1"))

func _sign(label: String, texture: Texture2D, at: Vector3, yaw: float, size_m: Vector2, tint: Color) -> void:
	var root := Node3D.new()
	root.name=label
	root.position=at
	root.rotation.y=yaw
	add_child(root)
	if _housing == null:
		_housing=StandardMaterial3D.new()
		_housing.albedo_color=Color("313436")
		_housing.metallic=0.65
		_housing.roughness=0.72
	var housing := MeshInstance3D.new()
	housing.name="SealedMetalHousing"
	var shell := BoxMesh.new()
	shell.size=Vector3(size_m.x+0.06,size_m.y+0.06,0.075)
	housing.mesh=shell
	housing.position.z=0.0375
	housing.material_override=_housing
	root.add_child(housing)
	var face := MeshInstance3D.new()
	face.name="OriginalPrintedSignFace"
	var quad := QuadMesh.new()
	quad.size=size_m
	face.mesh=quad
	face.position.z=0.077
	var material := StandardMaterial3D.new()
	material.albedo_texture=texture
	material.roughness=0.47
	material.emission_enabled=true
	material.emission=Color.WHITE
	material.emission_texture=texture
	material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_energy_multiplier=0.0
	face.material_override=material
	root.add_child(face)
	_faces.append(material)
	var spill := OmniLight3D.new()
	spill.name="SignSpill"
	spill.position=Vector3(0,-size_m.y*0.10,0.29)
	spill.light_color=tint
	spill.omni_range=3.8
	spill.omni_attenuation=1.8
	spill.light_energy=0.0
	spill.shadow_enabled=false
	root.add_child(spill)
	_lights.append(spill)

func set_night_factor(value: float) -> void:
	var night := smoothstep(0.35,0.85,clampf(value,0.0,1.0))
	for material in _faces:
		material.emission_energy_multiplier=1.45*night
	for lamp in _lights:
		lamp.light_energy=0.72*night
		lamp.visible=night>0.001
