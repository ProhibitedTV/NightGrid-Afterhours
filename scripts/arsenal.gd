extends RefCounted
## Fictional, arcade-balanced equipment state. All quantities are game units.
const IDS = ["holstered", "pulse", "arc"]
const SPECS = {
	"pulse": {"name": "VANTA PULSE", "capacity": 8, "reserve_max": 64, "damage": 18.0, "delay": 0.38, "reload": 1.25, "reach": 58.0},
	"arc": {"name": "COILBREAK ARC", "capacity": 4, "reserve_max": 32, "damage": 32.0, "delay": 0.76, "reload": 1.65, "reach": 34.0}
}
var equipped := "holstered"
var ammo := {"pulse": 8, "arc": 4}
var reserve := {"pulse": 32, "arc": 16}
var cooldown := 0.0
var reload_left := 0.0

func cycle() -> void:
	equipped = IDS[(IDS.find(equipped) + 1) % IDS.size()]
	reload_left = 0.0

func holster() -> void:
	equipped = "holstered"
	reload_left = 0.0

func spec() -> Dictionary:
	return SPECS.get(equipped, {})

func reload() -> bool:
	var s := spec()
	if s.is_empty() or reload_left > 0.0 or cooldown > 0.0:
		return false
	if int(ammo[equipped]) >= int(s["capacity"]) or int(reserve[equipped]) <= 0:
		return false
	reload_left = float(s["reload"])
	return true

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if reload_left <= 0.0:
		return
	reload_left = maxf(0.0, reload_left - delta)
	if reload_left <= 0.0 and not spec().is_empty():
		var transfer := mini(int(spec()["capacity"]) - int(ammo[equipped]), int(reserve[equipped]))
		ammo[equipped] = int(ammo[equipped]) + transfer
		reserve[equipped] = int(reserve[equipped]) - transfer

func discharge() -> bool:
	var s := spec()
	if s.is_empty() or cooldown > 0.0 or reload_left > 0.0 or int(ammo[equipped]) <= 0:
		return false
	ammo[equipped] = int(ammo[equipped]) - 1
	cooldown = float(s["delay"])
	return true

func status_text() -> String:
	if equipped == "holstered":
		return "HOLSTERED"
	return "%s\n%d / %d  •  %s" % [str(spec()["name"]), int(ammo[equipped]), int(reserve[equipped]),
		"RELOADING %.1fs" % reload_left if reload_left > 0.0 else ("EMPTY" if int(ammo[equipped]) == 0 else "READY")]

func inventory_text() -> String:
	return "VANTA PULSE  %d / %d   |   COILBREAK ARC  %d / %d" % [int(ammo["pulse"]), int(reserve["pulse"]), int(ammo["arc"]), int(reserve["arc"])]

func snapshot() -> Dictionary:
	return {"equipped": equipped, "ammo": ammo.duplicate(), "reserve": reserve.duplicate()}

func restore(value: Variant) -> void:
	equipped = "holstered"
	ammo = {"pulse": 8, "arc": 4}
	reserve = {"pulse": 32, "arc": 16}
	cooldown = 0.0
	reload_left = 0.0
	if not value is Dictionary:
		return
	# Always load holstered. Optional version-1 payload defaults for old saves.
	for id in SPECS:
		for key in ["ammo", "reserve"]:
			var group: Variant = value.get(key, {})
			if not group is Dictionary:
				continue
			var amount: Variant = group.get(id)
			if not (amount is int or amount is float) or not is_finite(float(amount)):
				continue
			if key == "ammo":
				ammo[id] = int(clampf(float(amount), 0.0, float(SPECS[id]["capacity"])))
			else:
				reserve[id] = int(clampf(float(amount), 0.0, float(SPECS[id]["reserve_max"])))
