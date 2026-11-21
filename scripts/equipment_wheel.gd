extends Control
## A single modal, paused-world equipment selector. Selection is a preview
## until explicitly accepted; opening and cancellation never spend ammo.
const Arsenal = preload("res://scripts/arsenal.gd")
const Ui = preload("res://scripts/ui_style.gd")
signal confirmed(id: String)
signal cancelled
const LABELS = ["HOLSTER", "VANTA PULSE", "COILBREAK ARC"]
const DIRECTIONS = [Vector2(0,-1), Vector2(0.866,0.5), Vector2(-0.866,0.5)]
var selected := 0
var equipped := 0
var ammo: Dictionary = {}
var reserve: Dictionary = {}
var _stick_latched := false
var _pad := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func present(state: Dictionary, pad: bool = false) -> void:
	equipped = maxi(0, Arsenal.IDS.find(str(state.get("equipped", "holstered"))))
	selected = equipped
	ammo = state.get("ammo", {}).duplicate()
	reserve = state.get("reserve", {}).duplicate()
	_pad = pad
	_stick_latched = true # require neutral before a pre-held stick selects
	show()
	queue_redraw()

func dismiss() -> void:
	hide()

func _radius() -> float:
	return minf(size.x, size.y) * 0.33

func index_for_direction(direction: Vector2) -> int:
	if direction.length_squared() < 0.0001:
		return -1
	var d := direction.normalized()
	var best := -1
	var score := -INF
	for i in range(DIRECTIONS.size()):
		var dot: float = d.dot(DIRECTIONS[i])
		if dot > score:
			score = dot
			best = i
	return best

func select_index(index: int) -> void:
	if index >= 0 and index < Arsenal.IDS.size() and selected != index:
		selected = index
		queue_redraw()

func _process(_delta: float) -> void:
	if not visible:
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() < 0.30:
		_stick_latched = false
	elif stick.length() > 0.65 and not _stick_latched:
		select_index(index_for_direction(stick))
		_pad = true

func _pointer(point: Vector2) -> bool:
	var d := point - size * 0.5
	if d.length() < _radius() * 0.40 or d.length() > _radius() * 1.15:
		return false
	select_index(index_for_direction(d))
	return true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_pad = false
		_pointer((event as InputEventMouseMotion).position)
		queue_redraw()
	elif event is InputEventMouseButton and event.is_pressed():
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and _pointer(mouse.position):
			confirmed.emit(Arsenal.IDS[selected])
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()
	elif event.is_pressed() and not event.is_echo():
		if event is InputEventJoypadButton:
			_pad = true
		if event.is_action_pressed("game_back") or event.is_action_pressed("game_pause") or event.is_action_pressed("weapon_wheel"):
			cancelled.emit()
		elif event.is_action_pressed("ui_accept"):
			confirmed.emit(Arsenal.IDS[selected])
		elif event.is_action_pressed("service_one"):
			select_index(0)
		elif event.is_action_pressed("service_two") and event is InputEventKey:
			select_index(1)
		elif event.is_action_pressed("service_three") and event is InputEventKey:
			select_index(2)
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_down"):
			select_index(posmod(selected - 1, Arsenal.IDS.size()))
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up"):
			select_index(posmod(selected + 1, Arsenal.IDS.size()))
		queue_redraw()
	# Consume all events, even the click/trigger or B used to close the modal.
	get_viewport().set_input_as_handled()

func _text_at(content: String, at: Vector2, font_size: int, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at + Vector2(-extent.x * 0.5, font_size * 0.35), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _sector(center: Vector2, radius: float, direction: Vector2, tint: Color, edge: Color) -> void:
	var points := PackedVector2Array()
	var angle := direction.angle()
	for i in range(33):
		points.append(center + Vector2.from_angle(angle - PI / 3.0 + 0.025 + (TAU / 3.0 - 0.05) * float(i) / 32.0) * radius)
	for i in range(32, -1, -1):
		points.append(center + Vector2.from_angle(angle - PI / 3.0 + 0.025 + (TAU / 3.0 - 0.05) * float(i) / 32.0) * radius * 0.38)
	draw_colored_polygon(points, tint)
	points.append(points[0])
	draw_polyline(points, edge, 2.2, true)

func _draw() -> void:
	if not visible:
		return
	var center := size * 0.5
	var radius := _radius()
	if radius < 40.0:
		return
	var type_size := maxi(12, roundi(radius * 0.067))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.04, 0.06, 0.89))
	_text_at("E Q U I P M E N T", center + Vector2(0, -radius * 1.24), type_size + 5, Ui.TEXT)
	for i in range(Arsenal.IDS.size()):
		var id: String = Arsenal.IDS[i]
		var active := i == selected
		var edge := Ui.ACCENT if active else Color("435663")
		var tint := Color("29494e") if active else Color("16232e")
		var direction: Vector2 = DIRECTIONS[i]
		_sector(center, radius, direction, tint, edge)
		var pos := center + direction * radius * 0.70
		_text_at(LABELS[i], pos - Vector2(0, type_size * 0.68), type_size, Ui.TEXT)
		var detail := "NO WEAPON" if i == 0 else "%02d  /  %02d" % [int(ammo.get(id, 0)), int(reserve.get(id, 0))]
		_text_at(detail, pos + Vector2(0, type_size * 0.65), type_size, Ui.AMBER if i > 0 and int(ammo.get(id, 0)) == 0 else edge.lightened(0.12))
		if i == equipped:
			_text_at("EQUIPPED", pos + Vector2(0, type_size * 1.8), maxi(10, type_size - 6), Ui.MUTED)
	draw_circle(center, radius * 0.32, Color("101821"))
	draw_arc(center, radius * 0.33, 0, TAU, 80, Ui.ACCENT, 2.0, true)
	_text_at("SELECTED", center - Vector2(0, type_size * 0.75), maxi(10, type_size - 6), Ui.MUTED)
	_text_at(LABELS[selected], center + Vector2(0, type_size * 0.50), maxi(12, type_size - 3), Ui.TEXT)
	var hint := "RIGHT STICK / D-PAD  Select     •     A  Equip     •     B  Cancel" if _pad else "MOUSE / ARROWS / 1–3  Select     •     CLICK / ENTER  Equip     •     ESC / RMB  Cancel"
	_text_at(hint, center + Vector2(0, radius * 1.23), maxi(12, type_size - 3), Ui.MUTED)
