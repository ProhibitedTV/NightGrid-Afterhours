extends RefCounted
## Fictional records investigation; no hacking, real credentials or courier cargo.
const ID = "investigation:paper_city"
const TITLE = "THE PAPER CITY"
const REWARD = 1450
const PREREQUISITES = ["technical:crane_interlock","technical:grid_telemetry"]
const STAGES = [
	{"site":"harbor_library","title":"Meet Penny","line":"Penny: Synaxis claims it sold the old district's power concessions last month. The public archive says otherwise. Find the original permit at Southworks Records. I'll pay for evidence, not rumors."},
	{"site":"records_office","title":"Inspect permit register","line":"Clerk Ada: Permit MB-091 lists a transfer effective June 2. The authorization field says pending. A later printed revision claims approval on May 19. Both are public copies; keep the dates."},
	{"site":"dock_watch","title":"Compare independent register","line":"Clerk Bo: The stamped register shows no approval before June 11. The May 19 version isn't corroborated by this register. That's all I can certify."},
	{"site":"harbor_library","title":"Present findings to Penny","line":"Penny: We have conflicting dates, a pending authorization and an independent register. What can we actually establish?"}
]
# Compact authored notes mirror the actual evidence dialogues, in order.
const EVIDENCE = [
	"Penny: Synaxis claims the concession sale was authorized last month; verify the public permit.",
	"Permit MB-091: transfer effective June 2; authorization pending. Later revision claims May 19 approval.",
	"Dock Watch: independent stamped register records no approval before June 11."
]
var stage := 0

func unlocked(wallet: RefCounted) -> bool:
	for id in PREREQUISITES:
		if wallet.call("has_receipt",id):
			return true
	return false

func available(wallet: RefCounted) -> bool:
	return unlocked(wallet) and stage < STAGES.size() and not wallet.call("has_receipt",ID)

func current(wallet: RefCounted) -> Dictionary:
	return STAGES[stage].duplicate() if available(wallet) else {}

func advance(site: String, choice: int, wallet: RefCounted) -> Dictionary:
	var step := current(wallet)
	if step.is_empty() or step["site"] != site:
		return {"status":"unavailable"}
	if choice != 0:
		return {"status":"incorrect","message":"The records do not establish a particular person's guilt. Keep the finding limited to what the documents support."}
	if stage == STAGES.size()-1:
		if not wallet.call("credit_once",ID,REWARD):
			return {"status":"blocked","message":"Payment blocked. Free wallet capacity and try again."}
		stage += 1
		return {"status":"complete","message":"Penny: That's a defensible finding. The archive will publish the discrepancy and request an independent review.","reward":REWARD}
	stage += 1
	return {"status":"advanced","message":"Evidence recorded. Open Workboard for your next lead."}

func restore(value: int, wallet: RefCounted) -> void:
	stage = STAGES.size() if wallet.call("has_receipt",ID) else (clampi(value,0,STAGES.size()-1) if unlocked(wallet) else 0)

func journal(wallet: RefCounted) -> String:
	var step := current(wallet)
	if step.is_empty() or stage == 0:
		return ""
	return "%s / %d of %d / %s" % [TITLE,stage+1,STAGES.size(),step["title"]]

## Journal-only case review. The compact HUD continues using journal().
## Derive evidence from existing validated stage and settlement receipt.
func case_review(wallet: RefCounted) -> String:
	if wallet.call("has_receipt",ID):
		return TITLE+" / COMPLETE\nFinding: conflicting public records warrant independent review; no individual guilt established.\n"+ "\n".join(PackedStringArray(EVIDENCE))
	if not available(wallet):
		return ""
	var lines := PackedStringArray([TITLE+" / "+str(STAGES[stage]["title"])])
	for i in range(mini(stage,EVIDENCE.size())):
		lines.append(EVIDENCE[i])
	return "\n".join(lines)
