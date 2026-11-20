extends Node3D
## Two permanent Central Exchange street façades: built as coherent UV-mapped
## architectural surfaces with real geometric window and shopfront recesses,
## not dozens of overlaid BoxMesh billboards. The existing core collision
## volumes and gameplay storefront IDs remain at their original coordinates.
##
## This is a production-oriented architectural *base* toward the approved
## photoreal benchmark, not a claim of final AAA-quality world artwork.
const Materials = preload("res://scripts/material_library.gd")
const AvenueFrontage = preload("res://scripts/central_exchange_avenue.gd")
const PBR_ROOT = "res:" + "//assets/pbr/polyhaven/brick_wall_001_"
const STEEL_PBR_ROOT = "res:" + "//assets/pbr/polyhaven/blue_metal_plate_"
const STOREY = 3.45
const GROUND = 4.55
const FRONT = -0.38
const GLASS = -0.14
const CANOPY_REACH = -1.55

var building_width := 15.0
var building_height := 20.0
var building_depth := 23.0
var district := "BRICKWATER"
var storefront_name := ""
var _style := "MASONRY"
var _buffers: Dictionary = {}
var _statistics := {
	"architecture_surfaces": 0, "window_openings": 0,
	"shopfront_openings": 0, "avenue_windows": 0, "reveal_faces": 0,
	"canopy_segments": 0, "real_pbr_maps": 0,
	"collision_bodies": 0, "local_lights": 0
}
var _mats: Dictionary = {}

func configure(width: float, height: float, depth: float, area: String, shop_name: String) -> void:
	building_width = width
	building_height = height
	building_depth = depth
	district = area
	storefront_name = shop_name
	_style = "MASONRY" if district == "BRICKWATER" else "GLAZED"

func _ready() -> void:
	_generate_facade()

func get_facade_stats() -> Dictionary:
	return _statistics.duplicate()

func _surface_material(family: String) -> Material:
	if _mats.has(family):
		return _mats[family]
	var out: StandardMaterial3D
	match family:
		"MASONRY":
			out = Materials.surface("BRICK", Color("c1b2a7"))
			# Use a separate material instance so this façade is genuinely
			# authored, not a global alteration of every concrete block.
			out = out.duplicate() as StandardMaterial3D
			out.albedo_color = Color("c9c2b7")
			# Optional CC0 source maps from Poly Haven's brick_wall_001.
			# Pipeline imports 2K maps; the fallback exists for source-only
			# builds and should NOT be mistaken for art approval.
			var paths := [
				PBR_ROOT + "diffuse_2k.jpg",
				PBR_ROOT + "nor_gl_2k.png",
				PBR_ROOT + "rough_2k.png"]
			if ResourceLoader.exists(paths[0]) and ResourceLoader.exists(paths[1]) and ResourceLoader.exists(paths[2]):
				var alb := load(paths[0]) as Texture2D
				var nor := load(paths[1]) as Texture2D
				var rough := load(paths[2]) as Texture2D
				if alb != null and nor != null and rough != null:
					out.albedo_texture = alb
					out.normal_texture = nor
					out.roughness_texture = rough
					out.albedo_color = Color("c5beb7")
					_statistics["real_pbr_maps"] += 3
			out.uv1_triplanar = false
			out.uv1_world_triplanar = false
			out.uv1_scale = Vector3.ONE
			out.normal_scale = 0.76
			out.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		"CLADDING":
			out = (Materials.surface("METAL", Color("808e9b"))).duplicate() as StandardMaterial3D
			out.albedo_color = Color("aabac2")
			out.metallic = 0.63
			out.roughness = 0.57
			out.uv1_triplanar = false
			out.uv1_world_triplanar = false
			out.uv1_scale = Vector3.ONE
			var steel_paths := [
				STEEL_PBR_ROOT + "diffuse_2k.jpg",
				STEEL_PBR_ROOT + "nor_gl_2k.png",
				STEEL_PBR_ROOT + "rough_2k.png"]
			if ResourceLoader.exists(steel_paths[0]) and ResourceLoader.exists(steel_paths[1]) and ResourceLoader.exists(steel_paths[2]):
				var steel_alb := load(steel_paths[0]) as Texture2D
				var steel_nor := load(steel_paths[1]) as Texture2D
				var steel_rough := load(steel_paths[2]) as Texture2D
				if steel_alb != null and steel_nor != null and steel_rough != null:
					out.albedo_texture = steel_alb
					out.normal_texture = steel_nor
					out.roughness_texture = steel_rough
					out.normal_scale = 0.52
					out.roughness = 1.0
					_statistics["real_pbr_maps"] += 3
		"REVEALS":
			out = (Materials.surface("CONCRETE", Color("8b8985"))).duplicate() as StandardMaterial3D
			out.albedo_color = Color("a7a39c")
			out.roughness = 0.71
			out.uv1_triplanar = false
			out.uv1_world_triplanar = false
			out.uv1_scale = Vector3.ONE
		"STEEL":
			out = StandardMaterial3D.new()
			out.albedo_color = Color("354851")
			out.metallic = 0.76
			out.roughness = 0.30
		"GLASS":
			out = StandardMaterial3D.new()
			out.albedo_color = Color("304855")
			out.metallic = 0.06
			out.roughness = 0.17
			out.clearcoat_enabled = true
			out.clearcoat = 0.51
			out.clearcoat_roughness = 0.18
		"INTERIOR":
			out = StandardMaterial3D.new()
			out.albedo_color = Color("736353")
			out.metallic = 0.05
			out.roughness = 0.69
			out.emission_enabled = true
			out.emission = Color("ad8060")
			out.emission_energy_multiplier = 0.28
		"PARAPET":
			out = Materials.surface("CONCRETE", Color("5f646b")).duplicate() as StandardMaterial3D
			out.albedo_color = Color("71787c")
			out.uv1_triplanar = false
			out.uv1_world_triplanar = false
			out.uv1_scale = Vector3.ONE
		_:
			out = StandardMaterial3D.new()
			out.albedo_color = Color("969b9b")
			out.roughness = 0.75
	# Each architectural strip is authored with a front-facing normal,
	# but inset jambs and the backside of the glazed interior can be seen
	# from both the roadway and adjacent sidewalk. Disable face culling
	# on this limited pilot so openings never appear as missing surfaces.
	# A later DCC-authored closed-wall asset should replace this policy
	# with consistently outward-wound, single-sided faces.
	out.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[family] = out
	return out

