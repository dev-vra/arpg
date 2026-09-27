## Diário de missões: ativas e prontas, com descrição, progresso, onde ir e rastreio.
extends "res://game/ui/panel_base.gd"

const Quests = preload("res://core/quests.gd")

var list: VBoxContainer


func title() -> String:
	return "Diário de missões"


func build() -> void:
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	body.add_child(scroll(list))
	_render()


func _render() -> void:
	clear(list)
	var ids: Array = GameState.tracked_quests()
	if ids.is_empty():
		list.add_child(rich("[color=#8b8f99]Nenhuma missão ativa. Fale com a Ilse ou com a Vesna no Bastião.[/color]"))
		return
	for id in ids:
		var q := Quests.find(GameState.quests_db, id)
		var p := Quests.progress(GameState.quests_db, GameState.quests, id)
		var ready: bool = GameState.quests["done"].has(id)
		var tracked: bool = GameState.tracked_quest == id
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color("#1b1e25"), UiTheme.GOLD if tracked else Color("#3a3f4b"), 10, 2, 12))
		list.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		var giver: String = GameState.dialogues_db["npcs"][q.get("giver", "mentor")]["name"]
		var where := "Entregar a %s, no Bastião" % giver if ready else _where(q)
		row.add_child(rich("[font_size=22][b]%s[/b][/font_size]  %s\n%s\n[color=#ffd166]%s[/color]" % [
			q["name"], "[color=#3fd67a]Concluída[/color]" if ready else "[color=#5aa0ff]%d/%d[/color]" % p, q["desc"], where]))
		row.add_child(UiTheme.button("Rastreando" if tracked else "Rastrear", _track.bind(id), 150))


func _where(q: Dictionary) -> String:
	var g: Dictionary = q["goal"]
	var map := ""
	match g["type"]:
		"kill", "clear":
			map = g.get("map", "")
		"collect":
			map = hud.world._map_with_mob(g["mob"])
	return "Onde: %s" % GameState.maps_db["maps"][map]["name"] if map != "" else ""


func _track(id: String) -> void:
	GameState.tracked_quest = id
	GameState.toast.emit("Rastreando: siga as marcas douradas", Color("#ffd166"))
	_render()
