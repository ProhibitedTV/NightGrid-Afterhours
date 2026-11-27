extends SceneTree
const Satire = preload("res://scripts/street_satire.gd")
const Venues = preload("res://scripts/venue_system.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var profile := Satire.stanky_profile()
	if profile["topics"].size()!=2 or Satire.STANKY_ID in Satire.CAST:
		_fail("Named identity and two authored topics")
		return
	var venues := Venues.new()
	root.add_child(venues)
	var at := venues.venue_position("static_room")
	venues.set_focus(at)
	venues.set_hour(22.0)
	var actor := venues.find_child("DaddyStanky",true,false) as Node3D
	if not is_instance_valid(actor):
		_fail("Missing fixed venue actor")
		return
	var listener := actor.global_position+Vector3.UP*1.15+Vector3.FORWARD
	if venues.daddy_stanky_near(listener)!=actor or venues.daddy_stanky_near(listener+Vector3.UP*5.0)!=null or venues.daddy_stanky_near(listener+Vector3.RIGHT*8.0)!=null:
		_fail("Contact proximity")
		return
	venues.set_hour(12.0)
	if venues.daddy_stanky_near(listener)!=null or actor.visible:
		_fail("Daytime visibility")
		return
	venues.set_hour(23.0)
	if venues.daddy_stanky_near(listener)!=actor or venues.find_children("DaddyStanky","Node3D",true,false).size()!=1:
		_fail("Recurring single actor")
		return
	print("STANKY PASS: fixed legend, two topics, proximity and recurring schedule")
	quit(0)

func _fail(message:String) -> void:
	push_error("STANKY "+message)
	quit(1)
