extends SceneTree
const Frontage=preload("res://scripts/synaxis_lift_frontage.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	for labels in [["UP / OFFICES","DOWN / B1 IT"],["UP / LOBBY","NO SERVICE"],["NO SERVICE","DOWN / OFFICES"]]:
		var lift:=Frontage.new()
		lift.up_label=labels[0]
		lift.down_label=labels[1]
		root.add_child(lift)
		if lift.find_children("*","CollisionShape3D",true,false).size()!=3:
			_fail("Physical shaft collision changed")
			return
		for i in range(2):
			var direction: String="Up" if i==0 else "Down"
			var available: bool=labels[i]!="NO SERVICE"
			var sign:=lift.get_node("Destination"+direction) as Label3D
			var station:=lift.get_node("CallDirection"+direction) as Label3D
			var mat:=lift.get_node("LandingMat"+direction) as MeshInstance3D
			var button:=lift.get_node("CallButton"+direction) as MeshInstance3D
			if sign.text!=labels[i] or station.text!=(direction.to_upper() if available else "OFF"):
				_fail("Unavailable direction must not advertise a usable call")
				return
			if mat.material_override.albedo_color!=Color("3c5655" if available else "4a4c4b") or button.material_override.albedo_color!=Color("80b8a8" if available else "55595a"):
				_fail("Call mat and button availability colors")
				return
			if sign.no_depth_test or station.no_depth_test:
				_fail("Call signage must respect physical occlusion")
				return
		lift.free()
	print("SYNAXIS_LIFT_FRONTAGE PASS: endpoint calls visibly disabled; collision retained")
	quit(0)

func _fail(reason:String) -> void:
	push_error("SYNAXIS_LIFT_FRONTAGE "+reason)
	quit(1)
