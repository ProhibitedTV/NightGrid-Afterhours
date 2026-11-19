extends Control
## Overview of streets, objective, player and chasing police.

var world_node: Node3D
const CITY_SPAN = 560.0
const GRID_RADIUS = 4

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Color(0.04, 0.065, 0.11, 0.88), true)
	var scale := side / CITY_SPAN
	for i in range(-GRID_RADIUS, GRID_RADIUS + 1):
		var p := side / 2.0 + float(i) * 58.0 * scale
		draw_line(Vector2(p, 0.0), Vector2(p, side), Color("46566e"), 4.0)
		draw_line(Vector2(0.0, p), Vector2(side, p), Color("46566e"), 4.0)
	if is_instance_valid(world_node):
		var state: Dictionary = world_node.call("get_map_state")
		var mission: Vector2 = state["mission"]
		var actor: Vector2 = state["player"]
		var color := Color("38e5e4") if state["carrying"] else Color("ffba56")
		draw_circle(_to_map(mission, side, scale), 5.5, color)
		for location in state.get("venues", []):
			var point: Vector2 = location["point"]
			var tint := Color("f3b86d")
			match str(location["kind"]):
				"CAFE":
					tint = Color("86d3df")
				"BAR":
					tint = Color("e5a1a6")
				"CLUB":
					tint = Color("e28eec")
			if not bool(location["open"]):
				tint = tint.darkened(0.65)
			draw_circle(_to_map(point, side, scale), 2.8, tint)
		for place in state.get("services", []):
			var point: Vector2 = place["point"]
			var tint := Color("a6d0c8")
			match str(place["kind"]):
				"GROCERY":
					tint = Color("dec37e")
				"CLINIC", "FIRE":
					tint = Color("86ded1")
				"WAREHOUSE", "GARAGE":
					tint = Color("d59e75")
				"CIVIC", "LIBRARY":
					tint = Color("aba7d6")
			if not bool(place["open"]):
				tint = tint.darkened(0.60)
			var point_on_map := _to_map(point, side, scale)
			draw_rect(Rect2(point_on_map - Vector2(2.8, 2.8), Vector2(5.6, 5.6)), tint, true)
		if bool(state.get("side_quest_active", false)):
			var quest: Vector2 = state["side_quest"]
			var destination := _to_map(quest, side, scale)
			draw_arc(destination, 7.4, 0.0, TAU, 16, Color("fff0ad"), 2.5)
		if bool(state.get("civic_quest_active", false)):
			var target: Vector2 = state["civic_quest"]
			draw_arc(_to_map(target, side, scale), 7.5, 0.0, TAU, 16, Color("95e7bc"), 2.5)
		for officer in state["officers"]:
			draw_circle(_to_map(officer, side, scale), 3.5, Color("f04e59"))
		draw_circle(_to_map(actor, side, scale), 5.5, Color("ee72cc"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Color("8eabc4"), false, 2.0)

func _to_map(point: Vector2, side: float, scale: float) -> Vector2:
	return Vector2(side * 0.5 + point.x * scale, side * 0.5 + point.y * scale)
