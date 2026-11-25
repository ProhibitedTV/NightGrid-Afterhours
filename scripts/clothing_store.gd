extends RefCounted
## Fixed public retail parcel. Ownership uses the existing wardrobe ledger.
const ID="vesper_threadline"
const NAME="THREADLINE"
const BLOCK=Vector2i(-3,-2)
const LOT=1
const COUNTER=Vector3(-2.25,1.15,2.8)
const Plan=preload("res://scripts/world_plan.gd")
static func entry() -> Vector3:
	return Vector3((BLOCK.x+.5)*58.0+10.5,1.15,(BLOCK.y+.5)*58.0-Plan.PUBLIC_FACADE_SETBACK-1.5)
