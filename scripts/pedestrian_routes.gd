extends RefCounted
## The two real Central Exchange retail portals use the same permanent
## addresses as the storefront collision regression.
const Plan = preload("res://scripts/world_plan.gd")
const Population = preload("res://scripts/sidewalk_population.gd")

static func retail_links() -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for side in [-1, 1]:
		var x := float(side) * 18.5
		links.append({"id": "central-retail-%d" % side, "district": Plan.district_at(Vector3(x, 0, 29)),
			"start": Vector3(x, 0.25, 9.7), "end": Vector3(x, 0.25, 15.45),
			"kind": "retail_portal", "arrival": "STOREFRONT", "priority": 0})
	return links

static func city_links() -> Array[Dictionary]:
	var links := retail_links()
	for ix in range(-Plan.GRID_RADIUS, Plan.GRID_RADIUS):
		for iz in range(-Plan.GRID_RADIUS, Plan.GRID_RADIUS):
			var sides := Population.block_candidates(ix, iz)
			for side in range(sides.size()):
				var route := sides[side]
				# One pass through every parcel before adding its second pair.
				route["priority"] = 1 + posmod(side + ix + iz, 4)
				route["arrival"] = "RESTING"
				var crossing := _marked_crossing(ix, iz, side)
				if crossing != Vector3i(99, 99, 99):
					route["arrival"] = "WAIT_CROSSING"
					route["signal"] = crossing
				links.append(route)
	return links

static func _marked_crossing(ix: int, iz: int, side: int) -> Vector3i:
	# Stop on an existing sidewalk approach. Only interior grid junctions
	# have conflicting traffic on both axes.
	var crossing := [Vector3i(ix + 1, iz, 0), Vector3i(ix + 1, iz + 1, 1),
		Vector3i(ix, iz + 1, 0), Vector3i(ix, iz, 1)][side] as Vector3i
	if absi(crossing.x) < Plan.GRID_RADIUS and absi(crossing.y) < Plan.GRID_RADIUS and posmod(ix + iz + side, 3) == 0:
		return crossing
	return Vector3i(99, 99, 99)
