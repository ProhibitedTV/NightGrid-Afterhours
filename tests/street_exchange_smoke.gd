extends SceneTree
const Director=preload("res://scripts/pedestrian_director.gd")
const Dialogue=preload("res://scripts/dialogue_director.gd")
const Pop=preload("res://scripts/sidewalk_population.gd")
const Satire=preload("res://scripts/street_satire.gd")

class CityFixture extends Node3D:
	func get_loaded_blocks()->Array[Vector2i]: return [Vector2i.ZERO]
	func get_streaming_stats()->Dictionary: return {"loads":1,"unloads":0}
	func is_spawn_area_ready(_at:Vector3,_radius:float)->bool: return true
	func reserve_pedestrian_parcel(_id:String,_a:Vector3,_b:Vector3)->bool: return true
	func release_pedestrian_parcel(_id:String)->bool: return true

func _initialize()->void:
	create_timer(20.0,true,false,true).timeout.connect(func()->void: quit(1))
	call_deferred("_verify")

func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("STREET_EXCHANGE: "+message)
		quit(1)
	return ok

func _id_for(character:String)->String:
	for i in range(1000):
		var id:="test-pedestrian-%d"%i
		if Satire.personality(id)==character:
			return id
	return ""

func _reset_cooldowns(pool:Node,ids:Array)->void:
	# Fixture only: skip the intentional 90-second gameplay cooldown.
	var leases:Dictionary=pool.get("_leases")
	for id in ids:
		leases[id]["social"]=0.0
		leases[id]["bark_cooldown"]=0.0
		leases[id]["social_cooldown"]=0.0

func _verify()->void:
	var first:=_id_for("robot_romantic")
	var second:=_id_for("nothing_happens")
	var beats:=Satire.exchange_for(first,second)
	if not _check(not first.is_empty() and not second.is_empty() and beats.size()==3 and Satire.exchange_for(first,first).is_empty(),"compatible identities only"):
		return
	var city:=CityFixture.new()
	root.add_child(city)
	var director:=Director.new()
	root.add_child(director)
	var speech:=Dialogue.new()
	root.add_child(speech)
	var links:Array[Dictionary]=[
		{"id":first,"district":"GLASSLINE","start":Vector3(-2,0,0),"end":Vector3(2,0,0)},
		{"id":second,"district":"GLASSLINE","start":Vector3(-2,0,3),"end":Vector3(2,0,3)}]
	var fixture:=Node3D.new()
	var visual:=PackedScene.new()
	visual.pack(fixture)
	fixture.free()
	if not _check(director.configure(city,42,links,visual,2),"real pool configured"):
		return
	var population:Variant=director.get("_population")
	population.restore({"phases":{first:0.25,second:0.25}})
	var pool=director.get("_pool")
	var allow:=func(_row:Dictionary)->bool: return true
	await physics_frame
	if not _check(pool.activate(population,first,0.0,allow) and pool.activate(population,second,0.0,allow),"two real physical leases"):
		return
	var listener:=Vector3(3,1.6,1.5)
	var captions:Array[String]=[]
	speech.caption_changed.connect(func(id:String,_text:String)->void:
		if not id.is_empty(): captions.append(id))
	director.set("_street_clock",0.0)
	director.update_street_dialogue(speech,listener,RID(),true,0.1)
	var pair:Dictionary=director.get("_exchange")
	if not _check(pair.get("beats",[]).size()==3 and pool.exchange_speaker(pair,"robot_romantic")!=pool.exchange_speaker(pair,"nothing_happens"),"separate real speaker bodies"):
		return
	# Advance only the audio/conversation clock in this fixture; the actors
	# remain at fixed certified test positions while their leases are live.
	for i in range(280):
		speech.tick(0.1,listener)
		director.update_street_dialogue(speech,listener,RID(),true,0.1)
		if (director.get("_exchange") as Dictionary).is_empty():
			break
	if not _check(captions==[beats[0]["id"],beats[1]["id"],beats[2]["id"]] and (director.get("_exchange") as Dictionary).is_empty(),"three alternating caption beats finish in order"):
		return
	if not _check(not pool.exchange_valid(pair) and speech.stats()["pending"]==0,"both social holds released"):
		return
	_reset_cooldowns(pool,[first,second])
	director.set("_street_clock",0.0)
	director.update_street_dialogue(speech,listener,RID(),true,0.1)
	speech.tick(0.1,listener)
	if not _check(speech.stats()["active"]==beats[0]["id"],"new exchange begins"):
		return
	speech.enqueue("fixture.story","Story interrupt",Dialogue.STORY)
	director.update_street_dialogue(speech,listener,RID(),true,0.1)
	if not _check((director.get("_exchange") as Dictionary).is_empty() and speech.stats()["pending"]==1,"story preemption discards exchange but preserves story"):
		return
	speech.cancel_all()
	_reset_cooldowns(pool,[first,second])
	director.set("_street_clock",0.0)
	director.update_street_dialogue(speech,listener,RID(),true,0.1)
	speech.tick(0.1,listener)
	director.update_street_dialogue(speech,listener,RID(),false,0.1)
	if not _check((director.get("_exchange") as Dictionary).is_empty() and speech.stats()["active"]=="","leaving street cancels current turn"):
		return
	# A direct question selects the canonical reply and keeps the live identity.
	var contact_listener:=Vector3(0,1.6,-2)
	director.update_street_dialogue(speech,contact_listener,RID(),true,0.2)
	var contact:=director.nearby_contact()
	if not _check(contact.get("lease_id")==first and contact.get("topics",[]).size()==2,"nearby contact and two choices"):
		return
	if not _check(director.request_player_reply(first,1) and not director.request_player_reply(first,9),"bounded topic selection"):
		return
	director.update_street_dialogue(speech,contact_listener,RID(),true,0.1)
	speech.tick(0.1,contact_listener)
	if not _check(speech.stats()["active"]=="street.robot_romantic.talk.2","player choice triggers the exact spatial reply"):
		return
	director.update_street_dialogue(speech,contact_listener,RID(),false,0.1)
	if not _check(speech.stats()["active"]=="" and director.nearby_contact().is_empty(),"leaving cancels direct reply and cached interaction"):
		return
	# Cancel an enqueued but not yet started reply. No line_ended event is
	# emitted for discarded pending entries; the controller must still release.
	director.update_street_dialogue(speech,contact_listener,RID(),true,0.2)
	if not _check(director.request_player_reply(first,0),"contact available after return"):
		return
	director.update_street_dialogue(speech,contact_listener,RID(),true,0.1)
	if not _check(speech.has_scope("street:player"),"reply queued"):
		return
	speech.cancel_all()
	director.update_street_dialogue(speech,contact_listener,RID(),true,0.1)
	if not _check(str(director.get("_player_lease")).is_empty() and not speech.has_scope("street:player"),"discarded reply cannot hold actor"):
		return
	director.cancel_street_dialogue(speech)
	if not _check(director.nearby_contact().is_empty(),"transition invalidates cached contact"):
		return
	director.shutdown()
	print("STREET_EXCHANGE PASS: compatible leases, alternating turns, story interruption and context cancellation")
	quit(0)
