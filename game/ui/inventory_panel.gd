## Mochila: equipados à esquerda com atributos, grade de itens no meio,
## detalhes e ações (equipar, reciclar) à direita, com diferença de poder.
extends "res://game/ui/panel_base.gd"

const Stats = preload("res://core/stats.gd")
const SLOT_ORDER := ["weapon", "shield", "helm", "armor", "gloves", "pants", "boots"]

var selected: Dictionary = {}
var cols: HBoxContainer


func title() -> String:
	return "Mochila"


func build() -> void:
	cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	body.add_child(cols)
	GameState.changed.connect(_render)
	_render()


func _render() -> void:
	if cols == null:
		return
	clear(cols)
	# Equipados + atributos
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	var grid_eq := GridContainer.new()
	grid_eq.columns = 2
	left.add_child(grid_eq)
	for slot in SLOT_ORDER:
		if GameState.equipped.has(slot):
			var it: Dictionary = GameState.equipped[slot]
			grid_eq.add_child(item_button(it, func(): _select(it), selected == it))
		else:
			var b := Button.new()
			b.text = GameState.items_db["slots"][slot]["label"] + "\n—"
			b.custom_minimum_size = Vector2(118, 74)
			b.disabled = true
			grid_eq.add_child(b)
	left.add_child(scroll(rich(ItemText.stats_block(GameState.stats))))
	# Grade
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var head := HBoxContainer.new()
	mid.add_child(head)
	var cnt := Label.new()
	cnt.text = "%d / %d itens" % [GameState.inventory.size(), GameState.INVENTORY_SIZE]
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cnt)
	head.add_child(UiTheme.button("Reciclar comuns", _salvage_commons, 190))
	var grid := GridContainer.new()
	grid.columns = 4
	for it in GameState.inventory:
		grid.add_child(item_button(it, func(): _select(it), selected == it))
	mid.add_child(scroll(grid))
	# Detalhe
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	cols.add_child(right)
	if selected.is_empty():
		right.add_child(rich("[color=#8b8f99]Toque em um item para ver detalhes.[/color]"))
		return
	right.add_child(scroll(rich(ItemText.bbcode(selected) + _delta_text())))
	var actions := HBoxContainer.new()
	right.add_child(actions)
	var is_eq: bool = GameState.equipped.get(selected["slot"]) == selected
	if is_eq:
		actions.add_child(UiTheme.button("Desequipar", func(): GameState.unequip(selected["slot"]), 150))
	else:
		actions.add_child(UiTheme.button("Equipar", func(): GameState.equip(selected), 130))
		actions.add_child(UiTheme.button("Reciclar", _salvage_selected, 130))


func _select(it: Dictionary) -> void:
	selected = it
	_render()


func _delta_text() -> String:
	if GameState.equipped.get(selected["slot"]) == selected:
		return ""
	var eq := GameState.equipped.duplicate()
	eq[selected["slot"]] = selected
	var p := Stats.power(Stats.compute(GameState.character.level, eq.values(), GameState.items_db, GameState.sets_db))
	var d := p - GameState.power()
	return "\n[b]Poder se equipar: [color=%s]%s%d[/color][/b]" % ["#3fd67a" if d >= 0 else "#ff6b6b", "+" if d >= 0 else "", d]


func _salvage_selected() -> void:
	var v := GameState.salvage(selected)
	GameState.toast.emit("Reciclado: +%d Zen%s" % [v.get("zen", 0), (" +%d Lume" % v["lume"]) if v.has("lume") else ""], Color("#ffd54f"))
	selected = {}
	_render()


func _salvage_commons() -> void:
	var n := GameState.salvage_all_common()
	GameState.toast.emit("%d itens comuns reciclados" % n, Color("#ffd54f"))
	selected = {}
	_render()
