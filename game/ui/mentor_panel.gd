## Mentora Ilse: como jogar, desafios e desbloqueio de tiers.
extends "res://game/ui/panel_base.gd"

const TierUnlocks = preload("res://core/tier_unlocks.gd")


const Quests = preload("res://core/quests.gd")

var list: VBoxContainer


func title() -> String:
	return "Ilse · Mentora"


func build() -> void:
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	body.add_child(scroll(list))
	_render()


func _render() -> void:
	clear(list)
	list.add_child(UiTheme.title("Missões", 22))
	var shown := 0
	for q in GameState.quests_db["quests"]:
		var st := GameState.quest_status(q["id"])
		if st == "completed" or st == "locked":
			continue
		shown += 1
		list.add_child(_card(q, st))
	if shown == 0:
		list.add_child(rich("[color=#8b8f99]Nenhuma missão nova agora. Suba de nível ou conclua as atuais.[/color]"))
	list.add_child(rich(_guide()))


func _card(q: Dictionary, st: String) -> Control:
	var card := PanelContainer.new()
	var border: Color = {"available": UiTheme.GOLD, "active": Color("#5aa0ff"), "ready": Color("#3fd67a")}[st]
	card.add_theme_stylebox_override("panel", UiTheme.box(Color("#1b1e25"), border, 10, 2, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var p := Quests.progress(GameState.quests_db, GameState.quests, q["id"])
	var r: Dictionary = q["reward"]
	var rew := []
	for k in r:
		if k == "item":
			rew.append("peça %s" % GameState.sets_db["sets"].get(r[k].get("set", ""), {}).get("name", "rara"))
		elif k == "xp":
			rew.append("%d XP" % int(r[k]))
		else:
			rew.append("%s %s" % [ItemText.short_zen(int(r[k])), "Zen" if k == "zen" else GameState.economy["jewels"][k]["name"]])
	var state_txt: String = {"available": "[color=#d9a441]Nova[/color]", "active": "[color=#5aa0ff]Em andamento %d/%d[/color]" % p, "ready": "[color=#3fd67a]Concluída: entregue![/color]"}[st]
	row.add_child(rich("[font_size=22][b]%s[/b][/font_size]  %s
%s
[color=#8b8f99]Recompensa: %s[/color]" % [q["name"], state_txt, q["desc"], ", ".join(rew)]))
	if st == "available":
		row.add_child(UiTheme.button("Aceitar", _accept.bind(q["id"]), 140))
	elif st == "ready":
		row.add_child(UiTheme.button("Entregar", _turn_in.bind(q["id"]), 140))
	return card


func _accept(id: String) -> void:
	GameState.accept_quest(id)
	_render()


func _turn_in(id: String) -> void:
	GameState.turn_in_quest(id)
	_render()


func _guide() -> String:
	var c = GameState.character
	var s := "\n[i]\"Sentinela, o boneco é a sua build. Cada peça muda o que você é, e o set completo muda como te veem.\"[/i]\n\n"
	s += "[color=#d9a441][b]O ciclo[/b][/color]\n1. Entre no Portal e limpe o mapa. O chefe dropa peças de set.\n2. Volte e fale com Vesna na Forja: refinar sempre sobe, girar sempre entrega um tier.\n3. Equipe e veja o boneco mudar. Set completo acende a aura.\n\n"
	s += "[color=#d9a441][b]Controles[/b][/color]\nToque: joystick à esquerda, ataque e skills à direita. Segure o ataque para repetir.\nTeclado: WASD mover · Espaço atacar · 1-4 skills · Shift esquiva · Q poção · E interagir · I mochila\n\n"
	s += "[color=#d9a441][b]Tiers e desafios[/b][/color]\n"
	for r in TierUnlocks.requirements(c, GameState.economy):
		s += "[color=%s]T%d[/color]  %s  %s\n" % [ItemText.tier_color(r["tier"]), r["tier"], "[color=#3fd67a]liberado[/color]" if r["unlocked"] else "[color=#8b8f99]bloqueado[/color]", r["requirement"]]
	s += "\n[color=#8b8f99]Tier bloqueado não entra no sorteio; a chance dele vai para os liberados. Tier já sorteado fica no item.[/color]\n\n"
	s += "[color=#d9a441][b]Desafios[/b][/color]\n"
	for id in GameState.economy["challenges"]:
		var info: Dictionary = GameState.economy["challenges"][id]
		s += "%s  [b]%s[/b]: %s\n" % ["[color=#3fd67a][x][/color]" if c.has_challenge(id) else "[color=#5c616b][ ][/color]", info["name"], info["desc"]]
	return s
