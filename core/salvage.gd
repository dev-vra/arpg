## Reciclagem: item excedente vira Zen e Lume, com perda (sumidouro de itens).
extends RefCounted


static func value(item: Dictionary, economy: Dictionary) -> Dictionary:
	var table: Dictionary = economy["field_loot"]["salvage"]
	var base: Dictionary = table.get(item["rarity"], table["common"])
	var out := {}
	for k in base:
		out[k] = int(base[k]) + (int(item["item_level"]) * 20 if k == "zen" else 0)
	return out


static func salvage(item: Dictionary, character, economy: Dictionary) -> Dictionary:
	var v := value(item, economy)
	for k in v:
		character.wallet.add(k, v[k])
	return v
