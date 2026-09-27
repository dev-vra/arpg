## Tema da UI: painéis escuros translúcidos com acento dourado, fontes grandes para toque.
extends RefCounted

const BG := Color(0.07, 0.075, 0.095, 0.94)
const BORDER := Color("#3a3f4b")
const GOLD := Color("#d9a441")
const TEXT := Color("#e8e2d6")
const MUTED := Color("#8b8f99")


static func box(bg: Color, border: Color, radius: int = 10, border_w: int = 2, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


## Moldura 9-slice (Kenney Fantasy UI Borders, tingida) sobre fundo escuro.
static func frame(name: String, pad: int = 12, margin: int = 14) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/frames/%s.png" % name)
	s.set_texture_margin_all(margin)
	s.set_content_margin_all(pad)
	return s


static func icon(name: String) -> Texture2D:
	var p := "res://assets/ui/icons/%s.svg" % name
	return load(p) if ResourceLoader.exists(p) else null


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("panel", "Panel", frame("panel", 14, 16))
	t.set_stylebox("panel", "PanelContainer", frame("panel", 16, 16))
	t.set_stylebox("normal", "Button", frame("button", 8, 12))
	t.set_stylebox("hover", "Button", frame("button_hover", 8, 12))
	t.set_stylebox("pressed", "Button", frame("button_pressed", 8, 12))
	t.set_stylebox("disabled", "Button", box(Color("#17191e"), Color("#2a2d34"), 8, 2, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.6), Color("#2a2d34"), 6, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(Color("#c0392b"), Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", box(BG, GOLD, 8))
	return t


static func bar(color: Color) -> StyleBoxFlat:
	return box(color, Color(0, 0, 0, 0), 6, 0, 0)


static func title(text: String, size: int = 26) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(cb)
	return b


## Botão só de ícone (HUD), com dica e selo opcional de contagem.
static func icon_button(icon_name: String, tip: String, cb: Callable, size: int = 60) -> Button:
	var b := Button.new()
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_constant_override("icon_max_width", size - 18)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("icon_normal_color", Color("#e8dcc0"))
	b.add_theme_color_override("icon_hover_color", Color("#ffd166"))
	b.pressed.connect(cb)
	return b
