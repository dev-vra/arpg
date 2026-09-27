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
	head.add_child(cnt)
	var w = GameState.character.wallet
	var money := rich("  [color=#ffd54f]Cinzas %s[/color]  [color=#ffe08a]Lume %d[/color]  [color=#ff7043]Brasa %d[/color]  [color=#c77dff]Prisma %d[/color]  [color=#4dd0e1]Sigilo %d[/color]" % [
		ItemText.short_zen(w.zen), w.amount("lume"), w.amount("brasa"), w.amount("prisma"), w.amount("sigilo")])
	money.add_theme_font_size_override("normal_font_size", 16)
	head.add_child(money)
	var acts := HBoxContainer.new()
	mid.add_child(acts)
	acts.add_child(UiTheme.button("Equipar melhores", _equip_best, 190))
	acts.add_child(UiTheme.button("Reciclar comuns", _salvage_commons, 190))
	var grid := GridContainer.new()
	grid.columns = 4
	for it in GameState.inventory:
		var b := item_button(it, func(): _select(it), selected == it)
		if GameState.is_upgrade(it):
			b.text += "  +"
			b.add_theme_color_override("font_color", Color("#3fd67a"))
		grid.add_child(b)
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


const COMPARE_ROWS := [["power", "Poder"], ["dps", "DPS"], ["max_hp", "Vida"], ["atk", "Ataque"], ["def", "Defesa"],
	["crit_chance", "Crítico %"], ["crit_damage", "Dano crítico %"], ["attack_speed", "Vel. ataque %"],
	["move_speed", "Vel. movimento %"], ["life_steal", "Roubo de vida %"], ["block", "Bloqueio %"], ["cooldown", "Recarga %"], ["resist_all", "Resistência %"]]


## Diferença para o item equipado no mesmo slot: poder, DPS e cada atributo que muda.
func _delta_text() -> String:
	if GameState.equipped.get(selected["slot"]) == selected:
		return ""
	var d := GameState.compare(selected)
	var cur = GameState.equipped.get(selected["slot"])
	var s := "\n[b]Se equipar[/b] [color=#8b8f99](no lugar de %s)[/color]\n" % (cur["name"] if cur else "nada")
	for row in COMPARE_ROWS:
		var v: float = d.get(row[0], 0.0)
		if absf(v) < 0.05:
			continue
		var col := "#3fd67a" if v > 0 else "#ff6b6b"
		s += "[color=%s]%s%s[/color]  %s\n" % [col, "+" if v > 0 else "", ItemText._num(v), row[1]]
	return s


func _equip_best() -> void:
	var n := GameState.equip_best()
	GameState.toast.emit("%d peça(s) trocada(s) pelas melhores" % n if n > 0 else "Você já está com o melhor", Color("#3fd67a"))
	selected = {}
	_render()


func _salvage_selected() -> void:
	var v := GameState.salvage(selected)
	GameState.toast.emit("Reciclado: +%d Cinzas%s" % [v.get("zen", 0), (" +%d Lume" % v["lume"]) if v.has("lume") else ""], Color("#ffd54f"))
	selected = {}
	_render()


func _salvage_commons() -> void:
	var n := GameState.salvage_all_common()
	GameState.toast.emit("%d itens comuns reciclados" % n, Color("#ffd54f"))
	selected = {}
	_render()
