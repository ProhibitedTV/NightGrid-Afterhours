extends Node3D
## Small optional diegetic interactions. No money, inventory or mission effects.
const Audio=preload("res://scripts/synaxis_generated_audio.gd")
const AnubisReview = preload("res://scripts/anubis_prop_review.gd")
const PRINTER=Vector3(-7.85,0,-.4)
const COFFEE=Vector3(-7.85,0,-2.45)
const PRINTER_USE=Vector3(-6.65,1.15,-.4)
const COFFEE_USE=Vector3(-6.65,1.15,-2.45)
const PRINT_TIME=3.0
const COFFEE_TIME=2.6
var level:=1
var _active:=false
var _task:=""
var _elapsed:=0.0
var _duration:=0.0
var _sheet:MeshInstance3D
var _liquid:MeshInstance3D
var _cup_mesh:MeshInstance3D
var _owner:=""
var _output:=""
var _claim_time:=0.0
var _stream:MeshInstance3D
var _status:Label3D
var _coffee_status:Label3D
var _printer_sound:AudioStreamPlayer3D
var _coffee_sound:AudioStreamPlayer3D
var _materials:Dictionary={}
var _printed:=0
var _brewed:=0
var _notice:=""
var _notice_time:=0.0

func _mat(color:Color) -> StandardMaterial3D:
	var key:=color.to_html()
	if not _materials.has(key):
		var m:=StandardMaterial3D.new()
		m.albedo_color=color
		m.roughness=.65
		_materials[key]=m
	return _materials[key]

func _box(id:String,at:Vector3,size:Vector3,color:Color,solid:bool=false) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	item.name=id
	var mesh:=BoxMesh.new()
	mesh.size=size
	item.mesh=mesh
	item.position=at
	item.material_override=_mat(color)
	add_child(item)
	if solid:
		var body:=StaticBody3D.new()
		body.name=id+"Collision"
		body.position=at
		var hit:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		hit.shape=shape
		body.add_child(hit)
		add_child(body)
	return item

func _label(id:String,value:String,at:Vector3,pixel:float) -> Label3D:
	var label:=Label3D.new()
	label.name=id
	label.text=value
	label.position=at
	label.rotation.y=PI/2
	label.font_size=40
	label.pixel_size=pixel
	label.outline_size=2
	add_child(label)
	return label

func _cylinder(id:String,at:Vector3,radius:float,height:float,color:Color) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	item.name=id
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=16
	item.mesh=mesh
	item.position=at
	item.material_override=_mat(color)
	add_child(item)
	return item

func _ready() -> void:
	# Dress the existing west printer cabinet, whose collision is owned by the floor.
	var printer := _box("PrinterBody",PRINTER+Vector3(0,1.25,0),Vector3(.55,.40,.65),Color("d3d7d5"))
	if OS.has_environment(AnubisReview.ROOT_ENV):
		var forward := Vector3(0.64, -0.77, 0.0).normalized()
		var up := Vector3(0.0, 0.0, 1.0)
		var orientation := Basis(forward, up, forward.cross(up)).transposed()
		AnubisReview.fitted(printer, "copier.glb", "632bb4b2501cc96cc2b441207ec171c1c8d817ac39401da70517ed84c52964a0",
			orientation, Vector3(0.55, 0.40, 0.65), PRINTER + Vector3(0, 1.06, 0))
	_box("PrinterOutputSlot",PRINTER+Vector3(.281,1.22,0),Vector3(.014,.07,.38),Color("242d32"))
	_box("PrinterOutputTray",PRINTER+Vector3(.43,1.16,0),Vector3(.31,.035,.42),Color("404b50"))
	_sheet=_box("PrintedSheet",PRINTER+Vector3(.29,1.185,0),Vector3(.27,.008,.205),Color("f1eee2"))
	_sheet.hide()
	_status=_label("PrinterStatus","READY",PRINTER+Vector3(.285,1.38,0),.0014)
	# Separate appliance on the west perimeter, between existing desk rows.
	_box("CoffeeCounter",COFFEE+Vector3(0,.51,0),Vector3(.66,1.02,1.14),Color("817664"),true)
	_box("CounterTop",COFFEE+Vector3(0,1.04,0),Vector3(.72,.08,1.20),Color("3e464a"))
	_box("MachineBody",COFFEE+Vector3(-.11,1.31,0),Vector3(.33,.47,.50),Color("31393e"))
	_box("MachineHead",COFFEE+Vector3(.08,1.48,0),Vector3(.37,.15,.48),Color("59636a"))
	_box("DripTray",COFFEE+Vector3(.16,1.12,0),Vector3(.31,.045,.46),Color("222b30"))
	for i in range(4):
		_box("TrayGroove",COFFEE+Vector3(.07+i*.05,1.145,0),Vector3(.012,.005,.42),Color("808a8c"))
	_cup_mesh=_cylinder("PaperCup",COFFEE+Vector3(.19,1.21,0),.056,.12,Color("d1c1a7"))
	_liquid=_cylinder("CoffeeSurface",COFFEE+Vector3(.19,1.272,0),.048,.005,Color("4c2e1f"))
	_liquid.hide()
	_stream=_cylinder("CoffeeStream",COFFEE+Vector3(.19,1.35,0),.008,.15,Color("6a4028"))
	_stream.hide()
	_coffee_status=_label("CoffeeStatus","COMPLIMENTARY / 1 CUP",COFFEE+Vector3(.285,1.66,0),.0016)
	_printer_sound=Audio.emitter(self,"office_printer",PRINTER+Vector3(0,1.2,0),-15.0,7.0)
	_coffee_sound=Audio.emitter(self,"office_coffee",COFFEE+Vector3(0,1.4,0),-17.0,6.0)
	set_active(false)

