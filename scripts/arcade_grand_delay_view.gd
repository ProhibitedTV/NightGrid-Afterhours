extends RefCounted
## Original cabinet UI. Drawn only for the selected driving game; no extra viewport.
const Art = preload("res://assets/arcade/grand_delay.svg")
const Marquee = preload("res://assets/arcade/grand_delay_marquee.svg")
const Car = preload("res://assets/arcade/grand_delay_car.svg")
const Scores = preload("res://scripts/arcade_scores.gd")
const INK := Color("0a1421")
const TEAL := Color("79efd4")
const GOLD := Color("ffce99")
const PINK := Color("ff8ca9")
const PAPER := Color("f0eadc")

func label(c: Control, message: String, x: float, y: float, color: Color, fs: int = 16) -> void:
	c.draw_string(ThemeDB.fallback_font,Vector2(x,y),message,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)

func panel(c: Control, rect: Rect2, color: Color, border: Color) -> void:
	c.draw_rect(rect,color)
	c.draw_rect(rect,border,false,1.0)

func render(c: Control, fraction: float, visual_lane: float, button_pulse: float) -> void:
	c.draw_rect(Rect2(0,0,800,480),INK)
	c.draw_texture_rect(Marquee,Rect2(20,12,760,67),false)
	if c.state == "play":
		_drive(c,fraction,visual_lane)
	else:
		c.draw_texture_rect(Art,Rect2(33,92,220,275),false)
		panel(c,Rect2(270,92,497,275),Color("182738"),Color("425a67"))
		if c.state == "select":
			label(c,"THE EVENTUAL EDITION / OFFLINE BUILD 1.0",286,116,GOLD,16)
			label(c,"All features included. Radical, we know.",286,143,PAPER,16)
			label(c,"Collect features. Avoid paywalls.",286,171,TEAL,18)
			label(c,"Three features charge nitro. A / Enter to use.",286,195,PAPER,16)
			label(c,"LOCAL LEGENDS / NO GLOBAL SERVER",286,230,GOLD,15)
			var rows: Array = Scores.board("grand_delay",c.best)
			for i in range(rows.size()):
				var row: Array = rows[i]
				label(c,"%02d  %-8s  %06d" % [i+1,row[0],row[1]],286+(i%2)*225,258+floori(i/2.0)*27,TEAL if row[0]=="YOU" else PAPER,16)
			label(c,"ENTER / A  START",286,344,TEAL,19)
			if c.locked_cabinet.is_empty():
				label(c,"LEFT / RIGHT  CABINETS",505,344,PAPER,15)
		else:
			label(c,"GOLD MASTER!" if c.round.result()["cleared"] else "RELEASE POSTPONED",286,142,TEAL if c.round.result()["cleared"] else PINK,30)
			label(c,"FINAL SCORE     %06d" % c.round.score,286,188,PAPER,24)
			label(c,"PERSONAL BEST  %06d" % int(c.best.get("grand_delay",0)),286,223,GOLD,20)
			label(c,"NEW LOCAL RECORD" if c.new_record else "THANK YOU FOR PLAYING",286,255,TEAL,19)
			label(c,"No sequel required. No season expires.",286,289,PAPER,16)
			label(c,"ENTER / A  REPLAY MENU",286,344,TEAL,19)
	_deck(c,visual_lane if c.state == "play" else 1.0,button_pulse)

func _drive(c: Control, fraction: float, visual_lane: float) -> void:
	var round = c.round
	var phase := float(round.step)+fraction
	panel(c,Rect2(20,91,760,276),Color("101d2b"),Color("41545e"))
	var sky := Color("241d3b")
	for i in range(12):
		var t := float(i)/11.0
		c.draw_rect(Rect2(22,93+i*9,756,10),sky.lerp(Color("c56b79"),t))
	c.draw_circle(Vector2(400,155),47,Color("fac397"))
	for side in [-1,1]:
		for i in range(11):
			var x := 400.0 + side*(58.0+i*31.0)
			var h := 21.0+float(posmod(i*37+side*19,61))
			var r := Rect2(x-13,196-h,26,h)
			c.draw_rect(r,Color("202c44"))
			for j in range(2):
				c.draw_rect(Rect2(x-8+j*11,201-h,4,9),Color("e6ab8a"))
	c.draw_rect(Rect2(22,196,756,169),Color("192a38"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(352,193),Vector2(448,193),Vector2(715,365),Vector2(85,365)]),Color("293746"))
	for sign in [-1,1]:
		c.draw_line(Vector2(400+sign*48,193),Vector2(400+sign*315,365),TEAL,3.0,true)
		for n in range(9):
			var t := fposmod((float(n)+phase*.47)/9.0,1.0)
			var t2 := minf(t+.045,1.0)
			var start := _perspective(1.0+sign*.5,t)
			var finish := _perspective(1.0+sign*.5,t2)
			c.draw_line(start,finish,Color("b1b9b0"),1.0+t*2.0,true)
	for item in round.objects:
		var depth := clampf((float(item["row"])+fraction)/5.0,0.0,1.0)
		var at := _perspective(float(item["lane"]),depth)
		var w := lerpf(18.0,108.0,depth)
		var h := lerpf(8.0,28.0,depth)
		var good: bool = item["kind"] == "feature"
		var tint := TEAL if good else PINK
		var box := Rect2(at-Vector2(w*.5,h*.5),Vector2(w,h))
		panel(c,box,Color("183e3c") if good else Color("582e43"),tint)
		if depth > .46:
			label(c,str(item.get("label","")),at.x-w*.43,at.y+4,tint,10)
		else:
			label(c,"+" if good else "$",at.x-3,at.y+4,tint,10)
	var pos := _perspective(visual_lane,1.0)
	if round.nitro_ticks > 0:
		for i in range(3):
			c.draw_line(pos+Vector2(-40+i*40,-10),pos+Vector2(-53+i*53,14),TEAL,4.0,true)
	c.draw_texture_rect(Car,Rect2(pos-Vector2(53,60),Vector2(106,63)),false)
	c.draw_rect(Rect2(22,93,756,31),Color("0a1421"))
	label(c,"SCORE %06d" % round.score,32,114,TEAL,16)
	label(c,"LIVES %d   /   BUILD %02d/32" % [round.lives,round.step],245,114,PAPER,16)
	label(c,"NITRO %d/3" % round.nitro_charge,603,114,GOLD,16)
	c.draw_rect(Rect2(22,337,756,28),Color("0a1421"))
	label(c,round.feedback,32,356,TEAL if round.lives>1 else PINK,15)
	label(c,"STREAK %02d" % round.streak,650,356,GOLD,14)

func _perspective(lane: float, depth: float) -> Vector2:
	var t := depth*depth
	return Vector2(400+(lane-1.0)*lerpf(31.0,205.0,t),lerpf(193.0,330.0,t))

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
	label(c,"LEFT / RIGHT  •  D-PAD",220,409,PAPER,16)
	label(c,"ENTER / A  •  START / NITRO",220,436,TEAL,16)
	label(c,"ESC / B  BACK",618,436,GOLD,16)