func _push(family: String, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, repeat_scale: float = 1.0) -> void:
	if not _buffers.has(family):
		_buffers[family] = []
	var quads: Array = _buffers[family]
	quads.append([a, b, c, d, repeat_scale])

func _rect(family: String, x0: float, x1: float,
		y0: float, y1: float, z: float, repeat_scale: float = 1.0) -> void:
	if x1 <= x0 or y1 <= y0:
		return
	_push(family, Vector3(x0, y0, z), Vector3(x0, y1, z),
		Vector3(x1, y1, z), Vector3(x1, y0, z), repeat_scale)

func _wall_segment(x0: float, x1: float, y0: float, y1: float) -> void:
	_rect("MASONRY" if _style == "MASONRY" else "CLADDING",
		x0, x1, y0, y1, FRONT, 0.30 if _style == "MASONRY" else 0.20)

func _window(x0: float, x1: float, bottom: float, top: float, is_lit: bool) -> void:
	# Actual absence of exterior wall geometry in the opening; draw the
	# receding jamb, soffit and sill, and put glass *behind* the wall plane.
	# The parent building collision remains unchanged and sealed behind it.
	var jamb := "REVEALS" if _style == "MASONRY" else "STEEL"
	var inner_left := x0 + 0.105
	var inner_right := x1 - 0.105
	var lower := bottom + 0.10
	var upper := top - 0.10
	_push(jamb, Vector3(x0, bottom, FRONT), Vector3(x0, top, FRONT),
		Vector3(inner_left, upper, GLASS), Vector3(inner_left, lower, GLASS))
	_push(jamb, Vector3(inner_right, lower, GLASS), Vector3(inner_right, upper, GLASS),
		Vector3(x1, top, FRONT), Vector3(x1, bottom, FRONT))
	_push(jamb, Vector3(x0, top, FRONT), Vector3(x1, top, FRONT),
		Vector3(inner_right, upper, GLASS), Vector3(inner_left, upper, GLASS))
	_push(jamb, Vector3(inner_left, lower, GLASS), Vector3(inner_right, lower, GLASS),
		Vector3(x1, bottom, FRONT), Vector3(x0, bottom, FRONT))
	_statistics["reveal_faces"] += 4
	_rect("INTERIOR" if is_lit else "GLASS",
		inner_left, inner_right, lower, upper, GLASS + 0.007, 0.72)
	# Window dividers are part of the architectural mesh, not intersecting
	# primitive boxes. Transoms sit in the reveal plane.
	var mullion := "STEEL"
	var middle := (inner_left + inner_right) * 0.5
	var t := 0.045 if _style == "GLAZED" else 0.025
	_rect(mullion, middle - t, middle + t, lower, upper, GLASS - 0.019)
	_rect(mullion, inner_left, inner_right,
		lower + (upper - lower) * 0.46 - t, lower + (upper - lower) * 0.46 + t,
		GLASS - 0.021)
	_statistics["window_openings"] += 1

