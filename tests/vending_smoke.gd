extends SceneTree
const Catalog = preload("res://scripts/consumables.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("VENDING_SMOKE: "+label)
		quit(1)
	return ok
func _verify() -> void:
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
	world.call("_venue_action",1)
	if not check(int(world.get("cash"))==97 and int(world.get("consumable_inventory").get("water",0))==1,"atomic water purchase"):
		return
	world.call("_close_venue")
	world.call("_consume_ration")
	if not check(float(player.get("stamina"))==55.0 and Catalog.count(world.get("consumable_inventory"))==0,"water restores stamina and consumes inventory"):
		return
	world.call("_toggle_interaction")
	world.call("_venue_action",1)
	world.call("_close_venue")
	var saved: Dictionary = world.call("_capture_snapshot")
	world.set("consumable_inventory",{})
	player.call("restore_stamina",100.0)
	world.call("_apply_snapshot",saved)
	if not check(int(world.get("consumable_inventory").get("water",0))==1 and float(player.get("stamina"))==55.0,"inventory and stamina round trip"):
		return
	if not check(Catalog.count(Catalog.restore({"water":100,"energy":100,"invalid":999}))==Catalog.MAX_ITEMS,"bounded validated saved inventory"):
		return
	saved.erase("stamina")
	saved.erase("consumables")
	world.call("_apply_snapshot",saved)
	if not check(float(player.get("stamina"))==100.0 and Catalog.count(world.get("consumable_inventory"))==0,"legacy saves default safely"):
		return
	print("VENDING_SMOKE PASS: stamina, real machine, purchase, consumption, bounded save migration")
	quit(0)
