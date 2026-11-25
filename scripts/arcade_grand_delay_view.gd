extends RefCounted
## Original cabinet UI. Drawn only for the selected driving game; no extra viewport.
const Track = preload("res://scripts/grand_delay_track.gd")
const Race = preload("res://scripts/grand_delay_race.gd")
const Art = preload("res://assets/arcade/grand_delay.svg")
const Marquee = preload("res://assets/arcade/grand_delay_marquee.svg")
const Car = preload("res://assets/arcade/grand_delay_car.svg")
const Scores = preload("res://scripts/arcade_scores.gd")
const INK = Color("0a1421")
const TEAL = Color("79efd4")
const GOLD = Color("ffce99")
const PINK = Color("ff8ca9")
const PAPER = Color("f0eadc")

func label(c: Control, message: String, x: float, y: float, color: Color, fs: int = 16) -> void:
	c.draw_string(ThemeDB.fallback_font,Vector2(x,y),message,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)

func panel(c: Control, rect: Rect2, color: Color, border: Color) -> void:
	c.draw_rect(rect,color)
	c.draw_rect(rect,border,false,1.0)

func render(c, visual_lane: float, button_pulse: float) -> void:
	c.draw_rect(Rect2(0,0,800,480),INK)
	c.draw_texture_rect(Marquee,Rect2(20,12,760,67),false)
	if c.state == "play":
		_drive(c)
	else:
		c.draw_texture_rect(Art,Rect2(33,92,220,275),false)
		panel(c,Rect2(270,92,497,275),Color("182738"),Color("425a67"))
		if c.state == "select":
			label(c,"THE EVENTUAL EDITION / OFFLINE BUILD 1.2",286,116,GOLD,16)
			label(c,"Three districts. Beat the checkpoint clock.",286,143,PAPER,16)
			label(c,"Hold UP to accelerate / DOWN to brake.",286,171,TEAL,18)
			label(c,"Collect 3 features for nitro. Avoid traffic.",286,195,PAPER,16)
			label(c,"LOCAL LEGENDS / NO GLOBAL SERVER",286,230,GOLD,15)
			var rows: Array = Scores.board("grand_delay",c.best)
			for i in range(rows.size()):
				var row: Array = rows[i]
				label(c,"%02d  %-8s  %06d" % [i+1,row[0],row[1]],286+(i%2)*225,258+floori(i/2.0)*27,TEAL if row[0]=="YOU" else PAPER,16)
			label(c,"ENTER / A  START",286,344,TEAL,19)
			if c.locked_cabinet.is_empty():
				label(c,"LEFT / RIGHT  CABINETS",505,344,PAPER,15)
		else:
			label(c,"GOLD MASTER / RANK "+c.round.grade() if c.round.result()["cleared"] else "RELEASE POSTPONED",286,142,TEAL if c.round.result()["cleared"] else PINK,27)
			label(c,"FINAL SCORE     %06d" % c.round.score,286,188,PAPER,24)
			label(c,"PERSONAL BEST  %06d" % int(c.best.get("grand_delay",0)),286,223,GOLD,20)
			label(c,"NEW LOCAL RECORD" if c.new_record else "THANK YOU FOR PLAYING",286,255,TEAL,19)
			label(c,"%04dm   %.1fs   %d features   %d near misses" % [int(c.round.distance),c.round.race_time,c.round.pickups,c.round.near_misses],286,289,PAPER,16)
			label(c,"COMBO %d / CONTACTS %d / DRIFTS %d" % [c.round.best_streak,c.round.collisions,c.round.drift_count],286,314,GOLD,15)
			label(c,"ENTER / A  REPLAY MENU",286,344,TEAL,19)
			if c.round.cleared:
				label(c,"S TARGET: 52s / CLEAN / 9+",510,344,GOLD,14)
			if c.round.splits.size()==3:
				label(c,"SPLITS  %.1f / %.1f / %.1f" % [c.round.splits[0],c.round.splits[1],c.round.splits[2]],286,365,PAPER,12)
	_deck(c,visual_lane if c.state == "play" else 1.0,button_pulse)

