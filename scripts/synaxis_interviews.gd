extends RefCounted
## Optional interviews, not quest gates. Stable topic IDs are useful to offline
## voice authoring. Statements reflect what this person knows at this stage.
const CONTACTS = {
	"worker_1_0": {"name":"Nora Finch","role":"AI & Robotics Engineer","topics":[
		{"id":"work","question":"What are you building?","before":"A mobile warehouse assistant. The demo says it can do everything. Our test report says it can do three things.","after":"The executive team wants a security demonstration. We still have open safety tickets."},
		{"id":"audit","question":"Who approves prototype access?","before":"Engineering owns the normal access list. Executive exceptions go through a separate system.","after":"I didn't approve the executive exception. If the log shows an override, ask the person who signed it."}]},
	"worker_2_0": {"name":"Ruth Lane","role":"Product & Design Specialist","topics":[
		{"id":"work","question":"What are you working on?","before":"A dashboard that turns six metrics into one. Unfortunately nobody agrees what the one metric means.","after":"They asked us to change the compliance indicator to a more reassuring shade of green."},
		{"id":"audit","question":"Does product review access alerts?","before":"We design the screens. Security owns the actual decisions.","after":"A green indicator is not evidence. It only means the rule feeding it returned green."}]},
	"worker_3_0": {"name":"Evan Cole","role":"Quality & Validation Analyst","topics":[
		{"id":"work","question":"How is validation going?","before":"We have a release deadline and a list of defects. Management has solved the deadline part.","after":"They asked whether the access defect could be classified as a documentation issue."},
		{"id":"audit","question":"Can an override hide an audit event?","before":"It can bypass an approval rule. It shouldn't erase the original event.","after":"Keep the event record separate from the dashboard's verdict. That's the distinction I'd make in a defect report."}]},
	"worker_4_0": {"name":"Morgan Pierce","role":"Business Operations Analyst","topics":[
		{"id":"work","question":"What's happening this quarter?","before":"We're reconciling the savings spreadsheet with the hiring spreadsheet. They are not on speaking terms.","after":"Everyone is waiting for the headcount announcement. The executive parking budget was already approved."},
		{"id":"audit","question":"Who pays for an executive exception?","before":"Executive Affairs owns its own cost center. We're not allowed to amend their entries.","after":"An expense approval and an access approval are different records. Don't assume one proves the other."}]},
	"cto": {"name":"Dr. Sera Okafor","role":"Chief Technology Officer","topics":[
		{"id":"work","question":"How is the robotics program?","before":"The engineers need another quarter. The board needs another announcement.","after":"I would prefer that our security review outlast the earnings call."},
		{"id":"audit","question":"Did engineering authorize the transfer?","before":"Restricted exports require authorization. Engineering does not delegate that to personal assistants.","after":"I didn't authorize the transfer. The executive exception is outside my approval chain."}]},
	"legal": {"name":"Marianne Cross","role":"General Counsel","topics":[
		{"id":"work","question":"How do I report a concern?","before":"Use the internal reporting process. Keep an accurate account of what you observed.","after":"Preserve the record. I can't promise what Executive Affairs will do with it."},
		{"id":"audit","question":"What counts as proof?","before":"Separate facts from inference. A suspicious circumstance is not a finding.","after":"A hotel approval alone does not establish a relationship. Document the access events and who authorized them."}]},
	"cfo": {"name":"Graham Voss","role":"Chief Financial Officer","topics":[
		{"id":"work","question":"How are the numbers?","before":"Very good. We have achieved remarkable savings in the department responsible for measuring savings.","after":"I would appreciate it if any security review concluded after the quarterly call."},
		{"id":"audit","question":"Who reviews executive expenses?","before":"Finance processes the approvals. Executive Affairs approves the exceptions.","after":"An approved expense isn't a security clearance. Ask Security about the access record."}]}
}
static func conversation(id: String, stage: int) -> Dictionary:
	if not CONTACTS.has(id):
		return {}
	var source: Dictionary = CONTACTS[id]
	var topics: Array[Dictionary] = []
	for item in source["topics"]:
		topics.append({"id":id+"."+str(item["id"]),"question":item["question"],
			"phase":"before" if stage<2 else "after","reply":item["before"] if stage<2 else item["after"]})
	return {"id":id,"name":source["name"],"role":source["role"],"topics":topics}
