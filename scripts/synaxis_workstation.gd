extends RefCounted
## Fictional intranet records, read-only. Story audit remains the canonical
## finding; the workstation exposes its components without granting authority.
const Opening=preload("res://scripts/opening_story.gd")
const MAIL=[
	{"from":"Mika / IP Security","subject":"SYN-771 / morning handoff","body":"Please carry the sealed change request to Eli in B1. Verify the restricted repository alert with IT before approaching Executive Affairs. Do not distribute unverified findings."},
	{"from":"People Experience","subject":"Your performance calibration","body":"Your manager has marked your work Exceeds Expectations. Final calibration is subject to budget alignment. An excellent rating does not constitute an expectation of continued employment."},
	{"from":"Executive Affairs","subject":"Quarterly all-hands / mandatory","body":"Attendance is required. Questions will be collected in advance, reviewed for relevance and answered subject to available time. Please bring your authentic self and an approved question."},
	{"from":"Facilities","subject":"Coffee service optimization","body":"The ground-floor machine will dispense one complimentary cup per shift. Executive hospitality is unaffected. Please report technical faults through the new service portal."}
]
const RECORDS=[
	{"event":"EXPORT / 01","actor":"Lin Xue / Executive Assistant","resource":"Restricted prototype repository","status":"Override accepted"},
	{"event":"EXPORT / 02","actor":"Lin Xue / Executive Assistant","resource":"Restricted prototype repository","status":"Override accepted"},
	{"event":"EXPORT / 03","actor":"Lin Xue / Executive Assistant","resource":"Restricted prototype repository","status":"Override accepted"},
	{"event":"AUTHORIZATION","actor":"Jetson Wang / CEO","resource":"Temporary access exception","status":"Approved outside normal engineering role"},
	{"event":"COMPLIANCE","actor":"Automated policy evaluator","resource":"Executive exception","status":"GREEN / exception supersedes rule"}
]
static func page(tab:String,verified:bool) -> Dictionary:
	match tab:
		"inbox":
			return {"title":"INBOX / 4 MESSAGES","rows":MAIL.duplicate(true)}
		"ticket":
			return {"title":"SERVICE DESK / SYN-771","body":Opening.TICKET}
		"access":
			if not verified:
				return {"title":"ACCESS RECORDS / PENDING","body":"The alert is assigned to you. Authorization details are unavailable until IT validates the sealed request."}
			return {"title":"ACCESS RECORDS / VALIDATED BY IT","rows":RECORDS.duplicate(true),"body":"Three export events and one executive exception are recorded. The automated result is not an independent finding. The recovered message and private correspondence are summarized in the case report."}
		_:
			return {}
