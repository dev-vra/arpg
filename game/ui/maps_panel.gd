## Portal dos Mapas: escolhe mapa e dificuldade.
extends "res://game/ui/panel_base.gd"


func title() -> String:
	return "Portal dos Mapas"


func build() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	body.add_child(scroll(list))
	var lvl: int = GameState.character.level
	for id in GameState.maps_db["maps"]:
		var m: Dictionary = GameState.maps_db["maps"][id]
		if m["kind"] != "field":
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color("#1b1e25"), Color("#3a3f4b"), 10, 2, 12))
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var sets := []
		for sid in m["sets"]:
			sets.append(GameState.sets_db["sets"][sid]["name"])
		var boss: Dictionary = GameState.mobs_db["mobs"][m["boss"]]
		var warn := "" if lvl >= int(m["level"]) else "  [color=#ff9f5a](recomendado nível %d)[/color]" % int(m["level"])
		var hard_lvl := int(m["level"]) + int(GameState.economy["field_loot"]["difficulty"]["hard"]["level"])
		row.add_child(rich("[font_size=24][b]%s[/b][/font_size]  [color=#8b8f99]Nível %d[/color]%s\nChefe: [color=#ff9f1c]%s[/color]\nSets: [color=#3fd67a]%s[/color]\n[color=#8b8f99]Difícil: monstros nível %d, mais loot.[/color]" % [m["name"], int(m["level"]), warn, boss["name"], ", ".join(sets), hard_lvl]))
		var btns := VBoxContainer.new()
		row.add_child(btns)
		btns.add_child(UiTheme.button("Normal", func(): hud.world.travel(id, "normal"), 160))
		btns.add_child(UiTheme.button("Difícil", func(): hud.world.travel(id, "hard"), 160))
