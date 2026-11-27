extends SceneTree
const LightingCurve = preload("res://scripts/venue_lighting_curve.gd")

func _initialize() -> void:
	for i in range(1441):
		var hour := float(i) / 60.0
		var expected := 0.0
		if hour >= 17.5:
			expected = smoothstep(17.5, 20.0, hour)
		elif hour < 7.0:
			expected = 1.0 - smoothstep(5.0, 7.0, hour)
		if not is_equal_approx(LightingCurve.darkness(hour), expected):
			push_error("Lighting curve changed at hour %s" % hour)
			quit(1)
			return
	print("VENUE_LIGHTING_CURVE PASS")
	quit(0)
