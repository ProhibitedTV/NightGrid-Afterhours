extends SceneTree
const Rhythm=preload("res://scripts/rhythm_rehearsal.gd")
const Ledger=preload("res://scripts/progression_ledger.gd")
const SceneRep=preload("res://scripts/scene_reputation.gd")
const Art=preload("res://scripts/instrument_art.gd")
const DEMOS=[preload("res://assets/audio/music/band_demo.wav"),preload("res://assets/audio/music/bass_demo.wav"),preload("res://assets/audio/music/busker_demo.wav"),preload("res://assets/audio/music/synth_demo.wav")]
func _initialize()->void:
	var rhythm:=Rhythm.new()
	rhythm.start(1)
	if rhythm.strike(0) or rhythm.claim():
		quit(1)
		return
	for lane in rhythm.pattern:
		rhythm.advance(rhythm.target_time()-rhythm.elapsed)
		if not rhythm.strike(lane) or rhythm.strike(lane):
			quit(1)
			return
	if not rhythm.passed() or not rhythm.claim() or rhythm.claim():
		quit(1)
		return
	rhythm.start(2)
	rhythm.advance(20.0)
	if rhythm.passed() or rhythm.claim():
		quit(1)
		return
	rhythm.start(3)
	rhythm.cancel()
	if rhythm.claim():
		quit(1)
		return
	rhythm.start(1,"busking")
	if rhythm.pattern.size()!=8 or rhythm.required_hits!=6 or rhythm.hit_window!=0.30:
		quit(1)
		return
	for lane in rhythm.pattern:
		rhythm.advance(rhythm.target_time()-rhythm.elapsed)
		rhythm.strike(lane)
	if not rhythm.claim() or rhythm.claim():
		quit(1)
		return
	var street:=Ledger.new()
	if not street.settle_busking_set(1) or street.settle_busking_set(1) or street.settle_busking_set(3) or street.balance!=8 or street.street_cred()!=4 or street.street_activity_runs("live_gig")!=0:
		quit(1)
		return
	var owner:=Ledger.new()
	owner.set_balance(39)
	if owner.buy_instrument("pocketbeat_m3") or owner.complete_sampler_practice(1):
		quit(1)
		return
	owner.set_balance(40)
	if not owner.buy_instrument("pocketbeat_m3") or owner.buy_instrument("pocketbeat_m3") or owner.balance!=0 or not owner.complete_sampler_practice(1) or owner.complete_sampler_practice(1) or owner.complete_sampler_practice(3) or owner.street_cred()!=0:
		quit(1)
		return
	var copy:=Ledger.new()
	if not copy.restore(0,JSON.parse_string(JSON.stringify(owner.snapshot()))) or not copy.owns_instrument("pocketbeat_m3") or copy.sampler_practice!=1:
		quit(1)
		return
	var invalid:=owner.snapshot()
	invalid["instruments"]=[]
	if copy.restore(999,invalid) or copy.balance!=0 or copy.sampler_practice!=1:
		quit(1)
		return
	rhythm.start(1,"practice")
	if rhythm.mode!="practice" or rhythm.pattern.size()!=8:
		quit(1)
		return
	if copy.owned_set_unlocked() or copy.settle_owned_sampler_set(1) or not copy.complete_sampler_practice(2) or not copy.complete_sampler_practice(3) or not copy.owned_set_unlocked():
		quit(1)
		return
	if not copy.settle_owned_sampler_set(1) or copy.settle_busking_set(1) or not copy.settle_busking_set(2) or copy.balance!=22 or copy.street_cred()!=8:
		quit(1)
		return
	rhythm.start(1,"owned_busking")
	if rhythm.pattern.size()!=10 or rhythm.required_hits!=8 or rhythm.hit_window!=0.25:
		quit(1)
		return
	var p:=Ledger.new()
	if p.settle_blue_hour_set(1):
		quit(1)
		return
	p.credit_once("venue:soundcheck_pass",125)
	if not p.settle_blue_hour_set(1) or p.settle_blue_hour_set(1) or p.settle_blue_hour_set(3) or p.balance!=170 or p.street_cred()!=42:
		quit(1)
		return
	var restored:=Ledger.new()
	if not restored.restore(p.balance,JSON.parse_string(JSON.stringify(p.snapshot()))) or restored.settle_blue_hour_set(1) or not restored.settle_blue_hour_set(2) or restored.street_activity_runs("live_gig")!=2:
		quit(1)
		return
	restored.set_balance(Ledger.MAX_CASH)
	if restored.settle_blue_hour_set(3) or restored.street_activity_runs("live_gig")!=2:
		quit(1)
		return
	# Reconciled asset library only; existing playable sampler stays unchanged.
	for id in Art.MODELS:
		var prop := Art.build(id)
		if prop.mesh == null or prop.mesh.get_surface_count() < 1 or prop.material_override != Art.material() or not prop.get_aabb().has_volume():
			prop.free()
			push_error("Missing or empty authored instrument: "+str(id))
			quit(1)
			return
		prop.free()
	for demo in DEMOS:
		if not demo is AudioStreamWAV or demo.get_length() < 1.0:
			push_error("Missing or empty authored music demo")
			quit(1)
			return
	var band:=Ledger.new()
	if band.recruit_band_member("rhea"):
		quit(1)
		return
	band.set_balance(40)
	band.buy_instrument("pocketbeat_m3")
	for n in range(1,4):
		band.complete_sampler_practice(n)
	band.credit_once("venue:soundcheck_pass",125)
	band.settle_blue_hour_set(1)
	var before:=band.balance
	var cred:=band.street_cred()
	if not band.recruit_band_member("rhea") or band.recruit_band_member("rhea") or band.recruit_band_member("unknown") or not band.recruit_band_member("milo") or band.balance!=before or band.street_cred()!=cred:
		quit(1)
		return
	var band_copy:=Ledger.new()
	if not band_copy.restore(before,JSON.parse_string(JSON.stringify(band.snapshot()))) or band_copy.band_recruit_available("milo") or not band_copy.band_summary().begins_with("UNSIGNED TRIO"):
		quit(1)
		return
	var bad:=band.snapshot()
	bad["band_members"]=["rhea","rhea"]
	if band_copy.restore(before,bad):
		quit(1)
		return
	if band.complete_band_rehearsal(2) or not band.band_rehearsal_available():
		quit(1)
		return
	rhythm.start(1,"band_rehearsal")
	if rhythm.pattern.size()!=16 or rhythm.required_hits!=13:
		quit(1)
		return
	for lane in rhythm.pattern:
		rhythm.advance(rhythm.target_time()-rhythm.elapsed)
		rhythm.strike(lane)
	if not rhythm.claim() or rhythm.claim() or not band.complete_band_rehearsal(1) or band.complete_band_rehearsal(1):
		quit(1)
		return
	if not band_copy.restore(before,JSON.parse_string(JSON.stringify(band.snapshot()))) or band_copy.band_rehearsals!=1 or not band_copy.complete_band_rehearsal(2) or band_copy.band_rehearsal_available() or band_copy.complete_band_rehearsal(3) or band_copy.balance!=before or band_copy.street_cred()!=cred:
		quit(1)
		return
	var impossible:=band_copy.snapshot()
	impossible["band_members"]=["rhea"]
	if Ledger.valid_snapshot(impossible):
		quit(1)
		return
	if band.band_debut_available() or not band_copy.band_debut_available():
		quit(1)
		return
	rhythm.start(1,"band_debut")
	if rhythm.pattern.size()!=24 or rhythm.required_hits!=20:
		quit(1)
		return
	for lane in rhythm.pattern:
		rhythm.advance(rhythm.target_time()-rhythm.elapsed)
		rhythm.strike(lane)
	if not rhythm.claim() or rhythm.claim():
		quit(1)
		return
	band_copy.set_balance(Ledger.MAX_CASH)
	if band_copy.settle_band_debut() or not band_copy.band_debut_available():
		quit(1)
		return
	band_copy.set_balance(before)
	if not band_copy.settle_band_debut() or band_copy.settle_band_debut() or band_copy.balance!=before+240 or band_copy.street_cred()!=cred+30:
		quit(1)
		return
	var debut_save:=band_copy.snapshot()
	if not band.restore(band_copy.balance,JSON.parse_string(JSON.stringify(debut_save))) or band.band_debut_available():
		quit(1)
		return
	debut_save["band_rehearsals"]=1
	if Ledger.valid_snapshot(debut_save):
		quit(1)
		return
	if not band.band_encore_available() or band.band_showcase_available() or band.settle_band_encore(2):
		quit(1)
		return
	for booking in [1,2]:
		rhythm.start(booking,"band_encore")
		if rhythm.pattern.size()!=20 or rhythm.required_hits!=17:
			quit(1)
			return
		for lane in rhythm.pattern:
			rhythm.advance(rhythm.target_time()-rhythm.elapsed)
			rhythm.strike(lane)
		if not rhythm.claim() or rhythm.claim() or not band.settle_band_encore(booking) or band.settle_band_encore(booking):
			quit(1)
			return
	if band.band_encore_available() or not band.band_showcase_available() or band.balance!=before+480 or band.street_cred()!=cred+54:
		quit(1)
		return
	rhythm.start(1,"band_showcase")
	if rhythm.pattern.size()!=32 or rhythm.required_hits!=27:
		quit(1)
		return
	for lane in rhythm.pattern:
		rhythm.advance(rhythm.target_time()-rhythm.elapsed)
		rhythm.strike(lane)
	if not rhythm.claim() or rhythm.claim() or not band.settle_band_showcase() or band.settle_band_showcase() or band.balance!=before+960 or band.street_cred()!=cred+99:
		quit(1)
		return
	var show_save:=band.snapshot()
	if not band_copy.restore(band.balance,JSON.parse_string(JSON.stringify(show_save))) or band_copy.band_showcase_available():
		quit(1)
		return
	show_save["street_activity_runs"]["band_encore"]=1
	if Ledger.valid_snapshot(show_save):
		quit(1)
		return
	var scene_wallet:=Ledger.new()
	var scores:=SceneRep.scores(scene_wallet)
	if scores!={"music":0,"community":0,"underground":0}:
		quit(1)
		return
	scene_wallet.set_balance(500)
	if SceneRep.scores(scene_wallet)!=scores:
		quit(1)
		return
	scene_wallet.credit_once("technical:crane_interlock",480)
	scene_wallet.credit_once("investigation:paper_city",1450)
	scene_wallet.settle_busking_set(1)
	var derived:=SceneRep.scores(scene_wallet)
	if derived!={"music":3,"community":12,"underground":40} or SceneRep.scores(band)["music"]!=78:
		quit(1)
		return
	var projection:=SceneRep.scores(scene_wallet)
	projection["music"]=100
	if SceneRep.scores(scene_wallet)!=derived:
		quit(1)
		return
	print("RHYTHM_REHEARSAL PASS: timing, cancellation, once-only claims, sequence and atomic payout")
	quit(0)
