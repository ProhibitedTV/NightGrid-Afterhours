extends Node3D
const AudioMix = preload("res://scripts/audio_mix.gd")
const Satire=preload("res://scripts/street_satire.gd")
const SOUNDCHECK="soundcheck_pass"
const MUSIC_REPUTATION=100
const PocketBeat=preload("res://assets/instruments/pocketbeat_m3.glb")
var _sampler_display:Node3D
const Breaker=preload("res://assets/instruments/ironwake_breaker_g6.glb")
const Dredge=preload("res://assets/instruments/ironwake_dredge_b4.glb")
var _string_display:Node3D
## Morrow Bay's authored social hubs: fixed addresses, opening hours, readable
## streetfront set dressing, services and four directed side-story contracts.
## The seed never changes a venue's address, contact or narrative identity.
const Materials = preload("res://scripts/material_library.gd")
const WorldPlan = preload("res://scripts/world_plan.gd")
const VenueAmbience = preload("res://scripts/venue_ambience.gd")
const CELL = 58.0
const INTERACT_RANGE = 5.5

const VENUES = [
	{"id": "insert_coin", "name": "INSERT COIN", "kind": "ARCADE", "ix": 1, "iz": 2, "side": 0, "opens": 14.0, "closes": 3.0, "price": 0, "host": "Rook", "flavor": "Independent games. No shareholders. No server required.", "item": "Free practice"},
	{"id": "moon_noodles", "name": "MOON NOODLES", "kind": "STALL", "ix": -3, "iz": -3, "side": 0, "opens": 11.0, "closes": 2.0, "price": 16, "host": "Auntie Sol", "flavor": "Steam, star anise and courier gossip.", "item": "Hot noodle bowl"},
	{"id": "lantern_cup", "name": "LANTERN CUP", "kind": "CAFE", "ix": -2, "iz": -3, "side": 1, "opens": 6.0, "closes": 22.0, "price": 18, "host": "Mara", "flavor": "Half the neighborhood runs on its dark roast.", "item": "Double espresso"},
	{"id": "ink_tonic", "name": "INK & TONIC", "kind": "BAR", "ix": -1, "iz": -1, "side": 0, "opens": 17.0, "closes": 3.0, "price": 24, "host": "The Archivist", "flavor": "Quiet booths and stories that never reach the police.", "item": "An anonymous introduction"},
	{"id": "helix_espresso", "name": "HELIX ESPRESSO", "kind": "CAFE", "ix": 0, "iz": -3, "side": 1, "opens": 5.0, "closes": 20.0, "price": 20, "host": "Ev", "flavor": "Perfect pours beneath the corporate rail.", "item": "Recovery coffee"},
	{"id": "afterimage", "name": "AFTERIMAGE LOUNGE", "kind": "BAR", "ix": 1, "iz": -2, "side": 0, "opens": 18.0, "closes": 4.0, "price": 30, "host": "Iris", "flavor": "Deals are made over glass and broken projections.", "item": "Low-profile meeting"},
	{"id": "prism_club", "name": "PRISM CLUB", "kind": "CLUB", "ix": 2, "iz": -1, "side": 1, "opens": 20.0, "closes": 5.0, "price": 38, "host": "DJ Lumen", "flavor": "A bass-heavy refuge from corporate schedules.", "item": "Quiet-room cover"},
	{"id": "dock_nine", "name": "DOCK NINE SOCIAL", "kind": "BAR", "ix": -3, "iz": 0, "side": 0, "opens": 15.0, "closes": 2.0, "price": 22, "host": "Old Ren", "flavor": "Shift workers trade stories under copper lamps.", "item": "Safehouse tip"},
	{"id": "furnace_skewers", "name": "FURNACE SKEWERS", "kind": "STALL", "ix": -2, "iz": 1, "side": 1, "opens": 12.0, "closes": 1.0, "price": 17, "host": "Nell", "flavor": "Charcoal smoke and stubborn neighborhood pride.", "item": "Midnight skewers"},
	{"id": "copper_cup", "name": "COPPER CUP", "kind": "CAFE", "ix": -1, "iz": 2, "side": 0, "opens": 6.0, "closes": 19.0, "price": 15, "host": "Hal", "flavor": "A tiny espresso counter built from scrap brass.", "item": "Restorative coffee"},
	{"id": "static_room", "name": "STATIC ROOM", "kind": "CLUB", "ix": 2, "iz": 1, "side": 0, "opens": 21.0, "closes": 5.0, "price": 45, "host": "Nyx", "flavor": "No cameras. One unforgettable wall of violet light.", "item": "Anonymous floor pass"},
	{"id": "neon_bao", "name": "NEON BAO", "kind": "STALL", "ix": 0, "iz": 1, "side": 1, "opens": 14.0, "closes": 4.0, "price": 19, "host": "Jun", "flavor": "A midnight counter where even rivals share a table.", "item": "Steamed bao"},
	{"id": "blue_hour", "name": "BLUE HOUR", "kind": "CLUB", "ix": 2, "iz": 2, "side": 0, "opens": 19.0, "closes": 4.0, "price": 35, "host": "Rae", "flavor": "Live light sculptures over a sunken dance floor.", "item": "Back-door discretion"}
]

