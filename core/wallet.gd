## Carteira do personagem: joias por tipo e Cinzas.
## Custos são dicionários {"lume": 2, "zen": 1500}.
extends RefCounted

var jewels: Dictionary = {}
var zen: int = 0


func amount(key: String) -> int:
	if key == "zen":
		return zen
	return int(jewels.get(key, 0))


func add(key: String, value: int) -> void:
	if key == "zen":
		zen += value
	else:
		jewels[key] = amount(key) + value


func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if amount(key) < int(cost[key]):
			return false
	return true


## Retorna a lista do que falta, útil para a UI.
func missing(cost: Dictionary) -> Dictionary:
	var out := {}
	for key in cost:
		var diff := int(cost[key]) - amount(key)
		if diff > 0:
			out[key] = diff
	return out


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for key in cost:
		add(key, -int(cost[key]))
	return true


func to_dict() -> Dictionary:
	return {"jewels": jewels.duplicate(), "zen": zen}


static func from_dict(d: Dictionary):
	var w = load("res://core/wallet.gd").new()
	w.jewels = d.get("jewels", {}).duplicate()
	w.zen = int(d.get("zen", 0))
	return w
