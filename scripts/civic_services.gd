extends Node3D
## Fixed public-services catalog and detailed street-level civic vignettes.
## Addresses survive all New Game seeds; only adjacent facade profiles can vary.
const WorldPlan = preload("res://scripts/world_plan.gd")
const Materials = preload("res://scripts/material_library.gd")
const CELL = 58.0
const VISIT_RADIUS = 5.7

const SITES = [
	{"id":"quay_fresh","name":"QUAY FRESH","kind":"GROCERY","ix":-3,"iz":-4,"side":0,"opens":6.0,"closes":23.0,"price":28,"host":"Tala","flavor":"Produce comes in on the dawn ferries. The lights never stop humming."},
	{"id":"tide_clinic","name":"TIDE CLINIC","kind":"CLINIC","ix":1,"iz":-4,"side":1,"opens":0.0,"closes":24.0,"price":42,"host":"Dr. Imani","flavor":"Walk-in care beneath the sea-glass emergency sign."},
	{"id":"harbor_library","name":"HARBOR READING ROOM","kind":"LIBRARY","ix":2,"iz":-4,"side":0,"opens":7.0,"closes":23.0,"price":0,"host":"Penny","flavor":"Ship manifests, city records and a rebellious public archive."},
	{"id":"seawall_pantry","name":"SEAWALL PANTRY","kind":"GROCERY","ix":3,"iz":-4,"side":1,"opens":5.0,"closes":1.0,"price":24,"host":"Sev","flavor":"Night-shift essentials beside the wave barriers."},
	{"id":"freight_control","name":"FREIGHT CONTROL","kind":"WAREHOUSE","ix":-4,"iz":-3,"side":0,"opens":0.0,"closes":24.0,"price":0,"host":"Cato","flavor":"The west dock cranes never truly sleep."},
	{"id":"crane_supply","name":"CRANE & GEAR","kind":"GARAGE","ix":-4,"iz":-2,"side":1,"opens":7.0,"closes":23.0,"price":55,"host":"Vik","flavor":"Independent mechanical work behind an old shipyard shutter."},
	{"id":"dock_watch","name":"DOCK WATCH DESK","kind":"CIVIC","station_id":"west","station_capacity":2,"ix":-4,"iz":-1,"side":0,"opens":0.0,"closes":24.0,"price":65,"host":"Clerk Bo","flavor":"Paper citations, patrol records and the occasional honest official."},
	{"id":"cold_storage","name":"COLD CHAIN 09","kind":"WAREHOUSE","ix":-4,"iz":2,"side":1,"opens":0.0,"closes":24.0,"price":0,"host":"Rook","flavor":"Temperature-controlled cargo kept off the corporate freight exchange."},
	{"id":"garden_clinic","name":"HORIZON HEALTH","kind":"CLINIC","ix":3,"iz":-2,"side":1,"opens":7.0,"closes":22.0,"price":40,"host":"Leena","flavor":"Neighborhood triage and solar-lit consultations."},
	{"id":"east_fire","name":"EASTSIDE FIRE 4","kind":"FIRE","ix":3,"iz":-1,"side":0,"opens":0.0,"closes":24.0,"price":18,"host":"Captain Ash","flavor":"A staffed rescue bay with its engine always ready."},
	{"id":"orchard_grocer","name":"ORCHARD GROCER","kind":"GROCERY","ix":3,"iz":1,"side":0,"opens":6.0,"closes":22.0,"price":29,"host":"Milo","flavor":"Fresh herbs, rooftop vegetables and cooperative prices."},
	{"id":"civic_library","name":"COMMONS LIBRARY","kind":"LIBRARY","ix":3,"iz":2,"side":1,"opens":8.0,"closes":21.0,"price":0,"host":"Tess","flavor":"Open knowledge and an old-fashioned local history collection."},
	{"id":"records_office","name":"SOUTHWORKS RECORDS","kind":"CIVIC","ix":-3,"iz":3,"side":0,"opens":8.0,"closes":19.0,"price":65,"host":"Clerk Ada","flavor":"Permit stamps, municipal files and very long paper trails."},
	{"id":"south_bus_yard","name":"SOUTH BUS WORKS","kind":"GARAGE","ix":-2,"iz":3,"side":1,"opens":5.0,"closes":2.0,"price":60,"host":"Yuri","flavor":"A midnight machine shop keeping the public fleet alive."},
	{"id":"union_supply","name":"UNION DISTRIBUTION","kind":"WAREHOUSE","ix":1,"iz":3,"side":0,"opens":0.0,"closes":24.0,"price":0,"host":"Edda","flavor":"The cooperative's essential parcels move without corporate permission."},
	{"id":"power_annex","name":"GRID ANNEX FOUR","kind":"UTILITY","ix":2,"iz":3,"side":1,"opens":0.0,"closes":24.0,"price":0,"host":"Lin","flavor":"A public-facing substation with suspiciously new ownership labels."},
	{"id":"police_hq","name":"MBPD CENTRAL DISPATCH","kind":"CIVIC","station_id":"central","station_capacity":3,"headquarters":true,"ix":1,"iz":0,"side":0,"opens":0.0,"closes":24.0,"price":65,"host":"Duty Officer Vale","flavor":"Citywide dispatch, public counter and precinct coordination."}
]

