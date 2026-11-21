extends SceneTree
const Ledger = preload("res://scripts/ambient_civic_ledger.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("AMBIENT_CIVIC: " + message)
		quit(1)
	return ok

func _verify() -> void:
	var sites: Array[Dictionary] = [
		{"site_id":"a", "station_id":"central", "district":"A", "point":Vector3.ZERO},
		{"site_id":"b", "station_id":"west", "district":"B", "point":Vector3.ONE}]
	var a = Ledger.new()
	var b = Ledger.new()
	a.configure(123, sites)
	sites.reverse()
	b.configure(123, sites)
	a.advance(20.0)
	for i in range(200):
		b.advance(0.1)
	if not _check(a.catalog() == b.catalog() and a.catalog().size() == 1 and a.catalog()[0]["state"] == "QUEUED", "seed, site order and timestep independence"):
		return
	a.advance(5.0)
	if not _check(a.catalog()[0]["state"] == "ACTIVE", "active phase"):
		return
	a.advance(13.0)
	if not _check(a.catalog()[0]["state"] == "RESOLVED" and a.open_count() == 0, "resolution"):
		return
	a.advance(50.25)
	b.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
	if not _check(a.catalog() == b.catalog() and a.catalog().size() <= Ledger.MAX_CASES and b.snapshot() == a.snapshot(), "bounded JSON round trip"):
		return
	if not _check(a.catalog()[0]["created_minute"] >= 60, "expired incident removed"):
		return
	b.restore({"minute":"invalid", "fraction":4})
	if not _check(b.catalog().is_empty(), "malformed optional save fallback"):
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var live = world.get("ambient_civic")
	var dispatch = world.get("dispatch")
	var original_heat: float = world.get("heat")
	var original_history: Array = dispatch.history.duplicate(true)
	world.call("_update_ambient_civic", 25.0)
	if not _check(live.open_count() == 1 and float(world.get("heat")) == original_heat and dispatch.history == original_history and dispatch.active.is_empty(), "civilian calls must not alter player police state"):
		return
	for incident in live.catalog():
		if not _check(dispatch.stations.has(incident["station_id"]) and not str(incident["district"]).is_empty() and not (world.get_node("CivicServices").call("site_by_id", incident["site_id"]) as Dictionary).is_empty(), "actual station and civic address"):
			return
	var saved: Dictionary = world.call("_capture_snapshot")
	var previous: Dictionary = live.snapshot()
	world.get("day_night").set("paused", true)
	world.call("_update_ambient_civic", 100.0)
	if not _check(live.snapshot() == previous, "paused day clock"):
		return
	live.restore({})
	live.restore(saved["ambient_civic"])
	if not _check(live.snapshot() == previous, "world save captures ledger"):
		return
	print("AMBIENT_CIVIC_SMOKE PASS: deterministic service lifecycle, expiration, save, pause, actual registry, independent heat")
	quit(0)
