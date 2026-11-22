extends Node3D
const WorldPlan = preload("res://scripts/world_plan.gd")
const Materials = preload("res://scripts/material_library.gd")
const PhotoMasonry = preload("res://scripts/photo_masonry.gd")
const CentralFrontage = preload("res://scripts/central_exchange_frontages.gd")
const WestDocksService = preload("res://scripts/west_docks_service_frontage.gd")
const CraneGearWarehouse = preload("res://scripts/crane_gear_warehouse.gd")
const RenderBatchOwner = preload("res://scripts/render_batch_owner.gd")
const VesperWindows = preload("res://scripts/vesper_window_assembly.gd")
const BrickwaterAlley = preload("res://scripts/brickwater_alley.gd")
const BrickwaterFacade = preload("res://scripts/brickwater_facade.gd")
## Seeded city dressing. Static shell collisions + batched decorative geometry.
## The four neighborhoods deliberately share road geometry but not street character.

const CELL = 58.0
const GRID_RADIUS = WorldPlan.GRID_RADIUS
const SEED = 834726
const DISTRICTS = ["VESPER MARKET", "GLASSLINE", "BRICKWATER", "AFTERHOURS", "NORTH QUAY", "WEST DOCKS", "HORIZON GARDENS", "SOUTHWORKS"]
const SHOPS = {
	"VESPER MARKET": ["MOON NOODLES", "VESPER MART", "SILK ROAD", "PAPER TIGER", "NOVA DELI", "INK & TONIC"],
	"GLASSLINE": ["HELIX DATA", "ASTER FINANCE", "NEON EXCHANGE", "VECTOR SYSTEMS", "MONO TOWER"],
	"BRICKWATER": ["RUSTWORKS", "LOADING BAY", "DOCK 9", "HARBOR RADIO", "BOLT SUPPLY", "LAST SHIFT"],
	"AFTERHOURS": ["BLUE HOUR", "SABLE CLUB", "24H ARCADE", "STATIC ROOM", "GHOST FM", "VOLT RAMEN"],
	"NORTH QUAY": ["QUAY FRESH", "MARINER DINER", "SEAWALL SUPPLY", "TIDELINE DELI", "HARBOR COFFEE"],
	"WEST DOCKS": ["PIER STORAGE", "CRANE & GEAR", "NINE LOGISTICS", "SHIFT HOUSE", "COLD CHAIN"],
	"HORIZON GARDENS": ["GARDEN MARKET", "HORIZON HEALTH", "COMMONS LIBRARY", "ORCHARD MART", "EASTSIDE FIRE"],
	"SOUTHWORKS": ["MUNICIPAL WORKS", "CITY RECORDS", "DEPOT 11", "WORKER CO-OP", "SUBSTATION 4"]
}
const ACCENT = {
	"VESPER MARKET": Color("ffc46b"),
	"GLASSLINE": Color("61cbff"),
	"BRICKWATER": Color("f68b59"),
	"AFTERHOURS": Color("ef68ce"),
	"NORTH QUAY": Color("79d6cb"),
	"WEST DOCKS": Color("d3a175"),
	"HORIZON GARDENS": Color("91d69c"),
	"SOUTHWORKS": Color("e0b275")
}
const BRICK = Color("713e48")
const METAL = Color("38465a")
const CONCRETE = Color("505865")
const ROAD_PAINT = Color("b9b8aa")
const DARK_GLASS = Color("1d3449")

var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _palette: Dictionary = {}
var _statistics := {"buildings": 0, "storefronts": 0, "street_props": 0, "batched_details": 0, "districts": 8, "landmarks": 0, "authored_lots": 0, "variant_lots": 0}
var _initialized := false
var world_seed: int = 834726
var world_manifest: Dictionary = {}
const STREAM_RADIUS = 2
const UNLOAD_RADIUS = 3
# Preload the approach before a car crosses the next block boundary. A single
# heavy collision/facade block may still cost a frame; never build a full 5x5
# batch on the moving player's render loop.
const PREFETCH_SECONDS = 1.25
const STREAM_STAGES_PER_FRAME = 1
const STREAM_BATCHES_PER_STAGE = 6
## Optional live sidewalk agents can hold at most twelve fully loaded parcels.
const MAX_PEDESTRIAN_RESERVATIONS = 12
var _pedestrian_reservations: Dictionary = {}
var _reservation_prune_due := false
var _loaded: Dictionary = {}
var _brickwater_night := 0.0
var _staging: Dictionary = {}
var _active_chunk: Node3D
var _current_block := Vector2i(999, 999)
var _loads := 0
var _unloads := 0
var _stream_locked := false
var _requested_cell := Vector2i(999, 999)
var _prefetch_cell := Vector2i(999, 999)
var _pending: Array[Vector2i] = []
var _last_stream_build_usec := 0
var _peak_stream_build_usec := 0
var _queue_replans := 0
var _stream_steps := 0
var _total_build_usec := 0
var _occupied_collision_fallback_stages := 0
var _server_visual_batches_created := 0
var _server_detail_instances_created := 0

func set_world_seed(value: int) -> void:
	assert(not _initialized)
	world_seed = value

func set_world_manifest(value: Dictionary) -> void:
	assert(not _initialized)
	if WorldPlan.valid_manifest(value):
		world_manifest = value.duplicate(true)

func _ready() -> void:
	# Called from world.gd after attaching this node; never regenerate on reload.
	pass

func generate() -> void:
	if _initialized:
		return
	_initialized = true
	_rng.seed = int(SEED) ^ world_seed
	# Roads, intersection controls and skyline are global; occupied blocks
	# allocate collisions and facade MultiMeshes only when nearby.
	_build_road_language()
	_build_intersections()
	_build_far_skyline()
	_flush_instances()
	set_focus(Vector3.ZERO)

func get_city_stats() -> Dictionary:
	# The atlas counts all authored lots; streaming metrics count only live nodes.
	var result := _statistics.duplicate()
	result["buildings"] = GRID_RADIUS * GRID_RADIUS * 8 - WorldPlan.LANDMARK_BLOCKS.size() * 2
	result["authored_lots"] = result["buildings"]
	result["storefronts"] = result["buildings"]
	result["landmarks"] = WorldPlan.LANDMARK_BLOCKS.size()
	result["loaded_blocks"] = _loaded.size()
	result["loaded_buildings"] = _count_loaded_buildings()
	return result

func get_streaming_stats() -> Dictionary:
	return {
		"loaded_blocks": _loaded.size(),
		"total_blocks": GRID_RADIUS * GRID_RADIUS * 4,
		"loaded_buildings": _count_loaded_buildings(),
		"loads": _loads, "unloads": _unloads,
		"radius": STREAM_RADIUS, "unload_radius": UNLOAD_RADIUS,
		"pending_blocks": _pending.size(), "staging_blocks": _staging.size(),
		"pedestrian_reservations": _pedestrian_reservations.size(),
		"stage_steps": _stream_steps, "total_build_usec": _total_build_usec,
		"queue_replans": _queue_replans,
		"last_build_usec": _last_stream_build_usec,
		"peak_build_usec": _peak_stream_build_usec,
		"prefetch_seconds": PREFETCH_SECONDS,
		"occupied_collision_fallback_stages": _occupied_collision_fallback_stages,
		"render_batch_backend": "RenderingServer",
		"render_batches_created": _server_visual_batches_created,
		"visual_instances_created": _server_detail_instances_created
	}

func get_render_batch_stats() -> Dictionary:
	# Snapshot only for F10 evidence and QA; never traverse the SceneTree for
	# every video frame. Includes both complete and partially staged chunks.
	var owners := 0
	var batches := 0
	var details := 0
	var global_owner := get_node_or_null("GlobalVisualBatches")
	if global_owner != null:
		var global_stats: Dictionary = global_owner.call("get_batch_stats")
		owners += 1
		batches += int(global_stats["batches"])
		details += int(global_stats["instances"])
	for grid in _loaded:
		var chunk: Node3D = _loaded[grid]
		var owner := chunk.get_node_or_null("VisualBatches")
		if owner != null:
			var stats: Dictionary = owner.call("get_batch_stats")
			owners += 1
			batches += int(stats["batches"])
			details += int(stats["instances"])
	for grid in _staging:
		var partial: Node3D = (_staging[grid] as Dictionary)["node"]
		var owner := partial.get_node_or_null("VisualBatches")
		if owner != null:
			var stats: Dictionary = owner.call("get_batch_stats")
			owners += 1
			batches += int(stats["batches"])
			details += int(stats["instances"])
	return {
		"renderer": "RenderingServer",
		"owner_nodes": owners,
		"live_batches": batches,
		"live_detail_instances": details,
		"avoided_scene_nodes": batches,
		"ever_created_batches": _server_visual_batches_created
	}

