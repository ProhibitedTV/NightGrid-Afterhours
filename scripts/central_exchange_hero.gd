extends Node3D
## CENTRAL EXCHANGE — permanent, handcrafted pedestrian/traffic junction at 0,0.
## Static detail only: real lane logic remains in traffic_signals.gd.
## No procedural randomness, collisions in the travelled roadway, or new save data.
const Materials = preload("res://scripts/material_library.gd")
const PhotoStreetKit = preload("res://scripts/central_exchange_street_kit.gd")
const AuthoredCurbs = preload("res://scripts/central_exchange_curb_kit.gd")
const CROSSING_DISTANCE = 10.3
const CURB_AT = 8.1
const STRIPE_COUNT = 9
const DISTRICT_NAME = "CENTRAL EXCHANGE"
const NIGHT_CYAN = Color("62d9d1")
const ROAD_Y = 0.008

var _stats := {
	"crossings": 0, "paint_wear_marks": 0, "curb_ramps": 0,
	"storm_drains": 0, "repair_patches": 0, "reflective_puddles": 0,
	"mounted_signal_heads": 0, "crossing_signs": 0,
	"batched_instances": 0, "night_lights": 0,
	"photographed_street_props": 0, "photo_road_decal_projections": 0,
	"measured_street_colliders": 0,
	"original_curb_modules": 0, "scanned_curb_draw_surfaces": 0,
	"beveled_concrete_sections": 0, "original_slotted_drains": 0
}
var _night := 0.0
var _hero_light: OmniLight3D
var _sign_faces: Array[MeshInstance3D] = []
var _reusable: Dictionary = {}

func _ready() -> void:
	name = "CentralExchangeHero"
	_build_worn_markings()
	_build_pavement_and_drains()
	_build_repaired_surface()
	_build_signal_mount()
	_build_street_furniture()
	# A bounded real-asset street kit sits beside this fixed junction, not in
	# the 81-traffic-light signal map or mutable generated parcel layout.
	var photo_kit := PhotoStreetKit.new()
	photo_kit.name = "CentralExchangePhotoStreetKit"
	add_child(photo_kit)
	var real_stats: Dictionary = photo_kit.get_street_stats()
	_stats["photographed_street_props"] = real_stats["source_installs"]
	_stats["photo_road_decal_projections"] = real_stats["road_decal_projections"]
	_stats["measured_street_colliders"] = real_stats["sidewalk_collision_bodies"]
	# Real modeled curb/grate sidewalk kit replaces only the 8 old
	# generic 36m inner curb boxes; all road crosswalk ramps are preserved.
	var curbs := AuthoredCurbs.new()
	curbs.name = "CentralExchangeAuthoredCurbProfiles"
	add_child(curbs)
	var curb_stats: Dictionary = curbs.get_curbstone_stats()
	_stats["original_curb_modules"] = curb_stats["installed_static_modules"]
	_stats["scanned_curb_draw_surfaces"] = curb_stats["photographed_material_surfaces"]
	_stats["beveled_concrete_sections"] = curb_stats["concrete_slab_sections"]
	_stats["original_slotted_drains"] = curb_stats["gutter_drain_grates"]
	_build_night_light()
	set_night_factor(0.0)

func get_visual_stats() -> Dictionary:
	return _stats.duplicate()

func set_night_factor(raw: float) -> void:
	_night = smoothstep(0.35, 0.85, clampf(raw, 0.0, 1.0))
	if _hero_light != null:
		_hero_light.visible = _night > 0.025
		_hero_light.light_energy = 0.85 * _night
	for pane in _sign_faces:
		var material := pane.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 1.35 * _night

func get_night_light_energy() -> float:
	return _hero_light.light_energy if _hero_light != null else 0.0

func _material(kind: String, tint: Color) -> StandardMaterial3D:
	if kind in ["METAL", "ASPHALT", "CONCRETE", "PAVERS", "WET"]:
		return Materials.surface(kind, tint)
	var key := kind + "/" + tint.to_html(true)
	if _reusable.has(key):
		return _reusable[key]
	var surface := StandardMaterial3D.new()
	surface.albedo_color = tint
	surface.metallic = 0.0
	surface.roughness = 0.88
	if kind == "REFLECTOR":
		surface.metallic = 0.06
		surface.roughness = 0.29
	if kind == "RUBBER":
		surface.roughness = 0.95
	if kind == "EMISSION":
		surface.albedo_color = tint.darkened(0.72)
		surface.emission_enabled = true
		surface.emission = tint
		surface.emission_energy_multiplier = 0.0
		surface.roughness = 0.26
	_reusable[key] = surface
	return surface

