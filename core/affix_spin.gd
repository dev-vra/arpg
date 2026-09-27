## Rotação de atributos: 1 Prisma + Cinzas por giro. Linhas travadas ficam;
## as destravadas são sorteadas de novo e sempre entregam um tier (T5 no pior caso).
extends RefCounted

const TierTable = preload("res://core/tier_table.gd")
const TierUnlocks = preload("res://core/tier_unlocks.gd")
const Item = preload("res://core/item.gd")


static func cost(item: Dictionary, locks: Array, economy: Dictionary) -> Dictionary:
	var s: Dictionary = economy["spin"]
	var base := float(s["zen_base"]) + float(s["zen_per_item_level"]) * int(item["item_level"])
	var zen := int(round(base * (1.0 + float(s["zen_lock_multiplier"]) * locks.size())))
	return {"prisma": int(s["prisma_cost"]), "zen": zen}


static func validate(item: Dictionary, locks: Array, economy: Dictionary) -> String:
	var n: int = item["affixes"].size()
	if n == 0:
		return "no_lines"
	if locks.size() > int(economy["spin"]["max_locks"]):
		return "too_many_locks"
	var seen := {}
	for l in locks:
		if typeof(l) != TYPE_INT or l < 0 or l >= n or seen.has(l):
			return "invalid_lock"
		seen[l] = true
	if locks.size() >= n:
		return "all_locked"
	return ""


## Tudo o que a tela mostra antes de confirmar: custo, chances e tiers bloqueados.
static func preview(item: Dictionary, locks: Array, character, economy: Dictionary) -> Dictionary:
	var unlocked := TierUnlocks.unlocked_tiers(character, economy)
	return {
		"error": validate(item, locks, economy),
		"cost": cost(item, locks, economy),
		"chances": TierTable.chances(economy, unlocked, item.get("fortune", false), character.pity),
		"tiers": TierUnlocks.requirements(character, economy),
		"pity": character.pity,
	}


static func spin(item: Dictionary, locks: Array, character, economy: Dictionary, affix_db: Dictionary, rng) -> Dictionary:
	var err := validate(item, locks, economy)
	if err != "":
		return {"ok": false, "error": err}
	var c := cost(item, locks, economy)
	if not character.wallet.spend(c):
		return {"ok": false, "error": "insufficient", "missing": character.wallet.missing(c)}

	var unlocked := TierUnlocks.unlocked_tiers(character, economy)
	var table := TierTable.chances(economy, unlocked, item.get("fortune", false), character.pity)

	# Atributos das travadas ficam reservados; as destravadas sorteiam sem repetir.
	var taken := []
	for l in locks:
		taken.append(item["affixes"][l]["stat"])
	var best := 99
	for i in item["affixes"].size():
		if locks.has(i):
			continue
		var line := Item.roll_line(item, table, economy, affix_db, rng, taken)
		item["affixes"][i] = line
		taken.append(line["stat"])
		best = mini(best, int(line["tier"]))

	var p: Dictionary = economy["pity"]
	if best <= int(p["reset_at_or_better"]):
		character.pity = 0
	else:
		character.pity = mini(character.pity + 1, int(p["max_stacks"]))

	return {"ok": true, "cost": c, "chances": table, "best_tier": best, "pity": character.pity}