func _generate_facade() -> void:
	var half := building_width * 0.5
	var bay_count := 4
	var x_start := -half + 0.42
	var content_width := building_width - 0.84
	var bay := content_width / float(bay_count)
	# Ground-floor retail is one coherent storefront with full-height glazed
	# bays and thick piers. Its canopy follows the same structural module.
	_wall_segment(-half, half, 0.15, 0.52)
	_wall_segment(-half, half, GROUND - 0.44, GROUND)
	_wall_segment(-half, x_start, 0.52, GROUND - 0.44)
	_wall_segment(half - 0.42, half, 0.52, GROUND - 0.44)
	for i in range(bay_count):
		var x0 := x_start + float(i) * bay + 0.09
		var x1 := x_start + float(i + 1) * bay - 0.09
		var y0 := 0.65
		var y1 := GROUND - 0.63
		# Real perimeter grid, lintels and recessed panes, not a large opaque
		# fake window pasted on a whole box.
		_rect("STEEL", x0 - 0.075, x1 + 0.075, y0 - 0.09, y0, FRONT - 0.06)
		_rect("STEEL", x0 - 0.075, x1 + 0.075, y1, y1 + 0.09, FRONT - 0.06)
		_window(x0, x1, y0, y1, i == 1 or i == 2)
		if i < bay_count - 1:
			_wall_segment(x1, x_start + float(i + 1) * bay + 0.09, 0.52, GROUND - 0.44)
		_statistics["shopfront_openings"] += 1
	# Real elevated window sills and intermediate floor piers. Floors are
	# measured 3.45m, and doors 3.3m: no one-pixel "windows" on giant walls.
	var level := GROUND
	var floor_index := 0
	while level < building_height - 0.36:
		var ceiling := minf(building_height, level + STOREY)
		var open_bottom := level + 0.65
		var open_top := minf(ceiling - 0.48, open_bottom + 2.02)
		if open_top - open_bottom < 0.40:
			_wall_segment(-half, half, level, ceiling)
			break
		_wall_segment(-half, half, level, open_bottom)
		_wall_segment(-half, half, open_top, ceiling)
		_wall_segment(-half, x_start, open_bottom, open_top)
		_wall_segment(half - 0.42, half, open_bottom, open_top)
		for i in range(bay_count):
			var x0 := x_start + float(i) * bay + 0.32
			var x1 := x_start + float(i + 1) * bay - 0.32
			if i < bay_count - 1:
				_wall_segment(x1, x_start + float(i + 1) * bay + 0.32, open_bottom, open_top)
			_window(x0, x1, open_bottom, open_top,
				(floor_index * 5 + i * 7 + (1 if _style == "GLAZED" else 0)) % 5 == 0)
		_rect("REVEALS", -half, half, level, level + 0.085, FRONT - 0.042)
		floor_index += 1
		level = ceiling
	# Frame cap and natural stone watertable, all strips share real depth.
	_rect("PARAPET", -half, half, building_height - 0.22,
		building_height + 0.30, FRONT - 0.10)
	_rect("REVEALS", -half, half, 0.10, 0.38, FRONT - 0.058)
	_build_swept_canopy(-half + 0.28, half - 0.28)
	# Finish the *actual* structure instead of keeping an underlying solid
	# visual cube that filled the physically recessed window openings.
	_build_enclosing_shell()
	_flush_meshes()
	_build_storefront_identification()
	# The side-facing façades, not just the wall to the south, dominate
	# visibility for players actually walking up Central Exchange.
	var avenue := AvenueFrontage.new()
	avenue.name = "AvenueFacingArchitecture"
	avenue.configure(building_width, building_height, building_depth,
		district, storefront_name)
	add_child(avenue)
	_statistics["avenue_windows"] = int(avenue.call("get_avenue_stats")["windows"])

