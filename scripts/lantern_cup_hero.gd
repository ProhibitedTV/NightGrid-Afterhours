extends Node3D
## LANTERN CUP — hand-composed, game-ready flagship café at its canonical
## Vesper Market address. Instantiated only while that room is occupied.
## All dimensions are local to InteriorSystem's 16m x 18m room.
const Materials = preload("res://scripts/material_library.gd")
const CoffeeSound = preload("res://scripts/lantern_cup_audio.gd")
const MaraHero = preload("res://scripts/mara_hero.gd")
const LanternPatron = preload("res://scripts/lantern_patron.gd")
# Five permanent regulars occupy actual booth-side seats and a back-of-house
# waiting spot. None sits in the center aisle or beside Mara's clue terminal.
const PATRONS = [
	{"id": "rin", "name": "Rin", "role": "M-Line track mechanic",
		"activity": "SIP", "palette": 0, "side": -1.0, "z": -3.25,
		"seated": true, "phase": 0.47},
	{"id": "ivo", "name": "Ivo", "role": "Night dispatch clerk",
		"activity": "SCROLL", "palette": 1, "side": 1.0, "z": -3.25,
		"seated": true, "phase": 1.31},
	{"id": "tamsin", "name": "Tamsin", "role": "Warehouse shift organizer",
		"activity": "CHAT", "palette": 2, "side": -1.0, "z": 0.25,
		"seated": true, "phase": 2.21},
	{"id": "len", "name": "Len", "role": "District records archivist",
		"activity": "READ", "palette": 3, "side": 1.0, "z": 0.25,
		"seated": true, "phase": 3.07},
	{"id": "aya", "name": "Aya", "role": "Off-shift street medic",
		"activity": "SCROLL", "palette": 4, "side": -1.0, "z": 3.78,
		"seated": true, "phase": 4.06}
]
const RUMOR_POSITION = Vector3(5.32, 1.18, 3.45)
const RUMOR_ID = "lantern_cup_shift_notes"
const RUMOR_TEXT = "Mara's shift notes: a quiet second delivery door faces the north service alley. Corporate couriers avoid the public night market."
const TEAL = Color("6fdbd5")
const AMBER = Color("efb77c")
const BRASS = Color("ae8661")
const DEEP_INK = Color("1c2d38")
const COFFEE = Color("3b2724")
const GLASS = Color(0.37, 0.55, 0.61, 0.39)

var _statistics := {
	"booths": 0, "seats": 0, "tables": 0,
	"espresso_groups": 0, "glass_panels": 0, "pendants": 0,
	"mugs": 0, "planters": 0, "menu_panels": 0,
	"collidable_furniture": 0, "steam_wisps": 0,
	"lights": 0, "original_audio_sources": 0, "characters": 0,
	"patrons": 0, "patron_meshes": 0, "patron_lights": 0,
	"patron_collision_objects": 0
}
var _materials: Dictionary = {}
var _steam_nodes: Array[MeshInstance3D] = []
var _patrons: Array[Node3D] = []
var _clock := 0.0

func _ready() -> void:
	_build_material_architecture()
	_build_cafe_bar()
	_build_banquette_nooks()
	_build_furniture()
	_build_lanterns_and_glazing()
	_build_local_lighting()
	_build_sounds()
	_build_mara_character()
	_build_ambient_patrons()

func get_visual_stats() -> Dictionary:
	return _statistics.duplicate()

func get_patron_manifest() -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	for patron in _patrons:
		manifest.append(patron.call("get_identity"))
	return manifest

func patron_near(at: Vector3, radius: float = 1.7) -> Dictionary:
	# InteriorSystem sends room-local coordinates, not world-space vectors.
	# A two-dimensional walk-up contact is compatible with floor snap height.
	for i in range(_patrons.size()):
		var patron := _patrons[i]
		var gap := Vector2(at.x - patron.position.x, at.z - patron.position.z)
		if gap.length() <= radius:
			return {"id": str(PATRONS[i]["id"]), "name": str(PATRONS[i]["name"]),
				"role": str(PATRONS[i]["role"]), "distance": gap.length()}
	return {}

