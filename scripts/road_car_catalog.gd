extends RefCounted
## Fixed models at the existing twelve parking addresses and v1 save indices.

const R9 = "cinder_r9"
# Stable individual IDs, aligned with permanent parking roster. Never renumber.
const PARKED_IDS = [
	"street:kestrel_01", "street:kestrel_02", "street:cinder_01",
	"street:kestrel_03", "street:kestrel_04", "street:kestrel_05",
	"street:cinder_02", "street:kestrel_06", "street:cinder_03",
	"street:kestrel_07", "street:kestrel_08", "street:kestrel_09"
]
# Two pilot titles only; more stock and garage access follow #278/#280.
const TITLES = {
	"street:kestrel_01": {"name":"Kestrel S6","price":500},
	"street:cinder_01": {"name":"Cinder R9","price":2500}
}
const R9_PAID_PARKING_SLOTS = {2: Color("9c2338"), 6: Color("27374d"), 8: Color("aca251")}
const DATA = {
	R9: {"name": "Cinder R9", "top": 79.0, "accel": 13.7, "brake": 17.5, "turn": 1.73,
		"grip": 14.5, "mass": 1460.0, "body": Vector3(2.03, 1.31, 4.66), "tire": 0.358,
		"axles": Vector2(-1.43, 1.44), "track": 0.858, "seat": Vector3(-0.41, -0.91, -0.26)},
}
