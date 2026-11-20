extends Node3D
## One active, enterable room at a time. Exterior address/quest identity is
## authored; transient geometry is allocated on entry and freed on exit.
## This is a separate interior space, not a cut-through doorway in building mesh.
const Materials = preload("res://scripts/material_library.gd")
const VenueAmbience = preload("res://scripts/venue_ambience.gd")
const LanternCupHero = preload("res://scripts/lantern_cup_hero.gd")
const HumanoidVisual = preload("res://scripts/humanoid_visual.gd")
const ORIGIN = Vector3(950.0, 0.0, 950.0)
const ENTRY_POINT = ORIGIN + Vector3(0.0, 1.18, 5.8)
const EXIT_POINT = ORIGIN + Vector3(0.0, 1.18, 6.9)
const COUNTER_POINT = ORIGIN + Vector3(0.0, 1.18, -3.45)
const COUNTER_RADIUS = 5.6
const EXIT_RADIUS = 4.8
var active_id := ""
var active_group := ""
var exterior_position := Vector3.ZERO
var _room: Node3D
var _material_cache: Dictionary = {}
var _created := 0
var _freed := 0

func is_inside() -> bool:
	return not active_id.is_empty()

func active_site_id() -> String:
	return active_id

func active_site_group() -> String:
	return active_group

func get_entry_point() -> Vector3:
	return ENTRY_POINT

func get_counter_point() -> Vector3:
	return COUNTER_POINT

func get_exit_point() -> Vector3:
	return EXIT_POINT

func counter_reachable(at: Vector3) -> bool:
	return is_inside() and at.distance_to(COUNTER_POINT) <= COUNTER_RADIUS

func exit_reachable(at: Vector3) -> bool:
	return is_inside() and at.distance_to(EXIT_POINT) <= EXIT_RADIUS

func get_patron_manifest() -> Array:
	if active_id != "lantern_cup" or active_group != "VENUE" or _room == null:
		return []
	var hero := _room.get_node_or_null("LanternCupHero")
	return hero.call("get_patron_manifest") if hero != null else []

func patron_near(at: Vector3) -> Dictionary:
	if active_id != "lantern_cup" or active_group != "VENUE" or _room == null:
		return {}
	var hero := _room.get_node_or_null("LanternCupHero")
	return hero.call("patron_near", _room.to_local(at)) if hero != null else {}

func talk_to_patron(at: Vector3, context: Dictionary) -> Dictionary:
	if active_id != "lantern_cup" or active_group != "VENUE" or _room == null:
		return {}
	var hero := _room.get_node_or_null("LanternCupHero")
	return hero.call("patron_dialogue", _room.to_local(at), context) if hero != null else {}

func get_mara_character() -> Node3D:
	if active_id != "lantern_cup" or active_group != "VENUE" or _room == null:
		return null
	return _room.get_node_or_null("LanternCupHero/MaraHero")

func get_mara_stats() -> Dictionary:
	var mara := get_mara_character()
	return mara.call("get_character_stats") if mara != null else {}

func mara_greeting(context: Dictionary) -> String:
	var mara := get_mara_character()
	return str(mara.call("greeting", context)) if mara != null else ""

func mara_talk(context: Dictionary) -> Dictionary:
	var mara := get_mara_character()
	return mara.call("next_dialogue", context) if mara != null else {}

func set_mara_attention(active: bool) -> void:
	var mara := get_mara_character()
	if mara != null:
		mara.call("set_attention", active)

func set_mara_focus(at: Vector3) -> void:
	var mara := get_mara_character()
	if mara != null:
		mara.call("set_look_target", at)

func mara_purchase_reaction() -> void:
	var mara := get_mara_character()
	if mara != null:
		mara.call("react_to_purchase")

func mara_discovery_reaction() -> void:
	var mara := get_mara_character()
	if mara != null:
		mara.call("react_to_discovery")

func get_hero_metrics() -> Dictionary:
	if active_id != "lantern_cup" or _room == null:
		return {}
	var hero := _room.get_node_or_null("LanternCupHero")
	return hero.call("get_visual_stats") if hero != null else {}

func get_hero_rumor_point() -> Vector3:
	return ORIGIN + LanternCupHero.RUMOR_POSITION

func inspect_hero_rumor(at: Vector3) -> Dictionary:
	if active_id != "lantern_cup" or active_group != "VENUE" or _room == null:
		return {}
	if at.distance_to(get_hero_rumor_point()) > 2.0:
		return {}
	var hero := _room.get_node_or_null("LanternCupHero")
	if hero == null:
		return {}
	return {"id": str(hero.call("rumor_id")), "text": str(hero.call("rumor_text"))}

