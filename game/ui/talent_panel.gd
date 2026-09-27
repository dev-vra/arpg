## Espíritos: 3 árvores (Juramento, Ascensão, Transcendência), 25 pontos cada.
## Colunas: 2 Superiores | neutro | 2 Infernais. O primeiro ponto num lado alinha a
## árvore àquele espírito. Toque num nó para ver e investir.
extends "res://game/ui/panel_base.gd"

const Talents = preload("res://core/talents.gd")
const COLS := ["s1", "s2", "n", "i1", "i2"]
const SIDE_COLOR := {"superior": Color("#ffd98a"), "infernal": Color("#ff6a4a"), "neutral": Color("#c9c4b8")}
const ERR := {"tree_locked": "Árvore bloqueada", "no_points": "Sem pontos", "maxed": "No máximo",
	"row_locked": "Invista mais nesta árvore para liberar a linha", "other_spirit": "Árvore alinhada ao outro espírito"}

var tree_i := 0
var sel := ""
var head: RichTextLabel
var grid_box: HBoxContainer


func title() -> String:
	return "Espíritos"


func build() -> void:
	head = rich()
	body.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for i in GameState.talents_db["trees"].size():
		var t: Dictionary = GameState.talents_db["trees"][i]
		var b := UiTheme.button("%s  (Nv %d+)" % [t["name"], int(t["unlock_level"])], _tab.bind(i), 230)
		b.toggle_mode = true
		b.button_pressed = i == tree_i
		b.disabled = GameState.character.level < int(t["unlock_level"])
		tabs.add_child(b)
	grid_box = HBoxContainer.new()
	grid_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_box.add_theme_constant_override("separation", 16)
	body.add_child(grid_box)
	_render()


func _tab(i: int) -> void:
	tree_i = i
	sel = ""
	hud.open_panel("talents")
	hud.panel.tree_i = i
	hud.panel._render()


func _render() -> void:
	var db: Dictionary = GameState.talents_db
	var st: Dictionary = GameState.talents
	var t: Dictionary = db["trees"][tree_i]
	var sp := GameState.spirit()
	var al := Talents.alignment(t, st)
	var sp_txt := "[color=#8b8f99]nenhum[/color]"
	if sp["side"] != "":
		sp_txt = "[color=%s]%s[/color] (%d pts)" % [SIDE_COLOR[sp["side"]].to_html(), db["spirit_bonus"][sp["side"]]["name"], int(sp[sp["side"]])]
	head.text = "Pontos livres: [b][color=#ffd166]%d[/color][/b]    Espírito dominante: %s    [color=#8b8f99]%s: %d/25 · %s[/color]" % [
		GameState.talent_points(), sp_txt, t["name"], Talents.spent_in(t, st),
		"alinhada ao " + db["spirit_bonus"][al]["name"] if al != "" else "sem alinhamento"]
	clear(grid_box)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid_box.add_child(grid)
	for c in COLS:
		var l := Label.new()
		l.text = {"s1": "Superior", "s2": "", "n": "Neutro", "i1": "Infernal", "i2": ""}[c]
		l.add_theme_color_override("font_color", SIDE_COLOR["superior" if c.begins_with("s") else ("infernal" if c.begins_with("i") else "neutral")])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(l)
	for r in 5:
		for c in COLS:
			grid.add_child(_node_button(t, "%s_%d_%s" % [t["id"], r, c]))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_box.add_child(right)
	if sel == "":
		right.add_child(rich("[color=#8b8f99]Toque num nó.\n\nO primeiro ponto num lado alinha esta árvore ao espírito Superior ou Infernal e tranca o outro lado. Com 10 pontos alinhados a árvore dá o bônus do espírito; completa (25), dá o dobro.\n\nCada linha exige 5 pontos investidos na árvore.[/color]"))
	else:
		var n := Talents.node(db, sel)
		var p := int(st["points"].get(sel, 0))
		right.add_child(rich("[font_size=24][b][color=%s]%s[/color][/b][/font_size]  %d/%d\n%s" % [SIDE_COLOR[n["side"]].to_html(), n["name"], p, int(n["max"]), _effect(n)]))
		var err := Talents.can_add(db, st, sel, GameState.character.level)
		var b := UiTheme.button("Investir ponto" if err == "" else ERR.get(err, err), _add.bind(sel), 260)
		b.disabled = err != ""
		right.add_child(b)
	right.add_child(UiTheme.button("Redistribuir esta árvore", _reset, 260))


func _node_button(t: Dictionary, id: String) -> Button:
	var n := Talents.node(GameState.talents_db, id)
	var p := int(GameState.talents["points"].get(id, 0))
	var err := Talents.can_add(GameState.talents_db, GameState.talents, id, GameState.character.level)
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 72)
	b.icon = UiTheme.icon(n["icon"])
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = "%d/%d" % [p, int(n["max"])]
	b.add_theme_font_size_override("font_size", 14)
	var col: Color = SIDE_COLOR[n["side"]]
	var dim := err in ["row_locked", "other_spirit", "tree_locked"] and p == 0
	b.add_theme_color_override("icon_normal_color", col if not dim else Color(0.35, 0.35, 0.38))
	b.add_theme_color_override("font_color", Color("#ffd166") if p > 0 else Color("#8b8f99"))
	if id == sel:
		b.add_theme_stylebox_override("normal", UiTheme.frame("button_pressed", 6, 12))
	b.pressed.connect(_select.bind(id))
	return b


func _select(id: String) -> void:
	sel = id
	_render()


func _effect(n: Dictionary) -> String:
	var parts := []
	for k in n.get("stats", {}):
		parts.append("+%s %s por ponto" % [ItemText._num(float(n["stats"][k])), ItemText.stat_name(k) if GameState.affixes["stats"].has(k) else ItemText.STAT_LABEL.get(k, k)])
	if n.has("skill"):
		var names := {"investida": "Investida", "giro": "Giro", "brado": "Brado", "impacto": "Impacto"}
		var labels := {"mult_pct": "dano %", "radius_pct": "raio %", "distance_pct": "distância %", "cooldown_pct": "recarga %", "stun": "atordoamento (s)", "heal_pct": "cura %", "def_bonus_pct": "defesa do brado %", "duration": "duração (s)"}
		for k in n["skill"]:
			if k != "id":
				parts.append("%s: %s%s %s por ponto" % [names[n["skill"]["id"]], "+" if float(n["skill"][k]) > 0 else "", ItemText._num(float(n["skill"][k])), labels.get(k, k)])
	return "\n".join(parts)


func _add(id: String) -> void:
	var err := GameState.add_talent(id)
	if err == "":
		GameState.toast.emit("%s +1" % Talents.node(GameState.talents_db, id)["name"], Color("#ffd166"))
	_render()


func _reset() -> void:
	GameState.reset_talent_tree(GameState.talents_db["trees"][tree_i]["id"])
	sel = ""
	_render()
