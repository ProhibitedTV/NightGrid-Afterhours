extends RefCounted
## Deterministic three-pad rehearsal. One input attempt per authored beat.
## Delta is elapsed real UI time, independent of paused world physics.
const PATTERNS=[[0,1,0,2,0,1,2,1,0,2,1,2],[0,2,1,0,1,2,0,0,2,1,2,0],[1,0,2,1,0,2,2,0,1,2,0,1]]
const BEAT=0.80
const LEAD=2.0
const WINDOW=0.23
const PASS_HITS=9
const REWARD=45
var elapsed:=0.0
var hits:=0
var index:=0
var pattern:Array=[]
var finished:=false
var cancelled:=false
var consumed:=false
var feedback:="GET READY"

func start(sequence:int)->void:
	pattern=PATTERNS[posmod(sequence-1,PATTERNS.size())].duplicate()
	elapsed=0.0
	hits=0
	index=0
	finished=false
	cancelled=false
	consumed=false
	feedback="GET READY"

func target_time()->float:
	return LEAD+float(index)*BEAT

func advance(delta:float)->void:
	if finished or cancelled or pattern.is_empty() or not is_finite(delta) or delta<0.0:
		return
	elapsed+=delta
	while index<pattern.size() and elapsed>target_time()+WINDOW:
		feedback="MISSED"
		index+=1
	finished=index>=pattern.size()

func strike(lane:int)->bool:
	if finished or cancelled or pattern.is_empty() or lane<0 or lane>2:
		return false
	var error:=elapsed-target_time()
	if absf(error)>WINDOW:
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
	return finished and not cancelled and hits>=PASS_HITS

func claim()->bool:
	if not passed() or consumed:
		return false
	consumed=true
	return true