func get_metrics() -> Dictionary:
	return {"loaded_rooms": 1 if _room != null else 0,
		"created": _created, "freed": _freed,
		"active": active_id, "group": active_group}

func snapshot() -> Dictionary:
	if not is_inside():
		return {}
	return {"id": active_id, "group": active_group,
		"outside": [exterior_position.x, exterior_position.y, exterior_position.z]}

func enter(site: Dictionary, group: String, outside: Vector3) -> Vector3:
	assert(group == "VENUE" or group == "CIVIC")
	if _room != null:
		_clear_room()
	active_id = str(site["id"])
	active_group = group
	exterior_position = outside
	_build_room(site)
	return ENTRY_POINT

func leave() -> Vector3:
	var outdoors := exterior_position
	_clear_room()
	active_id = ""
	active_group = ""
	exterior_position = Vector3.ZERO
	return outdoors

func restore(saved: Dictionary, site: Dictionary) -> bool:
	if site.is_empty() or saved.is_empty():
		return false
	var group := str(saved.get("group", ""))
	if group != "VENUE" and group != "CIVIC":
		return false
	var previous = saved.get("outside", [])
	if not previous is Array or previous.size() != 3:
		return false
	var point := Vector3(float(previous[0]), float(previous[1]), float(previous[2]))
	enter(site, group, point)
	return true

func _clear_room() -> void:
	if _room != null:
		_room.queue_free()
		_room = null
		_freed += 1

func _build_room(site: Dictionary) -> void:
	var kind: String = str(site["kind"])
	var accent := _kind_color(kind)
	var room := Node3D.new()
	room.name = "Interior_" + str(site["id"])
	room.position = ORIGIN
	add_child(room)
	_room = room
	_created += 1
	# Architectural shell: load-bearing floor, solid back/side walls,
	# segmented front wall with an explicit three-meter passage.
	_box(room, Vector3(0.0, -0.17, 0.0), Vector3(16.0, 0.34, 18.0), Color("4c535b"), true, "PAVERS")
	_box(room, Vector3(0.0, 5.25, 0.0), Vector3(16.1, 0.35, 18.1), Color("202d3e"), true)
	_box(room, Vector3(-7.87, 2.50, 0.0), Vector3(0.30, 5.25, 18.0), Color("414e5c"), true)
	_box(room, Vector3(7.87, 2.50, 0.0), Vector3(0.30, 5.25, 18.0), Color("414e5c"), true)
	_box(room, Vector3(0.0, 2.50, -8.9), Vector3(16.0, 5.2, 0.30), Color("2d3a49"), true)
	for side in [-4.65, 4.65]:
		_box(room, Vector3(side, 2.45, 8.9), Vector3(6.55, 5.1, 0.30), Color("2e3d4e"), true)
	_box(room, Vector3(0.0, 4.38, 8.9), Vector3(3.0, 1.25, 0.30), Color("344858"), true)
	for side in [-1.55, 1.55]:
		_box(room, Vector3(side, 2.0, 8.9), Vector3(0.18, 3.2, 0.25), accent)
	_box(room, Vector3(0.0, 0.22, 7.15), Vector3(3.4, 0.08, 1.35), accent)
	# A narrow protected walking axis leads from door to staffed counter.
	_box(room, Vector3(0.0, 0.08, 0.20), Vector3(2.75, 0.08, 14.5), Color("6a6870"))
	_box(room, Vector3(0.0, 1.02, -5.65), Vector3(4.1, 1.35, 1.15), Color("66747a"), true)
	_box(room, Vector3(0.0, 1.79, -5.65), Vector3(4.45, 0.19, 1.40), Color("a49c8e"), true)
	_box(room, Vector3(0.0, 2.83, -8.35), Vector3(3.2, 2.50, 0.30), accent)
	_label(room, str(site["name"]), Vector3(0.0, 4.22, -8.58), accent, 40, true)
	_label(room, str(site.get("host", "NIGHT SHIFT")), Vector3(0.0, 2.7, -8.58), Color("f0dfcb"), 32, true)
	_label(room, "H / EXIT TO STREET", Vector3(0.0, 3.93, 8.60), Color("f0bd78"), 29, false)
	# Other enterable shops/clubs use a human-scale stylized contact rather
	# than the previous stack of rectangular mannequin cubes. Mara keeps her
	# authored one-off look and dialogue scene.
	if not (active_id == "lantern_cup" and active_group == "VENUE"):
		var host := HumanoidVisual.new()
		host.name = "ContactHumanoid"
		host.configure(posmod(active_id.hash(), 6), kind)
		host.position = Vector3(0.0, 1.02, -7.12)
		room.add_child(host)
	match kind:
		"GROCERY", "STALL":
			_stocked_market(room, accent)
		"CLINIC", "FIRE":
			_treatment_room(room, accent, kind == "FIRE")
		"LIBRARY", "CIVIC":
			_public_records(room, accent)
		"WAREHOUSE", "GARAGE", "UTILITY":
			_service_bay(room, accent, kind)
		"CAFE":
			if active_id == "lantern_cup" and active_group == "VENUE":
				var cafe := LanternCupHero.new()
				cafe.name = "LanternCupHero"
				room.add_child(cafe)
			else:
				_lounge(room, accent, kind)
		"BAR", "CLUB":
			_lounge(room, accent, kind)
	# Set dressing and light fixtures remain bounded to the active room.
	for x in [-4.55, 4.55]:
		_box(room, Vector3(x, 4.97, -1.0), Vector3(3.1, 0.16, 1.0), Color("8c9299"))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.5, -1.0)
		lamp.omni_range = 11.0
		lamp.light_energy = 0.58
		lamp.shadow_enabled = false
		lamp.light_color = accent
		room.add_child(lamp)
	if kind == "BAR" or kind == "CAFE" or kind == "CLUB" or kind == "STALL":
		var sound := AudioStreamPlayer3D.new()
		sound.name = "OriginalAtmosphere"
		sound.position = Vector3(0.0, 2.0, -2.5)
		sound.stream = VenueAmbience.soundscape(kind)
		sound.volume_db = -13.0
		sound.max_distance = 24.0
		room.add_child(sound)
		sound.play()

