extends RefCounted
## Session-owned progression wallet. The existing top-level save cash field
## is the single serialized balance; receipts are independent of city geometry.
const VERSION = 1
const MAX_CASH = 1000000000
const MAX_RECEIPTS = 4096
const MAX_ID_LENGTH = 96
const RoadCars = preload("res://scripts/road_car_catalog.gd")
const StarterHome = preload("res://scripts/starter_home.gd")
const Wardrobe = preload("res://scripts/wardrobe_catalog.gd")
const Economy = preload("res://scripts/economy.gd")
const Opening = preload("res://scripts/opening_story.gd")
var bitcoin_sats: int = 0
# 0 unknown, 1 introduced, 2 post-dismissal check-in completed.
var synaxis_contact: int = 0
const CAL_RECEIPT="street:compatibility_patch"
const CAL_REWARD=85
var cal_quest:int=0 # 0 offered, 1 accepted, 2 collected, 3 completed
const StreetCred=preload("res://scripts/street_cred.gd")
const Rhythm=preload("res://scripts/rhythm_rehearsal.gd")
const Instruments=preload("res://scripts/instrument_catalog.gd")
var _instruments:Dictionary={}
var sampler_practice:=0
var _street_cred=StreetCred.new()

var balance: int = 0
var _receipts: Dictionary = {}
var _owned_vehicles: Dictionary = {}
var home_supplies: int = 0
var home_storage_expanded := false
var home_tenancy_paid := false
var outfit_id := Wardrobe.DEFAULT
var _purchased_outfits: Dictionary = {}
var clothing_slots:Dictionary={}
const LOOK_IDS=["look_1","look_2","look_3"]
var _saved_looks:Dictionary={}
var _owned_pieces:Dictionary={}

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

func meet_synaxis_contact() -> bool:
	if synaxis_contact!=0:
		return false
	synaxis_contact=1
	return true

func complete_synaxis_checkin() -> bool:
	if synaxis_contact!=1 or not has_receipt(Opening.RECEIPT):
		return false
	synaxis_contact=2
	return true

func owns_vehicle(id: String) -> bool:
	return _owned_vehicles.has(id)

func owned_vehicle_ids() -> Array:
	var ids: Array = _owned_vehicles.keys()
	ids.sort()
	return ids

## Catalog owns price; caller cannot choose it. Validate before debit.
func buy_vehicle(id: String) -> bool:
	if not RoadCars.TITLES.has(id) or owns_vehicle(id):
		return false
	if not spend(RoadCars.title_price(id)):
		return false
	_owned_vehicles[id] = true
	return true

## Transfer title only after the catalog-derived credit succeeds.
func sell_vehicle(id: String, condition: float) -> bool:
	if not owns_vehicle(id):
		return false
	var amount := RoadCars.resale_price(id, condition)
	if amount <= 0 or not credit(amount):
		return false
	_owned_vehicles.erase(id)
	return true

func owns_home() -> bool:
	return home_tenancy_paid and has_receipt(StarterHome.ACCESS_RECEIPT)

func activate_home_tenancy() -> bool:
	if not has_receipt(StarterHome.ACCESS_RECEIPT) or home_tenancy_paid:
		return false
	if not spend(StarterHome.move_in_price()):
		return false
	home_tenancy_paid = true
	return true

func grant_starter_vehicle() -> bool:
	# Historical API retained for garage callers; now a paid title.
	return owns_home() and buy_vehicle("street:kestrel_01")

func owns_outfit(id: String) -> bool:
	return Wardrobe.valid_id(id) and (id == Wardrobe.DEFAULT or _purchased_outfits.has(id))

func purchased_outfit_ids() -> Array:
	var ids: Array = _purchased_outfits.keys()
	ids.sort()
	return ids

func exchange_bitcoin(buy: bool) -> bool:
	var gross := Economy.EXCHANGE_USD
	var fee := Economy.EXCHANGE_FEE_USD
	if buy:
		var received := Economy.sats_for_usd(gross-fee)
		if bitcoin_sats > Economy.MAX_SATS-received or not spend(gross):
			return false
		bitcoin_sats += received
	else:
		var paid := Economy.sats_for_usd(gross)
		if bitcoin_sats < paid or not credit(gross-fee):
			return false
		bitcoin_sats -= paid
	return true