func _drive(c) -> void:
	var race = c.round
	var stage: int = race.district
	var phase: float = race.distance/38.0
	var skies = [Color("be677a"),Color("524571"),Color("263e69")]
	var skyline = [Color("332c47"),Color("242f4a"),Color("1b3147")]
	var ground = [Color("35424b"),Color("243345"),Color("203748")]
	panel(c,Rect2(20,91,760,276),Color("101d2b"),Color("41545e"))
	for i in range(12):
		var t = float(i)/11.0
		c.draw_rect(Rect2(22,93+i*9,756,10),Color("171a30").lerp(skies[stage],t))
	c.draw_circle(Vector2(400,151),40 if stage==0 else 23,Color("fac397") if stage==0 else Color("d1dded"))
	for side in [-1,1]:
		for i in range(11):
			var x: float = 400.0+float(side)*(58.0+i*31.0)
			var h: float = 21.0+float(posmod(i*37+int(side)*19+stage*31,61))
			c.draw_rect(Rect2(x-13,196-h,26,h),skyline[stage])
			for j in range(2):
				c.draw_rect(Rect2(x-8+j*11,201-h,4,9),Color("e6ab8a") if stage==0 else TEAL.darkened(.35))
			if stage==1 and i%3==0:
				c.draw_rect(Rect2(x-11,181-h,22,4),PINK)
	c.draw_rect(Rect2(22,180,756,185),ground[stage])
	# Draw far-to-near road bands; every object uses the same road projection.
	# The contact line is depth 1.0 and the foreground extends below the car.
	for i in range(32):
		var d0 = float(i)/32.0
		var d1 = float(i+1)/32.0
		var a = _perspective(race,-.52,d0)
		var b = _perspective(race,2.52,d0)
		var e = _perspective(race,-.52,d1)
		var g = _perspective(race,2.52,d1)
		var band = floori((race.distance+(1.0-d0)*Race.VIEW)/25.0)%2
		c.draw_colored_polygon(PackedVector2Array([a,b,g,e]),Color("293746") if band==0 else Color("303e4b"))
		for sign in [-1,1]:
			var edge = 1.0+sign*1.52
			c.draw_line(_perspective(race,edge,d0),_perspective(race,edge,d1),TEAL if band==0 else GOLD,3.0,true)
			if band==0:
				var mark = 1.0+sign*.5
				c.draw_line(_perspective(race,mark,d0),_perspective(race,mark,d1),Color("b1b9b0"),1.0+d0*2.0,true)
	c.draw_colored_polygon(PackedVector2Array([_perspective(race,-.52,1.0),_perspective(race,2.52,1.0),Vector2(748,365),Vector2(52,365)]),Color("293746"))
	for sign in [-1,1]:
		c.draw_line(_perspective(race,1.0+sign*1.52,1.0),Vector2(400+sign*348,365),TEAL,3.0,true)
		for n in range(6):
			var t = fposmod((float(n)+phase*.5)/6.0,1.0)
			var at = _perspective(race,1.0+sign*1.64,t)
			c.draw_line(at,at-Vector2(0,12+t*24),Color("819b9f"),1+t*2,true)
			c.draw_circle(at-Vector2(0,12+t*24),2+t*2,GOLD)
	var items: Array = race.objects.duplicate()
	items.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a["z"])>float(b["z"]))
	for item in items:
		var depth = 1.0-clampf((float(item["z"])-race.distance)/Race.VIEW,0.0,1.0)
		var at = _perspective(race,float(item["x"]),depth)
		var w = lerpf(8.0,94.0,depth*depth)
		var h = w*.38
		var kind: String = item["kind"]
		if kind=="traffic":
			var color = Color("a795e6") if int(item["velocity"])%3==0 else Color("f0bb83")
			c.draw_texture_rect(Car,Rect2(at-Vector2(w*.5,w*.60),Vector2(w,w*.60)),false,color)
		elif kind=="feature":
			var radius = w*.28
			c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius*1.6),at+Vector2(radius,0),at+Vector2(0,radius*.7),at+Vector2(-radius,0)]),TEAL.darkened(.4))
			c.draw_circle(at-Vector2(0,radius*.3),radius*.45,TEAL)
			if depth>.56:
				label(c,str(item["label"]),at.x-w*.45,at.y+14,TEAL,10)
		else:
			panel(c,Rect2(at-Vector2(w*.5,h),Vector2(w,h)),Color("582e43"),PINK)
			for n in range(3):
				c.draw_line(at+Vector2(-w*.42+n*w*.27,-h*.15),at+Vector2(-w*.24+n*w*.27,-h*.85),PINK,2,true)
			if depth>.56:
				label(c,str(item["label"]),at.x-w*.45,at.y-h-3,PINK,10)
	var pos = _perspective(race,race.position_x,1.0)
	if race.nitro_left>0.0:
		for i in range(8):
			var x = 35.0+i*102.0
			c.draw_line(Vector2(400+(x-400)*.58,210),Vector2(x,331),Color(TEAL,.27),2,true)
		c.draw_circle(pos-Vector2(35,5),7,TEAL)
		c.draw_circle(pos+Vector2(35,-5),7,TEAL)
	if race.drifting or race.shoulder:
		for i in range(5):
			var smoke = pos+Vector2(-29+i*14,2+sin(race.race_time*13+i)*4)
			c.draw_circle(smoke,4.0+i*.6,Color(.75,.81,.85,.28))
	if race.invulnerable<=0.0 or fmod(race.invulnerable,.16)<.08:
		c.draw_texture_rect(Car,Rect2(pos-Vector2(53,60),Vector2(106,63)),false)
	c.draw_rect(Rect2(22,93,756,46),INK)
	label(c,"SCORE %06d" % race.score,32,111,TEAL,16)
	label(c,"%03d KM/H" % int(race.speed*3.6),180,111,PAPER,16)
	label(c,"TIME %04.1f" % race.remaining,310,111,PINK if race.remaining<8 else GOLD,16)
	label(c,"LIVES %d" % race.lives,455,111,PAPER,16)
	label(c,"NITRO %d/3" % race.nitro_charge,610,111,TEAL,16)
	var pace: float = Track.pace_delta(race.distance,race.race_time)
	label(c,"%+.1fs PACE" % pace,180,130,TEAL if pace<=0 else GOLD,12)
	label(c,Race.DISTRICTS[stage],32,130,GOLD,13)
	c.draw_rect(Rect2(288,122,475,8),Color("344655"))
	c.draw_rect(Rect2(288,122,475*race.distance/Race.LENGTH,8),TEAL)
	for n in [1,2]:
		c.draw_rect(Rect2(288+475*n/3.0,120,2,12),GOLD)
	c.draw_rect(Rect2(22,337,756,28),INK)
	var hint: String = race.feedback if race.feedback_time>0 else Race.SUBTITLES[stage]
	if race.shoulder:
		hint = "SHOULDER / LIFT AND RETURN TO ROAD"
	elif race.drifting:
		hint = "DRIFT / %.1fs" % race.drift_time
	elif absf(Track.curvature(race.distance+110.0))>.35:
		hint = "BEND AHEAD / BRAKE + STEER TO DRIFT"
	label(c,hint,32,356,TEAL,15)
	label(c,"COMBO %02d" % race.streak,650,356,GOLD,14)
	if race.countdown>0.0:
		panel(c,Rect2(320,202,160,72),Color("12212f"),TEAL)
		label(c,"READY  %d" % ceili(race.countdown),339,246,PAPER,24)

