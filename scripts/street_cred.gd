extends RefCounted
## One-time neighborhood favors derive cred from existing settlement receipts.
## Repeatable activities use a bounded, monotonic completed-run count per source.
## A caller must verify successful gameplay before invoking settle_run.
const FAVOR_POINTS={
	"street:compatibility_patch":25,
	"venue:midnight_thermos":15,
	"venue:dead_frequency":25,
	"venue:glass_invoice":20,
	"venue:last_shift_recipe":20}
const FAVOR_NAMES={
	"street:compatibility_patch":"Compatibility Patch",
	"venue:midnight_thermos":"The Midnight Thermos",
	"venue:dead_frequency":"Dead Frequency",
	"venue:glass_invoice":"The Glass Invoice",
	"venue:last_shift_recipe":"Last Shift Recipe"}
const RUN_POINTS={"busking":4,"live_gig":12,"skate_session":3}
const MAX_RUNS=100000
const MAX_CRED=10000
const RANKS=[
	{"at":0,"name":"Unknown"},
	{"at":25,"name":"Local Face"},
	{"at":100,"name":"Recognized"},
	{"at":250,"name":"Neighborhood Name"},
	{"at":500,"name":"Underground Regular"},
	{"at":1000,"name":"Street Legend"}]
var _runs:Dictionary={}

static func valid_runs(value:Variant)->bool:
	if not value is Dictionary or value.size()>RUN_POINTS.size():
		return false
	for id in value:
		if not id is String or not RUN_POINTS.has(id):
			return false
		var n:Variant=value[id]
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)<0.0 or float(n)>MAX_RUNS or floor(float(n))!=float(n):
			return false
	return true

func restore(value:Variant)->bool:
	if not valid_runs(value):
		return false
	_runs.clear()
	for id in value:
		_runs[id]=int(value[id])
	return true

func snapshot()->Dictionary:
	return _runs.duplicate()

func completed_runs(source:String)->int:
	return int(_runs.get(source,0))

func settle_run(source:String,sequence:int)->bool:
	if not RUN_POINTS.has(source) or sequence<1 or sequence>MAX_RUNS or sequence!=completed_runs(source)+1:
		return false
	_runs[source]=sequence
	return true

func total(receipts:Dictionary)->int:
	var points:=0
	for id in FAVOR_POINTS:
		if receipts.has(id):
			points+=int(FAVOR_POINTS[id])
	for id in _runs:
		points+=int(_runs[id])*int(RUN_POINTS[id])
	return mini(points,MAX_CRED)

static func rank(points:int)->Dictionary:
	var value:=clampi(points,0,MAX_CRED)
	var current:Dictionary=RANKS[0]
	var next:Dictionary={}
	for row in RANKS:
		if int(row["at"])<=value:
			current=row
		else:
			next=row
			break
	return {"points":value,"name":current["name"],"floor":current["at"],"next":next.get("at",0),"next_name":next.get("name","")}

func summary(receipts:Dictionary)->String:
	var info:=rank(total(receipts))
	var result:="STREET CRED %d / %s"%[info["points"],str(info["name"]).to_upper()]
	if int(info["next"])>0:
		result+="  •  %d to %s"%[int(info["next"])-int(info["points"]),str(info["next_name"])]
	return result

## Fixed-size source summary; no unbounded activity history.
func earned_sources(receipts:Dictionary)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id in FAVOR_POINTS:
		if receipts.has(id):
			result.append({"name":FAVOR_NAMES[id],"points":FAVOR_POINTS[id]})
	for id in RUN_POINTS:
		var count:=completed_runs(id)
		if count>0:
			result.append({"name":str(id).replace("_"," ").capitalize(),"points":count*int(RUN_POINTS[id]),"runs":count})
	return result
