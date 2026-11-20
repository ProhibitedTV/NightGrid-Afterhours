extends Node3D
## Corner-building side elevations visible from the CENTRAL EXCHANGE avenue.
## Whole wall and real recessed glazing share a continuous authored YZ mesh.
## Building shell/colliders are owned by city_details, unaffected here.
const GROUND = 4.55
const STOREY = 3.45

var building_width := 15.0
var building_height := 25.0
var building_depth := 23.0
var district := "BRICKWATER"
var shop_name := ""
var _buffers: Dictionary = {}
var _stats := {"windows": 0, "shopfront_bays": 0,
	"reveal_faces": 0, "canopy_sections": 0, "meshes": 0}

func configure(width: float, height: float, depth: float,
		area: String, business: String) -> void:
	building_width = width
	building_height = height
	building_depth = depth
	district = area
	shop_name = business

func _ready() -> void:
	_build()

func get_avenue_stats() -> Dictionary:
	return _stats.duplicate()

func _push(family: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	if not _buffers.has(family):
		_buffers[family] = []
	var quads: Array = _buffers[family]
	quads.append([a, b, c, d])

func _rect(family: String, z0: float, z1: float,
		y0: float, y1: float, x: float) -> void:
	if z1 <= z0 or y1 <= y0:
		return
	var sign := 1.0 if district == "BRICKWATER" else -1.0
	# Correct front-face winding on BOTH sides of the street.
	if sign > 0.0:
		_push(family, Vector3(x, y0, z0), Vector3(x, y1, z0),
			Vector3(x, y1, z1), Vector3(x, y0, z1))
	else:
		_push(family, Vector3(x, y0, z1), Vector3(x, y1, z1),
			Vector3(x, y1, z0), Vector3(x, y0, z0))

func _opening(z0: float, z1: float, bottom: float, top: float,
		outer_x: float, glass_x: float, lit: bool) -> void:
	var inset := 0.13
	var g0 := z0 + inset
	var g1 := z1 - inset
	var low := bottom + 0.11
	var high := top - 0.11
	if g1 <= g0 or high <= low:
		return
	# Both one-building pilots separate transparent pane, reveal and room
	# backing. Recession points INWARD on both sides of the avenue.
	_rect("GLASS", g0, g1, low, high, glass_x)
	var recess_sign := 1.0 if district == "BRICKWATER" else -1.0
	_rect("INTERIOR" if lit else "DARK_ROOM", g0, g1, low, high,
		glass_x - recess_sign * 0.72)
	var jamb := "REVEALS" if district == "BRICKWATER" else "STEEL"
	_push(jamb, Vector3(outer_x, bottom, z0),
		Vector3(outer_x, top, z0), Vector3(glass_x, high, g0),
		Vector3(glass_x, low, g0))
	_push(jamb, Vector3(glass_x, low, g1),
		Vector3(glass_x, high, g1), Vector3(outer_x, top, z1),
		Vector3(outer_x, bottom, z1))
	_push(jamb, Vector3(outer_x, top, z0),
		Vector3(outer_x, top, z1), Vector3(glass_x, high, g1),
		Vector3(glass_x, high, g0))
	_push(jamb, Vector3(glass_x, low, g0),
		Vector3(glass_x, low, g1), Vector3(outer_x, bottom, z1),
		Vector3(outer_x, bottom, z0))
	var cross_y := lerpf(low, high, 0.54)
	_rect("STEEL", g0, g1, cross_y - 0.04, cross_y + 0.04,
		lerpf(outer_x, glass_x, 0.62))
	var mid := (g0 + g1) * 0.5
	_rect("STEEL", mid - 0.028, mid + 0.028, low, high,
		lerpf(outer_x, glass_x, 0.62))
	_stats["reveal_faces"] += 4
	_stats["windows"] += 1

func _build() -> void:
	var sign := 1.0 if district == "BRICKWATER" else -1.0
	var outside := sign * (building_width * 0.5 + 0.32)
	var inner := sign * (building_width * 0.5 + 0.075)
	var material := "MASONRY" if district == "BRICKWATER" else "CLADDING"
	var start := 0.22
	var finish := building_depth - 0.20
	var bay_count := maxi(4, floori(building_depth / 4.5))
	var step := (finish - start) / float(bay_count)
	_rect(material, start, finish, 0.15, 0.58, outside)
	_rect(material, start, finish, GROUND - 0.49, GROUND, outside)
	for floor_index in range(-1, ceili(building_height / STOREY)):
		var floor_bottom := 0.58 if floor_index < 0 else GROUND + float(floor_index) * STOREY
		if floor_bottom >= building_height - 0.3:
			break
		var ceiling := (GROUND - 0.49 if floor_index < 0 else
			minf(building_height - 0.10, floor_bottom + STOREY))
		var lower := floor_bottom if floor_index < 0 else floor_bottom + 0.47
		var upper := ceiling if floor_index < 0 else ceiling - 0.46
		if upper - lower < 0.44:
			_rect(material, start, finish, floor_bottom, ceiling, outside)
			continue
		if floor_index >= 0:
			_rect(material, start, finish, floor_bottom, lower, outside)
			_rect(material, start, finish, upper, ceiling, outside)
			_rect("REVEALS", start, finish, floor_bottom - 0.06,
				floor_bottom, outside - sign * 0.02)
		for bay in range(bay_count):
			var z0 := start + float(bay) * step
			var z1 := start + float(bay + 1) * step
			_rect(material, z0, z0 + 0.29, lower, upper, outside)
			_rect(material, z1 - 0.29, z1, lower, upper, outside)
			_opening(z0 + 0.29, z1 - 0.29, lower, upper,
				outside, inner, floor_index < 0 or (floor_index * 11 + bay * 7) % 5 == 0)
			if floor_index < 0:
				_stats["shopfront_bays"] += 1
	# Continuous steel awning is one engineered swept canopy, not stacked
	# decorative cube geometry. It does not create player collisions.
	for i in range(20):
		var z0 := lerpf(start + 0.24, finish - 0.24, float(i) / 20.0)
		var z1 := lerpf(start + 0.24, finish - 0.24, float(i + 1) / 20.0)
		var x1 := outside + sign * 1.1
		_push("STEEL", Vector3(outside, GROUND + 0.03, z0),
			Vector3(outside, GROUND + 0.03, z1),
			Vector3(x1, GROUND - 0.10, z1),
			Vector3(x1, GROUND - 0.10, z0))
		_stats["canopy_sections"] += 1
	_build_meshes()
	var sign_label := Label3D.new()
	sign_label.name = "AvenueShopIdentity"
	sign_label.text = shop_name
	sign_label.font_size = 43
	sign_label.pixel_size = 0.0068
	sign_label.position = Vector3(outside + sign * 1.14, GROUND - 0.08, (start + finish) * 0.5)
	sign_label.rotation.y = PI * 0.5 if sign > 0.0 else -PI * 0.5
	sign_label.modulate = Color("debd9d") if sign > 0.0 else Color("a3d5de")
	sign_label.outline_size = 4
	sign_label.outline_modulate = Color("172431")
	add_child(sign_label)

func _build_meshes() -> void:
	for family in _buffers:
		var quads: Array = _buffers[family]
		if quads.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for q in quads:
			var a: Vector3 = q[0]
			var b: Vector3 = q[1]
			var c: Vector3 = q[2]
			var d: Vector3 = q[3]
			for point in [a, b, c, a, c, d]:
				# The world-visible YZ elevations have real UV coverage, not a
				# vertically smeared one-pixel strip along the building side.
				surface.set_uv(Vector2(point.z * 0.39, point.y * 0.39))
				surface.add_vertex(point)
		surface.generate_normals()
		surface.generate_tangents()
		var node := MeshInstance3D.new()
		node.name = "AvenueSurface_%s" % family
		node.mesh = surface.commit()
		node.material_override = get_parent().call("_surface_material", family)
		node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if family == "GLASS" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		add_child(node)
		_stats["meshes"] += 1
	_buffers.clear()
