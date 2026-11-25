extends Control
## A single modal, paused-world equipment selector. Selection is a preview
## until explicitly accepted; opening and cancellation never spend ammo.
const Arsenal = preload("res://scripts/arsenal.gd")
const Ui = preload("res://scripts/ui_style.gd")
signal confirmed(id: String)
signal cancelled
const LABELS = ["Holster", "Vanta Pulse", "Coilbreak Arc"]
const SLOT_LABELS = ["01", "02", "03"]
const SELECT_TIME = 0.14
const DIRECTIONS = [Vector2(0,-1), Vector2(0.866,0.5), Vector2(-0.866,0.5)]
var selected := 0
var equipped := 0
var ammo: Dictionary = {}
var reserve: Dictionary = {}
var _stick_latched := false
var _pad := false
var _selection_weights := PackedFloat32Array([1.0, 0.0, 0.0])
var _selection_from := PackedFloat32Array([1.0, 0.0, 0.0])
var _selection_elapsed := SELECT_TIME

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	hide()

func present(state: Dictionary, pad: bool = false) -> void:
	equipped = maxi(0, Arsenal.IDS.find(str(state.get("equipped", "holstered"))))
	selected = equipped
	for i in range(Arsenal.IDS.size()):
		_selection_weights[i] = 1.0 if i == selected else 0.0
	_selection_from = _selection_weights.duplicate()
	_selection_elapsed = SELECT_TIME
	ammo = state.get("ammo", {}).duplicate()
	reserve = state.get("reserve", {}).duplicate()
	_pad = pad
	_stick_latched = true # require neutral before a pre-held stick selects
	show()
	queue_redraw()

func dismiss() -> void:
	hide()

func _radius() -> float:
	return minf(minf(size.x, size.y) * 0.33, 370.0)

func index_for_direction(direction: Vector2) -> int:
	if not direction.is_finite() or direction.length_squared() < 0.0001:
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
		_selection_from = _selection_weights.duplicate()
		_selection_elapsed = 0.0
		selected = index
		queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() < 0.30:
		_stick_latched = false
	elif stick.length() > 0.65 and not _stick_latched:
		select_index(index_for_direction(stick))
		if not _pad:
			_pad = true
			queue_redraw()
	if _selection_elapsed < SELECT_TIME:
		_selection_elapsed = minf(SELECT_TIME, _selection_elapsed + delta)
		var t := smoothstep(0.0, 1.0, _selection_elapsed / SELECT_TIME)
		for i in range(Arsenal.IDS.size()):
			_selection_weights[i] = lerpf(_selection_from[i], 1.0 if i == selected else 0.0, t)
		queue_redraw()

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
		if _pad:
			_pad = false
			queue_redraw()
		_pointer(get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and event.is_pressed():
		var mouse := event as InputEventMouseButton
		_pad = false
		queue_redraw()
		if mouse.button_index == MOUSE_BUTTON_LEFT and _pointer(get_global_transform_with_canvas().affine_inverse() * mouse.position):
			confirmed.emit(Arsenal.IDS[selected])
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()
	elif event.is_pressed() and not event.is_echo():
		if event is InputEventJoypadButton:
			_pad = true
		elif event is InputEventKey:
			_pad = false
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

func _text_at(content: String, at: Vector2, font_size: int, tint: Color, max_width: float = INF) -> void:
	var font := ThemeDB.fallback_font
	var fitted := font_size
	while fitted > 9 and font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > max_width:
		fitted -= 1
	var extent := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted)
	draw_string(font, at + Vector2(-extent.x * 0.5, fitted * 0.35), content, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, tint)

func _sector(center: Vector2, radius: float, direction: Vector2, tint: Color, edge: Color, weight: float) -> void:
	var points := PackedVector2Array()
	var angle := direction.angle()
	for i in range(33):
		points.append(center + Vector2.from_angle(angle - PI / 3.0 + 0.025 + (TAU / 3.0 - 0.05) * float(i) / 32.0) * radius)
	for i in range(32, -1, -1):
		points.append(center + Vector2.from_angle(angle - PI / 3.0 + 0.025 + (TAU / 3.0 - 0.05) * float(i) / 32.0) * radius * 0.38)
	draw_colored_polygon(points, tint)
	points.append(points[0])
	draw_polyline(points, edge, 1.5, true)
	if weight > 0.001:
		draw_arc(center, radius + 5.0, angle - PI / 3.0 + 0.055, angle + PI / 3.0 - 0.055, 40, Color(Ui.ACCENT, weight), 3.0, true)

