extends RefCounted
## Optional local dialogue. No access changes, wallet effects or quest flags.
const NAME="Marcus Vale"
const ANCHOR=Vector3(-6.55,0,18.55)
const TOPICS={
	"guard_r9":{"question":"Is that Jetson's R9?","reply":"Founder Edition. Custom paint, imported leather, the works. I have to log every scratch. The car has a better benefits package than I do."},
	"guard_parking":{"question":"Why does leadership get covered parking?","reply":"Risk mitigation. Rain on a founder's leather jacket is a strategic incident. Rain on your shirt is a personal development opportunity."},
	"guard_robots":{"question":"Are those robots going to replace security?","reply":"They say no. Yesterday they asked me to demonstrate everything I do on camera. For documentation, apparently."},
	"guard_access":{"question":"Can I park here?","reply":"Not unless your badge says executive. Even the executives need permission to use the founder's bay."}
}
static func greeting(former:bool) -> String:
	return "Marcus: I heard about your badge. Sorry, pal. I can talk out here, but I can't let you into the offices." if former else "Marcus: Morning. Leadership reserve. Keep the access aisle clear."

static func reply(topic:String,former:bool) -> String:
	if topic=="guard_access" and former:
		return "Your employee parking access was revoked with your badge. Public sidewalks are still public. I'm not going to give you trouble for standing here."
	return str(TOPICS.get(topic,{}).get("reply",""))
