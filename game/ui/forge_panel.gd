## Forja Cinzenta: refinar, girar atributos (com trava) e Sigilo.
## Mostra custo e chances antes de confirmar; tiers bloqueados aparecem apagados
## com o requisito. Nada falha.
extends "res://game/ui/panel_base.gd"

const Refine = preload("res://core/refine.gd")
const Spin = preload("res://core/affix_spin.gd")
const Sigil = preload("res://core/sigil.gd")
const TierTable = preload("res://core/tier_table.gd")
const TierUnlocks = preload("res://core/tier_unlocks.gd")

var item: Dictionary = {}
var mode := "refine"
var locks: Array = []
var list_box: VBoxContainer
var work: VBoxContainer
var last_changed: Array = []


func title() -> String:
	return "Forja Cinzenta · Vesna"


func build() -> void:
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	h.add_child(left)
	var hint := Label.new()
	hint.text = "Escolha o item"
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	left.add_child(hint)
	list_box = VBoxContainer.new()
	left.add_child(scroll(list_box))
	work = VBoxContainer.new()
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 10)
	h.add_child(work)
	var all := _items()
	if not all.is_empty():
		item = all[0]
	_render()


func _items() -> Array:
	var out := []
	for s in ["weapon", "shield", "helm", "armor", "gloves", "pants", "boots"]:
		if GameState.equipped.has(s):
			out.append(GameState.equipped[s])
	return out + GameState.inventory


