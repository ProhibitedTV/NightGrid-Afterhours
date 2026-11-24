extends Node3D
## Original center-stack digital instrumentation. All parts follow coachwork.
## No subviewport, dynamic lights or changes to engine/drive simulation.
const INTERVAL = .1
static var _panel_mesh: BoxMesh
static var _bar_mesh: QuadMesh

var _speed: Label3D
var _gear: Label3D
var _units: Label3D
var _brake: Label3D
var _bar: MeshInstance3D
var _bar_material: StandardMaterial3D
var _elapsed := 0.0
var _active := false
var _night := false
var _braking := false
var _fraction := 0.0

func _ready() -> void:
	if _panel_mesh == null:
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("13181f")
		dark.roughness = .5
		_panel_mesh = BoxMesh.new()
		_panel_mesh.size = Vector3(.255, .122, .014)
		_panel_mesh.material = dark
		_bar_mesh = QuadMesh.new()
		_bar_mesh.size = Vector2(.20, .008)
	var panel := MeshInstance3D.new()
	panel.mesh = _panel_mesh
	add_child(panel)
	_speed = _label("Speed", Vector3(-.035, .012, .008), 64, .00060)
	_gear = _label("Gear", Vector3(.090, .012, .008), 44, .00055)
	_units = _label("Units", Vector3(-.035, -.025, .008), 24, .00045)
	_units.text = "KM/H"
	_brake = _label("Brake", Vector3(.085, -.025, .008), 21, .00042)
	_brake.text = "BRAKE"
	_bar = MeshInstance3D.new()
	_bar.mesh = _bar_mesh
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_material = StandardMaterial3D.new()
	_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar.material_override = _bar_material
	add_child(_bar)
	reset_display()

func _label(label_name: String, point: Vector3, size: int, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.position = point
	label.font_size = size
	label.pixel_size = pixels
	label.outline_size = 0
	label.no_depth_test = false
	add_child(label)
	return label

func update_display(occupied: bool, night: bool, speed: float, rpm: float,
		gear: int, braking: bool, delta: float) -> void:
	if not occupied:
		if _active:
			reset_display()
		return
	_elapsed += maxf(delta, 0.0)
	if _active and _night == night and _braking == braking and _elapsed < INTERVAL:
		return
	_elapsed = 0.0
	_active = true
	_night = night
	_braking = braking
	_speed.text = "%03d" % clampi(roundi(absf(speed) * 3.6), 0, 999)
	_gear.text = "R" if speed < -.2 else str(clampi(gear, 1, 6))
	_fraction = clampf(rpm / 7250.0, 0.0, 1.0)
	var tint := Color("66a8ad") if night else Color("a7e6ea")
	for label in [_speed, _gear, _units]:
		label.modulate = tint
		label.show()
	_brake.modulate = Color("b94a38") if night else Color("ff6950")
	_brake.visible = braking
	_bar.scale.x = maxf(.001, _fraction)
	_bar.position = Vector3(-.10 + .10 * _fraction, .045, .008)
	var bar_color := Color("e5704a") if _fraction >= .83 else tint
	_bar_material.albedo_color = bar_color
	_bar.show()

func reset_display() -> void:
	_active = false
	_elapsed = 0.0
	_fraction = 0.0
	_night = false
	_braking = false
	_speed.text = ""
	_gear.text = ""
	for label in [_speed, _gear, _units, _brake]:
		label.hide()
	_bar.hide()

func get_display_state() -> Dictionary:
	return {"active": _active, "night": _night, "braking": _braking,
		"speed": _speed.text, "gear": _gear.text, "rpm_fraction": _fraction}
