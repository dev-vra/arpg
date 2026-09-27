## Base dos painéis modais: centralizado, título e botão de fechar.
extends PanelContainer

const UiTheme = preload("res://game/ui/ui_theme.gd")
const ItemText = preload("res://game/ui/item_text.gd")
const GearLook = preload("res://game/actors/gear_look.gd")

var hud
var body: VBoxContainer
var panel_size := Vector2(1180, 660)
const SLOT_ICONS := {"weapon": "broadsword", "shield": "round-shield", "helm": "visored-helm", "armor": "breastplate", "gloves": "gauntlet", "pants": "leg-armor", "boots": "boots"}


var _pending := {}   # chave da miniatura -> botões esperando


func _on_thumb(key: String, tex: Texture2D) -> void:
	for b in _pending.get(key, []):
		if is_instance_valid(b):
			b.icon = tex
	_pending.erase(key)


func _ready() -> void:
	Thumbs.thumb_ready.connect(_on_thumb)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := UiTheme.title(title())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiTheme.button("Fechar", func(): hud.close_panel(), 110))
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)
	build()
	var vp := get_viewport().get_visible_rect().size
	var s := Vector2(minf(panel_size.x, vp.x - 24), minf(panel_size.y, vp.y - 24))
	custom_minimum_size = s
	size = s
	position = (vp - s) / 2.0


func title() -> String:
	return ""


func build() -> void:
	pass


func rich(text: String = "", min_h: int = 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = text
	r.fit_content = min_h == 0
	r.custom_minimum_size = Vector2(0, min_h)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 19)
	return r


func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func scroll(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	return sc


## Botão de item: miniatura 3D da peça (gerada e guardada em cache pelo Thumbs),
## moldura na cor da raridade e o refino no canto.
func item_button(it: Dictionary, cb: Callable, selected: bool = false, px: int = 96) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	var col := Color(ItemText.rarity_color(it))
	var sb := UiTheme.frame("slot", 4, 14)
	sb.modulate_color = col if not selected else UiTheme.GOLD
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", px - 14)
	var tex: Texture2D = Thumbs.get_thumb(it)
	b.icon = tex if tex else Thumbs.fallback(it["slot"])
	if tex == null:
		var key := GearLook.thumb_key(it)
		if not _pending.has(key):
			_pending[key] = []
		_pending[key].append(b)
	b.text = ("+%d" % int(it["refine"])) if int(it["refine"]) > 0 else ""
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color("#ffd166"))
	b.tooltip_text = it.get("name", "")
	b.pressed.connect(cb)
	return b


func _best_tier(it: Dictionary) -> int:
	var best := 5
	for l in it["affixes"]:
		best = mini(best, int(l["tier"]))
	return best
