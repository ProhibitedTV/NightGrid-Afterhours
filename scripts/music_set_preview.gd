extends RefCounted
## Isolated equipment display for the paused rhythm UI. One render only;
## no scoring, input, physics, audio or world camera dependencies.
const PocketBeat=preload("res://assets/instruments/pocketbeat_m3.glb")
const Art=preload("res://scripts/instrument_art.gd")

static func build(trio: bool) -> SubViewportContainer:
	var frame := SubViewportContainer.new()
	frame.name="MusicSetPreview"
	frame.custom_minimum_size=Vector2(360,112)
	frame.stretch=true
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.name="EquipmentViewport"
	view.size=Vector2i(640,112)
	view.own_world_3d=true
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	frame.add_child(view)
	var sampler := PocketBeat.instantiate() as Node3D
	sampler.name="Sampler"
	sampler.position=Vector3(0,0.08,0)
	sampler.scale=Vector3.ONE*2.5 if trio else Vector3.ONE
	view.add_child(sampler)
	if trio:
		var bass := Art.build("punk_bass")
		bass.position=Vector3(-0.82,0,0)
		bass.rotation_degrees=Vector3(0,0,-15)
		view.add_child(bass)
		var synth := Art.build("portable_synth")
		synth.position=Vector3(0.82,0.05,0)
		view.add_child(synth)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.6 if trio else .22
	camera.position=Vector3(0,1.6,3.2)
	view.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3(0,.35 if trio else .035,0),Vector3.UP)
	camera.current=true
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-48,-32,0)
	key.light_energy=1.4
	view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-32,145,0)
	fill.light_color=Color("a0d6ee")
	fill.light_energy=.85
	view.add_child(fill)
	return frame
