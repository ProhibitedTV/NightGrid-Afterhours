extends Control
## Overview of streets, objective, player and chasing police.

const Nav = preload("res://scripts/navigation_waypoint.gd")
var world_node: Node3D
var interactive := false
var cursor := Vector2.ZERO
signal destination_changed
var _redraw_clock := 1.0
const CITY_SPAN = 560.0
const GRID_RADIUS = 4

func _ready() -> void:
	if interactive:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		if is_instance_valid(world_node):
			var state: Dictionary = world_node.call("get_map_state")
			cursor = state["waypoint"] if bool(state["waypoint_active"]) else Nav.clamp_point(state["player"])
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if not interactive or not is_instance_valid(world_node):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var side := minf(size.x, size.y)
			if side > 0.0 and Rect2(Vector2.ZERO, Vector2(side, side)).has_point(event.position):
				grab_focus()
				var point: Vector2 = ((event as InputEventMouseButton).position - Vector2.ONE * side * 0.5) * CITY_SPAN / side
				cursor = Nav.clamp_point(point)
				_place()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_destination()
			accept_event()
		return
	var step := Vector2.ZERO
	if event.is_action_pressed("ui_up", true):
		step = Vector2.UP
	elif event.is_action_pressed("ui_down", true):
		step = Vector2.DOWN
	elif event.is_action_pressed("ui_left", true):
		step = Vector2.LEFT
	elif event.is_action_pressed("ui_right", true):
		step = Vector2.RIGHT
	if step != Vector2.ZERO:
		cursor = Nav.clamp_point(cursor + 8.0 * step)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_place()
		accept_event()
	elif event.is_action_pressed("service_two") and not event.is_echo():
		clear_destination()
		accept_event()

func _place() -> void:
	var result: Vector2 = world_node.call("set_navigation_waypoint", cursor)
	cursor = result
	queue_redraw()
	destination_changed.emit()

func clear_destination() -> void:
	if is_instance_valid(world_node):
		world_node.call("clear_navigation_waypoint")
		queue_redraw()
		destination_changed.emit()

func _process(delta: float) -> void:
	_redraw_clock += delta
	if _redraw_clock >= 0.1:
		_redraw_clock = 0.0
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
		# Fixed M-Line corridor over the city; station squares and bus-stop
		# dots complement venue/social pins in the large pause-menu atlas.
		var rail_tint := Color("7fcfd5")
		draw_line(_to_map(Vector2(-223.0, -58.0), side, scale),
			_to_map(Vector2(241.0, -58.0), side, scale), rail_tint.darkened(0.52), 2.2)
		for stop in state.get("bus_stops", []):
			draw_circle(_to_map(stop, side, scale), 2.7, Color("f3cb7a"))
		for station in state.get("rail_stations", []):
			var pos := _to_map(station, side, scale)
			draw_rect(Rect2(pos - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), rail_tint, true)
			draw_rect(Rect2(pos - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), Color("1b4050"), false, 1.1)
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
		if bool(state.get("waypoint_active", false)):
			var destination: Vector2 = state["waypoint"]
			var target_pin := _to_map(destination, side, scale)
			var route: Dictionary = state.get("street_route", {})
			if not route.is_empty():
				var road: Array[Vector2] = route["points"]
				var plotted := PackedVector2Array()
				for point in road:
					plotted.append(_to_map(point, side, scale))
				if plotted.size() > 1:
					draw_polyline(plotted, Color("101821"), 5.0, true)
					draw_polyline(plotted, Nav.COLOR, 2.8, true)
				# Dotted access segments explicitly are not road routes.
				var entry: Vector2 = route["entry"]
				var exit: Vector2 = route["exit"]
				if actor.distance_to(entry) >= 0.1:
					draw_dashed_line(_to_map(actor, side, scale), _to_map(entry, side, scale), Nav.COLOR, 1.4, 4.0, true, true)
				if destination.distance_to(exit) >= 0.1:
					draw_dashed_line(_to_map(exit, side, scale), target_pin, Nav.COLOR, 1.4, 4.0, true, true)
			else:
				draw_dashed_line(_to_map(actor, side, scale), target_pin, Nav.COLOR, 1.4, 4.0, true, true)
			var diamond := PackedVector2Array([target_pin + Vector2(0, -8), target_pin + Vector2(8, 0),
				target_pin + Vector2(0, 8), target_pin + Vector2(-8, 0), target_pin + Vector2(0, -8)])
			draw_polyline(diamond, Nav.COLOR, 2.5, true)
		var actor_pin := _to_map(actor, side, scale)
		draw_circle(actor_pin, 7.0, Color("101821"))
		draw_circle(actor_pin, 5.5, Color("e7edf0"))
		draw_arc(actor_pin, 8.5, 0.0, TAU, 24, Color("81e0d4"), 1.8, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Color("54707c"), false, 2.0)
	if interactive and has_focus():
		var reticle := _to_map(cursor, side, scale)
		draw_arc(reticle, 11.0, 0.0, TAU, 24, Color("e7edf0"), 1.5, true)
		draw_line(reticle + Vector2(-15, 0), reticle + Vector2(-5, 0), Color.WHITE, 1.5)
		draw_line(reticle + Vector2(5, 0), reticle + Vector2(15, 0), Color.WHITE, 1.5)
		draw_line(reticle + Vector2(0, -15), reticle + Vector2(0, -5), Color.WHITE, 1.5)
		draw_line(reticle + Vector2(0, 5), reticle + Vector2(0, 15), Color.WHITE, 1.5)
		draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Nav.COLOR, false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(9, 19), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e7edf0"))

func _to_map(point: Vector2, side: float, scale: float) -> Vector2:
	return Vector2(side * 0.5 + point.x * scale, side * 0.5 + point.y * scale)