func _perspective(race, lane: float, depth: float) -> Vector2:
	var t = depth*depth
	var ahead = (1.0-depth)*Race.VIEW
	var center = 400.0+Track.road_center(race.distance,ahead)
	var hill = (Track.height_at(race.distance+ahead)-Track.height_at(race.distance))*.65*(1.0-depth)
	return Vector2(center+(lane-1.0)*lerpf(31.0,205.0,t),lerpf(193.0,330.0,t)-hill)

func _deck(c: Control, lane: float, pulse: float) -> void:
	panel(c,Rect2(20,379,760,81),Color("1a2934"),Color("536973"))
	var center := Vector2(86,420)
	c.draw_circle(center,27,Color("08121d"))
	c.draw_arc(center,24,0,TAU,32,Color("788f97"),3,true)
	var angle := (lane-1.0)*.68
	for i in range(3):
		var v := Vector2(0,-20).rotated(angle+i*TAU/3.0)
		c.draw_line(center,center+v,TEAL,4,true)
	c.draw_circle(center,8,Color("b8c6c6"))
	var button := Vector2(173,420)
	c.draw_circle(button,23,Color("07111b"))
	c.draw_circle(button,17-pulse*3,GOLD.lerp(TEAL,pulse))
	label(c,"STEER",53,453,PAPER,12)
	label(c,"NITRO",152,453,PAPER,12)
	label(c,"LEFT / RIGHT STEER  •  UP / DOWN SPEED",220,409,PAPER,16)
	label(c,"ENTER / A  •  START / NITRO",220,436,TEAL,16)
	label(c,"ESC / B  BACK",618,436,GOLD,16)