const SIDE_JOBS = [
	{"id": "midnight_thermos", "title": "THE MIDNIGHT THERMOS", "from": "moon_noodles", "to": "copper_cup", "reward": 180,
		"brief": "Auntie Sol needs a sealed thermos delivered to Hal before the next shift.", "ending": "Hal takes the thermos. The dock workers get breakfast after all."},
	{"id": "dead_frequency", "title": "DEAD FREQUENCY", "from": "ink_tonic", "to": "static_room", "reward": 265,
		"brief": "Carry an analog recording to Nyx. Keep it off the public data grid.", "ending": "Nyx recognizes the voice on the recording and pays for discretion."},
	{"id": "glass_invoice", "title": "THE GLASS INVOICE", "from": "afterimage", "to": "dock_nine", "reward": 230,
		"brief": "A private receipt shows who is buying the district's power rights.", "ending": "Old Ren files the invoice where the corporation cannot rewrite it."},
	{"id": "last_shift_recipe", "title": "LAST SHIFT RECIPE", "from": "furnace_skewers", "to": "neon_bao", "reward": 150,
		"brief": "Nell wants Jun to try her late father's recipe before the market closes.", "ending": "Jun puts the recipe on the menu. The old district lives another night."},
	{"id":"soundcheck_pass","title":"SOUNDCHECK PASS","from":"static_room","to":"blue_hour","reward":125,"min_cred":MUSIC_REPUTATION}
]

const KIND_COLOR = {
	"STALL": Color("f6ac68"),
	"CAFE": Color("85cad0"),
	"BAR": Color("e2a0a3"),
	"CLUB": Color("db80e8"),
	"ARCADE": Color("72d7cf")
}

var _nodes: Dictionary = {}
var _sign_materials: Dictionary = {}
var _open_labels: Dictionary = {}
var _patrons: Dictionary = {}
var _lights: Array[OmniLight3D] = []
var _focus := Vector3.ZERO
var _hour := 19.25
var _refresh_timer := 0.0
var _map_pins: Array[Dictionary] = []
var _ambience: Dictionary = {}

func _ready() -> void:
	for venue in VENUES:
		_build_venue(venue)
	for index in range(2):
		var pool_light := OmniLight3D.new()
		pool_light.name = "LocalVenueLight_%d" % index
		pool_light.omni_range = 13.0
		pool_light.light_energy = 0.0
		pool_light.shadow_enabled = false
		pool_light.visible = false
		add_child(pool_light)
		_lights.append(pool_light)
	_refresh()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 0.45:
		_refresh_timer = 0.0
		_refresh()

func set_focus(position: Vector3) -> void:
	_focus = position

func set_hour(hour: float) -> void:
	_hour = fposmod(hour, 24.0)
	_refresh()

func get_map_pins() -> Array[Dictionary]:
	return _map_pins

