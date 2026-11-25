extends RefCounted
## Department stand-up schedule. A short recurring meeting after a completed
## equipment round; no dependency on world time or the main mission stage.
const TITLES=["RISK ALIGNMENT","DESIGN SIGN-OFF","RELEASE READINESS","COST OPTIMIZATION"]
const AGENDA=[
	["Faye: First item: the safety review.","Sam: The robot has passed every test except the human override.","Faye: Put it under future improvements."],
	["Dana: Is the new interface ready?","Jules: The interface is ready. The approval interface isn't.","Dana: Schedule another design review."],
	["Avery: What's blocking the release?","Milo: We found a regression in the regression tests.","Avery: Put the fix behind a feature flag."],
	["Ellis: We need to reduce meeting overhead.","Lee: I've booked a meeting to discuss that.","Ellis: Excellent. Send the minutes."]
]
const BEAT=3.0
const DURATION=9.0
var elapsed:=0.0
var active:=false
var completed:=0

func begin() -> void:
	elapsed=0.0
	active=true

func tick(delta:float) -> void:
	if not active:
		return
	elapsed=minf(DURATION,elapsed+maxf(0.0,delta))
	if elapsed>=DURATION:
		active=false
		completed+=1

func speaker() -> int:
	return 7 if int(elapsed/BEAT)==1 else 6

func line(level:int) -> String:
	if not active:
		return ""
	return str(AGENDA[level-1][clampi(int(elapsed/BEAT),0,2)])

func reset() -> void:
	active=false
	elapsed=0.0