const WORK_ORDERS = [
	{"id":"cold_chain","title":"THE COLD CHAIN","from":"freight_control","to":"quay_fresh","reward":310,"brief":"A refrigeration crate must reach Quay Fresh before the morning market.","ending":"Tala checks the seals. The neighborhood keeps its produce supply."},
	{"id":"lifeline","title":"THE LIFELINE","from":"cold_storage","to":"garden_clinic","reward":365,"brief":"The clinic needs a sealed medical cooler that corporate couriers refused to route.","ending":"Leena receives the cooler. The community clinic can reopen its night ward."},
	{"id":"after_sparks","title":"AFTER THE SPARKS","from":"union_supply","to":"east_fire","reward":280,"brief":"Bring replacement breathing filters to the Eastside rescue team.","ending":"Captain Ash equips the crew, just in time for the next alarm."},
	{"id":"grid_audit","title":"GRID AUDIT","from":"power_annex","to":"dock_watch","reward":415,"brief":"Hand-deliver the original power-transfer ledger to Dock Watch.","ending":"Clerk Bo stamps the archive. The contract is now a public record."}
]

const KIND_COLOR = {
	"GROCERY": Color("d4c476"), "CLINIC": Color("85dfd5"),
	"LIBRARY": Color("b5a2e1"), "WAREHOUSE": Color("da9a72"),
	"GARAGE": Color("ddae75"), "CIVIC": Color("a4c8d0"),
	"FIRE": Color("f1807d"), "UTILITY": Color("a0e3be")
}

var _entries: Dictionary = {}
var _glow: Dictionary = {}
var _labels: Dictionary = {}
var _map_pins: Array[Dictionary] = []
var _material_cache: Dictionary = {}
var _hour := 19.25
var _focus := Vector3.ZERO
var _tick := 0.0
var _light_pool: Array[OmniLight3D] = []

func _ready() -> void:
	for site in SITES:
		_build_site(site)
	for index in range(2):
		var lamp := OmniLight3D.new()
		lamp.name = "CivicPoolLight_%d" % index
		lamp.omni_range = 12.0
		lamp.light_energy = 0.0
		lamp.visible = false
		lamp.shadow_enabled = false
		add_child(lamp)
		_light_pool.append(lamp)
	_refresh()

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.65:
		_tick = 0.0
		_refresh()

func set_hour(hour: float) -> void:
	_hour = fposmod(hour, 24.0)
	_refresh()

func set_focus(point: Vector3) -> void:
	_focus = point

func site_count() -> int:
	return _entries.size()

func get_map_pins() -> Array[Dictionary]:
	return _map_pins

func police_station_sites() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in SITES:
		if not site.has("station_id"):
			continue
		var address := position_for(str(site["id"]))
		# The office frontage is on the north side of the parcel. A marked
		# street-side staging location is derived from its fixed address.
		var launch := Vector3(address.x, 1.1, float(site["iz"]) * CELL + 3.25)
		result.append({"id":str(site["station_id"]), "name":str(site["name"]), "address":address, "launch":launch, "capacity":int(site["station_capacity"]), "hq":bool(site.get("headquarters", false))})
	return result

func active_light_count() -> int:
	var amount := 0
	for lamp in _light_pool:
		if lamp.visible:
			amount += 1
	return amount

func site_by_id(site_id: String) -> Dictionary:
	for site in SITES:
		if str(site["id"]) == site_id:
			return site
	return {}

func order_by_id(order_id: String) -> Dictionary:
	for order in WORK_ORDERS:
		if str(order["id"]) == order_id:
			return order
	return {}

func order_from(site_id: String) -> Dictionary:
	for order in WORK_ORDERS:
		if str(order["from"]) == site_id:
			return order
	return {}

func position_for(site_id: String) -> Vector3:
	var site := site_by_id(site_id)
	if site.is_empty():
		return Vector3.ZERO
	return Vector3((float(site["ix"]) + 0.5) * CELL + (-10.5 if int(site["side"]) == 0 else 10.5),
		1.15, (float(site["iz"]) + 0.5) * CELL - 19.3)

