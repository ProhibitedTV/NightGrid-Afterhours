extends SceneTree
const Catalog=preload("res://scripts/wardrobe_catalog.gd")
const Access=preload("res://scripts/wardrobe_accessories.gd")
const Visual=preload("res://scripts/courier_visual.gd")

func _initialize() -> void:
	call_deferred("_verify")

func check(ok:bool,message:String)->bool:
	if not ok:
		push_error("WARDROBE_ACCESSORIES: "+message)
		quit(1)
	return ok

func _verify()->void:
	var actor:=Visual.new()
	root.add_child(actor)
	await process_frame
	var rig:Skeleton3D=actor.skeleton
	var count:=0
	for id in Catalog.PIECE_IDS:
		var slot:String=Catalog.PIECES[id]["slot"]
		if slot not in ["glasses","watch"]:
			continue
		var slots:Dictionary={}
		slots[slot]=id
		if not check(actor.set_look(Catalog.DEFAULT,slots),"preview "+id):
			return
		var attachments:Dictionary=actor.get("_accessories")
		var attachment:BoneAttachment3D=attachments.get(id)
		if not check(is_instance_valid(attachment) and attachment.visible and attachment.get_parent()==rig and attachment.find_children("*","MeshInstance3D",true,false).size()>0,"live bone geometry "+id):
			return
		if not check(actor.set_look(Catalog.DEFAULT,{}) and not attachment.visible,"remove "+id):
			return
		if not check(actor.set_look(Catalog.DEFAULT,slots) and attachments[id]==attachment and actor.set_look(Catalog.DEFAULT,{}),"reuse "+id):
			return
		count+=1
	if not check(count==16 and Access.build(rig,"not_an_accessory")==null,"accessory coverage and invalid ID"):
		return
	print("WARDROBE_ACCESSORIES PASS: ",count," fitted accessory IDs; native visual fit pending")
	quit(0)
