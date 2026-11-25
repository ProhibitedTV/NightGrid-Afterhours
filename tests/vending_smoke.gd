extends SceneTree
const Catalog = preload("res://scripts/consumables.gd")
const Ledger = preload("res://scripts/progression_ledger.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("VENDING_SMOKE: "+label)
		quit(1)
	return ok
func _verify() -> void:
	var ledger := Ledger.new()
	if not check(ledger.balance == 0 and ledger.credit(100), "fresh progression wallet"):
		return
	if not check(not ledger.spend(101) and not ledger.spend(-1) and ledger.balance == 100, "invalid purchase has no effects"):
		return
	if not check(ledger.credit_once("story:night_shift", 50) and not ledger.credit_once("story:night_shift", 50) and ledger.balance == 150, "reward paid once"):
		return
	if not check(not ledger.credit_once("story:unpaid", 0) and not ledger.has_receipt("story:unpaid") and not ledger.credit_once("../ invalid", 1), "invalid reward is atomic"):
		return
	var encoded: Variant = JSON.parse_string(JSON.stringify(ledger.snapshot()))
	var restored := Ledger.new()
	if not check(restored.restore(150.0, encoded) and not restored.credit_once("story:night_shift", 50) and restored.balance == 150, "JSON round trip retains receipts"):
		return
	if not check(not restored.restore(1, {"version":1,"receipts":["a","a"]}) and not restored.restore(1, {"version":99,"receipts":[]}) and not restored.restore(1.5, encoded) and restored.balance == 150 and restored.has_receipt("story:night_shift"), "malformed state rejected without mutation"):
		return
	restored.set_balance(Ledger.MAX_CASH)
	if not check(not restored.credit_once("story:overflow", 1) and not restored.has_receipt("story:overflow"), "overflow has no receipt"):
		return
	var title_wallet := Ledger.new()
	title_wallet.set_balance(600)
	if not check(not title_wallet.buy_vehicle("unknown") and not title_wallet.buy_vehicle("street:cinder_01") and title_wallet.balance == 600, "unknown and unaffordable title rollback"):
		return
	if not check(title_wallet.buy_vehicle("street:kestrel_01") and not title_wallet.buy_vehicle("street:kestrel_01") and title_wallet.balance == 100, "registered title exactly once"):
		return
	var title_copy := Ledger.new()
	if not check(title_copy.restore(100, JSON.parse_string(JSON.stringify(title_wallet.snapshot()))) and title_copy.owns_vehicle("street:kestrel_01"), "stable title ID round trip"):
		return
	if not check(not title_copy.restore(0, {"version":1,"receipts":[],"owned_vehicles":["street:kestrel_01","street:kestrel_01"]}) and title_copy.balance == 100 and title_copy.owns_vehicle("street:kestrel_01"), "duplicate title save rejected atomically"):
		return
	var resale := Ledger.new()
	resale.set_balance(3000)
	if not check(resale.buy_vehicle("street:cinder_01") and resale.buy_vehicle("street:kestrel_01"),"paid title setup"):
		return
	if not check(not resale.sell_vehicle("street:kestrel_01",100.0) and not resale.sell_vehicle("street:cinder_01",NAN),"starter cannot be sold; invalid condition rejected"):
		return
	resale.set_balance(Ledger.MAX_CASH)
	if not check(not resale.sell_vehicle("street:cinder_01",100.0) and resale.owns_vehicle("street:cinder_01"),"overflow leaves title intact"):
		return
	resale.set_balance(0)
	if not check(resale.sell_vehicle("street:cinder_01",50.0) and resale.balance==750 and not resale.sell_vehicle("street:cinder_01",50.0),"condition payout exactly once"):
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	player.call("restore_stamina",100.0)
	for i in 60:
		player.call("tick_stamina",1.0/60.0,true,true,false)
	if not check(is_equal_approx(float(player.get("stamina")),86.0),"sprint drains at fixed rate"):
		return
	player.call("restore_stamina",10.0)
	var denied: Vector2i = player.call("tick_stamina",.01,false,false,true)
	if not check(denied.y==0,"jump requires stamina"):
		return
	player.call("restore_stamina",.1)
	player.call("tick_stamina",.1,true,true,false)
	var exhausted: Vector2i = player.call("tick_stamina",.1,true,true,false)
	if not check(exhausted.x==0,"exhaustion stops sprint"):
		return
	for i in 180:
		player.call("tick_stamina",1.0/60.0,false,false,false)
	if not check(float(player.get("stamina"))>20.0,"stamina regenerates while resting"):
		return
	var city: Node = world.get("city_details")
	var machine: Node3D
	for chunk in (city.get("_loaded") as Dictionary).values():
		machine = chunk.get_node_or_null("VendingProps/VendingMachine")
		if machine != null:
			break
	if not check(machine!=null,"real streamed vending machine exists"):
		return
	if not check(machine.get_child_count()==6 and machine.get_node("AnimatedMarquee").material_override is ShaderMaterial,"one collider, three material batches and animated original signage"):
		return
	if not check(machine.get_node("BrandSidePanels").multimesh.instance_count==2 and machine.get_node("BrandSidePanels").material_override.albedo_texture != null,"both original side advertisements are instanced"):
		return
	if not check(Catalog.PRODUCT_ICONS.size()==Catalog.ITEMS.size(),"all gameplay products have original packaging textures"):
		return
	if not check(not machine.is_processing() or not machine.has_method("_process"),"no per-machine animation callback"):
		return
	if not check(machine.get_meta("items")==Catalog.assortment(int(machine.get("variant"))),"display stock and gameplay share deterministic variant"):
		return
	player.global_position = machine.to_global(Vector3(0,1.15,-1.5))
	world.set("cash",100)
	world.set("health",50.0)
	player.call("restore_stamina",30.0)
	world.call("_toggle_interaction")
	if not check(world.get("venue_panel").visible and world.get("_vending_machine")==machine,"open machine from actual front"):
		return
	if not check(world.get("venue_service_button").icon==Catalog.PRODUCT_ICONS["water"],"real shop uses original product packaging"):
		return
	# Physics is disabled in this fixture. Establish grounded locomotion.
	var visual: Node3D = player.get_node("Visual")
	visual.call("update_motion",Vector3.ZERO,true,false,false,false)
	world.call("_venue_action",1)
	var anim: AnimationPlayer = visual.get("animations")
	if not check(anim.has_animation(&"drink_item") and anim.has_animation(&"eat_item") and anim.has_animation(&"purchase_item"),"actual skinned rig has all product action clips"):
		return
	if not check(int(world.get("cash"))==97 and int(world.get("consumable_inventory").get("water",0))==1,"atomic water purchase"):
		return
	world.call("_close_venue")
	world.call("_consume_ration")
	if not check(visual.get("current_pose")==&"drink_item" and is_instance_valid(visual.get("_held_product")),"consumption animates weighted character and attaches branded model"):
		return
	visual.call("_finish_action",&"drink_item")
	if not check(visual.get("_held_product")==null,"action completion cleans up prop"):
		return
	if not check(float(player.get("stamina"))==55.0 and Catalog.count(world.get("consumable_inventory"))==0,"water restores stamina and consumes inventory"):
		return
	world.call("_toggle_interaction")
	world.call("_venue_action",1)
	world.call("_close_venue")
	var live_ledger = world.get("progression")
	if not check(live_ledger.credit_once("story:roundtrip", 20), "world uses live ledger"):
		return
	var saved: Dictionary = world.call("_capture_snapshot")
	world.set("cash", 0)
	live_ledger.restore(0, {"version":1,"receipts":[]})
	world.set("consumable_inventory",{})
	player.call("restore_stamina",100.0)
	world.call("_apply_snapshot",saved)
	if not check(int(world.get("cash")) == int(saved["cash"]) and live_ledger.has_receipt("story:roundtrip") and not live_ledger.credit_once("story:roundtrip", 20), "world restores single balance and reward receipt"):
		return
	if not check(int(world.get("consumable_inventory").get("water",0))==1 and float(player.get("stamina"))==55.0,"inventory and stamina round trip"):
		return
	if not check(Catalog.count(Catalog.restore({"water":100,"energy":100,"invalid":999}))==Catalog.MAX_ITEMS,"bounded validated saved inventory"):
		return
	saved.erase("progression")
	saved.erase("stamina")
	saved.erase("consumables")
	world.call("_apply_snapshot",saved)
	if not check(not live_ledger.has_receipt("story:roundtrip") and int(world.get("cash")) == int(saved["cash"]), "pre-ledger saves keep cash and clear receipts"):
		return
	if not check(float(player.get("stamina"))==100.0 and Catalog.count(world.get("consumable_inventory"))==0,"legacy saves default safely"):
		return
	print("VENDING_SMOKE PASS: stamina, real machine, purchase, consumption, bounded save migration")
	quit(0)
