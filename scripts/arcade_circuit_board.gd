extends Control
## Read-only scorecard; the normal save owns all progress. No extra rewards or timer.
const Scores = preload("res://scripts/arcade_scores.gd")
const Catalog = preload("res://scripts/arcade_round.gd")
signal exit_requested
var rows: Array = []
var count := 0

func configure(scores: Dictionary) -> void:
	var clean := Scores.normalized(scores)
	rows = Scores.circuit_rows(clean)
	count = Scores.circuit_count(clean)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()

func _line(message: String, at: Vector2, tint: Color, font_size: int = 20) -> void:
	draw_string(ThemeDB.fallback_font,at,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("141a24"))
	var factor := minf(size.x/800.0,size.y/480.0)
	if factor <= 0.0:
		return
	draw_set_transform((size-Vector2(800,480)*factor)*.5,0,Vector2.ONE*factor)
	var accent := Color("e9c283")
	_line("INSERT COIN / ROOK'S NEIGHBORHOOD CIRCUIT",Vector2(25,38),accent,24)
	_line("Eight challenges. No subscription. No deadline.",Vector2(25,65),Color.WHITE,17)
	_line("STAMPS %d / %d" % [count,Scores.CIRCUIT.size()],Vector2(25,93),accent,20)
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var at := Vector2(25+(i%2)*380,112+floori(float(i)/2.0)*72)
		var tint := Color("69d8c2") if row["earned"] else Color("9aa7b5")
		draw_rect(Rect2(at,Vector2(365,64)),Color("25313c"))
		draw_rect(Rect2(at+Vector2(7,8),Vector2(15,15)),tint,false,2.0)
		if row["earned"]:
			draw_line(at+Vector2(9,15),at+Vector2(13,20),tint,2)
			draw_line(at+Vector2(13,20),at+Vector2(20,10),tint,2)
		_line(str(row["title"])+" / "+str(row["rival"]),at+Vector2(30,22),tint,16)
		_line(str(Catalog.GAMES[row["id"]]["title"]),at+Vector2(9,41),Color.WHITE,13)
		_line("%05d / %05d" % [row["best"],row["goal"]],at+Vector2(9,57),tint,14)
	_line("LOCAL LEGEND — the neighborhood salutes you." if count == Scores.CIRCUIT.size() else "Every finished run counts. Play what you love.",Vector2(25,431),accent,17)
	_line("ENTER / A OR ESC / B  RETURN TO ARCADE",Vector2(25,460),Color.WHITE,15)
