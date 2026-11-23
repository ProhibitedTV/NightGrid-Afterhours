extends SceneTree
const Clock=preload("res://scripts/day_night.gd")
class Sink extends Node:
	var calls:=0
	var factor:float=-1.0
	func set_night_factor(value:float)->void:
		calls+=1
		factor=value
func _initialize()->void:
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("CLOCK_ATMOSPHERE: "+message)
		quit(1)
	return ok
func _verify()->void:
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	root.add_child(env)
	var sun:=DirectionalLight3D.new()
	root.add_child(sun)
	var sink:=Sink.new()
	root.add_child(sink)
	var clock:=Clock.new()
	root.add_child(clock)
	clock.set_process(false)
	clock.configure(env,sun,sink,null)
	clock.paused=true
	clock.set_hour(12.0)
	var before:int=clock.get("_atmosphere_updates")
	var sky_before:int=clock.get("_sky_updates")
	var calls:=sink.calls
	var angle:=sun.rotation
	for i in range(20):
		clock.call("_process",0.2)
	if not _check(clock.get("_atmosphere_updates")==before and clock.get("_sky_updates")==sky_before and sink.calls==calls+20 and sun.rotation==angle,"paused clock preserves appearance while synchronizing streamed materials"):
		return
	clock.set_hour(13.0)
	if not _check(clock.get("_atmosphere_updates")==before+1 and clock.get("_sky_updates")==sky_before and sun.rotation!=angle,"day plateau rotates sun but does not rewrite sky"):
		return
	clock.cycle_render_profile()
	if not _check(clock.get("_atmosphere_updates")==before+2 and clock.get("_sky_updates")==sky_before and env.environment.tonemap_mode==Environment.TONE_MAPPER_ACES,"profile switch immediately updates tonemap without rewriting sky"):
		return
	clock.set_hour(0.0)
	if not _check(clock.get("_sky_updates")==sky_before+1 and sink.factor==1.0,"night transition updates sky and subscribers"):
		return
	clock.paused=false
	var night_updates:int=clock.get("_sky_updates")
	for i in range(20):
		clock.call("_process",0.2)
	if not _check(clock.hour>0.0 and clock.get("_sky_updates")==night_updates,"running night avoids redundant sky mutation"):
		return
	clock.configure(env,sun,sink,null)
	if not _check(clock.get("_sky_updates")==night_updates+1 and env.environment.sky.sky_material!=null,"reconfigure refreshes replacement sky"):
		return
	print("CLOCK_ATMOSPHERE_SMOKE PASS: paused, day/night plateaus, profile, subscriber cadence, reconfigure")
	quit(0)