func nearest_site(at: Vector3, radius: float = VISIT_RADIUS) -> Dictionary:
	var nearest := {}
	var min_distance := radius
	for site in SITES:
		var p := position_for(str(site["id"]))
		var distance := Vector2(at.x - p.x, at.z - p.z).length()
		if distance <= min_distance:
			nearest = site
			min_distance = distance
	return nearest

func is_open(site_id: String, hour: float = -1.0) -> bool:
	var site := site_by_id(site_id)
	if site.is_empty():
		return false
	var current := _hour if hour < 0.0 else fposmod(hour, 24.0)
	var opens: float = site["opens"]
	var closes: float = site["closes"]
	if closes >= 24.0:
		return true if opens <= 0.0 else current >= opens
	if opens < closes:
		return current >= opens and current < closes
	return current >= opens or current < closes

func sign_energy(site_id: String) -> float:
	var material: StandardMaterial3D = _glow.get(site_id)
	return material.emission_energy_multiplier if material != null else 0.0

func _build_site(site: Dictionary) -> void:
	var id: String = site["id"]
	var kind: String = site["kind"]
	var accent: Color = KIND_COLOR[kind]
	var front := Node3D.new()
	front.name = id
	front.position = position_for(id) + Vector3(0.0, -1.15, 2.35)
	add_child(front)
	_entries[id] = front
	_map_pins.append({"id": id, "point": Vector2(front.global_position.x, front.global_position.z - 2.35),
		"kind": kind, "open": false, "station": site.has("station_id")})
	_box(front, Vector3(0.0, 0.21, -0.65), Vector3(8.7, 0.08, 4.8), Color("555b5f"), "PAVERS")
	_box(front, Vector3(0.0, 2.5, 1.96), Vector3(9.1, 4.6, 0.24), Color("2c3546"))
	_box(front, Vector3(0.0, 4.35, 1.67), Vector3(9.0, 1.0, 0.24), Color("182a39"))
	var neon := StandardMaterial3D.new()
	neon.albedo_color = accent
	neon.emission_enabled = true
	neon.emission = accent
	neon.emission_energy_multiplier = 0.0
	neon.roughness = 0.40
	_glow[id] = neon
	_box(front, Vector3(0.0, 4.82, 1.38), Vector3(9.0, 0.09, 0.17), accent, "", neon)
	_box(front, Vector3(0.0, 3.87, 1.38), Vector3(9.0, 0.09, 0.17), accent, "", neon)
	_label(front, str(site["name"]), Vector3(0.0, 4.38, 1.30), accent, 46)
	_label(front, str(site["host"]) + " / " + kind, Vector3(0.0, 3.51, 1.29), Color("b4bdc7"), 24)
	var hours := _make_label(front, "OPEN", Vector3(3.5, 2.36, 1.21), accent, 24)
	_labels[id] = hours
	match kind:
		"GROCERY":
			_grocery(front, accent)
		"CLINIC":
			_clinic(front, accent, neon)
		"LIBRARY":
			_library(front, accent)
		"WAREHOUSE":
			_warehouse(front, accent)
		"GARAGE":
			_garage(front, accent)
		"CIVIC":
			_civic(front, accent)
			if site.has("station_id"):
				_label(front, "MORROW BAY POLICE DEPARTMENT", Vector3(0, 3.12, 1.05), Color("93bcf0"), 28)
				_label(front, "24H PUBLIC COUNTER", Vector3(0, 2.15, -1.30), Color("dce7ef"), 25)
		"FIRE":
			_fire(front, accent)
		"UTILITY":
			_utility(front, accent, neon)

func _grocery(node: Node3D, accent: Color) -> void:
	_box(node, Vector3(0.0, 2.88, -0.3), Vector3(8.2, 0.15, 3.3), accent)
	for shelf in [-2.5, 2.5]:
		_box(node, Vector3(shelf, 1.0, 0.15), Vector3(2.0, 1.8, 1.6), Color("58676a"))
		for row in range(3):
			for item in range(3):
				var color := Color("79b17b") if row == 0 else (Color("d6a570") if row == 1 else Color("c47c78"))
				_box(node, Vector3(shelf - 0.52 + float(item) * 0.52, 0.70 + float(row) * 0.43, -0.66),
					Vector3(0.44, 0.33, 0.37), color)
	_box(node, Vector3(0.0, 1.0, 0.63), Vector3(2.1, 1.3, 0.95), Color("b5aaa0"), "METAL")
	for x in [-1.9, 1.9]:
		_box(node, Vector3(x, 0.73, -1.6), Vector3(1.1, 1.2, 0.9), Color("8a7964"))
		_box(node, Vector3(x, 1.35, -1.6), Vector3(1.3, 0.18, 1.05), Color("d9bf8b"))