func get_loaded_blocks() -> Array[Vector2i]:
	var blocks: Array[Vector2i] = []
	for key in _loaded:
		blocks.append(key)
	blocks.sort()
	return blocks

func is_spawn_area_ready(at: Vector3, radius: float) -> bool:
	# New optional NPCs require complete nearby parcels, not just the first
	# collision-shell stage. Never force synchronous construction for them.
	if not _initialized or not at.is_finite() or not is_finite(radius) or radius < 0.0 or radius > 20.0:
		return false
	var min_x := floori((at.x-radius)/CELL)
	var max_x := floori((at.x+radius)/CELL)
	var min_z := floori((at.z-radius)/CELL)
	var max_z := floori((at.z+radius)/CELL)
	if min_x < -GRID_RADIUS or min_z < -GRID_RADIUS or max_x >= GRID_RADIUS or max_z >= GRID_RADIUS:
		return false
	for ix in range(min_x,max_x+1):
		for iz in range(min_z,max_z+1):
			var node: Variant = _loaded.get(Vector2i(ix,iz))
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				return false
	return true

## Reserve the whole straight, single-parcel sidewalk link BEFORE making its
## actor live. No preloading or synchronous construction on this path.
func reserve_pedestrian_parcel(id: String, start: Vector3, end: Vector3) -> bool:
	if id.is_empty() or id.length()>64 or not start.is_finite() or not end.is_finite():
		return false
	if start.distance_to(end)<1.0 or start.distance_to(end)>30.0:
		return false
	var cell := Vector2i(floori(start.x/CELL),floori(start.z/CELL))
	if cell!=Vector2i(floori(end.x/CELL),floori(end.z/CELL)):
		return false
	if not is_spawn_area_ready(start,0.65) or not is_spawn_area_ready(end,0.65):
		return false
	# Both endpoints and their expanded bounds must lie inside this parcel.
	var minimum := Vector2(cell)*CELL+Vector2.ONE*0.65
	var maximum := Vector2(cell+Vector2i.ONE)*CELL-Vector2.ONE*0.65
	for p in [start,end]:
		if p.x<minimum.x or p.x>maximum.x or p.z<minimum.y or p.z>maximum.y:
			return false
	if _pedestrian_reservations.has(id):
		return _pedestrian_reservations[id]==cell
	if _pedestrian_reservations.size()>=MAX_PEDESTRIAN_RESERVATIONS:
		return false
	_pedestrian_reservations[id] = cell
	return true

## Only release after the physical actor has been disabled or safely recycled.
func release_pedestrian_parcel(id: String) -> bool:
	if not _pedestrian_reservations.erase(id):
		return false
	_reservation_prune_due = true
	return true

func _count_loaded_buildings() -> int:
	var count := 0
	for key in _loaded:
		var grid: Vector2i = key
		if WorldPlan.landmark_for_block(grid.x, grid.y).is_empty():
			count += 2
	return count

func set_streaming_enabled(value: bool) -> void:
	_stream_locked = not value
	if _stream_locked:
		_pending.clear()
		_discard_unrequested_stages()
		# On resume, an unchanged actor cell must still rebuild the missing
		# predictive queue. Pausing streaming must not permanently lose work.
		_requested_cell = Vector2i(999, 999)
		_prefetch_cell = Vector2i(999, 999)

func _grid_cell(at: Vector3) -> Vector2i:
	return Vector2i(
		clampi(floori(at.x / CELL), -GRID_RADIUS, GRID_RADIUS - 1),
		clampi(floori(at.z / CELL), -GRID_RADIUS, GRID_RADIUS - 1))

func _candidate_priority(block: Vector2i, focus: Vector2i, forecast: Vector2i) -> int:
	# Safety-critical, currently occupied geometry precedes speculative blocks.
	var immediate := maxi(absi(block.x - focus.x), absi(block.y - focus.y))
	var future := maxi(absi(block.x - forecast.x), absi(block.y - forecast.y))
	return mini(immediate * 10, future * 10 + 5)

func _required_blocks(focus: Vector2i, forecast: Vector2i) -> Array[Vector2i]:
	var wanted := {}
	for center in [focus, forecast]:
		for x in range(maxi(-GRID_RADIUS, center.x - STREAM_RADIUS),
				mini(GRID_RADIUS, center.x + STREAM_RADIUS + 1)):
			for z in range(maxi(-GRID_RADIUS, center.y - STREAM_RADIUS),
					mini(GRID_RADIUS, center.y + STREAM_RADIUS + 1)):
				wanted[Vector2i(x, z)] = true
	var result: Array[Vector2i] = []
	for key in wanted:
		var block: Vector2i = key
		if not _loaded.has(block):
			result.append(block)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var rank_a := _candidate_priority(a, focus, forecast)
		var rank_b := _candidate_priority(b, focus, forecast)
		if rank_a != rank_b:
			return rank_a < rank_b
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

