extends RefCounted
## Optional local dialogue. No access changes or wallet effects.
const NAME="Marcus Vale"
const ANCHOR=Vector3(-6.55,0,18.55)
const TOPICS={
	"guard_r9":{"question":"Is that Jetson's R9?","reply":"Founder Edition. Custom paint, imported leather, the works. I have to log every scratch. The car has a better benefits package than I do."},
	"guard_parking":{"question":"Why does leadership get covered parking?","reply":"Risk mitigation. Rain on a founder's leather jacket is a strategic incident. Rain on your shirt is a personal development opportunity."},
	"guard_robots":{"question":"Are those robots going to replace security?","reply":"They say no. Yesterday they asked me to demonstrate everything I do on camera. For documentation, apparently."},
	"guard_access":{"question":"Can I park here?","reply":"Not unless your badge says executive. Even the executives need permission to use the founder's bay."},
	"guard_shift":{"question":"How long have you worked here?","reply":"Eleven years. Three contractors, four uniform changes, same booth. Every year they tell me the new badge system is simpler."},
	"guard_layoff":{"question":"Did they tell you why I was fired?","reply":"They sent an access-revocation notice. No explanation. It said to treat you with dignity while immediately disabling every door. For what it is worth, I never had a problem with you.","former_only":true},
	"guard_followup":{"question":"How have things been since I left?","reply":"Same booth, new contractor. A few folks asked where you went. If you ever need to talk, you know where I am. I can't let you through those doors, though.","former_only":true,"contact_only":true}
}
static func greeting(former:bool,contact:int=0) -> String:
	if former and contact>0:
		return "Marcus: Good to see you again. How's life outside the badge reader?"
	return "Marcus: I heard about your badge. Sorry, pal. I can talk out here, but I can't let you into the offices." if former else "Marcus: Morning. Leadership reserve. Keep the access aisle clear."

static func available(topic:String,former:bool,contact:int=0) -> bool:
	return TOPICS.has(topic) and (former or not bool(TOPICS[topic].get("former_only",false))) and (contact>0 or not bool(TOPICS[topic].get("contact_only",false)))

static func reply(topic:String,former:bool,contact:int=0) -> String:
	if not available(topic,former,contact):
		return ""
	if topic=="guard_access" and former:
		return "Your employee parking access was revoked with your badge. Public sidewalks are still public. I'm not going to give you trouble for standing here."
	return str(TOPICS.get(topic,{}).get("reply",""))
