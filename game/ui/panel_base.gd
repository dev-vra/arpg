## Base dos painéis modais: centralizado, título e botão de fechar.
extends PanelContainer

const UiTheme = preload("res://game/ui/ui_theme.gd")
const ItemText = preload("res://game/ui/item_text.gd")

var hud
var body: VBoxContainer
var panel_size := Vector2(1180, 660)
const SLOT_ICONS := {"weapon": "broadsword", "shield": "round-shield", "helm": "visored-helm", "armor": "breastplate", "gloves": "gauntlet", "pants": "leg-armor", "boots": "boots"}


func _ready() -> void:
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


## Botão de item: borda na cor da raridade, slot, refino e marca de set.
func item_button(it: Dictionary, cb: Callable, selected: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 74)
	var col := Color(ItemText.rarity_color(it))
	var sb := UiTheme.frame("slot", 6, 14)
	sb.modulate_color = col if not selected else UiTheme.GOLD
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	var label: String = GameState.items_db["slots"][it["slot"]]["label"]
	b.icon = UiTheme.icon(SLOT_ICONS.get(it["slot"], "gems"))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_color_override("icon_normal_color", col.lightened(0.2))
	b.text = "%s%s\n%s" % [label, (" +%d" % int(it["refine"])) if int(it["refine"]) > 0 else "", "Set" if it.get("set_id", "") != "" else ("T%d" % _best_tier(it))]
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", col.lightened(0.3))
	b.pressed.connect(cb)
	return b


func _best_tier(it: Dictionary) -> int:
	var best := 5
	for l in it["affixes"]:
		best = mini(best, int(l["tier"]))
	return best