func _stocked_market(room: Node3D, accent: Color) -> void:
	for x in [-5.3, 5.3]:
		for z in [-5.8, -1.0, 3.5]:
			_box(room, Vector3(x, 1.5, z), Vector3(2.6, 2.8, 1.45), Color("626d70"), true)
			for level in [0.8, 1.6, 2.4]:
				_box(room, Vector3(x, level, z - 0.8), Vector3(2.5, 0.13, 0.20), accent)
				for item in [-0.75, 0.0, 0.75]:
					_box(room, Vector3(x + item, level + 0.32, z - 0.65), Vector3(0.50, 0.50, 0.45),
						Color("83b77f") if level < 1.0 else Color("dfaa78"))
	for x in [-5.4, 5.4]:
		_box(room, Vector3(x, 0.65, 6.0), Vector3(1.3, 1.1, 0.95), Color("866a5b"))
		_box(room, Vector3(x, 1.30, 6.0), Vector3(1.4, 0.15, 1.12), accent)

func _treatment_room(room: Node3D, accent: Color, rescue: bool) -> void:
	for x in [-5.15, 5.15]:
		for z in [-3.0, 2.75]:
			_box(room, Vector3(x, 0.98, z), Vector3(2.6, 0.44, 1.25), Color("c2d0cb"), true)
			_box(room, Vector3(x, 1.22, z + 0.48), Vector3(2.35, 0.20, 0.38), Color("f0e9df"))
			_box(room, Vector3(x + 1.22, 2.5, z), Vector3(0.24, 2.3, 0.22), accent)
			_box(room, Vector3(x + 0.90, 3.37, z), Vector3(0.95, 0.18, 0.56), Color("c3e8e3"))
	if rescue:
		for x in [-5.0, 5.0]:
			_box(room, Vector3(x, 3.8, -7.6), Vector3(1.4, 1.55, 0.45), Color("ce5d65"))
			_box(room, Vector3(x, 4.05, -7.89), Vector3(0.21, 0.86, 0.10), Color("f8dbc2"))

func _public_records(room: Node3D, accent: Color) -> void:
	for x in [-5.5, 5.5]:
		for z in [-4.9, 0.0, 4.6]:
			_box(room, Vector3(x, 1.8, z), Vector3(2.1, 3.3, 1.1), Color("6c616b"), true)
			for row in range(4):
				for book in range(4):
					_box(room, Vector3(x - 0.64 + float(book) * 0.41, 0.66 + float(row) * 0.72, z - 0.6),
						Vector3(0.30, 0.49, 0.20), Color("cab28c") if book % 2 == 0 else accent)
	for x in [-5.4, 5.4]:
		_box(room, Vector3(x, 0.78, 6.40), Vector3(2.1, 0.21, 1.05), Color("a5a49e"))

