extends Control
## Small screen-centred sight and confirmed game-impact acknowledgement.
var impact := false

func _draw() -> void:
	var center := size * 0.5
	var tint := Color("edbc83") if impact else Color("81e0d4")
	for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + axis * 5.0, center + axis * 15.0, Color("101821"), 4.0, true)
		draw_line(center + axis * 5.0, center + axis * 15.0, tint, 2.0, true)
	draw_circle(center, 1.6, Color.WHITE)
	if impact:
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				var d := Vector2(x, y)
				draw_line(center + d * 6.0, center + d * 12.0, tint, 2.0, true)