func can_pay(usd: int, tender: String) -> bool:
	if usd <= 0:
		return false
	if tender == "USD":
		return balance >= usd
	return tender == "BTC" and bitcoin_sats >= Economy.sats_for_usd(usd)

func buy_outfit(id: String, tender: String = "USD", retail:bool=false) -> bool:
	if (not owns_home() and not retail) or not Wardrobe.valid_id(id) or owns_outfit(id):
		return false
	var price := Wardrobe.price(id)
	if not can_pay(price,tender):
		return false
	if tender == "BTC":
		bitcoin_sats -= Economy.sats_for_usd(price)
	else:
		balance -= price
	_purchased_outfits[id] = true
	return true

func select_outfit(id: String, retail:bool=false) -> bool:
	if (not owns_home() and not retail) or not owns_outfit(id):
		return false
	outfit_id = id
	clothing_slots.clear()
	return true

func owns_piece(id:String) -> bool:
	return Wardrobe.piece_valid(id) and _owned_pieces.has(id)

func buy_piece(id:String,tender:String="USD",retail:bool=false) -> bool:
	if (not owns_home() and not retail) or not Wardrobe.piece_valid(id) or owns_piece(id):
		return false
	var price:=Wardrobe.piece_price(id)
	if not can_pay(price,tender):
		return false
	if tender=="BTC":
		bitcoin_sats-=Economy.sats_for_usd(price)
	else:
		balance-=price
	_owned_pieces[id]=true
	return true

func select_piece(id:String,retail:bool=false) -> bool:
	if (not owns_home() and not retail) or not owns_piece(id):
		return false
	clothing_slots[Wardrobe.PIECES[id]["slot"]]=id
	return true

func clear_piece(slot:String,retail:bool=false) -> bool:
	if (not owns_home() and not retail) or slot not in Wardrobe.SLOTS:
		return false
	clothing_slots.erase(slot)
	return true

func saved_look(id:String) -> Dictionary:
	return (_saved_looks.get(id,{}) as Dictionary).duplicate(true)

func save_look(id:String,retail:bool=false) -> bool:
	if id not in LOOK_IDS or (not retail and not owns_home()) or not owns_outfit(outfit_id) or not Wardrobe.valid_slots(clothing_slots):
		return false
	for piece in clothing_slots.values():
		if not owns_piece(piece):
			return false
	_saved_looks[id]={"outfit":outfit_id,"slots":clothing_slots.duplicate()}
	return true

func equip_look(id:String,retail:bool=false) -> bool:
	if id not in LOOK_IDS or (not retail and not owns_home()):
		return false
	var look:=saved_look(id)
	if look.is_empty() or not owns_outfit(look["outfit"]) or not Wardrobe.valid_slots(look["slots"]):
		return false
	for piece in look["slots"].values():
		if not owns_piece(piece):
			return false
	outfit_id=look["outfit"]
	clothing_slots=look["slots"].duplicate()
	return true

func owned_piece_ids() -> Array:
	var ids:Array=_owned_pieces.keys()
	ids.sort()
	return ids

func home_capacity() -> int:
	return StarterHome.EXPANDED_STORAGE if home_storage_expanded else StarterHome.MAX_STORAGE

func expand_home_storage() -> bool:
	if not owns_home() or home_storage_expanded:
		return false
	if not spend(StarterHome.STORAGE_UPGRADE_PRICE):
		return false
	home_storage_expanded = true
	return true

# Return the number actually transferred; caller updates carried count once.
func deposit_supply(carried: int) -> int:
	if not owns_home() or carried <= 0 or home_supplies >= home_capacity():
		return 0
	home_supplies += 1
	return 1

func withdraw_supply(carried: int) -> int:
	if not owns_home() or carried >= 99 or carried < 0 or home_supplies <= 0:
		return 0
	home_supplies -= 1
	return 1

func accept_cal_quest()->bool:
	if cal_quest!=0 or has_receipt(CAL_RECEIPT):
		return false
	cal_quest=1
	return true

