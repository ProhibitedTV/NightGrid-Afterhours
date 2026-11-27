extends RefCounted
## Narrative score policy, separate from the creator-owned radio library.
## Only curated, imported Oggs under this dedicated root are discoverable.
## Raw NAS candidates and checkpoints are never runtime inputs.
const ROOT = "res://assets/audio/chapter_score/"
const CUES = {
	"score:title": {"id":"morrow.title.theme", "title":"Morrow Bay After Dark", "once":false},
	"score:arrival": {"id":"synaxis.arrival.security-pulse", "title":"Terms of Employment", "once":true},
	"score:offboarding": {"id":"synaxis.offboarding.empty-floor", "title":"Your Access Has Expired", "once":true},
	"score:lobby": {"id":"synaxis.lobby.after-hours", "title":"Glass and Concrete", "once":false},
	"score:basement": {"id":"synaxis.basement.server-room", "title":"Below the Surface", "once":false},
}

static func context(arrival: bool, offboarding: bool, room: String, screen: String, stage: int) -> String:
	if arrival:
		return "score:arrival"
	if offboarding or (screen == "opening" and stage == 4):
		return "score:offboarding"
	if room == "SYNAXIS_BASEMENT":
		return "score:basement"
	if room in ["SYNAXIS_LOBBY", "SYNAXIS_OFFICE", "SYNAXIS_CARPET", "SYNAXIS_FACILITIES", "SYNAXIS_EXECUTIVE"]:
		return "score:lobby"
	return ""

static func cue_id(key: String) -> String:
	return str((CUES.get(key, {}) as Dictionary).get("id", ""))

static func one_shot(key: String) -> bool:
	return bool((CUES.get(key, {}) as Dictionary).get("once", false))

static func title_for(id: String) -> String:
	for key in CUES:
		if cue_id(key) == id:
			return str(CUES[key]["title"])
	return ""
