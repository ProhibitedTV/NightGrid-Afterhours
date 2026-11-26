extends RefCounted
## Authored staff anchors and short nonmodal office remarks. No procedural identity.
const STAFF = [
	{"id":"jetson_wang","name":"Jetson Wang","role":"Chief Executive Officer","activity":"CHAT","seated":true,"palette":2,"position":Vector3(5,0,-6.65),"yaw":0.0,"outfit":"executive_leather","hair":"silver","glasses":false,"coat":"202125","height":.94,"width":.84,"phase":1.2},
	{"id":"people_ops","name":"Dana Mercer","role":"People Experience partner","activity":"TYPE","seated":true,"palette":4,"position":Vector3(-5,0,-6.65),"yaw":0.0,"outfit":"hr","hair":"bun","glasses":true,"coat":"514454","height":.88,"width":.74,"phase":2.1},
	{"id":"dev","name":"Dev Rao","role":"Platform engineer","activity":"SIP","seated":false,"palette":1,"position":Vector3(21.85,0,23.63),"yaw":PI,"outfit":"office","hair":"dark","glasses":true,"coat":"4e6570","height":.91,"width":.76,"phase":.7},
	{"id":"rina","name":"Rina Vale","role":"QA analyst","activity":"CHAT","seated":false,"palette":3,"position":Vector3(24.10,0,23.63),"yaw":PI,"outfit":"office","hair":"bun","glasses":false,"coat":"695a69","height":.85,"width":.72,"phase":3.4},
	{"id":"mika","name":"Mika Torres","role":"IP Security supervisor","activity":"CHAT","seated":false,"palette":0,"position":Vector3(6.35,0,2.65),"yaw":-PI/2,"outfit":"supervisor","hair":"parted","glasses":true,"coat":"344b4d","height":.91,"width":.80,"phase":1.8},
	{"id":"eli","name":"Eli Brooks","role":"IT support technician","activity":"SCROLL","seated":false,"palette":2,"position":Vector3(-6.75,-3.65,3.55),"yaw":PI/2,"outfit":"technician","hair":"cropped","glasses":true,"coat":"566375","height":.94,"width":.75,"phase":4.1},
	{"id":"security","name":"Owen Pike","role":"Lobby security officer","activity":"WATCH","seated":false,"palette":4,"position":Vector3(3.5,0,-8.75),"yaw":-PI/2,"outfit":"security","hair":"cropped","glasses":false,"coat":"253e54","height":.96,"width":.90,"phase":5.1},
	{"id":"reception","name":"Nina Bell","role":"Reception and access administration","activity":"TYPE","seated":false,"palette":0,"position":Vector3(6.35,0,8.3),"yaw":PI,"outfit":"office","hair":"bun","glasses":false,"coat":"786c61","height":.87,"width":.73,"phase":2.8}
]
const REMARKS = {
	"mika":["The approval copy is on your desk. Eli can reconcile it.","Good. Don't close the ticket until you've checked the access log.","Keep a copy of the incident number. Not on your personal device."],
	"eli":["Morning. Is that the signed access request?","I'll need the paper copy before I can reconcile the ticket.","Three export events. Same badge. The authorization trail is all there."],
	"dev":["Morning. The coffee is technically free.","Apparently the coffee budget has been optimized too.","I heard they called Legal. Be careful."],
	"rina":["The benefits renewal is on the noticeboard. Have you seen it?","They want a photo before lunch. Of course they do.","I saw your meeting disappear from the calendar."],
	"reception":["Good morning. Your badge is active.","Executive Affairs called. They're expecting you.","I'm sorry. They told me to prepare the exit paperwork."],
	"security":["Badge reader's been temperamental all week.","Stay on the employee side, please.","I'm just following the access list."],
	"jetson_wang":["Good morning. Remember: move fast, audit later.","My office is expecting you.","Let's keep this within the executive team."],
	"people_ops":["Have a productive shift.","I'll send the revised benefits notice.","Please take a seat. This won't take long."]
}

static func remark(id: String,phase: int) -> String:
	var lines: Array=REMARKS.get(id,[])
	return "" if lines.is_empty() else str(lines[clampi(phase,0,lines.size()-1)])