func collect_cal_gift()->bool:
	if cal_quest!=1:
		return false
	cal_quest=2
	return true

func complete_cal_quest()->bool:
	if cal_quest!=2 or not credit_once(CAL_RECEIPT,CAL_REWARD):
		return false
	cal_quest=3
	return true

func street_cred()->int:
	return _street_cred.total(_receipts)

func street_cred_rank()->Dictionary:
	return StreetCred.rank(street_cred())

func street_cred_summary()->String:
	return _street_cred.summary(_receipts)

func street_cred_sources()->Array[Dictionary]:
	return _street_cred.earned_sources(_receipts)

func street_activity_runs(source:String)->int:
	return _street_cred.completed_runs(source)

## Gameplay systems call this only after validating a completed activity.
func settle_street_activity(source:String,sequence:int)->bool:
	return _street_cred.settle_run(source,sequence)

## Atomic, catalog-priced repeatable set settlement. No caller-selected cash.
func settle_blue_hour_set(sequence:int)->bool:
	if not has_receipt("venue:soundcheck_pass") or balance>MAX_CASH-Rhythm.REWARD:
		return false
	if not _street_cred.settle_run("live_gig",sequence):
		return false
	balance+=Rhythm.REWARD
	return true

## The loaner street sampler has no contact or ownership prerequisite.
func settle_busking_set(sequence:int)->bool:
	if balance>MAX_CASH-Rhythm.BUSKING_REWARD or not _street_cred.settle_run("busking",sequence):
		return false
	balance+=Rhythm.BUSKING_REWARD
	return true

func owned_set_unlocked()->bool:
	return owns_instrument(Instruments.STARTER) and sampler_practice>=Instruments.OWNED_SET_PRACTICE

func settle_owned_sampler_set(sequence:int)->bool:
	if not owned_set_unlocked() or balance>MAX_CASH-Rhythm.OWNED_REWARD or not _street_cred.settle_run("busking",sequence):
		return false
	balance+=Rhythm.OWNED_REWARD
	return true

func owns_instrument(id:String)->bool:
	return Instruments.valid_id(id) and _instruments.has(id)

func buy_instrument(id:String)->bool:
	if not Instruments.valid_id(id) or owns_instrument(id) or not spend(Instruments.price(id)):
		return false
	_instruments[id]=true
	return true

func complete_sampler_practice(sequence:int)->bool:
	if not owns_instrument(Instruments.STARTER) or sequence!=sampler_practice+1 or sequence>Instruments.MAX_PRACTICE:
		return false
	sampler_practice=sequence
	return true

const BAND_MEMBERS={"rhea":{"name":"Rhea Vale","role":"Bass","site":"copper_cup","line":"I play low strings and keep time. Heard your opening set."},"milo":{"name":"Milo Static","role":"Synth","site":"dock_nine","line":"I have a battered synth and unfinished ideas. Let's make something weird."}}
var _band_members: Array[String] = []
const BAND_REHEARSALS_REQUIRED = 2
var band_rehearsals := 0

func band_rehearsal_available()->bool:
	return _band_members.size()==2 and band_rehearsals<BAND_REHEARSALS_REQUIRED

func complete_band_rehearsal(sequence:int)->bool:
	if not band_rehearsal_available() or sequence!=band_rehearsals+1:
		return false
	band_rehearsals=sequence
	return true

func band_recruit_available(id:String)->bool:
	return BAND_MEMBERS.has(id) and not _band_members.has(id) and owned_set_unlocked() and street_activity_runs("live_gig")>0 and has_receipt("venue:soundcheck_pass")

func recruit_band_member(id:String)->bool:
	if not band_recruit_available(id):
		return false
	_band_members.append(id)
	return true

