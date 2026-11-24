extends SceneTree
const Plan = preload("res://scripts/world_plan.gd")
const Masonry = preload("res://scripts/photo_masonry.gd")
func _initialize()->void:
	create_timer(40.0,true,false,true).timeout.connect(func()->void: quit(1))
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("PHOTO_MASONRY: "+message)
		quit(1)
	return ok
func _verify()->void:
	var packed:PackedScene = load("res://scenes/main.tscn")
	var world:Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var city:Node3D = world.get("city_details")
	var manifest:Dictionary = city.get("world_manifest")
	var areas: Array[Vector2i] = [Vector2i(-3,-3),Vector2i(-2,1)]
	var mapped := 0
	var reference: StandardMaterial3D = null
	for block in areas:
		var center := Vector3((float(block.x)+0.5)*Plan.BLOCK_SIZE,0,(float(block.y)+0.5)*Plan.BLOCK_SIZE)
		city.call("set_focus",center)
		var chunks:Dictionary = city.get("_loaded")
		var chunk:Node3D = chunks[block]
		var lots:Array = manifest["blocks"]["%d,%d" % [block.x,block.y]]
		for i in range(2):
			var lot:Dictionary = lots[i]
			if str(lot["material"])!="BRICK":
				continue
			var expected_x := center.x+(-10.5 if i==0 else 10.5)
			var expected_size := Vector3(float(lot["width"]),float(lot["height"]),float(lot["depth"]))
			var found := false
			for node in chunk.get_children():
				if not node is StaticBody3D or not is_equal_approx(node.position.x,expected_x):
					continue
				var visual:MeshInstance3D = null
				var collision:CollisionShape3D = null
				for part in node.get_children():
					if part is MeshInstance3D:
						visual=part
					elif part is CollisionShape3D:
						collision=part
				if collision == null or not collision.shape is BoxShape3D or (collision.shape as BoxShape3D).size != expected_size:
					continue
				if block == Vector2i(-2, 1):
					if not _check(visual == null, "Brickwater retains its collider without the opaque parcel mesh"):
						return
					visual = chunk.get_node("BrickwaterEnvelope_%d/StreetMasonry" % i) as MeshInstance3D
					if not _check(visual.mesh is QuadMesh and (visual.mesh as QuadMesh).size == Vector2(expected_size.x, expected_size.y), "closed authored parcel has original width and height"):
						return
				elif visual == null or not visual.mesh is BoxMesh or (visual.mesh as BoxMesh).size != expected_size:
					continue
				var material := visual.material_override as StandardMaterial3D
				var expected := Masonry.surface(Color(str(lot["wall"])))
				if not _check(material==expected and material.normal_enabled and material.metallic==0.0 and material.uv1_world_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/Masonry.TILE_METRES),"actual shell photo material/cache"):
					return
				if not _check(material.albedo_texture!=null and material.normal_texture!=null and material.roughness_texture!=null and material.albedo_texture.resource_path.ends_with("brick_wall_001_diffuse_2k.jpg") and material.normal_texture.resource_path.ends_with("brick_wall_001_nor_gl_2k.png") and material.roughness_texture.resource_path.ends_with("brick_wall_001_rough_2k.png"),"real licensed scan channels"):
					return
				if reference==null:
					reference=material
				if not _check(reference.albedo_texture==material.albedo_texture and reference.normal_texture==material.normal_texture and reference.roughness_texture==material.roughness_texture,"texture sharing"):
					return
				found=true
				mapped+=1
				break
			if not _check(found,"original shell and collider for brick lot"):
				return
	if not _check(mapped>=1,"at least one actual masonry lot"):
		return
	var clock: Node = world.get("day_night")
	clock.set_process(false)
	clock.set("paused", true)
	var dry_tint := reference.albedo_color
	var source_normal := reference.normal_texture
	var source_rough := reference.roughness_texture
	var source_albedo := reference.albedo_texture
	clock.call("set_weather", "storm")
	clock.call("_process", 3.0)
	if not _check(reference.albedo_color.r < dry_tint.r and is_equal_approx(reference.roughness, .76) and reference.normal_scale >= .65 and not reference.clearcoat_enabled, "rain dampens shared brick without mirror sheen"):
		return
	if not _check(reference.normal_texture == source_normal and reference.roughness_texture == source_rough and reference.albedo_texture == source_albedo, "weather preserves original texture resources"):
		return
	var late_tint := Color("a6b5c1")
	var late := Masonry.surface(late_tint)
	if not _check(is_equal_approx(late.roughness, .76) and late.albedo_texture == source_albedo, "newly streamed brick inherits current rain"):
		return
	clock.call("set_weather", "clear")
	clock.call("_process", 20.0)
	if not _check(reference.albedo_color.is_equal_approx(dry_tint) and is_equal_approx(reference.roughness, 1.0) and is_equal_approx(reference.normal_scale, .75) and late.albedo_color.is_equal_approx(Color.WHITE.lerp(late_tint,.38)), "drying restores original facade palette"):
		return
	print("PHOTO_MASONRY_SMOKE PASS: ",mapped," brick parcels use shared photo PBR and exact original colliders")
	quit(0)