func request_focus(at: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	# Gameplay traversal uses this nonblocking path. The player can move while
	# blocks are prepared; earlier loaded geometry remains until replacement is
	# ready. Prediction is clamped to the immutable authored city boundary.
	if not _initialized or _stream_locked:
		return
	var current := _grid_cell(at)
	var forecast := _grid_cell(at + Vector3(velocity.x, 0.0, velocity.z) * PREFETCH_SECONDS)
	if current == _requested_cell and forecast == _prefetch_cell:
		return
	_requested_cell = current
	_prefetch_cell = forecast
	_current_block = current
	# A fast arrival must never finish an entire partially staged city chunk
	# in the physics callback. Prime only the collision-bearing stage(s);
	# decorative parcels and material batches remain queued for render frames.
	if not _loaded.has(current):
		_ensure_occupied_collision(current)
	_pending = _required_blocks(current, forecast)
	_discard_unrequested_stages()
	_queue_replans += 1
	if _pending.is_empty():
		_prune_distant(current, forecast)

func _process(_delta: float) -> void:
	if not _initialized or _stream_locked:
		return
	if _pending.is_empty():
		if _reservation_prune_due:
			_prune_distant(_requested_cell,_prefetch_cell)
		return
	# One bounded build stage per rendered frame. A parcel collider is
	# present before either high-detail building frontage is authored.
	var block: Vector2i = _pending[0]
	if _run_build_stage(block):
		_pending.pop_front()
	if _pending.is_empty():
		_prune_distant(_requested_cell, _prefetch_cell)

func _prune_distant(focus: Vector2i, forecast: Vector2i) -> void:
	_reservation_prune_due = false
	var pinned := {}
	for cell in _pedestrian_reservations.values():
		pinned[cell] = true
	var obsolete: Array[Vector2i] = []
	for key in _loaded:
		var block: Vector2i = key
		var focus_distance := maxi(absi(block.x - focus.x), absi(block.y - focus.y))
		var forecast_distance := maxi(absi(block.x - forecast.x), absi(block.y - forecast.y))
		if focus_distance > UNLOAD_RADIUS and forecast_distance > UNLOAD_RADIUS and not pinned.has(block):
			obsolete.append(block)
	for block in obsolete:
		var node: Node3D = _loaded[block]
		_loaded.erase(block)
		node.queue_free()
		_unloads += 1

func set_focus(at: Vector3) -> void:
	# Teleport, save restore and explicit tests need an immediately solid ring.
	# Preserve this behavior and cancel speculative work on that transition.
	if not _initialized or _stream_locked:
		return
	var cell := _grid_cell(at)
	if cell == _current_block and _pending.is_empty():
		return
	_current_block = cell
	_requested_cell = cell
	_prefetch_cell = cell
	_pending.clear()
	for block in _required_blocks(cell, cell):
		_load_block(block)
	_discard_unrequested_stages()
	_prune_distant(cell, cell)

func _ensure_occupied_collision(block: Vector2i) -> void:
	if _loaded.has(block):
		return
	# The initial build stage creates both parcel collision shells. If that
	# stage is already staged, do not finish its visual work on actor arrival.
	if not _staging.has(block):
		_run_build_stage(block)
		_occupied_collision_fallback_stages += 1
	# Landmarks build their physical structures in phase 1 rather than the
	# normal parcel-shell phase 0. Complete only that collision-bearing stage.
	if not WorldPlan.landmark_for_block(block.x, block.y).is_empty() and _staging.has(block):
		var work: Dictionary = _staging[block]
		if int(work["phase"]) == 1:
			_run_build_stage(block)
			_occupied_collision_fallback_stages += 1

func _load_block(block: Vector2i) -> void:
	# Explicit teleport, interior exit, save restore and initial spawn need a
	# completely solid destination ring. This path is intentionally blocking.
	while not _loaded.has(block):
		_run_build_stage(block)

func _discard_unrequested_stages() -> void:
	var old: Array[Vector2i] = []
	for key in _staging:
		var block: Vector2i = key
		if not _pending.has(block):
			old.append(block)
	for block in old:
		var work: Dictionary = _staging[block]
		var partial: Node3D = work["node"]
		_staging.erase(block)
		partial.queue_free()

func _run_build_stage(block: Vector2i) -> bool:
	var started := Time.get_ticks_usec()
	if not _staging.has(block):
		var node := Node3D.new()
		node.name = "Block_%d_%d" % [block.x, block.y]
		add_child(node)
		var seeded := RandomNumberGenerator.new()
		seeded.seed = int(world_seed) ^ int(SEED) ^ (
			(block.x + GRID_RADIUS + 1) * 156553 + (block.y + GRID_RADIUS + 1) * 933847)
		_staging[block] = {
			"node": node, "phase": 0, "rng_state": seeded.state,
			"batches": {}, "flush_keys": [], "flush_cursor": 0
		}
	var work: Dictionary = _staging[block]
	_active_chunk = work["node"]
	_batches = work["batches"]
	_rng.state = int(work["rng_state"])
	var phase: int = int(work["phase"])
	var landmark: String = WorldPlan.landmark_for_block(block.x, block.y)
	var finished := false
	match phase:
		0:
			_build_block_base(block.x, block.y)
			if landmark.is_empty():
				_build_block_shells(block.x, block.y)
				if block == BrickwaterAlley.PILOT_BLOCK:
					_build_brickwater_alley(block.x, block.y)
			work["phase"] = 1
		1:
			if landmark.is_empty():
				_build_block_lot(block.x, block.y, 0)
				work["phase"] = 2
			else:
				var center := Vector3((float(block.x) + 0.5) * CELL,
					0.0, (float(block.y) + 0.5) * CELL)
				_build_landmark(center, landmark)
				_statistics["landmarks"] += 1
				work["phase"] = 4
		2:
			_build_block_lot(block.x, block.y, 1)
			work["phase"] = 3
		3:
			_build_block_street(block.x, block.y)
			work["phase"] = 4
		4:
			var keys: Array = work["flush_keys"]
			if keys.is_empty():
				keys = _batches.keys()
				keys.sort()
				work["flush_keys"] = keys
			var cursor: int = int(work["flush_cursor"])
			var end: int = mini(cursor + STREAM_BATCHES_PER_STAGE, keys.size())
			var unit_mesh := BoxMesh.new()
			unit_mesh.size = Vector3.ONE
			for index in range(cursor, end):
				_flush_instance_key(str(keys[index]), unit_mesh)
			work["flush_cursor"] = end
			finished = end >= keys.size()
	_active_chunk = null
	work["batches"] = _batches
	work["rng_state"] = _rng.state
	_batches = {}
	var cost: int = Time.get_ticks_usec() - started
	_last_stream_build_usec = cost
	_peak_stream_build_usec = maxi(_peak_stream_build_usec, cost)
	_total_build_usec += cost
	_stream_steps += 1
	if finished:
		_loaded[block] = work["node"]
		_staging.erase(block)
		_loads += 1
	else:
		_staging[block] = work
	return finished

func get_district_at(position: Vector3) -> String:
	return WorldPlan.district_at(position)

func get_nearby_landmark(position: Vector3) -> String:
	return WorldPlan.nearby_landmark(position)

func set_night_factor(value: float) -> void:
	_brickwater_night=clampf(value,0.0,1.0)
	BrickwaterFacade.set_night_factor(_brickwater_night)
	var chunk: Node3D = _loaded.get(BrickwaterAlley.PILOT_BLOCK)
	if chunk == null and _staging.has(BrickwaterAlley.PILOT_BLOCK):
		chunk = _staging[BrickwaterAlley.PILOT_BLOCK]["node"]
	if chunk != null:
		var alley := chunk.get_node_or_null("BrickwaterServiceAlley")
		if alley != null:
			alley.call("set_night_factor",_brickwater_night)
	# Static shared emissive materials change with the time controller.
	var brightness := 2.35 * smoothstep(0.42, 0.78, clampf(value, 0.0, 1.0))
	for key in _palette:
		if str(key).ends_with("_glow"):
			var material: StandardMaterial3D = _palette[key]
			material.emission_energy_multiplier = brightness

func _material(color: Color, emissive: bool = false, surface_kind: String = "") -> StandardMaterial3D:
	var key := color.to_html(false) + ("_glow" if emissive else "_matte")
	if not surface_kind.is_empty():
		key += "_surface_" + surface_kind
	if _palette.has(key):
		return _palette[key]
	var material: StandardMaterial3D
	if not surface_kind.is_empty():
		material = Materials.surface(surface_kind, color)
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.13
		material.roughness = 0.74
		if emissive:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 1.65
	_palette[key] = material
	return material

func _detail(at: Vector3, size: Vector3, color: Color, glow: bool = false, surface_kind: String = "") -> void:
	# MultiMesh keeps tens of thousands of architectural parts to a few draw calls.
	var material_key := color.to_html(false) + ("_glow" if glow else "_matte")
	if not surface_kind.is_empty():
		material_key += "_surface_" + surface_kind
	var key := "%s|%d,%d" % [material_key, floori(at.x / (CELL * 2.0)), floori(at.z / (CELL * 2.0))]
	if not _batches.has(key):
		_batches[key] = []
		_material(color, glow, surface_kind)
	var transforms: Array = _batches[key]
	transforms.append(Transform3D(Basis().scaled(size), at))
	_statistics["batched_details"] += 1

func _solid(at: Vector3, size: Vector3, color: Color, surface_kind: String = "CONCRETE") -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = PhotoMasonry.surface(color) if surface_kind == "PHOTO_BRICK" else Materials.surface(surface_kind, color)
	body.add_child(visual)
	(_active_chunk if _active_chunk != null else self).add_child(body)

func _flush_instance_key(key: String, unit_mesh: BoxMesh) -> void:
	var transforms: Array = _batches.get(key, [])
	if transforms.is_empty():
		_batches.erase(key)
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = unit_mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	# One owner per chunk (or global road paint) replaces dozens of
	# MultiMeshInstance3D children; all batches still render through the
	# existing material-keyed, spatially grouped MultiMesh assets.
	var parent: Node3D = _active_chunk if _active_chunk != null else self
	var owner_name := "VisualBatches" if _active_chunk != null else "GlobalVisualBatches"
	var owner: Node3D = parent.get_node_or_null(owner_name)
	if owner == null:
		owner = RenderBatchOwner.new()
		owner.name = owner_name
		parent.add_child(owner)
	owner.call("add_batch", multimesh, _palette[str(key).split("|")[0]])
	_server_visual_batches_created += 1
	_server_detail_instances_created += transforms.size()
	_batches.erase(key)

func _flush_instances() -> void:
	var unit_mesh := BoxMesh.new()
	unit_mesh.size = Vector3.ONE
	for key in _batches.keys():
		_flush_instance_key(str(key), unit_mesh)

func _build_road_language() -> void:
	for road_index in range(-GRID_RADIUS, GRID_RADIUS + 1):
		var axis := float(road_index) * CELL
		# Dash lines only between intersections, with narrow shoulder paint.
		for segment in range(-GRID_RADIUS, GRID_RADIUS):
			var middle := (float(segment) + 0.5) * CELL
			for lane_mark in range(-3, 4):
				var along := middle + float(lane_mark) * 6.2
				_detail(Vector3(axis, 0.018, along), Vector3(0.16, 0.026, 2.3), ROAD_PAINT)
				_detail(Vector3(along, 0.018, axis), Vector3(2.3, 0.026, 0.16), ROAD_PAINT)
			# Cracked asphalt repairs, not an identical repeating texture.
			if _rng.randf() > 0.30:
				var patch := middle + _rng.randf_range(-14.0, 14.0)
				_detail(Vector3(axis + 3.4, 0.011, patch), Vector3(1.6, 0.015, 3.8), Color("2d313b"))
		# Solid edge markings give the player a reliable read on lanes.
		for side in [-1.0, 1.0]:
			_detail(Vector3(axis + side * 6.65, 0.016, 0.0), Vector3(0.10, 0.025, 490.0), Color("707b88"))
			_detail(Vector3(0.0, 0.016, axis + side * 6.65), Vector3(490.0, 0.025, 0.10), Color("707b88"))

func _build_intersections() -> void:
	for ix in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for iz in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var x := float(ix) * CELL
			var z := float(iz) * CELL
			# Four clear zebra crossings and stop bars per intersection.
			for stripe in range(-4, 5):
				var offset := float(stripe) * 1.30
				for side in [-1.0, 1.0]:
					_detail(Vector3(x + offset, 0.030, z + side * 10.3), Vector3(0.80, 0.026, 3.15), ROAD_PAINT)
					_detail(Vector3(x + side * 10.3, 0.030, z + offset), Vector3(3.15, 0.026, 0.80), ROAD_PAINT)
			for side in [-1.0, 1.0]:
				_detail(Vector3(x, 0.028, z + side * 13.0), Vector3(12.5, 0.025, 0.23), Color("e9dfd2"))
				_detail(Vector3(x + side * 13.0, 0.028, z), Vector3(0.23, 0.025, 12.5), Color("e9dfd2"))
			# Signal units sit beyond the asphalt, on the sidewalk corner.
			# Signal heads are now driven by traffic_signals.gd, not static decorations.
			if (ix + iz) % 2 == 0:
				_lamp(Vector3(x - 8.4, 0.0, z - 8.6))
			if ix % 2 == 0 and iz % 2 == 0:
				_hydrant(Vector3(x + 9.3, 0.0, z - 9.2))

func _build_block_base(ix: int, iz: int) -> void:
	var center := Vector3((float(ix) + 0.5) * CELL, 0.0, (float(iz) + 0.5) * CELL)
	var district := get_district_at(center)
	var accent: Color = ACCENT[district]
	# Sidewalk slabs, tactile strips, curbs and grates around the perimeter.
	for side in [-1.0, 1.0]:
		# The four parcels surrounding Central Exchange leave a 6m gap at
		# the inner end of each curb. Sloped crossing approaches built by the
		# hero junction occupy that space instead of overlapping raised curbs.
		var inside_corner: bool = absf(center.x) == CELL * 0.5 and absf(center.z) == CELL * 0.5
		var inner_x_edge: bool = inside_corner and (side < 0.0 if center.x > 0.0 else side > 0.0)
		var inner_z_edge: bool = inside_corner and (side < 0.0 if center.z > 0.0 else side > 0.0)
		# The eight generic 36m inner grey boxes formerly sat exactly at
		# x/z = +/-8.2 and longitudinal +/-32m. The permanent hero origin now
		# owns ONE authored photographed glTF replacement per such edge; do not
		# double-render the old BoxMesh underneath the true beveled curb.
		# Other 248 neighborhood edges retain their original stage/collider
		# behavior and are not affected by this one-block pilot.
		if not inner_x_edge:
			_detail(center + Vector3(side * 20.8, 0.18, 0.0),
				Vector3(0.48, 0.24, 42.0), Color("bfc0bd"), false, "PHOTO_CURB")
		if not inner_z_edge:
			_detail(center + Vector3(0.0, 0.18, side * 20.8),
				Vector3(42.0, 0.24, 0.48), Color("bfc0bd"), false, "PHOTO_CURB")
		for slab in range(-4, 5):
			var offset := float(slab) * 4.2
			_detail(center + Vector3(side * 19.3, 0.151, offset), Vector3(0.065, 0.018, 3.3), Color("747c81"))
			_detail(center + Vector3(offset, 0.151, side * 19.3), Vector3(3.3, 0.018, 0.065), Color("747c81"))

func _block_lot_profile(ix: int, iz: int, which: int) -> Dictionary:
	var profile: Dictionary = WorldPlan.lot_profile(ix, iz, which, world_seed)
	var blocks: Dictionary = world_manifest.get("blocks", {})
	var parcel: Variant = blocks.get("%d,%d" % [ix, iz], [])
	if parcel is Array and parcel.size() == 2:
		profile = (parcel[which] as Dictionary).duplicate(true)
	return profile

func _build_block_shells(ix: int, iz: int) -> void:
	# The first stage places BOTH original, save-stable building collision
	# shells before any high-cost façade generation. This avoids a temporary
	# hole in vehicle collision while preparing the rest of the street.
	var center := Vector3((float(ix) + 0.5) * CELL, 0.0, (float(iz) + 0.5) * CELL)
	var district := get_district_at(center)
	for which in range(2):
		var profile := _block_lot_profile(ix, iz, which)
		var x := center.x + (-10.5 if which == 0 else 10.5)
		var z: float = center.z - WorldPlan.PUBLIC_FACADE_SETBACK + float(profile["depth"]) * 0.5
		_build_building(Vector3(x, 0.0, z), profile, district, ix, iz, which, true)

func _build_block_lot(ix: int, iz: int, which: int) -> void:
	var center := Vector3((float(ix) + 0.5) * CELL, 0.0, (float(iz) + 0.5) * CELL)
	var profile := _block_lot_profile(ix, iz, which)
	if (not WorldPlan.is_core_block(ix, iz)) or WorldPlan.lot_variant_index(ix, iz, world_seed) > 0:
		_statistics["variant_lots"] += 1
	var x := center.x + (-10.5 if which == 0 else 10.5)
	var z: float = center.z - WorldPlan.PUBLIC_FACADE_SETBACK + float(profile["depth"]) * 0.5
	_build_building(Vector3(x, 0.0, z), profile, get_district_at(center), ix, iz, which, false, true)
	_statistics["authored_lots"] += 1

func _build_brickwater_alley(ix: int, iz: int) -> void:
	var left := _block_lot_profile(ix,iz,0)
	var right := _block_lot_profile(ix,iz,1)
	var alley := BrickwaterAlley.new()
	alley.name = "BrickwaterServiceAlley"
	alley.position = Vector3((float(ix)+0.5)*CELL,0.0,(float(iz)+0.5)*CELL)
	alley.configure(-10.5+float(left["width"])*0.5,10.5-float(right["width"])*0.5)
	_active_chunk.add_child(alley)
	alley.set_night_factor(_brickwater_night)

func _build_block_street(ix: int, iz: int) -> void:
	var center := Vector3((float(ix) + 0.5) * CELL, 0.0, (float(iz) + 0.5) * CELL)
	var district := get_district_at(center)
	# The pilot replaces the old raised decorative slab and ghost dumpster.
	if Vector2i(ix,iz) != BrickwaterAlley.PILOT_BLOCK:
		_detail(center + Vector3(0.0, 0.155, 3.0), Vector3(3.8, 0.035, 25.0), Color("353e48"))
		for mark in range(4):
			_detail(center + Vector3(0.0, 0.175, -6.0 + float(mark) * 6.0), Vector3(3.4, 0.02, 0.10), Color("62686e"))
		_dumpster(center + Vector3(0.0, 0.3, 10.0))
	_furniture(center, district)
	_statistics["street_props"] += 1


func _build_landmark(center: Vector3, name: String) -> void:
	# Permanent city anchors. Open pedestrian space remains for later story scenes.
	var label_color := Color("ffe0a2")
	match name:
		"LANTERN COURT":
			label_color = Color("f4ba67")
			# Low market pavilion; open arcade with lantern-like light bars.
			_solid(center + Vector3(0.0, 2.20, 15.0), Vector3(18.0, 4.1, 5.0), Color("564759"))
			_detail(center + Vector3(0.0, 4.55, 15.0), Vector3(19.4, 0.35, 6.1), Color("e8a77b"))
			for x in [-8.0, -2.7, 2.7, 8.0]:
				_detail(center + Vector3(x, 3.1, 12.35), Vector3(0.20, 2.2, 0.20), Color("ffbf77"), true)
			for x in [-8.0, 8.0]:
				for z in [-4.0, 4.0]:
					_detail(center + Vector3(x, 2.6, z), Vector3(0.34, 5.0, 0.34), Color("75677c"))
				_detail(center + Vector3(x, 5.20, 0.0), Vector3(0.4, 0.23, 11.0), Color("d29364"), true)
			_label("LANTERN COURT", center + Vector3(0.0, 6.0, 11.9), label_color, 67)
		"HELIX TERMINAL":
			label_color = Color("6de5ee")
			# Civic rail canopy, structural ribs and turquoise station indicator.
			_solid(center + Vector3(0.0, 0.48, 0.0), Vector3(22.0, 0.82, 12.0), Color("4f6971"))
			_detail(center + Vector3(0.0, 0.93, 0.0), Vector3(21.3, 0.11, 11.4), Color("9aadb0"))
			for x in [-10.2, 10.2]:
				for z in [-4.8, 4.8]:
					_solid(center + Vector3(x, 4.4, z), Vector3(0.56, 7.4, 0.56), Color("506c7c"))
			_detail(center + Vector3(0.0, 8.25, 0.0), Vector3(25.5, 0.42, 16.0), Color("263c55"))
			for x in [-9.0, -3.0, 3.0, 9.0]:
				_detail(center + Vector3(x, 8.0, -7.8), Vector3(0.25, 0.33, 0.22), label_color, true)
			_detail(center + Vector3(0.0, 5.30, -8.2), Vector3(13.5, 1.85, 0.20), Color("19273c"))
			_label("HELIX TERMINAL", center + Vector3(0.0, 5.5, -8.42), label_color, 70)
		"FOUNDRY COMMONS":
			label_color = Color("d6b987")
			# Accessible green with an abstract copper civic monument.
			for x in [-18.0, 18.0]:
				_detail(center + Vector3(x, 0.21, 0.0), Vector3(0.45, 0.28, 32.0), Color("7d7067"))
			for z in [-18.0, 18.0]:
				_detail(center + Vector3(0.0, 0.21, z), Vector3(34.0, 0.28, 0.45), Color("7d7067"))
			_detail(center + Vector3(0.0, 0.19, 0.0), Vector3(5.0, 0.15, 34.0), Color("746b66"))
			_detail(center + Vector3(0.0, 0.19, 0.0), Vector3(34.0, 0.15, 4.3), Color("746b66"))
			_solid(center + Vector3(0.0, 1.08, -6.0), Vector3(4.7, 1.7, 4.7), Color("5c666c"))
			_detail(center + Vector3(0.0, 5.10, -6.0), Vector3(0.95, 7.0, 1.0), Color("e4ad76"))
			_detail(center + Vector3(0.85, 6.60, -6.0), Vector3(2.1, 0.4, 1.0), Color("f4c98c"), true)
			_label("FOUNDRY COMMONS", center + Vector3(0.0, 4.4, 17.1), label_color, 60)
		"NORTH QUAY EXCHANGE":
			label_color = Color("81dace")
			# Walk-through covered market and public board, not a solid facade.
			for x in [-13.0, 13.0]:
				for z in [-10.0, 10.0]:
					_solid(center + Vector3(x, 3.20, z), Vector3(0.58, 6.3, 0.58), Color("738d91"), "METAL")
			_detail(center + Vector3(0.0, 6.55, 0.0), Vector3(31.0, 0.42, 24.0), Color("365c65"))
			_detail(center + Vector3(0.0, 6.85, -12.0), Vector3(30.0, 0.18, 0.18), label_color, true)
			for row in [-6.0, 6.0]:
				for x in [-9.0, -3.0, 3.0, 9.0]:
					_detail(center + Vector3(x, 0.65, row), Vector3(4.15, 1.02, 2.20), Color("69777b"))
					_detail(center + Vector3(x, 1.35, row), Vector3(3.75, 0.23, 1.8), Color("d1a775"))
					for produce in [-1.0, 0.0, 1.0]:
						_detail(center + Vector3(x + produce, 1.61, row), Vector3(0.55, 0.32, 0.45), Color("78af78"))
			_label("NORTH QUAY EXCHANGE", center + Vector3(0.0, 5.45, -12.2), label_color, 46)
		"PIER NINE DEPOT":
			label_color = Color("e2ac76")
			# Open loading lanes, freight stacks and a signal gantry.
			for x in [-16.0, 16.0]:
				_detail(center + Vector3(x, 0.22, 0.0), Vector3(0.28, 0.16, 36.0), Color("d6ad70"))
			for row in [-11.0, 11.0]:
				for x in [-12.0, 12.0]:
					_solid(center + Vector3(x, 2.3, row), Vector3(7.5, 4.15, 7.0), Color("6b777c"), "METAL")
					_detail(center + Vector3(x, 4.50, row), Vector3(8.0, 0.24, 7.5), Color("dc9e64"))
			_detail(center + Vector3(0.0, 7.4, 16.5), Vector3(28.0, 0.46, 0.55), label_color)
			for x in [-14.0, 14.0]:
				_detail(center + Vector3(x, 3.95, 16.5), Vector3(0.56, 7.5, 0.56), Color("7e9298"))
			_label("PIER NINE DEPOT", center + Vector3(0.0, 5.9, 16.2), label_color, 56)
		"HORIZON COMMONS":
			label_color = Color("a8dfa6")
			# Public green and walk-through health pavilion.
			_detail(center + Vector3(0.0, 0.19, 0.0), Vector3(36.0, 0.11, 5.0), Color("a4a28e"))
			_detail(center + Vector3(0.0, 0.19, 0.0), Vector3(5.0, 0.11, 36.0), Color("a4a28e"))
			for x in [-13.0, 13.0]:
				for z in [-12.0, 12.0]:
					_detail(center + Vector3(x, 0.19, z), Vector3(5.5, 0.13, 5.4), Color("4d8068"))
			for x in [-8.0, 8.0]:
				_solid(center + Vector3(x, 2.70, 11.0), Vector3(0.40, 5.0, 0.40), Color("729d9a"))
			_detail(center + Vector3(0.0, 5.4, 11.0), Vector3(22.0, 0.45, 8.5), Color("4b7176"))
			_detail(center + Vector3(0.0, 4.6, 6.8), Vector3(4.0, 0.16, 0.16), Color("e4fae2"), true)
			_label("HORIZON COMMONS", center + Vector3(0.0, 5.8, 15.4), label_color, 54)
		"SOUTHWORKS HALL":
			label_color = Color("ebc38c")
			# Municipal service counter, bell canopy, public benches.
			_solid(center + Vector3(0.0, 2.7, 12.0), Vector3(22.0, 4.6, 6.5), Color("5d606b"))
			_detail(center + Vector3(0.0, 5.25, 12.0), Vector3(23.2, 0.46, 7.2), Color("9b8978"))
			for x in [-9.0, -3.0, 3.0, 9.0]:
				_detail(center + Vector3(x, 2.4, 8.5), Vector3(0.36, 4.1, 0.40), Color("c5ac8d"))
			for x in [-12.0, 12.0]:
				for z in [-7.0, 2.0]:
					_detail(center + Vector3(x, 0.65, z), Vector3(3.2, 1.0, 1.4), Color("798084"))
			_detail(center + Vector3(0.0, 6.0, 9.0), Vector3(6.0, 0.14, 0.18), label_color, true)
			_label("SOUTHWORKS HALL", center + Vector3(0.0, 4.10, 8.45), label_color, 53)
		"SABLE SQUARE":
			label_color = Color("fc7fcb")
			# Permanent community stage, public plaza and overhanging marquee.
			_solid(center + Vector3(0.0, 1.0, 11.0), Vector3(19.0, 1.6, 9.5), Color("384057"))
			_solid(center + Vector3(0.0, 5.75, 15.5), Vector3(22.0, 0.55, 1.1), Color("28273e"))
			for x in [-10.4, 10.4]:
				_detail(center + Vector3(x, 4.6, 15.5), Vector3(0.44, 8.8, 0.44), Color("9b6190"))
			for stripe in range(-5, 6):
				_detail(center + Vector3(float(stripe) * 1.77, 2.25, 6.0), Vector3(1.0, 0.17, 0.25), label_color, true)
			_label("SABLE SQUARE", center + Vector3(0.0, 7.15, 14.8), label_color, 70)
	_statistics["street_props"] += 1

func _build_building(center: Vector3, profile: Dictionary, district: String, ix: int, iz: int, which: int,
		shell_only: bool = false, shell_prebuilt: bool = false) -> void:
	var height: float = profile["height"]
	var width: float = profile["width"]
	var depth: float = profile["depth"]
	var wall := Color(str(profile["wall"]))
	var surface_kind: String = profile["material"]
	var front := center.z - depth / 2.0
	var back := center.z + depth / 2.0
	var left := center.x - width / 2.0
	var right := center.x + width / 2.0
	# Preserve the save-stable collider but do not render an opaque block
	# behind the recessed photo-material architecture. West Docks Dock Watch
	# is the real civic storefront at (-4,-1), left (west) lot.
	var dock_watch_exposure := ix == -4 and iz == -1 and which == 0
	var dock_service_exposure := ix == -4 and iz == -1 and which == 1
	var crane_gear_exposure := ix == -4 and iz == -2 and which == 1
	var exchange_walk_in: bool = (ix == -1 and iz == 0 and which == 1) or (ix == 0 and iz == 0 and which == 0)
	var brickwater_exposure := Vector2i(ix,iz)==BrickwaterAlley.PILOT_BLOCK
	var authored_exposure: bool = dock_watch_exposure or dock_service_exposure or crane_gear_exposure or exchange_walk_in
	var shell_at := Vector3(center.x, height / 2.0 + 0.15, center.z)
	var shell_size := Vector3(width, height, depth)
	if not shell_prebuilt:
		if authored_exposure or brickwater_exposure:
			var volume := StaticBody3D.new()
			volume.name = "PreservedBuildingCollision"
			volume.position = shell_at
			if exchange_walk_in:
				# Replace JUST the two fixed Central Exchange whole-volume boxes
				# with a tightly partitioned four-Box collision envelope. The
				# previously solid center is now a 2.84m x 3.35m pedestrian
				# vestibule ending in a real back wall, not a collision trap.
				# This is constructed in stage 0 before the expensive visual art,
				# so nobody ever loses the surrounding building's street collider.
				var portal_half: float = 1.42
				var portal_depth: float = 3.35
				var portal_height: float = 3.17
				var flank_width: float = (width * 0.5 - portal_half)
				for side in [-1.0, 1.0]:
					var flank := CollisionShape3D.new()
					flank.name = "BuildingColliderFlank_%d" % int(side)
					var flank_shape := BoxShape3D.new()
					flank_shape.size = Vector3(flank_width, height, depth)
					flank.shape = flank_shape
					flank.position = Vector3(side * (width * 0.5 + portal_half) * 0.5, 0.0, 0.0)
					volume.add_child(flank)
				var rear := CollisionShape3D.new()
				rear.name = "BuildingColliderVestibuleRear"
				var rear_shape := BoxShape3D.new()
				rear_shape.size = Vector3(portal_half * 2.0, height, depth - portal_depth)
				rear.shape = rear_shape
				rear.position = Vector3(0.0, 0.0, portal_depth * 0.5)
				volume.add_child(rear)
				var header := CollisionShape3D.new()
				header.name = "BuildingColliderVestibuleHeader"
				var header_shape := BoxShape3D.new()
				header_shape.size = Vector3(portal_half * 2.0, height - portal_height, portal_depth)
				header.shape = header_shape
				header.position = Vector3(0.0, portal_height * 0.5, -(depth - portal_depth) * 0.5)
				volume.add_child(header)
			else:
				# Source-owned West Docks warehouse and civic façades retain the
				# complete original single-Box save-stable collision as before.
				var collision := CollisionShape3D.new()
				collision.name = "BuildingCollider"
				var shape := BoxShape3D.new()
				shape.size = shell_size
				collision.shape = shape
				volume.add_child(collision)
			(_active_chunk if _active_chunk != null else self).add_child(volume)
			if brickwater_exposure:
				var envelope := BrickwaterFacade.new()
				envelope.name = "BrickwaterFacade_%d"%which
				envelope.position = Vector3(center.x,0.15,center.z)
				_active_chunk.add_child(envelope)
				envelope.install(width,height,depth,which,wall)
		else:
			_solid(shell_at, shell_size, wall, "PHOTO_BRICK" if surface_kind == "BRICK" else surface_kind)
	if shell_only:
		return
	_statistics["buildings"] += 1
	# Replace fake-window blockout with contiguous UV-mapped wall surfaces
	# around actual 3D openings. Keep collision, seeds and public door anchors.
	if dock_service_exposure:
		# Neighbor of the fixed Dock Watch civic shop. An official CC0
		# photogrammetric glTF gives real shutter geometry/PBR on a cohesive
		# UV-authored building shell, with the SAME invisible save collider.
		var service := WestDocksService.new()
		service.name = "WestDocksServiceFrontage"
		service.configure(width, height, depth)
		service.position = Vector3(center.x, 0.15, center.z)
		_active_chunk.add_child(service)
		_statistics["storefronts"] += 1
		return
	if crane_gear_exposure:
		# Actual UV-authored 3D building replacing the old opaque window-sticker
		# block. Same original save-stable parcel collider, public shop address,
		# roads/sidewalks and streaming lifetime.
		var crane_gear := CraneGearWarehouse.new()
		crane_gear.name = "OriginalCraneGearWarehouse"
		crane_gear.configure(width, height, depth)
		crane_gear.position = Vector3(center.x, 0.15, center.z)
		_active_chunk.add_child(crane_gear)
		_statistics["storefronts"] += 1
		return
	if authored_exposure:
		var names: Array = SHOPS[district]
		var stable_name: String = "DOCK WATCH DESK" if dock_watch_exposure else names[abs(ix * 11 + iz * 17 + which * 3) % names.size()]
		var facade := CentralFrontage.new()
		facade.name = "PhotorealFrontage_%d_%d_%d" % [ix, iz, which]
		facade.configure(width, height, depth, district, stable_name, exchange_walk_in)
		facade.position = Vector3(center.x, 0.15, front)
		_active_chunk.add_child(facade)
		_statistics["storefronts"] += 1
		return

	# Foundation plinth, cast shadow line, parapet, mechanical penthouse.
	_detail(Vector3(center.x, 0.47, front - 0.15), Vector3(width + 0.20, 0.80, 0.22), Color("313743"))
	_detail(Vector3(center.x, height + 0.30, center.z), Vector3(width + 0.72, 0.54, depth + 0.72), Color("1b2634"))
	_detail(Vector3(center.x, height + 1.26, center.z + 1.4), Vector3(width * 0.34, 1.65, depth * 0.31), Color("36404b"))
	for vent in range(3):
		var vx := center.x + (float(vent) - 1.0) * width * 0.25
		_detail(Vector3(vx, height + 2.35, center.z + depth * 0.17), Vector3(1.35, 0.65, 1.1), METAL)
		_detail(Vector3(vx, height + 2.72, center.z + depth * 0.17), Vector3(1.52, 0.10, 1.25), Color("9cabb2"))
	if district == "BRICKWATER" or district == "WEST DOCKS":
		# Rooftop water tank and a vertical fire escape.
		_detail(Vector3(center.x + 3.8, height + 3.2, center.z), Vector3(3.6, 4.4, 3.6), Color("4f6570"))
		_detail(Vector3(center.x + 3.8, height + 5.5, center.z), Vector3(4.0, 0.22, 4.0), Color("a0a2a0"))
		for floor_step in range(2, int(height / 3.4)) if not brickwater_exposure else []:
			var step_y := float(floor_step) * 3.4
			_detail(Vector3(right + 0.28, step_y, center.z + 0.5), Vector3(0.65, 0.17, 5.4), Color("65757c"))
			_detail(Vector3(right + 0.54, step_y + 0.9, center.z + 0.5), Vector3(0.09, 1.70, 5.3), Color("819198"))
	if district == "GLASSLINE" or district == "NORTH QUAY":
		# Facade fins, lit corner spines and tall skyline silhouettes.
		for edge in [left + 0.40, right - 0.40]:
			_detail(Vector3(edge, height * 0.52, front - 0.12), Vector3(0.20, height * 0.90, 0.18), Color("68badd"), true)
		_detail(Vector3(center.x, height + 3.1, center.z), Vector3(0.23, 4.0, 0.23), Color("dce7fa"))
	if district == "AFTERHOURS":
		for band in range(1, int(height / 7.0)):
			var y := float(band) * 7.0
			_detail(Vector3(center.x, y, front - 0.17), Vector3(width * 0.97, 0.12, 0.19), ACCENT[district], true)
	# Outer zoning has recognizably different silhouettes and public frontage.
	if district == "NORTH QUAY":
		for balcony in range(2, int(height / 5.2)):
			var level := float(balcony) * 5.2
			_detail(Vector3(center.x, level, front - 0.82), Vector3(width * 0.68, 0.18, 1.25), Color("879f9b"))
			_detail(Vector3(center.x, level + 0.65, front - 1.30), Vector3(width * 0.68, 0.11, 0.11), Color("75d4ca"), true)
		_detail(Vector3(center.x, height + 2.2, center.z + 2.0), Vector3(width * 0.72, 0.22, 6.0), Color("5a8385"))
	elif district == "WEST DOCKS":
		for stripe in range(2, int(height / 3.2)):
			var level := float(stripe) * 3.2
			_detail(Vector3(center.x, level, front - 0.20), Vector3(width * 0.90, 0.15, 0.15), Color("77665a"))
		for door in [-2.8, 2.8]:
			_detail(Vector3(center.x + door, 2.25, front - 0.32), Vector3(3.6, 4.0, 0.26), Color("626c6e"))
			_detail(Vector3(center.x + door, 4.35, front - 0.38), Vector3(3.7, 0.20, 0.25), Color("d6a36a"))
		_detail(Vector3(center.x - 3.7, height + 3.0, center.z), Vector3(0.7, 5.0, 0.7), Color("917967"))
	elif district == "HORIZON GARDENS":
		for floor_index in range(2, int(height / 5.0)):
			_detail(Vector3(center.x, float(floor_index) * 5.0, front - 0.56),
				Vector3(width * 0.84, 0.26, 0.80), Color("648d70"))
		for garden in [-3.0, 0.0, 3.0]:
			_detail(Vector3(center.x + garden, height + 0.95, center.z - 2.0), Vector3(2.5, 1.45, 2.9), Color("538b70"))
	elif district == "SOUTHWORKS":
		for pipe in [-3.3, 0.0, 3.3]:
			_detail(Vector3(center.x + pipe, height * 0.45, front - 0.27),
				Vector3(0.24, height * 0.80, 0.28), Color("a88b70"))
		for roof_tower in [-3.0, 3.0]:
			_detail(Vector3(center.x + roof_tower, height + 3.5, center.z + 1.5),
				Vector3(1.1, 5.8, 1.2), Color("68757e"))
	# Replace front window stickers on the Moon Noodles parcel with an
	# original continuous frame/reveal/glazing assembly; retain RNG draws.
	var pilot_windows := ix == -3 and iz == -3
	var window_specs: Array[Dictionary] = []
	# Carefully varied windows. Lit and dark windows avoid checkerboard monotony.
	for floor_index in range(2, int(height / 3.3)):
		var fy := float(floor_index) * 3.3 + 0.10
		for window_index in range(4):
			var wx := center.x + (float(window_index) - 1.5) * width * 0.205
			var lit := _rng.randf() > (0.52 if district == "BRICKWATER" else 0.30)
			var glass := Color("b7d7cf") if lit else DARK_GLASS
			var glowing := lit and _rng.randf() > 0.72
			if pilot_windows:
				window_specs.append({"x":wx-center.x,"y":fy,"width":width*0.135,"lit":lit,"glowing":glowing})
			else:
				_detail(Vector3(wx, fy, front - 0.095), Vector3(width * 0.135, 1.48, 0.09), glass, glowing, "GLASS" if not lit else "")
				_detail(Vector3(wx, fy - 0.81, front - 0.12), Vector3(width * 0.145, 0.12, 0.13), Color("101e2b"))
			_detail(Vector3(wx, fy, back + 0.095), Vector3(width * 0.135, 1.48, 0.09), glass, false, "GLASS")
		# Floor banding gives each building a perceived internal structure.
		_detail(Vector3(center.x, fy - 1.55, front - 0.055), Vector3(width, 0.11, 0.13), Color("252d3d"))
		for side in [-1.0, 1.0]:
			if brickwater_exposure and side == (1.0 if which == 0 else -1.0):
				continue
			for side_window in range(2):
				var wz := center.z + (float(side_window) - 0.5) * depth * 0.38
				_detail(Vector3(center.x + side * (width / 2.0 + 0.07), fy, wz), Vector3(0.11, 1.45, 2.0), Color("426178"), false, "GLASS")

	if pilot_windows and not window_specs.is_empty():
		var windows := VesperWindows.build(window_specs)
		windows.name = "VesperWindowAssembly_%d" % which
		windows.position = Vector3(center.x,0.0,front)
		_active_chunk.add_child(windows)

	# Street-level retail facade. Entry is visual-only until interiors exist.
	var sign_color: Color = ACCENT[district]
	_detail(Vector3(center.x, 2.0, front - 0.12), Vector3(width * 0.84, 2.75, 0.14), Color("182637"))
	_detail(Vector3(center.x, 2.0, front - 0.22), Vector3(2.10, 2.55, 0.08), Color("647e8d"), false, "GLASS")
	_detail(Vector3(center.x + 1.0, 2.0, front - 0.24), Vector3(0.07, 2.55, 0.12), Color("121b28"))
	_detail(Vector3(center.x, 4.0, front - 0.24), Vector3(width * 0.86, 0.75, 0.22), Color("1b2636"))
	_detail(Vector3(center.x, 4.45, front - 0.27), Vector3(width * 0.88, 0.12, 0.19), sign_color, true)
	_detail(Vector3(center.x, 3.70, front - 0.27), Vector3(width * 0.88, 0.11, 0.19), sign_color, true)
	var names: Array = SHOPS[district]
	var label_text: String = names[abs(ix * 11 + iz * 17 + which * 3) % names.size()]
	_label(label_text, Vector3(center.x, 4.08, front - 0.42), sign_color, 54)
	_statistics["storefronts"] += 1
	for awning in range(4):
		var awning_x := center.x + (float(awning) - 1.5) * width * 0.19
		var color := sign_color if awning % 2 == 0 else Color("232c3c")
		_detail(Vector3(awning_x, 3.15, front - 1.08), Vector3(width * 0.19, 0.12, 1.75), color)
	# Corner rain pipes and electric conduit remain visible up close.
	_detail(Vector3(left + 0.35, height * 0.48, front - 0.20), Vector3(0.16, height * 0.90, 0.20), Color("87949d"))
	_detail(Vector3(right - 0.35, height * 0.48, front - 0.20), Vector3(0.16, height * 0.90, 0.20), Color("87949d"))
	_detail(Vector3(right - 0.6, 1.25, front - 0.30), Vector3(0.77, 1.05, 0.32), Color("89929d"))

func _label(value: String, at: Vector3, color: Color, point_size: int = 48) -> void:
	var sign := Label3D.new()
	sign.text = value
	sign.font_size = point_size
	sign.pixel_size = 0.011
	sign.modulate = color
	sign.outline_modulate = Color("070e1b")
	sign.outline_size = 8
	sign.position = at
	sign.rotation.y = PI
	sign.double_sided = true
	(_active_chunk if _active_chunk != null else self).add_child(sign)

func _furniture(center: Vector3, district: String) -> void:
	var color: Color = ACCENT[district]
	# Furnishing faces the road, stays on the sidewalks, not in traffic lanes.
	for side in [-1.0, 1.0]:
		_bin(center + Vector3(side * 19.5, 0.0, -12.8), district == "SOUTHWORKS")
		_detail(center + Vector3(side * 19.8, 0.17, -3.5), Vector3(0.54, 0.035, 1.22), Color("232d39"))
	if district == "VESPER MARKET" or district == "NORTH QUAY":
		_vendor(center + Vector3(-5.0, 0.0, -18.6), color)
		_vendor(center + Vector3(5.0, 0.0, -18.6), Color("e48f8a"))
		if district == "NORTH QUAY":
			for bollard in [-14.0, 0.0, 14.0]:
				_detail(center + Vector3(bollard, 0.55, 19.4), Vector3(0.38, 1.1, 0.40), Color("80a9a8"))
				_detail(center + Vector3(bollard, 1.14, 19.4), Vector3(0.59, 0.15, 0.59), color)
	elif district == "BRICKWATER" or district == "WEST DOCKS" or district == "SOUTHWORKS":
		_crates(center + Vector3(-2.0, 0.0, -18.5), district == "SOUTHWORKS")
		_crates(center + Vector3(6.0, 0.0, -18.5), district == "SOUTHWORKS")
		if district == "WEST DOCKS":
			for x in [-7.0, 7.0]:
				_detail(center + Vector3(x, 0.25, 9.0), Vector3(2.6, 0.25, 5.4), Color("bd925b"))
				_detail(center + Vector3(x, 1.10, 9.0), Vector3(2.4, 1.4, 2.7), Color("657582"))
		elif district == "SOUTHWORKS":
			_detail(center + Vector3(0.0, 0.25, -14.0), Vector3(12.0, 0.04, 0.55), Color("d9b67d"))
			for x in [-9.0, 9.0]:
				_solid(center + Vector3(x, 1.20, -17.5), Vector3(0.30, 2.3, 0.30), Color("b5aa91"), "METAL")
	elif district == "GLASSLINE" or district == "HORIZON GARDENS":
		_planter(center + Vector3(-4.0, 0.0, -18.4))
		_planter(center + Vector3(4.0, 0.0, -18.4))
		if district == "HORIZON GARDENS":
			_bench(center + Vector3(0.0, 0.0, 13.6))
			for flower in [-10.0, -6.0, 6.0, 10.0]:
				_detail(center + Vector3(flower, 0.60, 17.5), Vector3(1.20, 0.9, 1.10), Color("5d9879"))
				_detail(center + Vector3(flower, 1.12, 17.5), Vector3(0.42, 0.32, 0.42), Color("e6bd9f"))
	else:
		_vending(center + Vector3(-3.4, 0.0, -18.2), color)
		_bench(center + Vector3(5.4, 0.0, -18.2))
	# Repeated elements in all four districts: alley grime and street repair.
	for patch in range(3):
		var x := center.x + _rng.randf_range(-1.25, 1.25)
		var z := center.z + _rng.randf_range(-9.0, 12.0)
		_detail(Vector3(x, 0.195, z), Vector3(_rng.randf_range(0.7, 2.0), 0.025, _rng.randf_range(0.8, 2.1)), Color("1c2736"))

func _bin(at: Vector3, physical: bool = false) -> void:
	# Solid-looking waist-high street furniture must have an accurately
	# matched collision body at South Bus Works. Keep its thin lid cosmetic:
	# colliding both parts would introduce a seam/step at vehicle bumper level.
	if physical:
		_solid(at + Vector3.UP * 0.45, Vector3(0.8, 0.9, 0.8), Color("253e48"), "METAL")
	else:
		_detail(at + Vector3.UP * 0.45, Vector3(0.8, 0.9, 0.8), Color("253e48"))
	_detail(at + Vector3.UP * 0.94, Vector3(0.92, 0.10, 0.92), Color("728088"))
	_statistics["street_props"] += 1

func _dumpster(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.6, Vector3(2.35, 1.3, 1.8), Color("28666a"))
	_detail(at + Vector3.UP * 1.32, Vector3(2.48, 0.14, 1.9), Color("1b353d"))
	_detail(at + Vector3(-0.70, 0.5, -0.94), Vector3(0.5, 0.25, 0.1), Color("e7c56e"))

func _vendor(at: Vector3, color: Color) -> void:
	_detail(at + Vector3.UP * 1.0, Vector3(3.1, 0.8, 1.65), Color("48515b"))
	_detail(at + Vector3.UP * 2.7, Vector3(3.7, 0.18, 2.05), color)
	for dx in [-1.6, 1.6]:
		_detail(at + Vector3(dx, 1.65, -0.70), Vector3(0.12, 3.3, 0.12), Color("99a1a5"))
	for item in range(5):
		_detail(at + Vector3((float(item) - 2.0) * 0.46, 1.51, -0.52), Vector3(0.35, 0.24, 0.38), Color("e5ba74"))
	_statistics["street_props"] += 1

func _planter(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.42, Vector3(1.9, 0.84, 1.1), Color("7a8a91"))
	for stem in [-0.50, 0.0, 0.50]:
		_detail(at + Vector3(stem, 1.23, 0.0), Vector3(0.50, 1.10, 0.62), Color("42816e"))
	_statistics["street_props"] += 1

func _crates(at: Vector3, physical: bool = false) -> void:
	for index in range(3):
		var ix := float(index % 2)
		var iy := float(index / 2)
		var position := at + Vector3(ix * 1.2, 0.52 + iy * 1.02, 0.0)
		if physical:
			# Match the exact visible 1m cargo crate. Don't add a hidden wall
			# across the garage entrance or all decorative trim as colliders.
			_solid(position, Vector3(1.0, 1.0, 1.0), Color("8e7759"), "WOOD")
		else:
			_detail(position, Vector3(1.0, 1.0, 1.0), Color("8e7759"))
		_detail(at + Vector3(ix * 1.2, 0.52 + iy * 1.02, -0.55), Vector3(0.76, 0.13, 0.07), Color("dac4a4"))
	_statistics["street_props"] += 1

func _vending(at: Vector3, accent: Color) -> void:
	_detail(at + Vector3.UP * 1.20, Vector3(1.6, 2.4, 1.0), Color("283543"))
	_detail(at + Vector3(0.0, 1.50, -0.54), Vector3(1.3, 1.35, 0.07), accent, true)
	_detail(at + Vector3(0.45, 0.45, -0.58), Vector3(0.3, 0.3, 0.10), Color("d8e8ea"), true)
	_statistics["street_props"] += 1

func _bench(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.65, Vector3(3.1, 0.17, 0.72), Color("866e5a"))
	_detail(at + Vector3(0.0, 1.15, 0.32), Vector3(3.1, 0.9, 0.16), Color("866e5a"))
	for dx in [-1.25, 1.25]:
		_detail(at + Vector3(dx, 0.32, 0.0), Vector3(0.19, 0.61, 0.7), Color("384953"))
	_statistics["street_props"] += 1

func _signal(at: Vector3, variant: int) -> void:
	_detail(at + Vector3.UP * 3.0, Vector3(0.25, 6.0, 0.25), Color("738395"))
	_detail(at + Vector3(-1.55, 5.95, 0.0), Vector3(3.0, 0.22, 0.23), Color("738395"))
	_detail(at + Vector3(-3.05, 5.4, 0.0), Vector3(0.60, 1.75, 0.68), Color("152435"))
	var green := variant % 2 == 0
	_detail(at + Vector3(-3.05, 5.9, -0.38), Vector3(0.36, 0.36, 0.06), Color("f0445e") if not green else Color("422b40"), not green)
	_detail(at + Vector3(-3.05, 5.4, -0.38), Vector3(0.36, 0.36, 0.06), Color("66573a"))
	_detail(at + Vector3(-3.05, 4.9, -0.38), Vector3(0.36, 0.36, 0.06), Color("48e1bc") if green else Color("25433e"), green)
	_statistics["street_props"] += 1

func _lamp(at: Vector3) -> void:
	_detail(at + Vector3.UP * 3.5, Vector3(0.23, 7.0, 0.23), Color("627480"))
	_detail(at + Vector3(-0.8, 7.0, 0.0), Vector3(1.65, 0.20, 0.20), Color("627480"))
	_detail(at + Vector3(-1.58, 6.76, 0.0), Vector3(0.85, 0.24, 0.60), Color("ffcd8d"), true)
	_statistics["street_props"] += 1

func _hydrant(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.48, Vector3(0.52, 0.95, 0.55), Color("ce5b60"))
	_detail(at + Vector3.UP * 0.98, Vector3(0.66, 0.18, 0.66), Color("dfab79"))
	_detail(at + Vector3.UP * 0.52, Vector3(0.92, 0.19, 0.25), Color("dca077"))
	_statistics["street_props"] += 1

func _build_far_skyline() -> void:
	# Authored heights and silhouettes. No RNG decides skyline landmarks.
	var silhouettes := [
		18.0, 32.0, 47.0, 23.0, 56.0, 76.0, 34.0, 49.0,
		31.0, 64.0, 40.0, 82.0, 29.0, 43.0, 58.0, 28.0,
		36.0, 51.0, 88.0, 35.0, 60.0, 73.0, 31.0, 44.0,
		39.0, 68.0, 35.0, 61.0, 26.0, 45.0, 69.0, 39.0
	]
	for index in range(silhouettes.size()):
		var angle := TAU * float(index) / float(silhouettes.size())
		var radius := 360.0 + float(index % 4) * 7.5
		var height: float = silhouettes[index]
		var at := Vector3(cos(angle) * radius, height / 2.0, sin(angle) * radius)
		_detail(at, Vector3(14.0 + float(index % 3) * 3.0, height, 14.0 + float(index % 4) * 2.5), Color("172434"))
		if index % 3 == 0:
			_detail(at + Vector3(0.0, height / 2.0 + 0.25, 0.0), Vector3(13.0, 0.16, 12.0), Color("447d90"), true)