func band_summary()->String:
	if _band_members.size()==2:
		return "UNSIGNED TRIO / Rhea Vale: bass / Milo Static: synth\n"+("REHEARSE AT COPPER CUP / %d of %d"%[band_rehearsals,BAND_REHEARSALS_REQUIRED] if band_rehearsal_available() else "TWO REHEARSALS COMPLETE / Ready for band booking")
	if not owned_set_unlocked() or street_activity_runs("live_gig")==0:
		return "BAND / Complete personal sampler practice and a Blue Hour opening set to meet collaborators."
	var names:Array[String]=[]
	for id in BAND_MEMBERS:
		if not _band_members.has(id):
			names.append(str(BAND_MEMBERS[id]["name"])+" at "+("Copper Cup" if id=="rhea" else "Dock Nine"))
	return "BAND / Meet "+", ".join(names)+" (%d/2 recruited)"%_band_members.size()

func instrument_summary()->String:
	if not owns_instrument(Instruments.STARTER):
		return "INSTRUMENT / Loaners available; PocketBeat M3 $40 at Copper Cup"
	var info:=Instruments.skill(sampler_practice)
	return "POCKETBEAT M3 / %s • %d practice sets"%[info["name"],sampler_practice]+(" / PERSONAL SET UNLOCKED" if owned_set_unlocked() else " / %d to personal set"%maxi(0,Instruments.OWNED_SET_PRACTICE-sampler_practice))

