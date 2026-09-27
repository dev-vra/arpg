## Drops de campo: joias, Cinzas e itens por abate, calibrados a partir dos números
## por partida de economy.json (drops) divididos pelos abates de uma partida.
## playtest_multiplier acelera o teste fechado; a simulação usa 1.
extends RefCounted

const Item = preload("res://core/item.gd")
const TierTable = preload("res://core/tier_table.gd")
const TierUnlocks = preload("res://core/tier_unlocks.gd")

const EQUIP_SLOTS := ["helm", "armor", "gloves", "pants", "boots", "weapon", "shield"]
const SET_SLOTS := ["helm", "armor", "gloves", "pants", "boots"]


## ctx: {economy, affixes, items, sets, character, rng, uid_fn(optional)}
static func roll_kill(ctx: Dictionary, map_def: Dictionary, difficulty: String, is_boss: bool) -> Array:
	var eco: Dictionary = ctx["economy"]
	var fl: Dictionary = eco["field_loot"]
	var rng = ctx["rng"]
	var mult := float(fl["playtest_multiplier"]) * float(fl["difficulty"][difficulty]["loot"])
	var weight := float(fl["boss_kill_weight"]) if is_boss else 1.0
	var per_kill := mult * weight / float(fl["kills_per_run"])
	var out := []
	var d: Dictionary = eco["drops"]
	for k in d["per_run"]:
		var expected := float(d["per_run"][k]) * per_kill
		if k == "zen":
			out.append({"kind": "currency", "key": "zen", "amount": maxi(1, int(expected * rng.randf_range(0.6, 1.4)))})
			continue
		var n := int(expected) + (1 if rng.randf() < expected - int(expected) else 0)
		if n > 0:
			out.append({"kind": "currency", "key": k, "amount": n})
	var ilvl := item_level(map_def, difficulty, eco)
	if is_boss:
		var set_chance := minf(1.0, float(d["set_piece_chance"]) * mult)
		if rng.randf() < set_chance:
			out.append({"kind": "item", "item": make_item(ctx, rng.pick(SET_SLOTS), ilvl, "ancestral", rng.pick(map_def["sets"]))})
		for i in int(fl["boss_items"]):
			out.append({"kind": "item", "item": make_item(ctx, rng.pick(EQUIP_SLOTS), ilvl, "superior", "")})
	elif rng.randf() < float(fl["item_chance"]):
		var rarity := "superior" if rng.randf() < float(fl["superior_share"]) else "common"
		out.append({"kind": "item", "item": make_item(ctx, rng.pick(EQUIP_SLOTS), ilvl, rarity, "")})
	return out


static func item_level(map_def: Dictionary, difficulty: String, eco: Dictionary) -> int:
	return int(map_def["level"]) + int(eco["field_loot"]["difficulty"][difficulty]["level"])


static func make_item(ctx: Dictionary, slot: String, ilvl: int, rarity: String, set_id: String) -> Dictionary:
	var eco: Dictionary = ctx["economy"]
	var rng = ctx["rng"]
	var fortune: bool = rng.randf() < float(eco["field_loot"]["fortune_chance"])
	var it := Item.make(slot, ilvl, set_id, fortune)
	it["rarity"] = rarity
	it["uid"] = "%d_%d" % [Time.get_ticks_usec(), rng.randi_range(0, 999999)]
	it["name"] = item_name(ctx, slot, rarity, set_id, rng)
	var span: Array = eco["field_loot"]["lines"][rarity]
	var n: int = rng.randi_range(int(span[0]), int(span[1]))
	var unlocked := TierUnlocks.unlocked_tiers(ctx["character"], eco)
	var table := TierTable.chances(eco, unlocked, fortune, 0)
	for i in n:
		var line := Item.roll_line(it, table, eco, ctx["affixes"], rng, Item.used_stats(it))
		if not line.is_empty():
			it["affixes"].append(line)
	return it


static func item_name(ctx: Dictionary, slot: String, rarity: String, set_id: String, rng) -> String:
	var def: Dictionary = ctx["items"]["slots"][slot]
	if set_id != "":
		return "%s %s" % [def["label"], ctx["sets"]["sets"][set_id]["name"]]
	return rng.pick(def.get(rarity, def["common"]))
