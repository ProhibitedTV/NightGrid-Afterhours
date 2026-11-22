extends Node3D
## Close the saved parcel around the imported apartment openings. The
## original full-size physics box is owned by the collision streaming stage.
const Architecture = preload("res://scripts/brickwater_alley_architecture.gd")
const Maps = preload("res://scripts/material_library.gd")
const Masonry = preload("res://scripts/photo_masonry.gd")
const Plan = preload("res://scripts/world_plan.gd")
const BACKING_DEPTH = 0.38

func install(size: Vector3, lot: int, tint: Color, surface: String, neighbor: bool) -> void:
	var wall: Material = Masonry.surface(tint) if surface == "BRICK" else Maps.surface(surface, tint)
	var alley_wall := Architecture.alley_masonry(lot == 0)
	var half := size * 0.5
	var inward := 1.0 if lot == 0 else -1.0
	var yaw := inward * PI * 0.5
	var face := inward * half.x
	_panel("StreetMasonry", Vector3(0, half.y, -half.z), Vector2(size.x, size.y), PI, wall)
	_panel("RearMasonry", Vector3(0, half.y, half.z), Vector2(size.x, size.y), 0, wall)
	_panel("OuterMasonry", Vector3(-face, half.y, 0), Vector2(size.z, size.y), -yaw, wall)
	_panel("RoofMembrane", Vector3(0, size.y, 0), Vector2(size.x, size.z), 0,
		Maps.surface("PHOTO_SIDEWALK", Color("555457")), -PI * 0.5)

	# The assembled three-metre wall/window modules span this exact opening.
	# Return masonry stays on the saved wall datum so all services meet it.
	var hall_start := Architecture.MIN_Z + Plan.PUBLIC_FACADE_SETBACK - half.z
	var hall_end := hall_start + Architecture.BAY_WIDTH * Architecture.bay_count(neighbor)
	var base := Architecture.FIRST_LEVEL - position.y
	var top := base + Architecture.BAY_WIDTH * Architecture.LEVELS
	if lot == 0 and not neighbor:
		var room_start := Architecture.WORKROOM_START_Z + Plan.PUBLIC_FACADE_SETBACK - half.z
		var room_end := room_start + Architecture.BAY_WIDTH
		_side("GroundMasonry", face, -half.z, room_start, 0, base, yaw, alley_wall)
		_side("GroundMasonryNorth", face, room_end, half.z, 0, base, yaw, alley_wall)
		_side("WorkroomHeader", face, room_start, room_end, Architecture.BAY_WIDTH, base, yaw, alley_wall)
	else:
		_side("GroundMasonry", face, -half.z, half.z, 0, base, yaw, alley_wall)
	_side("UpperMasonry", face, -half.z, half.z, top, size.y, yaw, alley_wall)
	_side("SouthReturn", face, -half.z, hall_start, base, top, yaw, alley_wall)
	_side("NorthReturn", face, hall_end, half.z, base, top, yaw, alley_wall)
	_side("WindowBacking", face - inward * BACKING_DEPTH, hall_start - 0.02, hall_end + 0.02,
		base - 0.02, top + 0.02, yaw, Maps.surface("CONCRETE", Color("32302d")))

func _side(label: String, x: float, z0: float, z1: float, y0: float, y1: float, yaw: float, material: Material) -> void:
	if z1 <= z0 or y1 <= y0:
		return
	_panel(label, Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector2(z1 - z0, y1 - y0), yaw, material)

func _panel(label: String, at: Vector3, size: Vector2, yaw: float, material: Material, pitch: float = 0.0) -> void:
	var panel := QuadMesh.new()
	panel.size = size
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = panel
	view.material_override = material
	view.position = at
	view.rotation = Vector3(pitch, yaw, 0)
	add_child(view)