func _build_swept_canopy(x0: float, x1: float) -> void:
	# One ribbed extruded canopy surface, curved over the actual sidewalk
	# without replacing pedestrian collision or crossing ramps.
	var segments := 20
	var y := GROUND + 0.02
	for i in range(segments):
		var u := float(i) / float(segments)
		var v := float(i + 1) / float(segments)
		var z0 := lerpf(FRONT - 0.05, CANOPY_REACH, u)
		var z1 := lerpf(FRONT - 0.05, CANOPY_REACH, v)
		var y0 := y + sin(u * PI) * 0.095 - u * 0.10
		var y1 := y + sin(v * PI) * 0.095 - v * 0.10
		_push("STEEL",
			Vector3(x0, y0, z0), Vector3(x1, y0, z0),
			Vector3(x1, y1, z1), Vector3(x0, y1, z1))
		_statistics["canopy_segments"] += 1
	# The face of the canopy is a single continuous metal fascia.
	_rect("CLADDING", x0, x1, y - 0.24, y - 0.02, CANOPY_REACH - 0.015)

func _build_enclosing_shell() -> void:
	# Built from the same UV / PBR material surfaces as the storefront.
	# Parent retains a full-volume collider for gameplay but no BoxMesh
	# visual that can bleed through our actual façade openings.
	var half := building_width * 0.5
	var roof := building_height + 0.14
	var back := building_depth + 0.08
	var walls := "MASONRY" if _style == "MASONRY" else "CLADDING"
	# Rear elevation toward the inner parcel service yard, outward +Z.
	_push(walls, Vector3(half, 0.15, back), Vector3(half, roof, back),
		Vector3(-half, roof, back), Vector3(-half, 0.15, back), 0.28)
	# Opaque non-avenue side toward the lot's neighboring service gap.
	var far_side := -1.0 if district == "BRICKWATER" else 1.0
	var x := far_side * (half + 0.04)
	if far_side < 0.0:
		_push(walls, Vector3(x, 0.15, -0.16), Vector3(x, 0.15, back),
			Vector3(x, roof, back), Vector3(x, roof, -0.16), 0.28)
	else:
		_push(walls, Vector3(x, 0.15, back), Vector3(x, 0.15, -0.16),
			Vector3(x, roof, -0.16), Vector3(x, roof, back), 0.28)
	# Roofing membrane and capping line are visible from the rail.
	_push("PARAPET", Vector3(-half, roof, -0.16),
		Vector3(-half, roof, back), Vector3(half, roof, back),
		Vector3(half, roof, -0.16), 0.22)
	# Tinted deep interior plate 0.5m back behind the south display glazing.
	# This preserves visual interior depth even before fully enterable rooms
	# get their own mesh/lighting/collision contract.
	_rect("INTERIOR", -half + 0.1, half - 0.1, 0.5,
		GROUND - 0.42, 0.50, 0.43)

func _build_storefront_identification() -> void:
	# Functional shop identity uses a stable existing district label, not a
	# detached glowing billboard. The small fascia is a single metal surface.
	if storefront_name.is_empty():
		return
	var sign := Label3D.new()
	sign.name = "ExistingShopIdentity"
	sign.text = storefront_name
	sign.font_size = 46
	sign.pixel_size = 0.0065
	sign.modulate = Color("e5dad0") if _style == "MASONRY" else Color("add5d8")
	sign.outline_modulate = Color("1e2d34")
	sign.outline_size = 5
	sign.position = Vector3(0.0, GROUND - 0.095, CANOPY_REACH - 0.036)
	sign.rotation.y = PI
	add_child(sign)

func _flush_meshes() -> void:
	for family in _buffers:
		var polygons: Array = _buffers[family]
		if polygons.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for quad in polygons:
			var a: Vector3 = quad[0]
			var b: Vector3 = quad[1]
			var c: Vector3 = quad[2]
			var d: Vector3 = quad[3]
			var uv_scale: float = quad[4]
			for vertex in [a, b, c, a, c, d]:
				# Surface axes matter for CC0 scanned PBR: side walls
				# follow Z/Y, front/back follow X/Y, roof follows X/Z.
				var along_side := absf(a.x - b.x) < 0.002 and absf(a.x - c.x) < 0.002
				var horizontal := absf(a.y - b.y) < 0.002 and absf(a.y - c.y) < 0.002
				var u: float = (vertex.z if along_side else vertex.x) * uv_scale
				var v: float = (vertex.z if horizontal else vertex.y) * uv_scale
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(vertex)
		surface.generate_normals()
		var mesh: ArrayMesh = surface.commit()
		var surface_node := MeshInstance3D.new()
		surface_node.name = "Facade_%s" % family
		surface_node.mesh = mesh
		surface_node.material_override = _surface_material(family)
		surface_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(surface_node)
		_statistics["architecture_surfaces"] += 1
	_buffers.clear()