func set_active(active:bool) -> void:
	_active=active
	set_process(active and (not _task.is_empty() or _notice_time>0.0))
	if not active:
		Audio.activate(_printer_sound,false)
		Audio.activate(_coffee_sound,false)
		_task=""
		_owner=""
		_output=""
		_claim_time=0.0
		_cup_mesh.show()
		_notice=""
		_notice_time=0.0
		_status.text="READY"
		_coffee_status.text="COMPLIMENTARY / 1 CUP"
		_stream.hide()
		_sheet.hide()
		_liquid.hide()

func nearby(at:Vector3) -> String:
	if not _active or not at.is_finite():
		return ""
	var p:=to_local(at)
	if p.distance_to(PRINTER_USE)<.95:
		return "printer"
	if p.distance_to(COFFEE_USE)<.95:
		return "coffee"
	return ""

func prompt(at:Vector3) -> String:
	var site:=nearby(at)
	if site.is_empty():
		return ""
	if not _task.is_empty() or not _owner.is_empty():
		return "Equipment busy..."
	if not _notice.is_empty():
		return _notice
	return "Print test page" if site=="printer" else "Brew office coffee"

func interact(at:Vector3) -> bool:
	var site:=nearby(at)
	if site.is_empty():
		return false
	request(site,"player")
	return true

# Shared appliance transaction. NPCs never enter a player-owned cycle.
func request(site:String,owner:String) -> bool:
	if not _active or site not in ["printer","coffee"] or owner.is_empty() or not _task.is_empty() or not _owner.is_empty():
		return false
	_owner=owner
	_output=""
	_claim_time=0.0
	_notice=""
	_notice_time=0.0
	_task=site
	_elapsed=0.0
	_duration=PRINT_TIME if site=="printer" else COFFEE_TIME
	if site=="printer":
		_sheet.hide()
		_status.text="PRINTING..."
		if is_instance_valid(_printer_sound):
			_printer_sound.play()
	else:
		_cup_mesh.show()
		_liquid.hide()
		_stream.show()
		_coffee_status.text="BREWING..."
		if is_instance_valid(_coffee_sound):
			_coffee_sound.play()
	set_process(true)
	return true

func collect(owner:String,site:String) -> bool:
	if owner!=_owner or site!=_output or not _task.is_empty():
		return false
	if site=="printer":
		_sheet.hide()
	else:
		_cup_mesh.hide()
		_liquid.hide()
	_owner=""
	_output=""
	_claim_time=0.0
	return true

func _process(delta:float) -> void:
	if not _active:
		return
	if _task.is_empty():
		_notice_time=maxf(0.0,_notice_time-delta)
		if _notice_time<=0.0:
			_notice=""
		if not _owner.is_empty():
			_claim_time=maxf(0.0,_claim_time-delta)
			if _claim_time<=0.0:
				_owner=""
				_output=""
		if _notice_time<=0.0 and _owner.is_empty():
			set_process(false)
		return
	_elapsed=minf(_duration,_elapsed+maxf(0.0,delta))
	var progress:=_elapsed/_duration
	if _task=="printer":
		_sheet.visible=progress>.25
		_sheet.position.x=PRINTER.x+.28+smoothstep(.25,.90,progress)*.17
	else:
		_stream.visible=progress<.94
		_liquid.visible=progress>.80
	if progress>=1.0:
		if _task=="printer":
			_printed+=1
			_status.text="READY"
			_notice="Test page printed. No paperless initiative was harmed."
		else:
			_brewed+=1
			_stream.hide()
			_coffee_status.text="COMPLIMENTARY / 1 CUP"
			_notice="Coffee ready. Compensation remains unchanged."
		if _owner=="player":
			_owner=""
			_output=""
		else:
			_output=_task
			_claim_time=8.0
			_notice=""
		_task=""
		_notice_time=4.0

func stats() -> Dictionary:
	return {"active":_active,"task":_task,"printed":_printed,"brewed":_brewed,"stream":_stream.visible,"owner":_owner,"output":_output}
