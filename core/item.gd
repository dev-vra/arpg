## Item como dicionário puro (serializável, pronto para save e rede).
## Campos: uid, base_id, slot, rarity, item_level, refine, affixes, set_id, sockets, fortune.
## Cada linha de atributo: {stat, tier, value}.
extends RefCounted

const TierTable = preload("res://core/tier_table.gd")

const SLOTS := ["helm", "armor", "gloves", "pants", "boots", "weapon", "shield", "wings", "pet"]
const RARITIES := ["common", "superior", "ancestral", "socketed", "relic"]


static func make(slot: String, item_level: int, set_id: String = "", fortune: bool = false) -> Dictionary:
	assert(SLOTS.has(slot), "slot inválido: %s" % slot)
	return {
		"uid": "",
		"base_id": "",
		"slot": slot,
		"rarity": "ancestral" if set_id != "" else "common",
		"item_level": item_level,
		"refine": 0,
		"affixes": [],
		"set_id": set_id,
		"sockets": [],
		"fortune": fortune,
	}


static func used_stats(item: Dictionary, skip_index: int = -1) -> Array:
	var out := []
	for i in item["affixes"].size():
		if i != skip_index:
			out.append(item["affixes"][i]["stat"])
	return out


## Sorteia uma linha nova para o slot, sem repetir atributo já presente.
static func roll_line(item: Dictionary, chance_table: Dictionary, economy: Dictionary, affix_db: Dictionary, rng, exclude: Array) -> Dictionary:
	var pool: Array = []
	for s in affix_db["pools"][item["slot"]]:
		if not exclude.has(s):
			pool.append(s)
	if pool.is_empty():
		return {}
	var stat: String = rng.pick(pool)
	var tier := TierTable.roll_tier(chance_table, rng)
	var crit := false
	if item.get("fortune", false):
		crit = rng.randf() < float(economy["fortune"]["crit_chance"])
	var pct := TierTable.roll_value_pct(economy, tier, rng, crit)
	return {
		"stat": stat,
		"tier": tier,
		"value": TierTable.stat_value(affix_db["stats"][stat], pct),
	}