func snapshot() -> Dictionary:
	var ids: Array = _receipts.keys()
	ids.sort()
	var instruments:Array=_instruments.keys()
	instruments.sort()
	return {"version": VERSION, "receipts": ids, "owned_vehicles": owned_vehicle_ids(), "home_supplies":home_supplies, "home_storage_expanded":home_storage_expanded, "home_tenancy_paid":home_tenancy_paid, "outfit_id":outfit_id, "purchased_outfits":purchased_outfit_ids(), "owned_pieces":owned_piece_ids(), "clothing_slots":clothing_slots.duplicate(), "saved_looks":_saved_looks.duplicate(true), "bitcoin_sats":bitcoin_sats, "synaxis_contact":synaxis_contact, "cal_quest":cal_quest, "street_activity_runs":_street_cred.snapshot(), "instruments":instruments, "sampler_practice":sampler_practice,"band_members":_band_members.duplicate(),"band_rehearsals":band_rehearsals}

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
	var instruments:Variant=data.get("instruments",[])
	if not instruments is Array or instruments.size()>Instruments.ITEMS.size():
		return false
	var instrument_seen:Dictionary={}
	for id in instruments:
		if not Instruments.valid_id(id) or instrument_seen.has(id):
			return false
		instrument_seen[id]=true
	var practice:Variant=data.get("sampler_practice",0)
	if not valid_cash(practice) or int(practice)>Instruments.MAX_PRACTICE or (int(practice)>0 and not instrument_seen.has(Instruments.STARTER)):
		return false
	if not StreetCred.valid_runs(data.get("street_activity_runs",{})):
		return false
	var roster:Variant=data.get("band_members",[])
	if not roster is Array or roster.size()>BAND_MEMBERS.size():
		return false
	var roster_seen:Dictionary={}
	for id in roster:
		if not id is String or not BAND_MEMBERS.has(id) or roster_seen.has(id):
			return false
		roster_seen[id]=true
	if not roster.is_empty() and (int(practice)<Instruments.OWNED_SET_PRACTICE or not seen.has("venue:soundcheck_pass") or int(data.get("street_activity_runs",{}).get("live_gig",0))<1):
		return false
	var rehearsals:Variant=data.get("band_rehearsals",0)
	if not valid_cash(rehearsals) or int(rehearsals)>BAND_REHEARSALS_REQUIRED or (int(rehearsals)>0 and roster_seen.size()!=BAND_MEMBERS.size()):
		return false
	var cal:Variant=data.get("cal_quest",0)
	if not valid_cash(cal) or int(cal)>3 or (int(cal)==3)!=seen.has(CAL_RECEIPT):
		return false
	var contact: Variant = data.get("synaxis_contact",0)
	if not valid_cash(contact) or int(contact)>2 or (int(contact)==2 and not seen.has(Opening.RECEIPT)):
		return false
	# Older saves already granted residence access; grandfather it, not new missions.
	var tenancy: Variant = data.get("home_tenancy_paid",seen.has(StarterHome.ACCESS_RECEIPT))
	if not tenancy is bool or (tenancy and not seen.has(StarterHome.ACCESS_RECEIPT)):
		return false
	var sats: Variant = data.get("bitcoin_sats",0)
	if not (sats is int or sats is float) or not is_finite(float(sats)) or float(sats)<0 or float(sats)>Economy.MAX_SATS or floor(float(sats))!=float(sats):
		return false
	var purchased: Variant = data.get("purchased_outfits",[])
	if not purchased is Array or purchased.size() > Wardrobe.IDS.size():
		return false
	var closet: Dictionary = {}
	for id in purchased:
		if not Wardrobe.valid_id(id) or id == Wardrobe.DEFAULT or closet.has(id):
			return false
		closet[id] = true
	var outfit: Variant = data.get("outfit_id",Wardrobe.DEFAULT)
	if not Wardrobe.valid_id(outfit):
		return false
	if outfit != Wardrobe.DEFAULT and not closet.has(outfit):
		return false
	var pieces:Variant=data.get("owned_pieces",[])
	if not pieces is Array or pieces.size()>Wardrobe.PIECE_IDS.size():
		return false
	var owned_pieces:Dictionary={}
	for id in pieces:
		if not Wardrobe.piece_valid(id) or owned_pieces.has(id):
			return false
		owned_pieces[id]=true
	var slots:Variant=data.get("clothing_slots",{})
	if not Wardrobe.valid_slots(slots):
		return false
	for id in slots.values():
		if not owned_pieces.has(id):
			return false
	var looks:Variant=data.get("saved_looks",{})
	if not looks is Dictionary or looks.size()>LOOK_IDS.size():
		return false
	for id in looks:
		if id not in LOOK_IDS or not looks[id] is Dictionary:
			return false
		var look:Dictionary=looks[id]
		if look.size()!=2 or not Wardrobe.valid_id(look.get("outfit")) or not Wardrobe.valid_slots(look.get("slots")):
			return false
		if look["outfit"]!=Wardrobe.DEFAULT and not closet.has(look["outfit"]):
			return false
		for piece in look["slots"].values():
			if not owned_pieces.has(piece):
				return false
	var expanded: Variant = data.get("home_storage_expanded", false)
	if not expanded is bool or (expanded and not tenancy):
		return false
	var limit := StarterHome.EXPANDED_STORAGE if expanded else StarterHome.MAX_STORAGE
	var stored: Variant = data.get("home_supplies", 0)
	if not valid_cash(stored) or int(stored) > limit or (int(stored) > 0 and not tenancy):
		return false
	var owned: Variant = data.get("owned_vehicles", [])
	if not owned is Array or owned.size() > RoadCars.TITLES.size():
		return false
	seen.clear()
	for id in owned:
		if not valid_id(id) or not RoadCars.TITLES.has(id) or seen.has(id):
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
	var titles: Dictionary = {}
	for id in data.get("owned_vehicles", []):
		titles[id] = true
	balance = int(amount)
	_receipts = next
	home_tenancy_paid = data.get("home_tenancy_paid",next.has(StarterHome.ACCESS_RECEIPT))
	_owned_vehicles = titles
	home_supplies = int(data.get("home_supplies",0))
	home_storage_expanded = data.get("home_storage_expanded",false)
	outfit_id = data.get("outfit_id",Wardrobe.DEFAULT)
	bitcoin_sats = int(data.get("bitcoin_sats",0))
	synaxis_contact = int(data.get("synaxis_contact",0))
	clothing_slots=data.get("clothing_slots",{}).duplicate()
	_saved_looks=data.get("saved_looks",{}).duplicate(true)
	_owned_pieces.clear()
	for id in data.get("owned_pieces",[]):
		_owned_pieces[id]=true
	cal_quest=int(data.get("cal_quest",0))
	_street_cred.restore(data.get("street_activity_runs",{}))
	_instruments.clear()
	for id in data.get("instruments",[]):
		_instruments[id]=true
	sampler_practice=int(data.get("sampler_practice",0))
	_band_members.assign(data.get("band_members",[]))
	band_rehearsals=int(data.get("band_rehearsals",0))
	_purchased_outfits.clear()
	for id in data.get("purchased_outfits",[]):
		_purchased_outfits[id] = true
	return true