func patron_dialogue(at: Vector3, context: Dictionary) -> Dictionary:
	var near := patron_near(at)
	if near.is_empty():
		return {}
	var actor_id: String = str(near["id"])
	var line := ""
	var late := float(context.get("hour", 12.0)) >= 18.0
	match actor_id:
		"rin":
			line = ("Rin: The CICADA's bearings sound different after midnight. I'll check the M-Line guideway."
				if late else "Rin: Nothing runs itself. Those M-Line cars take a whole crew to keep rolling.")
		"ivo":
			line = "Ivo: The courier schedule is the only honest map of Morrow Bay."
		"tamsin":
			line = "Tamsin: If the warehouse rota changes again, we're organizing another shift meeting."
		"len":
			line = ("Len: Mara's notes are more useful than the city archive."
				if bool(context.get("shift_notes", false)) else
				"Len: If you're looking for a clue, watch where Mara keeps her shift notes.")
		"aya":
			line = "Aya: Drink water between deliveries. Coffee doesn't fix a whole night on your feet."
	return {"id": actor_id, "name": near["name"], "role": near["role"], "line": line}

func mara_character() -> Node3D:
	return get_node_or_null("MaraHero")

func _build_ambient_patrons() -> void:
	# Build only when Lantern Cup itself is streamed. Stable authorial slots
	# mean revisits and save/load use the same cast and seating.
	for details in PATRONS:
		var guest := LanternPatron.new()
		guest.configure(details)
		var side := float(details["side"])
		guest.position = Vector3(side * 5.88, 0.0, float(details["z"]))
		# Torso/eyes orient from the window-side bench toward their own table.
		guest.rotation.y = -PI * 0.5 if side > 0.0 else PI * 0.5
		add_child(guest)
		_patrons.append(guest)
		var guest_stats: Dictionary = guest.call("get_visual_stats")
		_statistics["patrons"] += 1
		_statistics["patron_meshes"] += int(guest_stats["mesh_parts"])
		_statistics["patron_lights"] += int(guest_stats["lights"])
		_statistics["patron_collision_objects"] += int(guest_stats["colliders"])

func _build_mara_character() -> void:
	# Behind-counter anti-fatigue riser is raised 33cm so Mara's footwear
	# really meets the floor and her face clears the high café service bar.
	_box("StaffRaisedServicePlinth", Vector3(0.0, 0.15, -7.12),
		Vector3(1.73, 0.30, 1.55), "TIMBER", Color("3e3d3d"))
	_box("RubberAntiFatigueMat", Vector3(0.0, 0.321, -7.12),
		Vector3(1.62, 0.021, 1.44), "ACOUSTIC", Color("2c3439"))
	# Artist-scoped character is streamed with the room, not left in the city.
	var mara := MaraHero.new()
	mara.name = "MaraHero"
	mara.position = Vector3(0.0, 0.33, -7.12)
	add_child(mara)
	_statistics["characters"] += 1

func get_rumor_position() -> Vector3:
	return RUMOR_POSITION

func rumor_text() -> String:
	return RUMOR_TEXT

func rumor_id() -> String:
	return RUMOR_ID

func _process(delta: float) -> void:
	_clock = fposmod(_clock + delta, 7.0)
	for i in range(_steam_nodes.size()):
		var cloud := _steam_nodes[i]
		var cycle := fposmod(_clock * 0.34 + float(i) * 0.32, 1.0)
		cloud.position.y = 2.39 + cycle * 0.85
		cloud.scale = Vector3(0.8 + cycle * 0.65, 0.75 + cycle * 0.60, 0.8 + cycle * 0.65)
		cloud.visible = cycle < 0.88

