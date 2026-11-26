extends SceneTree
const Garage = preload("res://scripts/starter_garage.gd")
const Home = preload("res://scripts/starter_home.gd")
const RoadCars = preload("res://scripts/road_car_catalog.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,reason: String) -> bool:
	if not ok:
		push_error("GARAGE_SMOKE: "+reason)
		quit(1)
	return ok
func _verify() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	world.set_process(false)
	world.set_physics_process(false)
	var city: Node3D = world.get("city_details")
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	var cars: Array = world.get("cars")
	for car in cars:
		car.set_physics_process(false)
	city.call("set_focus",Garage.entry())
	var garage: Node3D = city.call("starter_garage",Garage.entry())
	if not check(is_instance_valid(garage) and garage.find_children("*","CollisionShape3D",true,false).size()>=6,"physical streamed shell"):
		return
	player.global_position = garage.call("desk_point")
	var ledger = world.get("progression")
	world.call("_toggle_interaction")
	if not check(not world.get("venue_panel").visible and not ledger.owns_vehicle(Garage.IDS[0]),"locked services"):
		return
	ledger.credit_once(Home.ACCESS_RECEIPT,100)
	world.get("story_mission").restore({"version":1,"id":Home.ACCESS_RECEIPT,"status":"complete","step":3})
	world.set("cash",Home.move_in_price())
	if not check(ledger.activate_home_tenancy(),"paid tenancy"):
		return
	world.set("cash",RoadCars.title_price(Garage.IDS[0])+200)
	world.set("heat",0.0)
	await physics_frame
	world.call("_toggle_interaction")
	world.call("_venue_action",1)
	var car: CharacterBody3D = cars[0]
	if not check(ledger.owns_vehicle(Garage.IDS[0]) and garage.call("parked_at",car.global_position,0) and world.get("cash")==200 and cars.size()==12,"paid starter title uses original car, no duplicate spawn"):
		return
	var button: Button = world.get("venue_service_button")
	if not check(button.disabled and button.text.contains("PARKED") and button.text.contains("NO FEE"),"parked vehicle status is explicit"):
		return
	world.call("_venue_action",1)
	if not check(world.get("cash")==200,"already parked costs nothing"):
		return
	car.global_position = Garage.entry()+Vector3(0,0,-8)
	car.set("condition",45.0)
	world.call("_update_venue_panel")
	if not check(not button.disabled and button.text.contains("$75"),"recoverable vehicle shows fee"):
		return
	car.set("occupied",true)
	world.call("_update_venue_panel")
	if not check(button.disabled and button.text.contains("UNAVAILABLE"),"occupied vehicle cannot be requested"):
		return
	car.set("occupied",false)
	world.call("_update_venue_panel")
	var blocker: CharacterBody3D = cars[1]
	var previous := blocker.global_position
	var bay: Vector3 = garage.call("bay_point",0)
	blocker.global_position = bay+Vector3.UP
	await physics_frame
	world.call("_venue_action",1)
	if not check(world.get("cash")==200 and not garage.call("parked_at",car.global_position,0),"blocked bay cannot debit or relocate"):
		return
	blocker.global_position = previous
	await physics_frame
	world.call("_venue_action",1)
	if not check(world.get("cash")==125 and garage.call("parked_at",car.global_position,0) and car.get("condition")==45.0,"recovery preserves condition and debits once"):
		return
	world.call("_close_venue")
	var saved: Dictionary = world.call("_capture_snapshot")
	var session := root.get_node("GameSession")
	if not check(session.call("is_valid_snapshot",session.call("make_snapshot",saved)),"garage state uses existing save"):
		return
	car.global_position = Garage.entry()
	world.call("_apply_snapshot",saved)
	if not check(garage.call("parked_at",car.global_position,0) and car.get("condition")==45.0 and ledger.owns_vehicle(Garage.IDS[0]) and cars.size()==12,"same vehicle and damage restore"):
		return
	print("GARAGE_SMOKE PASS: title, blocked bay, recovery and physical save")
	quit(0)
