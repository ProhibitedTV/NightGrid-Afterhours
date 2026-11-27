extends RefCounted
## Shared existing civic/venue illumination curve; hours are local game time.
static func darkness(hour: float) -> float:
	if hour >= 17.5:
		return smoothstep(17.5, 20.0, hour)
	if hour < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, hour)
	return 0.0
