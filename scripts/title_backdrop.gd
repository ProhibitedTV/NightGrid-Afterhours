extends Control
## Original editorial title artwork, not a representation of the actual map.
## No scene capture, textures, shaders, lights, or per-frame node allocations.
var motion_enabled := true
var phase := 0.0
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_processing)
	_sync_processing()

func _sync_processing() -> void:
	set_process(motion_enabled and is_visible_in_tree())

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.05:
		return
	phase = fmod(phase + minf(_elapsed, 0.15), 120.0)
	_elapsed = 0.0
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1600, 900))
	draw_rect(Rect2(0, 0, 1600, 900), Color("111622"))
	# Ink-and-paper color fields, with a muted sunset behind industrial roofs.
	for band in range(18):
		var fraction := float(band) / 17.0
		draw_rect(Rect2(0, band * 50.0, 1600, 51), Color("171825").lerp(Color("432a40"), fraction))
	draw_circle(Vector2(1200, 348), 182, Color("ad6b78"))
	for i in range(7):
		draw_rect(Rect2(1018, 398 + i * 17, 364, 5 + i * 2), Color("3f2a3e"))
	# Two depth planes, fixed graphic compositions, no runtime city generation.
	_rooftops(0, 555, 26, Color("302738"), false)
	_rooftops(28, 665, 19, Color("171d29"), true)
	draw_rect(Rect2(0, 665, 1600, 235), Color("101722"))
	# Elevated industrial viaduct and the reflections of its cyan edge.
	draw_rect(Rect2(0, 625, 1600, 13), Color("0c121a"))
	draw_line(Vector2(0, 629), Vector2(1600, 629), Color("4e8589"), 2.0)
	for i in range(9):
		var x := 40.0 + float(i) * 190.0
		draw_rect(Rect2(x, 638, 13, 64), Color("131a24"))
		draw_line(Vector2(x + 6, 704), Vector2(x - 22, 896), Color(0.31, 0.58, 0.59, 0.12), 7)
	for i in range(38):
		var x := float((i * 137 + 31) % 1600)
		var y := 685.0 + float((i * 59) % 215)
		draw_line(Vector2(x, y), Vector2(x + 26 + i % 7 * 12, y), Color(0.70, 0.34, 0.48, 0.14), 2)
	# Slow, sparse rain. No flashing or high-contrast animation.
	for i in range(68):
		var x := fposmod(float(i * 139) - phase * 12.0, 1660.0) - 30.0
		var y := fposmod(float(i * 193) + phase * (36.0 + float(i % 4) * 9.0), 940.0) - 20.0
		draw_line(Vector2(x, y), Vector2(x - 7, y + 25), Color(0.68, 0.78, 0.82, 0.10), 1.2)
	# A graphic frame and record-sleeve catalog typography, visible at wide sizes.
	draw_rect(Rect2(28, 28, 1544, 844), Color(0.79, 0.66, 0.66, 0.18), false, 1.5)
	if size.x >= 1100.0:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(940, 88), "MORROW BAY  /  NIGHT SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("d4b4b7"))
		draw_string(font, Vector2(940, 794), "AFTER DARK.  STILL ALIVE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 31, Color("e7d7cc"))
		draw_string(font, Vector2(940, 832), "BITRIVER GAMING  //  MORROW BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("81b5b4"))

func _rooftops(offset: int, baseline: int, count: int, tint: Color, windows: bool) -> void:
	var step := 1600.0 / float(count)
	for i in range(count):
		var x := float(i) * step - 5.0
		var height := float(78 + ((i + offset) * 73 % 228))
		var width := step - 4.0
		draw_rect(Rect2(x, baseline - height, width, height), tint)
		draw_rect(Rect2(x + width * 0.21, baseline - height - 10, width * 0.58, 11), tint)
		if i % 4 == 0:
			draw_line(Vector2(x + width * 0.48, baseline - height - 10), Vector2(x + width * 0.48, baseline - height - 32), tint, 3)
		if windows:
			for floor_index in range(1, int(height / 20.0)):
				for column in range(2):
					if (i * 7 + floor_index * 3 + column) % 5 < 2:
						var light := Color("9f7770") if i % 3 == 0 else Color("4a777e")
						draw_rect(Rect2(x + 9 + column * 24, baseline - floor_index * 20, 10, 4), light)
