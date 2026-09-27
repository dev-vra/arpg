## Curva de XP e subida de nível.
extends RefCounted


static func xp_to_next(level: int, economy: Dictionary) -> int:
	var p: Dictionary = economy["progression"]
	return int(float(p["xp_base"]) * pow(level, float(p["xp_exp"])))


## Soma XP e sobe quantos níveis couberem. Retorna os níveis ganhos.
static func add_xp(state: Dictionary, amount: int, economy: Dictionary) -> int:
	var max_level := int(economy["progression"]["max_level"])
	var gained := 0
	state["xp"] = int(state["xp"]) + amount
	while int(state["level"]) < max_level and int(state["xp"]) >= xp_to_next(int(state["level"]), economy):
		state["xp"] = int(state["xp"]) - xp_to_next(int(state["level"]), economy)
		state["level"] = int(state["level"]) + 1
		gained += 1
	if int(state["level"]) >= max_level:
		state["xp"] = 0
	return gained
