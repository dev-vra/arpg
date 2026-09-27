## Mentora Ilse: como jogar, desafios e desbloqueio de tiers.
extends "res://game/ui/panel_base.gd"

const TierUnlocks = preload("res://core/tier_unlocks.gd")


func title() -> String:
	return "Ilse · Mentora"


func build() -> void:
	var c = GameState.character
	var s := "[i]\"Sentinela, o boneco é a sua build. Cada peça muda o que você é, e o set completo muda como te veem.\"[/i]\n\n"
	s += "[color=#d9a441][b]O ciclo[/b][/color]\n1. Entre no Portal e limpe o mapa. O chefe dropa peças de set.\n2. Volte e fale com Vesna na Forja: refinar sempre sobe, girar sempre entrega um tier.\n3. Equipe e veja o boneco mudar. Set completo acende a aura.\n\n"
	s += "[color=#d9a441][b]Controles[/b][/color]\nToque: joystick à esquerda, ataque e skills à direita. Segure o ataque para repetir.\nTeclado: WASD mover · Espaço atacar · 1-4 skills · Shift esquiva · Q poção · E interagir · I mochila\n\n"
	s += "[color=#d9a441][b]Tiers e desafios[/b][/color]\n"
	for r in TierUnlocks.requirements(c, GameState.economy):
		s += "[color=%s]T%d[/color]  %s  %s\n" % [ItemText.tier_color(r["tier"]), r["tier"], "[color=#3fd67a]liberado[/color]" if r["unlocked"] else "[color=#8b8f99]bloqueado[/color]", r["requirement"]]
	s += "\n[color=#8b8f99]Tier bloqueado não entra no sorteio; a chance dele vai para os liberados. Tier já sorteado fica no item.[/color]\n\n"
	s += "[color=#d9a441][b]Desafios[/b][/color]\n"
	for id in GameState.economy["challenges"]:
		var info: Dictionary = GameState.economy["challenges"][id]
		s += "%s  [b]%s[/b]: %s\n" % ["[color=#3fd67a]✓[/color]" if c.has_challenge(id) else "[color=#5c616b]○[/color]", info["name"], info["desc"]]
	body.add_child(scroll(rich(s)))
