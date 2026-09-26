## Desbloqueio de tiers por nível mínimo e desafio concluído.
## Tier bloqueado não entra no sorteio.
extends RefCounted


static func unlocked_tiers(character, economy: Dictionary) -> Array:
	var out := []
	for rule in economy["tiers"]["unlocks"]:
		if _meets(character, rule):
			out.append(int(rule["tier"]))
	out.sort()
	return out


static func _meets(character, rule: Dictionary) -> bool:
	if character.level < int(rule["min_level"]):
		return false
	var challenge: String = rule.get("challenge", "")
	return challenge == "" or character.has_challenge(challenge)


## Texto do requisito de cada tier, para a tela de chances mostrar os bloqueados.
static func requirements(character, economy: Dictionary) -> Array:
	var out := []
	for rule in economy["tiers"]["unlocks"]:
		var challenge: String = rule.get("challenge", "")
		var text := "Nível %d" % int(rule["min_level"])
		if challenge != "":
			var info: Dictionary = economy.get("challenges", {}).get(challenge, {})
			text += " e desafio %s" % info.get("name", challenge)
		out.append({
			"tier": int(rule["tier"]),
			"unlocked": _meets(character, rule),
			"requirement": text,
		})
	return out
