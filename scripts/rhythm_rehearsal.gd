extends RefCounted
## Deterministic three-pad rehearsal. One input attempt per authored beat.
## Delta is elapsed real UI time, independent of paused world physics.
const PATTERNS=[[0,1,0,2,0,1,2,1,0,2,1,2],[0,2,1,0,1,2,0,0,2,1,2,0],[1,0,2,1,0,2,2,0,1,2,0,1]]
const BAND_PATTERNS=[[0,1,2,0,2,1,0,1,2,2,0,1,2,0,1,2],[2,0,1,2,0,0,1,2,1,0,2,1,1,2,0,2]]
const DEBUT_PATTERNS=[[0,1,2,0,2,1,0,0,1,2,1,0,2,1,2,0,1,0,2,2,1,0,1,2]]
const ENCORE_PATTERNS=[[0,2,1,0,1,2,0,2,0,1,2,1,0,2,1,2,0,1,0,2],[2,1,0,1,0,2,1,0,2,2,0,1,0,2,1,0,2,1,2,0]]
const SHOWCASE_PATTERNS=[[0,1,2,0,2,1,0,0,2,1,0,2,1,0,2,2,1,0,1,2,0,1,2,0,2,1,0,2,1,0,1,2]]
const BEAT=0.80
const LEAD=2.0
const WINDOW=0.23
const PASS_HITS=9
const REWARD=45
const BUSKING_REWARD=8
const OWNED_REWARD=14
const OWNED_PATTERNS=[[0,1,2,0,1,0,2,1,0,2],[1,0,2,1,2,0,1,0,2,1],[2,0,1,0,2,1,0,1,2,0]]
const BUSKING_PATTERNS=[[0,1,0,1,0,2,0,1],[0,2,0,1,0,2,1,0],[1,0,1,2,1,0,2,0]]
var mode:="live_gig"
var beat_seconds:=BEAT
var hit_window:=WINDOW
var required_hits:=PASS_HITS
var elapsed:=0.0
var hits:=0
var index:=0
var pattern:Array=[]
var finished:=false
var cancelled:=false
var consumed:=false
var feedback:="GET READY"

func start(sequence:int,source:String="live_gig")->void:
	mode=source if source in ["busking","practice","owned_busking","band_rehearsal","band_debut","band_encore","band_showcase"] else "live_gig"
	var band:=mode=="band_rehearsal"
	var debut:=mode=="band_debut"
	var encore:=mode=="band_encore"
	var showcase:=mode=="band_showcase"
	var street:=mode in ["busking","practice"]
	var owned:=mode=="owned_busking"
	var patterns:=SHOWCASE_PATTERNS if showcase else ENCORE_PATTERNS if encore else DEBUT_PATTERNS if debut else BAND_PATTERNS if band else (OWNED_PATTERNS if owned else (BUSKING_PATTERNS if street else PATTERNS))
	beat_seconds=0.60 if showcase else 0.67 if encore else 0.65 if debut else 0.72 if band else (0.85 if owned else (1.0 if street else BEAT))
	hit_window=0.16 if showcase else 0.19 if encore else 0.18 if debut else 0.20 if band else (0.25 if owned else (0.30 if street else WINDOW))
	required_hits=27 if showcase else 17 if encore else 20 if debut else 13 if band else (8 if owned else (6 if street else PASS_HITS))
	pattern=patterns[posmod(sequence-1,patterns.size())].duplicate()
	elapsed=0.0
	hits=0
	index=0
	finished=false
	cancelled=false
	consumed=false
	feedback="GET READY"

func target_time()->float:
	return LEAD+float(index)*beat_seconds

func advance(delta:float)->void:
	if finished or cancelled or pattern.is_empty() or not is_finite(delta) or delta<0.0:
		return
	elapsed+=delta
	while index<pattern.size() and elapsed>target_time()+hit_window:
		feedback="MISSED"
		index+=1
	finished=index>=pattern.size()

func strike(lane:int)->bool:
	if finished or cancelled or pattern.is_empty() or lane<0 or lane>2:
		return false
	var error:=elapsed-target_time()
	if absf(error)>hit_window:
		return false
	var hit:=lane==int(pattern[index])
	if hit:
		hits+=1
	feedback="ON BEAT" if hit else "WRONG PAD"
	index+=1
	finished=index>=pattern.size()
	return hit

func cancel()->void:
	cancelled=true

func passed()->bool:
	return finished and not cancelled and hits>=required_hits

func claim()->bool:
	if not passed() or consumed:
		return false
	consumed=true
	return true
