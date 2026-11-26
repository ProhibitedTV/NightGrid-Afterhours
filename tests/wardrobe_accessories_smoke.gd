extends SceneTree
const Catalog=preload("res://scripts/wardrobe_catalog.gd")
const Access=preload("res://scripts/wardrobe_accessories.gd")
const Visual=preload("res://scripts/courier_visual.gd")
const Ledger=preload("res://scripts/progression_ledger.gd")

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
		if slot not in ["glasses","watch","hat"]:
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
	if not check(count==28 and Access.build(rig,"not_an_accessory")==null,"accessory coverage and invalid ID"):
		return
	var mixed:Dictionary={"hat":"hat_thread_cap","glasses":"glasses_metro","watch":"watch_commute"}
	if not check(actor.set_look(Catalog.DEFAULT,mixed),"independent hat glasses and watch"):
		return
	var attached:Dictionary=actor.get("_accessories")
	for id in mixed.values():
		if not check(attached[id].visible,"mixed accessory visible "+id):
			return
	mixed.erase("hat")
	if not check(actor.set_look(Catalog.DEFAULT,mixed) and not attached["hat_thread_cap"].visible and attached["glasses_metro"].visible and attached["watch_commute"].visible,"remove only headwear"):
		return
	var p:=Ledger.new()
	p.set_balance(100)
	if not check(p.buy_piece("hat_thread_cap","USD",true) and p.select_piece("hat_thread_cap",true) and p.save_look("look_1",true),"purchase headwear and save preset"):
		return
	var saved:=p.snapshot()
	var restored:=Ledger.new()
	if not check(restored.restore(p.balance,saved) and restored.owns_piece("hat_thread_cap") and restored.clothing_slots.get("hat")=="hat_thread_cap","headwear ownership round trip"):
		return
	if not check(restored.clear_piece("hat",true) and restored.owns_piece("hat_thread_cap") and restored.equip_look("look_1",true) and restored.clothing_slots.get("hat")=="hat_thread_cap","remove and equip owned preset"):
		return
	var invalid:=saved.duplicate(true)
	invalid["clothing_slots"]["hat"]="glasses_metro"
	if not check(not restored.restore(999,invalid) and restored.balance==p.balance and restored.clothing_slots.get("hat")=="hat_thread_cap","reject invalid hat slot atomically"):
		return
	var stores=preload("res://scripts/clothing_store.gd")
	var collector:=Ledger.new()
	collector.set_balance(10000)
	var initial:Dictionary=stores.remaining_stock(0,collector)
	if not check(initial.size()==stores.IDS.size(),"all retailers represented"):
		return
	for store_id in stores.IDS:
		if not check(initial[store_id]==stores.stock_for_day(store_id,0).size()-1,"owned starter outfit excluded"):
			return
	if not check(collector.buy_outfit("signal_rivet","USD",true) and collector.buy_piece("hat_thread_cap","USD",true),"collection fixture purchases"):
		return
	var after:Dictionary=stores.remaining_stock(0,collector)
	if not check(after[stores.THRIFT]==initial[stores.THRIFT]-1 and after[stores.ID]==initial[stores.ID]-1,"purchases reduce matching shop stock"):
		return
	var tomorrow:Dictionary=stores.remaining_stock(1,collector)
	if not check(tomorrow[stores.THRIFT]==stores.stock_for_day(stores.THRIFT,1).size()-1,"thrift day changes available unowned stock"):
		return
	collector.set_balance(0)
	if not check(stores.remaining_stock(0,collector)==after,"collection count independent of affordability"):
		return
	print("WARDROBE_ACCESSORIES PASS: ",count," fitted accessory IDs; native visual fit pending")
	quit(0)