func _box(part_name: String, at: Vector3, dimensions: Vector3,
		kind: String, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = _material(kind, color)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(part)
	return part

func _cylinder(part_name: String, at: Vector3, radius: float, height: float,
		kind: String, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	part.mesh = mesh
	part.position = at
	part.material_override = _material(kind, color)
	(parent if parent != null else self).add_child(part)
	return part

func _batch(name: String, size: Vector3, positions: Array[Vector3],
		kind: String, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	mm.mesh = unit
	mm.instance_count = positions.size()
	for i in range(positions.size()):
		mm.set_instance_transform(i, Transform3D(Basis().scaled(size), positions[i]))
	var mesh := MultiMeshInstance3D.new()
	mesh.name = name
	mesh.multimesh = mm
	mesh.material_override = _material(kind, color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	_stats["batched_instances"] += positions.size()

func _build_worn_markings() -> void:
	# Original 81 working crossings remain owned by city_details.gd.
	# The hero junction adds targeted weathering ON TOP of their existing paint.
	# Intermittent abrasion exposes charcoal asphalt through faded zebra stripes.
	var abrasions: Array[Vector3] = []
	var speckles: Array[Vector3] = []
	for approach in range(4):
		_stats["crossings"] += 1
		for stripe in range(STRIPE_COUNT):
			var stripe_offset := float(stripe - 4) * 1.30
			for tear in range(6):
				var along := -1.20 + float(tear) * 0.49
				var offset := stripe_offset + sin(float(stripe * 17 + tear * 11 + approach * 23)) * 0.27
				var at := Vector3.ZERO
				if approach < 2:
					at = Vector3(offset, 0.052, (-CROSSING_DISTANCE if approach == 0 else CROSSING_DISTANCE) + along)
				else:
					at = Vector3((-CROSSING_DISTANCE if approach == 2 else CROSSING_DISTANCE) + along, 0.052, offset)
				abrasions.append(at)
			# Edge reflectors read as surface-set road studs, never speed bumps.
			if stripe % 2 == 0:
				var at_stud := Vector3.ZERO
				if approach < 2:
					at_stud = Vector3(stripe_offset, 0.041, (-13.38 if approach == 0 else 13.38))
				else:
					at_stud = Vector3((-13.38 if approach == 2 else 13.38), 0.041, stripe_offset)
				speckles.append(at_stud)
	_batch("FadedZebraAsphaltAbrasion", Vector3(0.16, 0.004, 0.18), abrasions,
		"ASPHALT", Color("333b46"))
	_stats["paint_wear_marks"] = abrasions.size()
	_batch("ReflectiveStopLineStuds", Vector3(0.12, 0.018, 0.12), speckles,
		"REFLECTOR", Color("e9c79d"))
	var seam_marks: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for step in range(15):
			var offset := -5.5 + float(step) * 0.79
			seam_marks.append(Vector3(side * 14.6, 0.020, offset))
			seam_marks.append(Vector3(offset, 0.020, side * 14.6))
		_batch("ThermoplasticEdgeFragment_%s" % str(side),
			Vector3(0.12, 0.009, 0.13), seam_marks, "CONCRETE", Color("99958e"))
		seam_marks.clear()

func _build_pavement_and_drains() -> void:
	# Eight sloped ramps replace the last few metres of the existing raised
	# corner curbs (which are cut out in city_details.gd for THIS junction).
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_ramp(Vector3(sx * CURB_AT, 0.0, sz * 10.4),
				Vector3(-sx, 0.0, 0.0), "EW")
			_add_ramp(Vector3(sx * 10.4, 0.0, sz * CURB_AT),
				Vector3(0.0, 0.0, -sz), "NS")
			# Storm grate placed along the gutter beside, not in, the crossing.
			_drain(Vector3(sx * 6.80, 0.013, sz * 15.15), false)
			_drain(Vector3(sx * 15.15, 0.013, sz * 6.80), true)
			# A low reflective bead traces the eroded curb after rain.
			_box("GutterReflector", Vector3(sx * 7.05, 0.019, sz * 16.4),
				Vector3(0.035, 0.014, 2.1), "WET", Color("667c81"))
			_box("GutterReflector", Vector3(sx * 16.4, 0.019, sz * 7.05),
				Vector3(2.1, 0.014, 0.035), "WET", Color("667c81"))

func _add_ramp(sidewalk: Vector3, toward_street: Vector3, label_name: String) -> void:
	# The high edge meets the 0.14 m sidewalk; the low edge meets road grade.
	# Quad sits flush, is non-colliding decoration and leaves lane centers clear.
	var right := Vector3(-toward_street.z, 0.0, toward_street.x)
	var a := sidewalk - right * 1.08 + Vector3.UP * 0.144
	var b := sidewalk + right * 1.08 + Vector3.UP * 0.144
	var c := sidewalk + right * 1.08 + toward_street * 1.46 + Vector3.UP * 0.035
	var d := sidewalk - right * 1.08 + toward_street * 1.46 + Vector3.UP * 0.035
	var vertices := PackedVector3Array([a, c, b, a, d, c]) if (c - a).cross(b - a).y > 0.0 else PackedVector3Array([a, b, c, a, c, d])
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(vertices.size()):
		normals.append(Vector3.UP)
		uvs.append(Vector2(vertices[i].x * 0.20, vertices[i].z * 0.20))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var view := MeshInstance3D.new()
	view.name = "AccessibleRamp_%s_%02d" % [label_name, _stats["curb_ramps"]]
	view.mesh = mesh
	view.material_override = _material("PAVERS", Color("9ba5a3"))
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	_stats["curb_ramps"] += 1
	# Contrasting tactile paving sits on sidewalk-side lip, clear of driving.
	_box("TactileThreshold", sidewalk + Vector3.UP * 0.154,
		Vector3(0.11, 0.021, 1.83) if absf(toward_street.x) > 0.5 else Vector3(1.83, 0.021, 0.11),
		"METAL", Color("d3ad78"))

func _drain(at: Vector3, across_x: bool) -> void:
	# A submerged grate in the gutter, surrounded by a dark rectangular socket.
	_box("StormDrainSocket", at, Vector3(0.57, 0.009, 0.83) if not across_x else Vector3(0.83, 0.009, 0.57),
		"RUBBER", Color("1b2732"))
	for tooth in range(7):
		var displacement := -0.32 + float(tooth) * 0.105
		var position := at + Vector3(0.0, 0.009, displacement) if not across_x else at + Vector3(displacement, 0.009, 0.0)
		_box("SlottedCastIronGrate", position,
			Vector3(0.49, 0.018, 0.043) if not across_x else Vector3(0.043, 0.018, 0.49),
			"METAL", Color("63757a"))
	_stats["storm_drains"] += 1

func _triangles(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for pos in [a, b, c]:
		mesh.set_uv(Vector2(pos.x * 0.2, pos.z * 0.2))
		mesh.add_vertex(pos)

func _irregular_patch(center: Vector3, width: float, length: float,
		kind: String, color: Color, name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(16):
		var start := TAU * float(segment) / 16.0
		var end := TAU * float(segment + 1) / 16.0
		var jitter1 := 0.85 + sin(start * 5.0 + width) * 0.075 + cos(start * 9.0 + length) * 0.035
		var jitter2 := 0.85 + sin(end * 5.0 + width) * 0.075 + cos(end * 9.0 + length) * 0.035
		var first := Vector3(cos(start) * width * jitter1, 0.0, sin(start) * length * jitter1)
		var second := Vector3(cos(end) * width * jitter2, 0.0, sin(end) * length * jitter2)
		_triangles(st, Vector3.ZERO, second, first)
	st.generate_normals()
	var surface := MeshInstance3D.new()
	surface.name = name
	surface.mesh = st.commit()
	surface.position = center
	surface.material_override = _material(kind, color)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

func _build_repaired_surface() -> void:
	# Repaired patches and shallow wet seams frame the road, not a flat
	# all-over mirror. Both are flat, lightly irregular and deterministic.
	for place in [
		Vector3(-3.85, 0.016, 3.15),
		Vector3(3.71, 0.016, -3.25),
		Vector3(-4.65, 0.016, -4.95)
	]:
		_irregular_patch(place, 0.70, 1.28, "ASPHALT",
			Color("434750"), "ResurfacedAsphalt_%02d" % _stats["repair_patches"])
		_stats["repair_patches"] += 1
	for place in [
		Vector3(-6.05, 0.026, 6.35),
		Vector3(6.01, 0.026, -6.25)
	]:
		_irregular_patch(place, 0.57, 1.19, "WET",
			Color("617782"), "GutterRainPuddle_%02d" % _stats["reflective_puddles"])
		_stats["reflective_puddles"] += 1
	# Hairline sealant marks imply maintenance without making roadway obstacles.
	var sealed: Array[Vector3] = []
	for i in range(30):
		sealed.append(Vector3(-4.7 + float(i) * 0.13,
			0.027, 3.5 + sin(float(i) * 0.62) * 0.18))
	_batch("BitumenCrackSeal", Vector3(0.092, 0.012, 0.063), sealed,
		"RUBBER", Color("1c2831"))

func _build_signal_mount() -> void:
	# Both original phase-driven signal heads occupy the NE sidewalk corner at
	# (+9.2, +9.2), y=5.8. We mount their REAL nodes; no fake parallel lights.
	var mount := Vector3(9.2, 0.0, 9.2)
	_cylinder("MastArmPole", mount + Vector3.UP * 3.00,
		0.16, 6.0, "METAL", Color("677b80"))
	_cylinder("MastAnchorFoot", mount + Vector3.UP * 0.19,
		0.38, 0.31, "METAL", Color("485c66"))
	_box("SignalMastCrossArm", mount + Vector3.UP * 5.55,
		Vector3(1.48, 0.15, 0.17), "METAL", Color("546875"))
	_box("FiberSignalCabinet", mount + Vector3(-0.45, 0.80, 0.61),
		Vector3(0.73, 1.27, 0.48), "METAL", Color("536877"))
	_box("SignalCabinetDoor", mount + Vector3(-0.45, 0.80, 0.878),
		Vector3(0.58, 1.02, 0.025), "METAL", Color("82939a"))
	_box("ControllerWarningTape", mount + Vector3(-0.45, 1.15, 0.897),
		Vector3(0.48, 0.085, 0.02), "REFLECTOR", Color("e9b874"))
	_stats["mounted_signal_heads"] = 2

func _sign(text_value: String, at: Vector3, color: Color, size: int) -> void:
	var sign := Label3D.new()
	sign.text = text_value
	sign.position = at
	sign.font_size = size
	sign.pixel_size = 0.0040
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = color
	sign.outline_modulate = Color("122532")
	sign.outline_size = 7
	add_child(sign)
	_stats["crossing_signs"] += 1

func _build_street_furniture() -> void:
	# Readable city-specific details occupy sidewalk corners and have no
	# collision shapes or footprint in through travel lanes.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector3(sx * 11.1, 0.0, sz * 11.0)
			if sx > 0.0 and sz > 0.0:
				# Avoid duplicating NE signal's existing mast and cabinet.
				_sign("M / EXCHANGE", corner + Vector3.UP * 2.8,
					Color("9de8da"), 38)
				continue
			_cylinder("CrosswalkInformationPost", corner + Vector3.UP * 1.55,
				0.078, 3.1, "METAL", Color("7b8991"))
			_box("ReflectiveWayfindingPlate", corner + Vector3.UP * 2.70,
				Vector3(1.38, 0.48, 0.10), "METAL", Color("293f52"))
			_box("WayfindingLightBlade", corner + Vector3.UP * 2.44,
				Vector3(1.24, 0.035, 0.16), "EMISSION", NIGHT_CYAN)
			_sign("CROSS  /  M", corner + Vector3.UP * 2.72,
				Color("b0e6dc"), 27)
			_box("ProtectiveBollard", corner + Vector3(-sx * 1.06, 0.51, sz * 1.20),
				Vector3(0.22, 0.94, 0.22), "METAL", Color("667884"))
			_box("BollardReflector", corner + Vector3(-sx * 1.06, 0.86, sz * 1.20),
				Vector3(0.245, 0.065, 0.245), "REFLECTOR", Color("d2bb8c"))
	_box("DistrictNameBlade", Vector3(-11.2, 4.50, 11.2),
		Vector3(3.20, 0.59, 0.16), "METAL", Color("263c4d"))
	_sign("CENTRAL  /  EXCHANGE", Vector3(-11.2, 4.53, 11.38),
		Color("d0e3d9"), 32)
	# Four warm/cool contrast points without a full-scale glowing street grid.
	for sx in [-1.0, 1.0]:
		_sign("NIGHTGRID  06", Vector3(sx * 10.5, 1.25, -9.8),
			Color("d1af82"), 24)

func _build_night_light() -> void:
	var fixture := _box("SuspendedAreaFixture", Vector3(-9.25, 4.08, 9.18),
		Vector3(1.14, 0.12, 0.43), "METAL", Color("617782"))
	var lens := _box("PracticalAreaLens", Vector3(-9.25, 4.005, 9.18),
		Vector3(1.00, 0.032, 0.30), "EMISSION", NIGHT_CYAN)
	_sign_faces.append(lens)
	_hero_light = OmniLight3D.new()
	_hero_light.name = "BoundedExchangeNightLight"
	_hero_light.position = fixture.position + Vector3.DOWN * 0.24
	_hero_light.omni_range = 10.0
	_hero_light.light_color = Color("a3e0d4")
	_hero_light.shadow_enabled = false
	_hero_light.light_energy = 0.0
	_hero_light.visible = false
	add_child(_hero_light)
	_stats["night_lights"] = 1
