extends RefCounted
## Session-owned progression wallet. The existing top-level save cash field
## is the single serialized balance; receipts are independent of city geometry.
const VERSION := 1
const MAX_CASH := 1000000000
const MAX_RECEIPTS := 4096
const MAX_ID_LENGTH := 96

var balance: int = 0
var _receipts: Dictionary = {}

static func valid_cash(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var n := float(value)
	return is_finite(n) and n >= 0.0 and n <= float(MAX_CASH) and floor(n) == n

static func valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var id: String = value
	if id.is_empty() or id.length() > MAX_ID_LENGTH:
		return false
	for i in range(id.length()):
		var c := id.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 65 and c <= 90) or (c >= 48 and c <= 57) or c in [45, 46, 58, 95]):
			return false
	return true

func set_balance(amount: int) -> void:
	balance = clampi(amount, 0, MAX_CASH)

func credit(amount: int) -> bool:
	if amount <= 0 or amount > MAX_CASH - balance:
		return false
	balance += amount
	return true

func spend(amount: int) -> bool:
	if amount < 0 or amount > balance:
		return false
	balance -= amount
	return true

func charge_up_to(amount: int) -> void:
	if amount > 0:
		balance -= mini(balance, amount)

func has_receipt(id: String) -> bool:
	return _receipts.has(id)

## Idempotent one-time payout. All checks precede both state changes.
## Repeatable jobs should use a monotonic counter, not an unbounded receipt per run.
func credit_once(id: String, amount: int) -> bool:
	if not valid_id(id) or has_receipt(id) or _receipts.size() >= MAX_RECEIPTS:
		return false
	if not credit(amount):
		return false
	_receipts[id] = true
	return true

func snapshot() -> Dictionary:
	var ids: Array = _receipts.keys()
	ids.sort()
	return {"version": VERSION, "receipts": ids}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var version: Variant = data.get("version")
	if not valid_cash(version) or int(version) != VERSION:
		return false
	var raw: Variant = data.get("receipts")
	if not raw is Array or raw.size() > MAX_RECEIPTS:
		return false
	var seen: Dictionary = {}
	for id in raw:
		if not valid_id(id) or seen.has(id):
			return false
		seen[id] = true
	return true

## Validate first, then replace state as a unit. Empty optional data is only
## used by callers for the pre-ledger format, never for an unknown version.
func restore(amount: Variant, data: Variant) -> bool:
	if not valid_cash(amount) or not valid_snapshot(data):
		return false
	var next: Dictionary = {}
	for id in data["receipts"]:
		next[id] = true
	balance = int(amount)
	_receipts = next
	return true