# Original abstract equipment marks, not external icons or real weapon art.
func _slot_icon(index: int, at: Vector2, scale_px: float, tint: Color) -> void:
	var shape := PackedVector2Array()
	match index:
		0:
			draw_circle(at, scale_px * 0.42, tint, false, 2.0, true)
			shape = PackedVector2Array([Vector2(-0.22, -0.22), Vector2(0, 0.04), Vector2(0.22, -0.22)])
		1:
			shape = PackedVector2Array([Vector2(-0.48, 0), Vector2(-0.25, 0), Vector2(-0.10, -0.36), Vector2(0.12, 0.35), Vector2(0.27, 0), Vector2(0.48, 0)])
		2:
			shape = PackedVector2Array([Vector2(-0.35, 0.28), Vector2(0.06, -0.39), Vector2(0.02, -0.02), Vector2(0.36, -0.02), Vector2(-0.08, 0.39), Vector2(-0.03, 0.03), Vector2(-0.35, 0.28)])
	for i in range(shape.size()):
		shape[i] = at + shape[i] * scale_px
	draw_polyline(shape, tint, 2.2, true)

func _draw() -> void:
	if not visible:
		return
	var center := size * 0.5
	var radius := _radius()
	if radius < 40.0:
		return
	var type_size := clampi(roundi(radius * 0.067), 12, 24)
	var small := maxi(10, type_size - 5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.04, 0.06, 0.72))
	_text_at("NIGHTGRID  /  FIELD KIT", center + Vector2(0, -radius * 1.36), small, Ui.AMBER, size.x * 0.90)
	_text_at("Equipment", center + Vector2(0, -radius * 1.20), type_size + 7, Ui.TEXT, size.x * 0.90)
	draw_circle(center, radius + 12.0, Color(0.035, 0.055, 0.075, 0.83), true, -1.0, true)
	draw_arc(center, radius + 12.0, 0, TAU, 120, Color("354956"), 1.0, true)
	for i in range(Arsenal.IDS.size()):
		var id: String = Arsenal.IDS[i]
		var weight := _selection_weights[i]
		var edge := Color("435663").lerp(Ui.ACCENT, weight)
		var tint := Color("16232e").lerp(Color("29494e"), weight)
		var direction: Vector2 = DIRECTIONS[i]
		_sector(center, radius, direction, tint, edge, weight)
		var pos := center + direction * radius * 0.70
		_slot_icon(i, pos - Vector2(0, type_size * 1.45), type_size * 1.5, edge.lightened(0.18))
		_text_at(SLOT_LABELS[i] + "  " + LABELS[i], pos, type_size, Ui.TEXT, radius * 0.69)
		var detail := "Unarmed" if i == 0 else "%02d  /  %02d" % [int(ammo.get(id, 0)), int(reserve.get(id, 0))]
		_text_at(detail, pos + Vector2(0, type_size * 1.05), small, Ui.AMBER if i > 0 and int(ammo.get(id, 0)) == 0 else Ui.MUTED, radius * 0.65)
		if i == equipped:
			_text_at("EQUIPPED", pos + Vector2(0, type_size * 2.0), small, Ui.ACCENT, radius * 0.62)
	draw_circle(center, radius * 0.33, Ui.INK, true, -1.0, true)
	draw_arc(center, radius * 0.33, 0, TAU, 80, Color("52616e"), 1.5, true)
	_text_at("CURRENT" if selected == equipped else "PREVIEW", center - Vector2(0, type_size * 1.05), small, Ui.MUTED, radius * 0.55)
	_text_at(LABELS[selected], center, type_size + 1, Ui.TEXT, radius * 0.59)
	var selected_id: String = Arsenal.IDS[selected]
	var status := "Hands free" if selected == 0 else ("Empty" if int(ammo.get(selected_id, 0)) == 0 else "%d loaded" % int(ammo.get(selected_id, 0)))
	_text_at(status, center + Vector2(0, type_size * 1.1), small, Ui.AMBER if status == "Empty" else Ui.ACCENT, radius * 0.53)
	var select_hint := "RIGHT STICK / D-PAD   Select" if _pad else "MOUSE / ARROWS / 1–3   Select"
	var action_hint := "A   Equip     •     B   Cancel" if _pad else "CLICK / ENTER   Equip     •     ESC / RMB   Cancel"
	_text_at(select_hint, center + Vector2(0, radius * 1.18), small, Ui.MUTED, size.x * 0.90)
	_text_at(action_hint, center + Vector2(0, radius * 1.30), type_size, Ui.TEXT, size.x * 0.90)
