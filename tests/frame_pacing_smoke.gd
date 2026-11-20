extends SceneTree
## Determinism under different render callback rates; NOT an FPS benchmark.
const RailSystem = preload("res://scripts/rail_system.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("FRAME_PACING_SMOKE: " + reason)
	quit(1)

func _run_ticks(rail: Node3D, render_calls_per_tick: int) -> Dictionary:
	for tick in range(240):
		rail.call("_physics_process", 1.0 / 60.0)
		for draw in range(render_calls_per_tick):
			rail.call("_process", 1.0 / float(60 * render_calls_per_tick))
	return rail.call("snapshot")

func _verify() -> void:
	if int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)) != 60:
		_fail("Fixed simulation must run at 60Hz")
		return
	if int(ProjectSettings.get_setting("application/run/max_fps", -1)) != 0:
		_fail("Renderer must be uncapped; VSync and the GPU determine actual frames")
		return
	var rail := RailSystem.new()
	root.add_child(rail)
	rail.set_process(false)
	rail.set_physics_process(false)
	rail.set("dwell_remaining", 0.0)
	var initial: Dictionary = rail.call("snapshot")
	var low_draw: Dictionary = _run_ticks(rail, 1)
	rail.call("restore", initial)
	var high_draw: Dictionary = _run_ticks(rail, 4)
	for key in ["x", "speed", "dwell"]:
		if absf(float(low_draw[key]) - float(high_draw[key])) > 0.0001:
			_fail("Render cadence changed train physics: %s" % key)
			return
	for key in ["current_station", "next_station", "direction"]:
		if int(low_draw[key]) != int(high_draw[key]):
			_fail("Render cadence changed train schedule: %s" % key)
			return
	if absf(float(high_draw["x"]) - float(initial["x"])) < 1.0:
		_fail("Train never advanced under fixed physics ticks")
		return
	var train: Node3D = rail.get("train")
	var visual: Node3D = rail.get("train_visual")
	rail.call("restore", initial)
	if absf(visual.position.x) > 0.0001:
		_fail("Saved state left a stale visual offset")
		return
	# Staged capture or teleport should never tween through another district.
	train.position.x = 116.0
	rail.call("_process", 1.0 / 144.0)
	if absf(visual.position.x) > 0.0001:
		_fail("Train teleports must reset the interpolation offset")
		return
	print("FRAME_PACING_SMOKE PASS: 60Hz physics independent of rendered-frame count, safe reloads/teleports")
	quit(0)
