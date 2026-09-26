## Refino: sempre sobe +1. O custo em joias cresce por nível (economy.json).
## Os únicos "não" são de pré-condição (sem joias, nível máximo), nunca falha sorteada.
extends RefCounted


static func max_level(economy: Dictionary) -> int:
	return int(economy["refine"]["mvp_max"])


## Custo para ir do nível atual ao próximo; vazio se já está no máximo.
static func next_cost(item: Dictionary, economy: Dictionary) -> Dictionary:
	var target := int(item["refine"]) + 1
	if target > max_level(economy):
		return {}
	for step in economy["refine"]["levels"]:
		if int(step["level"]) == target:
			return {step["jewel"]: int(step["cost"])}
	return {}


static func preview(item: Dictionary, economy: Dictionary) -> Dictionary:
	var cost := next_cost(item, economy)
	return {
		"from": int(item["refine"]),
		"to": int(item["refine"]) + 1 if not cost.is_empty() else int(item["refine"]),
		"cost": cost,
		"success_chance": 1.0,
		"at_max": cost.is_empty(),
	}


static func refine(item: Dictionary, character, economy: Dictionary) -> Dictionary:
	var cost := next_cost(item, economy)
	if cost.is_empty():
		return {"ok": false, "error": "max_level"}
	if not character.wallet.spend(cost):
		return {"ok": false, "error": "insufficient", "missing": character.wallet.missing(cost)}
	item["refine"] = int(item["refine"]) + 1
	return {"ok": true, "cost": cost, "refine": item["refine"]}