func _clinic(node: Node3D, accent: Color, neon: StandardMaterial3D) -> void:
	for x in [-2.8, 2.8]:
		_box(node, Vector3(x, 1.00, -0.32), Vector3(2.0, 0.58, 1.0), Color("c9d3cf"))
		_box(node, Vector3(x, 0.53, -0.32), Vector3(0.20, 0.72, 0.20), Color("6d8c8a"))
		_box(node, Vector3(x, 1.38, -0.32), Vector3(1.35, 0.13, 0.72), Color("e6e5df"))
	for x in [-3.55, 3.55]:
		_box(node, Vector3(x, 2.30, 1.16), Vector3(0.28, 3.4, 0.25), accent)
	_box(node, Vector3(0.0, 2.6, 0.96), Vector3(0.55, 1.55, 0.15), accent, "", neon)
	_box(node, Vector3(0.0, 2.6, 0.96), Vector3(1.55, 0.45, 0.15), accent, "", neon)
	_box(node, Vector3(0.0, 0.7, -1.24), Vector3(1.5, 1.2, 1.0), Color("627c7e"))

func _library(node: Node3D, accent: Color) -> void:
	for shelf_x in [-3.1, -1.65, 1.65, 3.1]:
		_box(node, Vector3(shelf_x, 1.90, 0.60), Vector3(1.22, 3.5, 0.75), Color("605564"))
		for row in range(4):
			for book in range(4):
				var ink := Color("b9a8cf") if book % 3 == 0 else (Color("c8b18a") if book % 3 == 1 else Color("84a4a1"))
				_box(node, Vector3(shelf_x - 0.43 + float(book) * 0.29, 0.6 + float(row) * 0.70, 0.12),
					Vector3(0.24, 0.47, 0.40), ink)
	_box(node, Vector3(0.0, 0.87, -0.64), Vector3(2.5, 0.16, 1.3), Color("8d8073"))
	_box(node, Vector3(0.0, 1.53, -0.62), Vector3(0.33, 1.16, 0.28), accent)

func _warehouse(node: Node3D, accent: Color) -> void:
	for x in [-3.25, 3.25]:
		_box(node, Vector3(x, 2.0, 0.35), Vector3(0.45, 3.7, 0.44), Color("8b959b"), "METAL")
		_box(node, Vector3(x, 3.75, 0.30), Vector3(0.96, 0.20, 1.4), accent)
	for x in [-2.3, 0.0, 2.3]:
		for y in [0.57, 1.80]:
			_box(node, Vector3(x, y, -0.80), Vector3(1.8, 1.18, 1.72), Color("9c7b5a"))
			_box(node, Vector3(x, y, -1.69), Vector3(1.5, 0.13, 0.12), Color("c7a476"))
	_box(node, Vector3(0.0, 2.93, -1.73), Vector3(7.6, 0.20, 0.16), accent)

func _garage(node: Node3D, accent: Color) -> void:
	_box(node, Vector3(0.0, 0.27, -0.72), Vector3(7.2, 0.14, 2.5), Color("303b46"))
	for x in [-2.6, 2.6]:
		_box(node, Vector3(x, 1.13, 0.14), Vector3(0.5, 1.7, 2.05), Color("a08d72"))
		_box(node, Vector3(x, 2.20, 0.14), Vector3(0.8, 0.25, 2.1), accent)
	for x in [-3.6, 3.6]:
		_box(node, Vector3(x, 2.55, 0.60), Vector3(0.42, 4.0, 0.40), Color("a6adb0"))
	for i in range(6):
		var x := -2.5 + float(i) * 0.9
		_box(node, Vector3(x, 3.0, 0.8), Vector3(0.24, 0.62, 0.25), Color("9ba7ac"))
	_box(node, Vector3(0.0, 1.1, -1.4), Vector3(1.7, 1.3, 1.25), Color("444b52"))

func _civic(node: Node3D, accent: Color) -> void:
	for x in [-3.7, 3.7]:
		_box(node, Vector3(x, 2.0, -0.2), Vector3(0.45, 3.8, 0.45), Color("9d9b93"))
	_box(node, Vector3(0.0, 1.12, 0.55), Vector3(6.2, 1.25, 0.9), Color("8d8980"))
	_box(node, Vector3(0.0, 1.85, 0.0), Vector3(6.5, 0.17, 1.1), accent)
	for x in [-2.0, 0.0, 2.0]:
		_box(node, Vector3(x, 2.55, 1.2), Vector3(1.1, 0.95, 0.13), Color("d2c8ac"))
	_box(node, Vector3(0.0, 0.55, -1.3), Vector3(7.5, 0.15, 1.2), Color("6c787c"))

