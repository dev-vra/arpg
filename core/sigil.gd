## Sigilo: cria uma linha nova (até o máximo) com tier sorteado entre os liberados.
extends RefCounted

const TierTable = preload("res://core/tier_table.gd")
const TierUnlocks = preload("res://core/tier_unlocks.gd")
const Item = preload("res://core/item.gd")


static func add_line(item: Dictionary, character, economy: Dictionary, affix_db: Dictionary, rng) -> Dictionary:
	var cfg: Dictionary = economy["sigil"]
	if item["affixes"].size() >= int(cfg["max_lines"]):
		return {"ok": false, "error": "max_lines"}
	var exclude := Item.used_stats(item)
	if affix_db["pools"][item["slot"]].size() <= exclude.size():
		return {"ok": false, "error": "pool_exhausted"}
	var c := {"sigilo": int(cfg["sigilo_cost"])}
	if not character.wallet.spend(c):
		return {"ok": false, "error": "insufficient", "missing": character.wallet.missing(c)}
	var unlocked := TierUnlocks.unlocked_tiers(character, economy)
	var table := TierTable.chances(economy, unlocked, item.get("fortune", false), 0)
	var line := Item.roll_line(item, table, economy, affix_db, rng, exclude)
	item["affixes"].append(line)
	return {"ok": true, "cost": c, "line": line}
