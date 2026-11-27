extends SceneTree
const Satire = preload("res://scripts/street_satire.gd")
const Venues = preload("res://scripts/venue_system.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var profile := Satire.stanky_profile()
	if profile["topics"].size()!=8 or Satire.STANKY_ID in Satire.CAST:
		_fail("Named identity and eight authored topics")
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
	var flyer:=venues.find_child("HumanityFlyer",true,false) as MeshInstance3D
	if flyer==null or flyer.get_node_or_null("PrintedArtwork")==null:
		_fail("Missing physical mixtape flyer")
		return
	var patrons:Dictionary=venues.get("_patrons")
	var fans:Array=patrons["static_room"]
	for i in range(fans.size()):
		var fan:Node3D=fans[i]
		var gossip:=venues.stanky_fan_near(fan.global_position+Vector3.UP*1.15+Vector3.FORWARD*.4)
		if gossip.get("stanky_rumor",-1)!=i:
			_fail("Missing distinct fan lore")
			return
	var show:=Satire.stanky_show()
	if show.size()!=7 or not venues.stanky_show_reachable(listener) or venues.stanky_show_reachable(listener+Vector3.RIGHT*20.0):
		_fail("Show script or audience radius")
		return
	for i in range(show.size()):
		if int(show[i]["stanky_show"])!=i or venues.stanky_show_speaker(show[i]["character"],i)==null:
			_fail("Show sequence or speaker")
			return
	for set_id in ["fight","family"]:
		var alternate:=Satire.stanky_show(set_id)
		if alternate.size()!=(7 if set_id=="fight" else 8):
			_fail("Missing alternate show "+set_id)
			return
		for i in range(alternate.size()):
			if int(alternate[i]["stanky_show"])!=i or venues.stanky_show_speaker(alternate[i]["character"],i)==null:
				_fail("Alternate show ordering or speaker")
				return
	var trio:=Satire.stanky_show("trio")
	var rc:=venues.stanky_show_speaker("rc",0)
	var boon:=venues.stanky_show_speaker("boon",0)
	if trio.size()!=9 or rc==null or boon==null or rc==boon or rc.name!="RC" or boon.name!="Boon":
		_fail("Named old friends and trio dialogue")
		return
	for i in range(trio.size()):
		if int(trio[i]["stanky_show"])!=i or venues.stanky_show_speaker(trio[i]["character"],i)==null:
			_fail("Trio set ordering or speaker")
			return
	if not Satire.stanky_show("invalid").is_empty():
		_fail("Unknown show")
		return
	venues.set_stanky_show_active(true)
	venues.set_hour(12.0)
	if bool(venues.get("_stanky_show_active")):
		_fail("Closed venue must stop show")
		return
	if venues.daddy_stanky_near(listener)!=null or actor.visible:
		_fail("Daytime visibility")
		return
	venues.set_hour(23.0)
	if venues.daddy_stanky_near(listener)!=actor or venues.find_children("DaddyStanky","Node3D",true,false).size()!=1:
		_fail("Recurring single actor")
		return
	print("STANKY PASS: fixed legend, eight topics, proximity and recurring schedule")
	quit(0)

func _fail(message:String) -> void:
	push_error("STANKY "+message)
	quit(1)
