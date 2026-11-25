extends StaticBody3D
## Structural market counter with one bounded, impact-triggered stock spill.
## This is a streamed prop, not a collapsible building or permanent save state.
const Materials = preload("res://scripts/material_library.gd")
const SPILL_SPEED = 6.0
const STOCK_SIZE = Vector3(.55,.32,.45)
const DEBRIS_SECONDS = 5.0
var _stock: Array[MeshInstance3D] = []
var spilled := false

func _ready() -> void:
	_solid(Vector3(0,.50,0),Vector3(4.15,1.02,2.20),Color("69777b"),"CONCRETE")
	_solid(Vector3(0,1.115,0),Vector3(3.75,.23,1.80),Color("d1a775"),"WOOD")
	for x in [-1.0,0.0,1.0]:
		var item := _view(STOCK_SIZE,Color("78af78"),"WOOD")
		item.position=Vector3(x,1.39,0)
		add_child(item)
		_stock.append(item)

func receive_fixture_impact(closing:float,direction:Vector3,point:Vector3)->void:
	if spilled or not is_finite(closing) or closing<SPILL_SPEED or not direction.is_finite() or direction.length_squared()<.001 or not point.is_finite():
		return
	spilled=true
	_scatter.call_deferred(direction.normalized(),minf(closing,20.0))

func _scatter(direction:Vector3,closing:float)->void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	for i in range(_stock.size()):
		var item := _stock[i]
		var body := RigidBody3D.new()
		body.name="MarketStockDebris_%d"%i
		body.mass=.8
		body.continuous_cd=true
		# Debris contacts the static world, not the striking vehicle or player.
		# No debris-debris collisions and at most three bodies per counter.
		body.collision_layer=0
		body.collision_mask=1
		body.position=item.position
		add_child(body)
		item.reparent(body,false)
		item.position=Vector3.ZERO
		var shape:=CollisionShape3D.new()
		var bounds:=BoxShape3D.new()
		bounds.size=STOCK_SIZE
		shape.shape=bounds
		body.add_child(shape)
		var lateral:=Vector3(-direction.z,0,direction.x)*float(i-1)*.9
		body.apply_central_impulse((direction*minf(closing*.24,4.0)+Vector3.UP*2.0+lateral)*body.mass)
		get_tree().create_timer(DEBRIS_SECONDS,false,true).timeout.connect(body.queue_free)
	_stock.clear()

func _view(size:Vector3,color:Color,material:String)->MeshInstance3D:
	var view:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	view.mesh=mesh
	view.material_override=Materials.surface(material,color)
	return view

func _solid(at:Vector3,size:Vector3,color:Color,material:String)->void:
	var view:=_view(size,color,material)
	view.position=at
	add_child(view)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	collider.position=at
	add_child(collider)
