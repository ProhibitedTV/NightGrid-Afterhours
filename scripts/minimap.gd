extends Control
## Overview of streets, objective, player and chasing police.

var world_node: Node3D
const CITY_SPAN = 420.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Color(0.04, 0.065, 0.11, 0.88), true)
	var scale := side / CITY_SPAN
	for i in range(-3, 4):
		var p := side / 2.0 + float(i) * 58.0 * scale
		draw_line(Vector2(p, 0.0), Vector2(p, side), Color("46566e"), 4.0)
		draw_line(Vector2(0.0, p), Vector2(side, p), Color("46566e"), 4.0)
	if is_instance_valid(world_node):
		var state: Dictionary = world_node.call("get_map_state")
		var mission: Vector2 = state["mission"]
		var actor: Vector2 = state["player"]
		var color := Color("38e5e4") if state["carrying"] else Color("ffba56")
		draw_circle(_to_map(mission, side, scale), 5.5, color)
		for officer in state["officers"]:
			draw_circle(_to_map(officer, side, scale), 3.5, Color("f04e59"))
		draw_circle(_to_map(actor, side, scale), 5.5, Color("ee72cc"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Color("8eabc4"), false, 2.0)

func _to_map(point: Vector2, side: float, scale: float) -> Vector2:
	return Vector2(side * 0.5 + point.x * scale, side * 0.5 + point.y * scale)