func _render() -> void:
	clear(list_box)
	for it in _items():
		var b := item_button(it, func(): _pick(it), it == item)
		b.custom_minimum_size = Vector2(260, 64)
		b.text = "%s%s" % [it.get("name", "Item"), (" +%d" % int(it["refine"])) if int(it["refine"]) > 0 else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		list_box.add_child(b)
	clear(work)
	if item.is_empty():
		work.add_child(rich("Sem itens para forjar."))
		return
	var tabs := HBoxContainer.new()
	work.add_child(tabs)
	for pair in [["refine", "Refinar"], ["spin", "Girar atributos"], ["sigil", "Sigilo"]]:
		var b := UiTheme.button(pair[1], _set_mode.bind(pair[0]), 180)
		b.toggle_mode = true
		b.button_pressed = mode == pair[0]
		tabs.add_child(b)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	work.add_child(scroll(main))
	main.add_child(rich(_item_header()))
	match mode:
		"refine": _refine_view(main)
		"spin": _spin_view(main)
		"sigil": _sigil_view(main)


func _set_mode(m: String) -> void:
	mode = m
	locks = []
	last_changed = []
	_render()


func _pick(it: Dictionary) -> void:
	item = it
	locks = []
	last_changed = []
	_render()


func _item_header() -> String:
	var s := "[font_size=24][color=%s][b]%s[/b][/color][/font_size]" % [ItemText.rarity_color(item), item.get("name", "")]
	if int(item["refine"]) > 0:
		s += " [color=#ffd166][b]+%d[/b][/color]" % int(item["refine"])
	if item.get("fortune", false):
		s += "  [color=#ffd54f]★ Fortuna[/color]"
	return s


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	var w = GameState.character.wallet
	for k in cost:
		var have: int = w.amount(k)
		var nm: String = "Cinzas" if k == "zen" else GameState.economy["jewels"][k]["name"]
		parts.append("[color=%s]%s %s[/color] [color=#8b8f99](tem %s)[/color]" % ["#e8e2d6" if have >= int(cost[k]) else "#ff6b6b", ItemText.short_zen(int(cost[k])), nm, ItemText.short_zen(have)])
	return "Custo: " + "   ".join(parts)


# --- Refinar ---

func _refine_view(main: VBoxContainer) -> void:
	var p := Refine.preview(item, GameState.economy)
	if p["at_max"]:
		main.add_child(rich("Este item está no refino máximo do MVP (+%d). Aurora (+13 a +15) chega na fase 4." % Refine.max_level(GameState.economy)))
		return
	var glow := ""
	for t in GameState.visuals["glow_thresholds"]:
		if int(p["to"]) == int(t):
			glow = "\n[color=#7fd1ff]Em +%d o item passa a brilhar mais no boneco.[/color]" % int(t)
	main.add_child(rich("[font_size=30][b]+%d  →  [color=#ffd166]+%d[/color][/b][/font_size]\n%s\n[color=#3fd67a]Chance de sucesso: 100%%. Nada falha.[/color]%s" % [p["from"], p["to"], _cost_text(p["cost"]), glow]))
	var b := UiTheme.button("Refinar", _do_refine, 220)
	b.disabled = not GameState.character.wallet.can_afford(p["cost"])
	main.add_child(b)


func _do_refine() -> void:
	var r := Refine.refine(item, GameState.character, GameState.economy)
	if r["ok"]:
		GameState.toast.emit("Refinado para +%d" % r["refine"], Color("#ffd166"))
		GameState.item_changed(item)
	_render()


# --- Girar ---

func _chances_table(main: VBoxContainer, chances: Dictionary) -> void:
	var reqs := TierUnlocks.requirements(GameState.character, GameState.economy)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	main.add_child(grid)
	for t in [1, 2, 3, 4, 5]:
		var req: Dictionary = reqs.filter(func(r): return r["tier"] == t)[0]
		var col := Color(ItemText.tier_color(t))
		var l := Label.new()
		l.text = "T%d" % t
		l.add_theme_color_override("font_color", col if req["unlocked"] else UiTheme.MUTED.darkened(0.3))
		grid.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(260, 18)
		bar.show_percentage = false
		bar.value = chances[t]
		bar.add_theme_stylebox_override("fill", UiTheme.bar(col if req["unlocked"] else Color("#333")))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var txt := Label.new()
		txt.text = "%.1f%%" % chances[t] if req["unlocked"] else "Bloqueado: " + req["requirement"]
		txt.add_theme_color_override("font_color", UiTheme.TEXT if req["unlocked"] else UiTheme.MUTED)
		txt.add_theme_font_size_override("font_size", 17)
		grid.add_child(txt)


func _spin_view(main: VBoxContainer) -> void:
	if item["affixes"].is_empty():
		main.add_child(rich("Este item não tem linhas. Use um Sigilo para criar a primeira."))
		return
	var max_locks := int(GameState.economy["spin"]["max_locks"])
	main.add_child(rich("[color=#8b8f99]Trave até %d linhas boas; as outras são sorteadas de novo.[/color]" % max_locks))
	for i in item["affixes"].size():
		var row := HBoxContainer.new()
		main.add_child(row)
		var cb := CheckButton.new()
		cb.text = "Travar"
		cb.button_pressed = locks.has(i)
		cb.disabled = not locks.has(i) and locks.size() >= max_locks
		cb.toggled.connect(func(on): _toggle_lock(i, on))
		row.add_child(cb)
		var txt := ItemText.line(item["affixes"][i])
		if last_changed.has(i):
			txt = "[pulse freq=2.0 color=#ffffff40 ease=-2.0]%s[/pulse]  [color=#ffd166]novo[/color]" % txt
		row.add_child(rich(txt))
	var pv := Spin.preview(item, locks, GameState.character, GameState.economy)
	main.add_child(rich("\n[b]Chances por linha[/b]   [color=#8b8f99]Piedade: %d giro(s) sem T3 ou melhor[/color]" % pv["pity"]))
	_chances_table(main, pv["chances"])
	main.add_child(rich(_cost_text(pv["cost"])))
	var b := UiTheme.button("Girar", _do_spin, 220)
	b.disabled = pv["error"] != "" or not GameState.character.wallet.can_afford(pv["cost"])
	main.add_child(b)


func _toggle_lock(i: int, on: bool) -> void:
	if on and not locks.has(i):
		locks.append(i)
	elif not on:
		locks.erase(i)
	_render()


func _do_spin() -> void:
	var r := Spin.spin(item, locks, GameState.character, GameState.economy, GameState.affixes, GameState.rng)
	if r["ok"]:
		last_changed = []
		for i in item["affixes"].size():
			if not locks.has(i):
				last_changed.append(i)
		GameState.toast.emit("Melhor linha: T%d" % r["best_tier"], Color(ItemText.tier_color(r["best_tier"])))
		GameState.item_changed(item)
	_render()


# --- Sigilo ---

func _sigil_view(main: VBoxContainer) -> void:
	var max_lines := int(GameState.economy["sigil"]["max_lines"])
	var n: int = item["affixes"].size()
	var txt := "Linhas: [b]%d / %d[/b]\n" % [n, max_lines]
	for l in item["affixes"]:
		txt += ItemText.line(l) + "\n"
	main.add_child(rich(txt))
	if n >= max_lines:
		main.add_child(rich("[color=#8b8f99]Item com o máximo de linhas.[/color]"))
		return
	var unlocked := TierUnlocks.unlocked_tiers(GameState.character, GameState.economy)
	main.add_child(rich("[b]Tier da nova linha[/b]"))
	_chances_table(main, TierTable.chances(GameState.economy, unlocked, item.get("fortune", false), 0))
	var cost := {"sigilo": int(GameState.economy["sigil"]["sigilo_cost"])}
	main.add_child(rich(_cost_text(cost)))
	var b := UiTheme.button("Usar Sigilo", _do_sigil, 220)
	b.disabled = not GameState.character.wallet.can_afford(cost)
	main.add_child(b)


func _do_sigil() -> void:
	var r := Sigil.add_line(item, GameState.character, GameState.economy, GameState.affixes, GameState.rng)
	if r["ok"]:
		last_changed = [item["affixes"].size() - 1]
		GameState.toast.emit("Nova linha: T%d" % r["line"]["tier"], Color(ItemText.tier_color(r["line"]["tier"])))
		GameState.item_changed(item)
	_render()
