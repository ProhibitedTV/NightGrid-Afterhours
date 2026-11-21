extends RefCounted
## Shared visual language for the real game UI. No external fonts or textures.
## Palette is intentionally restrained so the city, not the HUD, owns the frame.
const INK = Color("101821")
const TEXT = Color("e7edf0")
const MUTED = Color("a4b5bf")
const ACCENT = Color("81e0d4")
const AMBER = Color("edbc83")
const DANGER = Color("f3958b")

static func card(alpha: float = 0.96, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	style.border_color = Color("354956")
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color("83929d"))
	t.set_stylebox("normal", "Button", button_style(Color("192730"), Color("344752")))
	t.set_stylebox("hover", "Button", button_style(Color("243940"), ACCENT))
	t.set_stylebox("pressed", "Button", button_style(ACCENT, ACCENT))
	t.set_stylebox("disabled", "Button", button_style(Color("172027"), Color("25343d")))
	var focus := button_style(Color(0, 0, 0, 0), ACCENT)
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("focus", "CheckButton", focus)
	t.set_stylebox("focus", "HSlider", focus)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_focus_color", "CheckButton", ACCENT)
	t.set_stylebox("panel", "PanelContainer", card())
	t.set_stylebox("separator", "HSeparator", button_style(Color("354956"), Color("354956")))
	return t