func witness_candidates(target: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for venue_id in _patrons:
		for patron in _patrons[venue_id]:
			var p := patron as Node3D
			if p.is_visible_in_tree() and p.global_position.distance_squared_to(target) <= 30.0 * 30.0:
				# Exterior patrons are authored with their faces toward -Z.
				result.append({"eye": p.global_position + Vector3.UP * 1.56, "facing": -p.global_basis.z, "police": false})
	return result

func get_venue_count() -> int:
	return _nodes.size()

func venue_by_id(venue_id: String) -> Dictionary:
	for venue in VENUES:
		if str(venue["id"]) == venue_id:
			return venue
	return {}

func job_by_id(job_id: String) -> Dictionary:
	for job in SIDE_JOBS:
		if str(job["id"]) == job_id:
			return _job_details(job)
	return {}

func job_from(venue_id: String) -> Dictionary:
	for job in SIDE_JOBS:
		if str(job["from"]) == venue_id:
			return _job_details(job)
	return {}

func venue_position(venue_id: String) -> Vector3:
	var venue := venue_by_id(venue_id)
	if venue.is_empty():
		return Vector3.ZERO
	var center := Vector3((float(venue["ix"]) + 0.5) * CELL, 0.0,
		(float(venue["iz"]) + 0.5) * CELL)
	var x := -10.5 if int(venue["side"]) == 0 else 10.5
	# The curbside interaction point is on the authored sidewalk, not in traffic.
	return center + Vector3(x, 1.15, -19.3)

func nearest_venue(at: Vector3, radius: float = INTERACT_RANGE) -> Dictionary:
	var selected := {}
	var minimum := radius
	for venue in VENUES:
		var point := venue_position(str(venue["id"]))
		var distance := Vector2(at.x - point.x, at.z - point.z).length()
		if distance <= minimum:
			minimum = distance
			selected = venue
	return selected

func is_open(venue_id: String, hour: float = -1.0) -> bool:
	var venue := venue_by_id(venue_id)
	if venue.is_empty():
		return false
	var now := _hour if hour < 0.0 else fposmod(hour, 24.0)
	var opens: float = venue["opens"]
	var closes: float = venue["closes"]
	if opens < closes:
		return now >= opens and now < closes
	return now >= opens or now < closes

func get_lighting_state(venue_id: String) -> Dictionary:
	var material: StandardMaterial3D = _sign_materials.get(venue_id)
	return {"open": is_open(venue_id), "energy": material.emission_energy_multiplier if material != null else -1.0}

func get_soundscape_count() -> int:
	return VenueAmbience.soundscape_count()

func get_audio_player_count() -> int:
	return _ambience.size()

func get_active_audio_count() -> int:
	var count := 0
	for player in _ambience.values():
		if (player as AudioStreamPlayer3D).playing:
			count += 1
	return count

func get_active_light_count() -> int:
	var total := 0
	for lamp in _lights:
		if lamp.visible:
			total += 1
	return total

func service_effect(kind: String) -> Dictionary:
	match kind:
		"STALL":
			return {"heal": 28.0, "heat": 0.0}
		"CAFE":
			return {"heal": 20.0, "heat": 0.0}
		"BAR":
			return {"heal": 0.0, "heat": 0.65}
		"CLUB":
			return {"heal": 0.0, "heat": 1.0}
	return {"heal": 0.0, "heat": 0.0}

func _build_venue(venue: Dictionary) -> void:
	var venue_id: String = venue["id"]
	var kind: String = venue["kind"]
	var accent: Color = KIND_COLOR[kind]
	var sidewalk := venue_position(venue_id)
	var front := Node3D.new()
	front.name = venue_id
	front.position = sidewalk + Vector3(0.0, -1.15, 2.3)
	add_child(front)
	_nodes[venue_id] = front
	_map_pins.append({
		"id": venue_id,
		"point": Vector2(sidewalk.x, sidewalk.z),
		"kind": kind,
		"open": false
	})
	# Pad, facade, lightbox and close-up pavement details form an authored
	# sidewalk vignette. No new collision body obstructs pedestrian movement.
	_box(front, Vector3(0.0, 0.19, -0.5), Vector3(8.4, 0.09, 5.3), Color("3d4350"), "PAVERS")
	if venue_id != "helix_espresso":
		_box(front, Vector3(0.0, 2.35, 2.12), Vector3(8.5, 4.2, 0.22), Color("243146"))
	_box(front, Vector3(0.0, 4.25, 1.82), Vector3(8.3, 0.95, 0.24), Color("172335"))
	var neon := StandardMaterial3D.new()
	neon.albedo_color = accent
	neon.emission_enabled = true
	neon.emission = accent
	neon.emission_energy_multiplier = 0.0
	neon.metallic = 0.20
	neon.roughness = 0.4
	_sign_materials[venue_id] = neon
	_box(front, Vector3(0.0, 4.75, 1.55), Vector3(8.4, 0.09, 0.18), accent, "", neon)
	_box(front, Vector3(0.0, 3.75, 1.55), Vector3(8.4, 0.10, 0.18), accent, "", neon)
	_label(front, str(venue["name"]), Vector3(0.0, 4.24, 1.45), accent, 51)
	_label(front, str(venue["host"]) + "  /  " + kind,
		Vector3(0.0, 3.45, 1.46), Color("b6c8d3"), 24)
	var hours := _make_label(front, "OPEN", Vector3(3.0, 2.32, 1.34), accent, 21)
	_open_labels[venue_id] = hours
	match kind:
		"STALL":
			_build_stall(front, accent, neon)
		"CAFE":
			# Physical Helix lobby replaces the visual-only sidewalk counter.
			if venue_id != "helix_espresso":
				_build_cafe(front, accent, neon)
			if venue_id=="copper_cup":
				_sampler_display=PocketBeat.instantiate() as Node3D
				_sampler_display.name="PocketBeatConsignment"
				_sampler_display.position=Vector3(0.45,1.676,0.57)
				_sampler_display.rotation.y=deg_to_rad(12.0)
				front.add_child(_sampler_display)
				_build_ironwake_display(front)
			if venue_id == "lantern_cup":
				_build_lantern_cup_streetfront(front, accent, neon)
		"BAR":
			_build_bar(front, accent, neon)
		"CLUB":
			_build_club(front, accent, neon)
	# District atmosphere: restrained silhouettes, scratched tile and tiny
	# pieces of lived-in furniture. All art is original primitive geometry.
	_box(front, Vector3(-3.75, 0.24, -1.55), Vector3(0.65, 0.14, 0.64), Color("6d7784"))
	_box(front, Vector3(3.7, 0.24, -1.55), Vector3(0.64, 0.14, 0.65), Color("6d7784"))
	var patrons: Array[Node3D] = []
	for i in range(2 if kind != "CLUB" else 4):
		var x := -3.2 + float(i) * 1.3
		var patron := _build_patron(front, Vector3(x, 0.3, -2.1), kind, i)
		patrons.append(patron)
	_patrons[venue_id] = patrons
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Atmosphere"
	AudioMix.ensure()
	audio.bus = AudioMix.OUTSIDE_BEDS
	audio.position = Vector3(0.0, 1.9, 0.0)
	audio.stream = VenueAmbience.soundscape("BAR" if kind == "ARCADE" else kind)
	audio.max_distance = 28.0
	audio.unit_size = 5.0
	audio.volume_db = -17.0 if kind != "CLUB" else -14.5
	front.add_child(audio)
	_ambience[venue_id] = audio

func _build_stall(root: Node3D, accent: Color, neon: StandardMaterial3D) -> void:
	_box(root, Vector3(0.0, 2.85, -0.65), Vector3(7.7, 0.18, 3.35), accent)
	_box(root, Vector3(0.0, 2.67, -2.12), Vector3(7.4, 0.16, 0.15), accent, "", neon)
	for x in [-3.25, 3.25]:
		_box(root, Vector3(x, 1.48, -2.1), Vector3(0.15, 2.8, 0.17), Color("a0a8ad"))
	_box(root, Vector3(0.0, 1.25, -0.60), Vector3(6.3, 0.93, 1.12), Color("6b5860"), "METAL")
	_box(root, Vector3(-1.2, 1.73, -0.87), Vector3(2.25, 0.13, 0.95), Color("343944"), "METAL")
	for x in [-2.2, -1.25, -0.30, 0.65, 1.6]:
		_box(root, Vector3(x, 1.90, -0.89), Vector3(0.35, 0.26, 0.36), Color("efd7a6"))
	for x in [-2.7, 2.7]:
		_box(root, Vector3(x, 2.46, -2.20), Vector3(0.43, 0.56, 0.45), accent, "", neon)
	_box(root, Vector3(2.4, 0.68, 0.55), Vector3(1.4, 1.14, 1.0), Color("807763"))
	_box(root, Vector3(2.4, 1.35, 0.55), Vector3(1.5, 0.12, 1.1), Color("3a4144"))

func _build_cafe(root: Node3D, accent: Color, neon: StandardMaterial3D) -> void:
	_box(root, Vector3(0.0, 3.05, -0.48), Vector3(8.1, 0.18, 3.1), Color("697c83"))
	_box(root, Vector3(0.0, 2.85, -2.0), Vector3(7.6, 0.13, 0.15), accent, "", neon)
	_box(root, Vector3(0.0, 1.2, 0.75), Vector3(5.6, 0.95, 1.05), Color("87796c"))
	_box(root, Vector3(1.80, 1.85, 0.16), Vector3(1.2, 0.53, 0.74), Color("596b73"), "METAL")
	for i in range(4):
		var x := -2.0 + float(i) * 0.68
		_box(root, Vector3(x, 1.83, 0.12), Vector3(0.26, 0.24, 0.28), Color("f4dfb4"))
		_box(root, Vector3(x, 1.97, 0.12), Vector3(0.35, 0.07, 0.34), accent)
	for x in [-2.0, 2.0]:
		_box(root, Vector3(x, 0.75, -1.67), Vector3(1.25, 0.14, 1.15), Color("aa8774"))
		_box(root, Vector3(x, 0.42, -1.67), Vector3(0.18, 0.6, 0.18), Color("485c65"))
	_box(root, Vector3(-3.4, 0.66, 0.75), Vector3(0.95, 1.1, 0.95), Color("3a5360"))
	_box(root, Vector3(-3.4, 1.37, 0.75), Vector3(0.9, 0.75, 0.9), Color("548d78"))

func _build_lantern_cup_streetfront(front: Node3D, accent: Color,
		neon: StandardMaterial3D) -> void:
	# A recognisable piece of the real Vesper Market street, not an unplaced
	# showcase. All artwork is static, original and safe for existing H/G input.
	var cafe := Node3D.new()
	cafe.name = "LanternCupStreetfront"
	front.add_child(cafe)
	var copper := Color("b38b6b")
	var steel := Color("3f5765")
	for side in [-1.0, 1.0]:
		# Recessed shopfront glazing. The center remains an open H entry way,
		# with gold door handles, exterior floor drain and readable signage.
		var window := MeshInstance3D.new()
		window.name = "TranslucentStreetWindow"
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(2.31, 2.42, 0.045)
		window.mesh = window_mesh
		window.position = Vector3(side * 2.85, 2.02, 1.68)
		var tinted := StandardMaterial3D.new()
		tinted.albedo_color = Color(0.30, 0.48, 0.55, 0.42)
		tinted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tinted.cull_mode = BaseMaterial3D.CULL_DISABLED
		tinted.roughness = 0.15
		window.material_override = tinted
		cafe.add_child(window)
		for arch_x in [1.57, 4.1]:
			_box(cafe, Vector3(side * float(arch_x), 2.04, 1.60),
				Vector3(0.085, 2.6, 0.10), copper, "METAL")
		for transom in [0.77, 3.29]:
			_box(cafe, Vector3(side * 2.85, float(transom), 1.60),
				Vector3(2.41, 0.10, 0.11), steel, "METAL")
		_box(cafe, Vector3(side * 1.48, 2.05, 1.56),
			Vector3(0.092, 3.0, 0.15), copper, "METAL")
		_box(cafe, Vector3(side * 1.28, 1.34, 1.47),
			Vector3(0.045, 0.27, 0.09), Color("e3c597"), "METAL")
		# Lanterns have actual supports, warmer copper housings and lenses.
		for z in [-1.70, -0.06]:
			_box(cafe, Vector3(side * 3.16, 3.15, float(z)),
				Vector3(0.075, 0.31, 0.08), copper, "METAL")
			_box(cafe, Vector3(side * 3.16, 2.91, float(z)),
				Vector3(0.41, 0.16, 0.41), copper, "METAL")
			_box(cafe, Vector3(side * 3.16, 2.75, float(z)),
				Vector3(0.29, 0.24, 0.29), accent, "", neon)
		_box(cafe, Vector3(side * 3.55, 0.13, -1.64),
			Vector3(0.45, 0.10, 1.0), Color("71898d"), "PAVERS")
		# Planter frames avoid the H doorway and remain non-colliding.
		_box(cafe, Vector3(side * 4.0, 0.47, -2.18),
			Vector3(0.52, 0.75, 0.53), Color("53645e"), "CONCRETE")
		_box(cafe, Vector3(side * 4.0, 1.09, -2.18),
			Vector3(0.45, 0.71, 0.42), Color("4e8b75"))
	# Authored double-frame doorway is deliberately passable in the room
	# transition model, with neutral light, front-of-house words and pricing.
	_box(cafe, Vector3(0.0, 3.41, 1.62),
		Vector3(3.05, 0.12, 0.18), copper, "METAL")
	_box(cafe, Vector3(0.0, 2.82, 1.63),
		Vector3(2.54, 0.08, 0.12), accent, "", neon)
	_label(cafe, "LANTERN CUP  /  MARA",
		Vector3(0.0, 3.00, 1.49), Color("e4d4b9"), 27)
	_label(cafe, "H  /  ENTER     G  /  ORDER",
		Vector3(0.0, 1.72, 1.45), Color("b4d9d2"), 23)
	_label(cafe, "LAST POUR 22:00  //  VESPER",
		Vector3(0.0, 0.66, 1.45), Color("d0b49e"), 20)

func _build_bar(root: Node3D, accent: Color, neon: StandardMaterial3D) -> void:
	_box(root, Vector3(0.0, 1.12, -0.04), Vector3(7.4, 1.06, 1.05), Color("674b56"))
	_box(root, Vector3(0.0, 1.71, -0.24), Vector3(7.6, 0.17, 1.25), Color("b48d79"))
	for shelf in [2.2, 2.8]:
		_box(root, Vector3(0.0, shelf, 1.58), Vector3(6.8, 0.12, 0.42), Color("9c6e63"))
		for i in range(9):
			var x := -2.9 + float(i) * 0.72
			var color := Color("73b4b4") if i % 3 == 0 else (Color("cf9a80") if i % 3 == 1 else Color("ad8eb5"))
			_box(root, Vector3(x, shelf + 0.29, 1.43), Vector3(0.21, 0.51, 0.22), color)
	for x in [-2.55, -0.85, 0.85, 2.55]:
		_box(root, Vector3(x, 0.78, -1.38), Vector3(0.74, 0.14, 0.65), Color("455c65"))
		_box(root, Vector3(x, 0.40, -1.38), Vector3(0.12, 0.70, 0.12), Color("8b9799"))
	_box(root, Vector3(0.0, 2.04, -0.95), Vector3(6.7, 0.09, 0.16), accent, "", neon)

func _build_club(root: Node3D, accent: Color, neon: StandardMaterial3D) -> void:
	_box(root, Vector3(-3.5, 2.1, 0.66), Vector3(0.55, 4.1, 1.45), Color("253046"))
	_box(root, Vector3(3.5, 2.1, 0.66), Vector3(0.55, 4.1, 1.45), Color("253046"))
	for x in [-3.5, 3.5]:
		_box(root, Vector3(x, 2.2, -0.22), Vector3(0.12, 4.1, 0.12), accent, "", neon)
		_box(root, Vector3(x, 0.57, -1.30), Vector3(0.8, 1.05, 0.8), Color("191f35"))
	_box(root, Vector3(0.0, 2.35, 0.92), Vector3(3.8, 3.2, 0.16), Color("25223d"))
	_box(root, Vector3(0.0, 3.93, -0.33), Vector3(6.0, 0.14, 0.18), accent, "", neon)
	for segment in range(7):
		var x := (float(segment) - 3.0) * 0.72
		_box(root, Vector3(x, 1.35 + float(segment % 3) * 0.28, -0.60),
			Vector3(0.35, 1.55 + float(segment % 3) * 0.55, 0.12), accent, "", neon)
	for x in [-2.9, 2.9]:
		_box(root, Vector3(x, 0.55, -2.0), Vector3(0.14, 1.1, 0.14), Color("b7a0b9"))
		_box(root, Vector3(x, 1.08, -2.0), Vector3(1.3, 0.08, 0.20), Color("d9b2cc"))
	_box(root, Vector3(0.0, 0.27, -2.0), Vector3(3.4, 0.14, 1.25), Color("58566c"))

func _build_patron(parent: Node3D, at: Vector3, kind: String, index: int) -> Node3D:
	var patron := Node3D.new()
	patron.position = at
	parent.add_child(patron)
	var coat := Color("354052") if index % 2 == 0 else Color("5a4354")
	_box(patron, Vector3(0.0, 0.92, 0.0), Vector3(0.49, 1.0, 0.33), coat)
	_box(patron, Vector3(0.0, 1.56, 0.0), Vector3(0.39, 0.38, 0.36), Color("c6a08b"))
	if kind == "CLUB":
		_box(patron, Vector3(0.0, 0.98, -0.19), Vector3(0.38, 0.10, 0.07), KIND_COLOR[kind])
	return patron

func _make_label(parent: Node3D, contents: String, at: Vector3, color: Color, point_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = contents
	label.position = at
	label.rotation.y = PI
	label.font_size = point_size
	label.pixel_size = 0.010
	label.modulate = color
	label.outline_size = 7
	label.outline_modulate = Color("101623")
	label.double_sided = true
	parent.add_child(label)
	return label

func _label(parent: Node3D, contents: String, at: Vector3, color: Color, point_size: int) -> void:
	_make_label(parent, contents, at, color, point_size)

func _box(parent: Node3D, at: Vector3, size: Vector3, tint: Color, surface_kind: String = "",
	shared_material: Material = null) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	if shared_material != null:
		visual.material_override = shared_material
	elif not surface_kind.is_empty():
		visual.material_override = Materials.surface(surface_kind, tint)
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 0.72
		visual.material_override = material
	parent.add_child(visual)

func _night_factor() -> float:
	if _hour >= 17.5:
		return smoothstep(17.5, 20.0, _hour)
	if _hour < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, _hour)
	return 0.0

func _refresh() -> void:
	if is_instance_valid(_sampler_display):
		_sampler_display.visible=is_open("copper_cup") and venue_position("copper_cup").distance_squared_to(_focus)<35.0*35.0
	if is_instance_valid(_string_display):
		_string_display.visible=is_open("copper_cup") and venue_position("copper_cup").distance_squared_to(_focus)<25.0*25.0
	var darkness := _night_factor()
	var nearby: Array[Dictionary] = []
	for pin in _map_pins:
		pin["open"] = is_open(str(pin["id"]))
	for venue in VENUES:
		var venue_id: String = venue["id"]
		var open_now := is_open(venue_id)
		var material: StandardMaterial3D = _sign_materials[venue_id]
		material.emission_energy_multiplier = (0.17 + 2.15 * darkness) if open_now else (0.045 + 0.16 * darkness)
		var label: Label3D = _open_labels[venue_id]
		label.text = "OPEN" if open_now else "CLOSED"
		label.modulate = KIND_COLOR[str(venue["kind"])] if open_now else Color("718293")
		var patrons: Array = _patrons[venue_id]
		for patron in patrons:
			(patron as Node3D).visible = open_now
		var sound_position := venue_position(venue_id)
		var sound_distance := Vector2(sound_position.x - _focus.x, sound_position.z - _focus.z).length()
		var nearby_audio := open_now and sound_distance < 26.0
		var ambient_player: AudioStreamPlayer3D = _ambience[venue_id]
		if nearby_audio and not ambient_player.playing:
			ambient_player.play()
		elif not nearby_audio and ambient_player.playing:
			ambient_player.stop()
		if open_now and darkness > 0.02:
			var point := venue_position(venue_id)
			var distance := Vector2(point.x - _focus.x, point.z - _focus.z).length()
			if distance < 34.0:
				nearby.append({"distance": distance, "position": point, "color": KIND_COLOR[str(venue["kind"])]})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for index in range(_lights.size()):
		var lamp := _lights[index]
		lamp.visible = index < nearby.size()
		if lamp.visible:
			lamp.global_position = nearby[index]["position"] + Vector3(0.0, 3.4, 1.5)
			lamp.light_color = nearby[index]["color"]
			lamp.light_energy = 0.75 * darkness
		else:
			lamp.light_energy = 0.0

func job_unlocked(job:Dictionary,cred:int)->bool:
	return not job.is_empty() and cred>=int(job.get("min_cred",0))

static func _job_details(job:Dictionary)->Dictionary:
	var result:=job.duplicate()
	if result["id"]==SOUNDCHECK:
		for beat in ["brief","ending"]:
			result[beat]=Satire.venue_job_line(SOUNDCHECK,beat)["text"]
	return result

## Static consignment wall display, not player inventory. Meter-scale imported
## assets share existing frontage lighting; no new collision or processing.
func _build_ironwake_display(front:Node3D)->void:
	_string_display=Node3D.new()
	_string_display.name="IronwakeConsignment"
	front.add_child(_string_display)
	for i in range(2):
		var model:Node3D=(Breaker if i==0 else Dredge).instantiate() as Node3D
		model.name="BreakerG6" if i==0 else "DredgeB4"
		model.position=Vector3(3.05+float(i)*0.64,0.88,1.91)
		model.rotation.y=PI
		_string_display.add_child(model)
	_label(_string_display,"IRONWAKE / DISPLAY ONLY",Vector3(3.37,2.18,1.77),Color("b9a48d"),15)