func _mat(kind: String, tint: Color) -> StandardMaterial3D:
	if kind in ["METAL", "PAVERS", "CONCRETE", "BRICK", "GLASS"]:
		return Materials.surface(kind, tint)
	var key := kind + "|" + tint.to_html(true)
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	match kind:
		"BRASS":
			result.metallic = 0.78
			result.roughness = 0.38
		"TIMBER":
			result.metallic = 0.02
			result.roughness = 0.65
		"LEATHER":
			result.metallic = 0.04
			result.roughness = 0.72
		"CERAMIC":
			result.metallic = 0.03
			result.roughness = 0.26
		"GLAZING":
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.roughness = 0.14
			result.metallic = 0.04
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
		"STEAM":
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
		"NEON":
			result.albedo_color = tint.darkened(0.70)
			result.emission_enabled = true
			result.emission = tint
			result.emission_energy_multiplier = 1.65
		"ACOUSTIC":
			result.roughness = 0.94
		_:
			result.roughness = 0.81
	_materials[key] = result
	return result

func _box(name: String, position_value: Vector3, dimensions: Vector3,
		kind: String, tint: Color, solid: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = _mat(kind, tint)
	if solid:
		var collision := StaticBody3D.new()
		collision.name = "Collision_" + name
		collision.position = position_value
		part.position = Vector3.ZERO
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		shape_node.shape = shape
		collision.add_child(shape_node)
		collision.add_child(part)
		add_child(collision)
		_statistics["collidable_furniture"] += 1
	else:
		add_child(part)
	return part

func _cylinder(name: String, position_value: Vector3, radius: float,
		height: float, kind: String, tint: Color,
		radial: int = 14) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	var part := MeshInstance3D.new()
	part.name = name
	part.position = position_value
	part.mesh = mesh
	part.material_override = _mat(kind, tint)
	add_child(part)
	return part

func _label(message: String, position_value: Vector3, tint: Color,
		size: int, rotation_value: float = 0.0) -> Label3D:
	var sign := Label3D.new()
	sign.name = "Inscription"
	sign.text = message
	sign.font_size = size
	sign.pixel_size = 0.0042
	sign.position = position_value
	sign.rotation.y = rotation_value
	sign.modulate = tint
	sign.outline_size = 6
	sign.outline_modulate = Color("101e2b")
	add_child(sign)
	return sign

func _build_material_architecture() -> void:
	# Tall wainscot, exposed glazed-brick backsplash and copper service runs.
	# The existing collidable room hull remains the true structural envelope.
	for side in [-1.0, 1.0]:
		_box("AgedWallWainscot", Vector3(side * 7.64, 0.86, 0.0),
			Vector3(0.10, 1.67, 16.5), "TIMBER", Color("413b3e"))
		_box("BrassChairRail", Vector3(side * 7.58, 1.72, 0.0),
			Vector3(0.085, 0.055, 16.6), "BRASS", BRASS)
		_box("ServiceDuct", Vector3(side * 7.35, 4.54, -1.45),
			Vector3(0.32, 0.24, 11.0), "METAL", Color("52616b"))
		for z in [-6.7, -2.8, 1.1, 5.0]:
			_box("ServiceDuctBracket", Vector3(side * 7.34, 4.58, z),
				Vector3(0.45, 0.29, 0.10), "METAL", Color("9e958c"))
	_box("GlazedBrickBehindBar", Vector3(0.0, 2.30, -8.62),
		Vector3(10.0, 2.92, 0.08), "BRICK", Color("646f70"))
	_box("BrassCounterWallRail", Vector3(0.0, 3.91, -8.56),
		Vector3(10.8, 0.11, 0.12), "BRASS", BRASS)
	# Slatted acoustic ceiling prevents the game-typical featureless black lid.
	for i in range(17):
		var z := -7.8 + float(i) * 0.90
		_box("AcousticCeilingBlade", Vector3(0.0, 5.00, z),
			Vector3(13.85, 0.16, 0.10), "ACOUSTIC", Color("394e54"))
		for side in [-1.0, 1.0]:
			_box("SlatJoinery", Vector3(side * 6.70, 4.97, z),
				Vector3(0.19, 0.18, 0.14), "BRASS", Color("837d74"))
	_box("CaféFloorInlaidThreshold", Vector3(0.0, 0.012, 6.57),
		Vector3(2.60, 0.015, 0.12), "BRASS", BRASS)
	for x in [-6.8, 6.8]:
		_box("GlowingBaseboard", Vector3(x, 0.13, -0.60),
			Vector3(0.035, 0.033, 13.8), "NEON", TEAL.darkened(0.48))
	# Feature wall is made of clear stacked translucent glass strips, not signage.
	for y in [1.80, 2.14, 2.48, 2.82, 3.16]:
		_box("CastGlassFeatureWall", Vector3(-7.53, float(y), -6.72),
			Vector3(0.055, 0.25, 2.60), "GLAZING", GLASS)
		_statistics["glass_panels"] += 1

func _build_cafe_bar() -> void:
	# Existing world room owns the functional counter and Mara's contact slot.
	# These details are fitted ABOVE it or behind it to avoid clipping collision.
	_box("BrewBarStoneTop", Vector3(0.0, 1.91, -5.74),
		Vector3(4.55, 0.065, 1.44), "PAVERS", Color("afa69e"))
	_box("EspressoSplashGuard", Vector3(0.0, 2.13, -6.42),
		Vector3(4.19, 0.45, 0.07), "GLAZING", Color(0.55, 0.66, 0.68, 0.22))
	_statistics["glass_panels"] += 1
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 1.47
		# Real group geometry: external casing, head, portafilter and drip tray.
		_box("EspressoMachineChassis", Vector3(x, 2.17, -5.80),
			Vector3(0.95, 0.62, 0.69), "METAL", Color("899b9d"))
		_box("BrewGroupHead", Vector3(x, 2.34, -5.40),
			Vector3(0.24, 0.22, 0.22), "BRASS", BRASS)
		_cylinder("PortafilterHandle", Vector3(x, 2.17, -5.26),
			0.055, 0.38, "TIMBER", Color("3f3131"))
		_box("DrainageTray", Vector3(x, 1.99, -5.32),
			Vector3(0.53, 0.055, 0.37), "METAL", Color("475b63"))
		_box("BrewPressureDisplay", Vector3(x - 0.23, 2.30, -5.40),
			Vector3(0.24, 0.18, 0.025), "NEON", Color("a3dad1"))
		_statistics["espresso_groups"] += 1
		for shelf in [2.82, 3.35]:
			_box("BackbarShelf", Vector3(x * 2.5, float(shelf), -8.21),
				Vector3(2.20, 0.11, 0.48), "TIMBER", Color("5e5147"))
			_box("ShelfCopperEdge", Vector3(x * 2.5, float(shelf), -7.94),
				Vector3(2.20, 0.038, 0.045), "BRASS", BRASS)
		# Rows of inverted cups and espresso tins behind the service bar.
		for shelf in [2.98, 3.52]:
			for i in range(6):
				_cylinder("StockedCeramicCup",
					Vector3(x * 2.5 - 0.86 + float(i) * 0.35, float(shelf), -8.18),
					0.095, 0.18, "CERAMIC", Color("cdcbbd"), 12)
				_statistics["mugs"] += 1
	# Quiet menu slate and real textual affordances remain readable at the counter.
	for idx in range(3):
		var x := -3.0 + float(idx) * 3.00
		_box("MechanicalMenuDisplay", Vector3(x, 3.48, -8.48),
			Vector3(2.68, 0.82, 0.10), "TIMBER", DEEP_INK)
		_box("MenuGlowUnderlip", Vector3(x, 3.02, -8.44),
			Vector3(2.52, 0.052, 0.08), "NEON", TEAL)
		_statistics["menu_panels"] += 1
	_label("DARK ROAST   18", Vector3(-3.0, 3.50, -8.36), Color("e1d4bf"), 35)
	_label("OAT LATTE   18", Vector3(0.0, 3.50, -8.36), Color("e1d4bf"), 35)
	_label("NIGHTSHIFT  /  MARA", Vector3(3.0, 3.50, -8.36), Color("d9c6a9"), 30)
	# Collateral and cups near the near counter edge remain visual only.
	for x in [-0.79, -0.38, 0.37, 0.82]:
		_cylinder("TakeawayCup", Vector3(x, 1.98, -5.11),
			0.087, 0.16, "CERAMIC", Color("c6c7bb"), 12)
		_statistics["mugs"] += 1
	for i in range(3):
		var cloud := _cylinder("AnimatedBrewSteam_%02d" % i,
			Vector3(-1.54 + float(i) * 0.09, 2.39, -5.42),
			0.060, 0.45, "STEAM", Color(0.75, 0.90, 0.90, 0.10), 10)
		_steam_nodes.append(cloud)
		_statistics["steam_wisps"] += 1

func _build_banquette_nooks() -> void:
	# Upholstery, woodwork and brass give architectural scale. Keep central
	# walk axis x[-1.4,+1.4] and the return doorway fully unobstructed.
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 5.77
		for z in [-3.25, 0.25, 3.78]:
			_box("BoothBackFrame", Vector3(x + side * 0.82, 0.96, float(z)),
				Vector3(0.23, 1.32, 2.35), "TIMBER", Color("423d3c"))
			_box("LeatherBanquette", Vector3(x + side * 0.31, 0.61, float(z)),
				Vector3(1.41, 0.34, 2.06), "LEATHER", Color("496269"), true)
			_box("BoothHeadRest", Vector3(x + side * 0.79, 1.31, float(z)),
				Vector3(0.23, 0.41, 1.98), "LEATHER", Color("5e7676"))
			_box("BrassBackrestTrim", Vector3(x + side * 0.74, 1.57, float(z)),
				Vector3(0.12, 0.04, 2.18), "BRASS", BRASS)
			_statistics["booths"] += 1
			_statistics["seats"] += 2
		# Feature table for the clue bench is next to the rear seating and
		# cannot block the service counter or central H door.
		_box("NookTableTop", Vector3(side * 3.54, 0.92, 3.40),
			Vector3(1.50, 0.11, 1.28), "TIMBER", Color("675a50"), true)
		_box("NookTablePedestal", Vector3(side * 3.54, 0.47, 3.40),
			Vector3(0.13, 0.81, 0.13), "BRASS", BRASS)
		_statistics["tables"] += 1
	# The optional radio-city lore clue is at the right rear booth,
	# outside the staffed counter radius and without any extra menu scene.
	_box("MaraNotesHolder", Vector3(4.91, 1.04, 3.45),
		Vector3(0.31, 0.07, 0.43), "BRASS", BRASS)
	_box("MaraNotesScreen", Vector3(4.90, 1.12, 3.45),
		Vector3(0.28, 0.025, 0.38), "NEON", TEAL.darkened(0.55))
	_label("G  /  SHIFT NOTES", Vector3(5.30, 1.70, 3.51),
		Color("bdd8c9"), 22, PI * 0.5)

func _build_furniture() -> void:
	# Six sculpted pedestal tables and coffee service; all are positioned in
	# wall-side nooks, leaving through circulation intact.
	for side in [-1.0, 1.0]:
		for z in [-2.10, 0.54, 4.12]:
			var x: float = float(side) * 3.35
			_cylinder("CastIronTableFoot", Vector3(x, 0.16, float(z)),
				0.43, 0.12, "METAL", Color("5d6567"), 16)
			_cylinder("BrassTableColumn", Vector3(x, 0.48, float(z)),
				0.081, 0.62, "BRASS", BRASS, 12)
			_cylinder("WalnutTableTop", Vector3(x, 0.83, float(z)),
				0.63, 0.12, "TIMBER", Color("8a7061"), 18)
			_statistics["tables"] += 1
			for offset in [-0.28, 0.30]:
				_cylinder("CustomerCup", Vector3(x + float(offset), 0.99, float(z)),
					0.085, 0.17, "CERAMIC", Color("d6caba"), 12)
				_statistics["mugs"] += 1
	for side in [-1.0, 1.0]:
		for z in [-5.65, 5.66]:
			var x: float = float(side) * 6.98
			_cylinder("CeramicPlanter", Vector3(x, 0.48, float(z)),
				0.44, 0.82, "CERAMIC", Color("626b64"), 12)
			_cylinder("Soil", Vector3(x, 0.90, float(z)),
				0.37, 0.07, "TIMBER", Color("36302a"), 10)
			_cylinder("PlantTrunk", Vector3(x, 1.36, float(z)),
				0.06, 0.84, "TIMBER", Color("7f6650"), 8)
			for dy in [1.60, 1.98]:
				_cylinder("LowPolyFoliage", Vector3(x, float(dy), float(z)),
					0.44 if dy < 1.9 else 0.32, 0.34,
					"ACOUSTIC", Color("4f806d"), 8)
			_statistics["planters"] += 1

func _build_lanterns_and_glazing() -> void:
	# Acoustic panels + refractive-looking alpha glass, with fixtures
	# hanging from structural anchor posts instead of floating neon cubes.
	for x in [-5.33, -2.76, 2.76, 5.33]:
		for z in [-4.1, 0.06, 4.10]:
			_cylinder("CeilingPendantCable", Vector3(float(x), 4.54, float(z)),
				0.025, 0.80, "METAL", Color("849398"), 8)
			_cylinder("SpunCopperPendant", Vector3(float(x), 4.09, float(z)),
				0.26, 0.20, "BRASS", BRASS, 14)
			_cylinder("WarmOpalDiffuser", Vector3(float(x), 3.93, float(z)),
				0.19, 0.12, "NEON", AMBER.darkened(0.17), 14)
			_statistics["pendants"] += 1
	# Front shop glazing is inset to either side of the real existing H exit
	# opening. No closed glass panel crosses the walking passage.
	for side in [-1.0, 1.0]:
		_box("StreetFacingGlazing", Vector3(side * 5.28, 2.02, 8.68),
			Vector3(2.80, 3.34, 0.045), "GLAZING", GLASS)
		_statistics["glass_panels"] += 1
		for y in [0.40, 3.66]:
			_box("WindowCopperRail", Vector3(side * 5.28, float(y), 8.61),
				Vector3(2.81, 0.063, 0.074), "BRASS", BRASS)
		for edge in [-1.0, 1.0]:
			_box("WindowBronzeMullion", Vector3(side * 5.28 + edge * 1.42, 2.02, 8.61),
				Vector3(0.075, 3.35, 0.08), "BRASS", BRASS)
	_box("LanternCupBacklight", Vector3(0.0, 4.29, -8.54),
		Vector3(7.56, 0.07, 0.07), "NEON", TEAL)

func _build_local_lighting() -> void:
	# The generic interior provides two diffuse Omni lights. These two warm
	# worklights are unshadowed and small-range to avoid expensive overlap.
	for x in [-3.12, 3.12]:
		var light := OmniLight3D.new()
		light.name = "WarmBarWorklight"
		light.position = Vector3(float(x), 3.66, -5.35)
		light.light_color = Color("ffd7a9")
		light.light_energy = 0.48
		light.omni_range = 6.5
		light.shadow_enabled = false
		add_child(light)
		_statistics["lights"] += 1

func _build_sounds() -> void:
	# The parent room's CAFE soundscape already handles venue atmosphere.
	# Add only one cached, original spatial espresso machine loop.
	var machine := AudioStreamPlayer3D.new()
	machine.name = "OriginalBaristaSteamPump"
	machine.position = Vector3(-1.47, 2.35, -5.48)
	machine.stream = CoffeeSound.sound()
	machine.volume_db = -20.0
	machine.max_distance = 13.0
	machine.unit_size = 2.8
	add_child(machine)
	machine.play()
	_statistics["original_audio_sources"] += 1