func _service_bay(room: Node3D, accent: Color, kind: String) -> void:
	for x in [-5.3, 5.3]:
		for z in [-4.6, 0.0, 4.7]:
			_box(room, Vector3(x, 0.86, z), Vector3(2.4, 1.42, 1.8),
				Color("79665a") if kind == "WAREHOUSE" else Color("657782"), true)
			_box(room, Vector3(x, 1.72, z), Vector3(2.5, 0.17, 1.95), accent)
			if kind == "UTILITY":
				for light in range(3):
					_box(room, Vector3(x - 0.66 + float(light) * 0.66, 1.10, z - 0.94),
						Vector3(0.35, 0.28, 0.12), Color("94e8b2"))
	if kind == "GARAGE":
		for side in [-4.5, 4.5]:
			_box(room, Vector3(side, 0.12, 1.3), Vector3(1.2, 0.22, 5.3), Color("a6adad"))
			_box(room, Vector3(side, 1.5, 1.3), Vector3(0.24, 2.8, 0.21), accent)

func _lounge(room: Node3D, accent: Color, kind: String) -> void:
	for x in [-5.1, 5.1]:
		for z in [-4.1, 0.5, 4.5]:
			_box(room, Vector3(x, 0.83, z), Vector3(1.60, 0.17, 1.5), Color("877e80"), true)
			_box(room, Vector3(x, 0.41, z), Vector3(0.25, 0.82, 0.25), Color("6a727a"))
			for dx in [-0.90, 0.90]:
				_box(room, Vector3(x + dx, 0.59, z), Vector3(0.53, 0.19, 0.62), accent)
	# A low stage along one wall for clubs, backlit shelves for bars,
	# and an espresso cabinet at the cafe.
	if kind == "CLUB":
		_box(room, Vector3(0.0, 0.37, -6.45), Vector3(6.1, 0.42, 1.7), Color("3c3b55"))
		for x in [-6.25, 6.25]:
			_box(room, Vector3(x, 2.16, -6.3), Vector3(0.85, 2.8, 0.85), Color("323346"))
			_box(room, Vector3(x, 3.65, -6.3), Vector3(0.95, 0.19, 0.95), accent)
	elif kind == "BAR":
		for x in [-5.2, 5.2]:
			for level in [1.6, 2.6, 3.6]:
				_box(room, Vector3(x, level, -7.8), Vector3(2.8, 0.12, 0.70), Color("947970"))
				for glass in [-0.85, 0.0, 0.85]:
					_box(room, Vector3(x + glass, level + 0.36, -7.62),
						Vector3(0.40, 0.55, 0.36), accent)
	else:
		for x in [-5.5, 5.5]:
			_box(room, Vector3(x, 1.10, -7.2), Vector3(1.6, 2.10, 1.1), Color("a9b5b2"))
			for row in [1.9, 2.6]:
				_box(room, Vector3(x, row, -7.87), Vector3(1.15, 0.10, 0.18), accent)

func _kind_color(kind: String) -> Color:
	match kind:
		"CAFE", "CLINIC":
			return Color("7ed4d8")
		"BAR", "FIRE":
			return Color("de8a9a")
		"CLUB":
			return Color("cf83e0")
		"GROCERY", "STALL":
			return Color("e1ba79")
		"LIBRARY", "CIVIC":
			return Color("b9accf")
		"WAREHOUSE", "GARAGE":
			return Color("d6a17a")
		_:
			return Color("9bd6bb")

func _label(parent: Node3D, message: String, at: Vector3, tint: Color, size: int, flip: bool) -> void:
	var label := Label3D.new()
	label.text = message
	label.position = at
	label.rotation.y = 0.0 if flip else PI
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = tint
	label.outline_size = 6
	label.outline_modulate = Color("141b2a")
	label.double_sided = true
	parent.add_child(label)

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color,
	collider: bool = false, surface: String = "") -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = at
	if not surface.is_empty():
		instance.material_override = Materials.surface(surface, tint)
	else:
		var key := tint.to_html(false)
		if not _material_cache.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_color = tint
			material.metallic = 0.12
			material.roughness = 0.70
			_material_cache[key] = material
		instance.material_override = _material_cache[key]
	if collider:
		var solid := StaticBody3D.new()
		solid.name = "Solid"
		solid.position = at
		instance.position = Vector3.ZERO
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = dimensions
		shape.shape = box
		solid.add_child(shape)
		solid.add_child(instance)
		parent.add_child(solid)
	else:
		parent.add_child(instance)