func _fire(node: Node3D, accent: Color) -> void:
	# Engine silhouette behind a roll-up door.
	_box(node, Vector3(0.0, 1.18, 0.21), Vector3(6.2, 2.0, 1.9), Color("a83f4c"), "METAL")
	_box(node, Vector3(0.0, 2.40, 0.14), Vector3(4.1, 0.78, 1.85), Color("c96f66"))
	for x in [-2.1, 2.1]:
		_box(node, Vector3(x, 0.42, -0.90), Vector3(1.0, 0.86, 0.64), Color("2b2e37"))
		_box(node, Vector3(x, 1.25, -0.83), Vector3(0.66, 0.36, 0.15), Color("fff1ac"))
	for x in [-3.85, 3.85]:
		_box(node, Vector3(x, 2.25, 0.80), Vector3(0.24, 4.1, 0.36), Color("9ca5a6"))
	_box(node, Vector3(0.0, 3.75, -0.71), Vector3(7.1, 0.12, 0.15), accent)

func _utility(node: Node3D, accent: Color, neon: StandardMaterial3D) -> void:
	for x in [-2.7, 0.0, 2.7]:
		_box(node, Vector3(x, 1.55, 0.25), Vector3(1.80, 2.7, 1.4), Color("526771"), "METAL")
		for y in [0.75, 1.2, 1.65, 2.1]:
			_box(node, Vector3(x, y, -0.48), Vector3(1.56, 0.06, 0.18), Color("a0bcc0"))
	_box(node, Vector3(0.0, 3.40, -0.51), Vector3(7.4, 0.15, 0.16), accent, "", neon)
	_box(node, Vector3(0.0, 0.52, -1.65), Vector3(7.4, 0.15, 1.05), Color("d0b871"))

func _make_label(parent: Node3D, message: String, at: Vector3, tint: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = message
	label.position = at
	label.rotation.y = PI
	label.pixel_size = 0.010
	label.font_size = size
	label.modulate = tint
	label.outline_size = 6
	label.outline_modulate = Color("14202e")
	label.double_sided = true
	parent.add_child(label)
	return label

func _label(parent: Node3D, message: String, at: Vector3, tint: Color, size: int) -> void:
	_make_label(parent, message, at, tint, size)

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color,
	surface_kind: String = "", custom_material: Material = null) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	if custom_material != null:
		node.material_override = custom_material
	elif not surface_kind.is_empty():
		node.material_override = Materials.surface(surface_kind, tint)
	else:
		var key := tint.to_html(false)
		if not _material_cache.has(key):
			var shared := StandardMaterial3D.new()
			shared.albedo_color = tint
			shared.roughness = 0.78
			_material_cache[key] = shared
		node.material_override = _material_cache[key]
	parent.add_child(node)

func _darkness() -> float:
	if _hour >= 17.5:
		return smoothstep(17.5, 20.0, _hour)
	if _hour < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, _hour)
	return 0.0

func _refresh() -> void:
	var darkness := _darkness()
	var nearby: Array[Dictionary] = []
	for index in range(SITES.size()):
		var site: Dictionary = SITES[index]
		var id: String = site["id"]
		var opened := is_open(id)
		_map_pins[index]["open"] = opened
		var material: StandardMaterial3D = _glow[id]
		material.emission_energy_multiplier = (0.25 + 1.80 * darkness) if opened else (0.04 + 0.10 * darkness)
		var label: Label3D = _labels[id]
		label.text = "OPEN" if opened else "CLOSED"
		label.modulate = KIND_COLOR[str(site["kind"])] if opened else Color("79868c")
		var point := position_for(id)
		var gap := Vector2(point.x - _focus.x, point.z - _focus.z).length()
		if opened and gap < 31.0 and darkness > 0.03:
			nearby.append({"distance": gap, "position": point, "color": KIND_COLOR[str(site["kind"])]})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for index in range(_light_pool.size()):
		var lamp := _light_pool[index]
		lamp.visible = index < nearby.size()
		if lamp.visible:
			lamp.global_position = nearby[index]["position"] + Vector3(0.0, 3.45, 0.4)
			lamp.light_color = nearby[index]["color"]
			lamp.light_energy = 0.72 * darkness
		else:
			lamp.light_energy = 0.0
