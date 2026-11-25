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
const LATE_AGENDA=[
	["Faye: Did you see the new access notice?","Sam: Yes. We have been asked to preserve the logs.","Faye: Keep working from the approved branch."],
	["Dana: The review agenda has changed.","Jules: Legal wants us to retain the design history.","Dana: We will wait for the next update."],
	["Avery: Release readiness is on hold.","Milo: I have archived the original test results.","Avery: Good. Leave the records untouched."],
	["Ellis: There is a new approval freeze.","Lee: HR asked us to refer questions to management.","Ellis: All right. We can still finish the forecast."]
]
const BEAT=3.0
const DURATION=9.0
var elapsed:=0.0
var active:=false
var completed:=0
var _late:=false

func begin(late:bool=false) -> void:
	_late=late
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
	var agenda:Array=LATE_AGENDA[level-1] if _late else AGENDA[level-1]
	return str(agenda[clampi(int(elapsed/BEAT),0,2)])

func reset() -> void:
	active=false
	elapsed=0.0
