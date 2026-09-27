## Atributos finais do personagem: base por nível + base dos itens (com refino)
## + linhas de atributo + bônus de set. Puro, sem cena.
extends RefCounted

const SetBonus = preload("res://core/set_bonus.gd")

const PCT_OF := {"atk_pct": "atk", "hp_pct": "max_hp", "def_pct": "def"}
const FLAT_TO := {"atk_flat": "atk", "hp_flat": "max_hp", "def_flat": "def"}


static func base(level: int) -> Dictionary:
	return {
		"max_hp": 120.0 + 18.0 * level, "atk": 8.0 + 2.0 * level, "def": 4.0 + level,
		"crit_chance": 5.0, "crit_damage": 50.0, "attack_speed": 0.0, "move_speed": 0.0,
		"life_steal": 0.0, "block": 0.0, "cooldown": 0.0, "resist_all": 0.0, "zen_find": 0.0,
	}


## Base do item já com crescimento por nível do item e bônus de refino.
static func item_base(item: Dictionary, items_db: Dictionary) -> Dictionary:
	var def: Dictionary = items_db["slots"].get(item["slot"], {})
	var grow := 1.0 + float(items_db["base_growth_per_level"]) * (int(item["item_level"]) - 1)
	var ref := 1.0 + float(items_db["refine_bonus_per_level"]) * int(item["refine"])
	var out := {}
	for k in def.get("base", {}):
		out[k] = snappedf(float(def["base"][k]) * grow * ref, 0.1)
	return out


static func compute(level: int, equipped: Array, items_db: Dictionary, sets_db: Dictionary, extra: Array = []) -> Dictionary:
	var s := base(level)
	var pct := {"atk": 0.0, "max_hp": 0.0, "def": 0.0}
	var adds := []
	for it in equipped:
		adds.append(item_base(it, items_db))
		var lines := {}
		for line in it["affixes"]:
			lines[line["stat"]] = lines.get(line["stat"], 0.0) + float(line["value"])
		adds.append(lines)
	adds.append(SetBonus.evaluate(equipped, sets_db)["_total"])
	adds.append_array(extra)
	for block in adds:
		for k in block:
			var v := float(block[k])
			if PCT_OF.has(k):
				pct[PCT_OF[k]] += v
			elif FLAT_TO.has(k):
				s[FLAT_TO[k]] += v
			elif s.has(k):
				s[k] += v
	for k in pct:
		s[k] = s[k] * (1.0 + pct[k] / 100.0)
	s["crit_chance"] = minf(s["crit_chance"], 75.0)
	s["block"] = minf(s["block"], 50.0)
	s["cooldown"] = minf(s["cooldown"], 40.0)
	s["resist_all"] = minf(s["resist_all"], 60.0)
	return s


## Dano recebido após defesa (curva suave, nunca zera).
static func mitigate(damage: float, defense: float, attacker_level: int) -> float:
	return damage * 100.0 / (100.0 + defense * 100.0 / (40.0 + 10.0 * attacker_level))


## Poder aproximado, para comparar itens na UI.
static func power(s: Dictionary) -> int:
	var dps: float = s["atk"] * (1.0 + s["crit_chance"] / 100.0 * s["crit_damage"] / 100.0) * (1.0 + s["attack_speed"] / 100.0)
	return int(dps * 4.0 + s["max_hp"] * 0.35 + s["def"] * 1.5)


## Dano por segundo do ataque básico (média com crítico e velocidade).
static func dps(s: Dictionary, basic_cooldown: float = 0.75) -> float:
	var crit: float = s["crit_chance"] / 100.0 * s["crit_damage"] / 100.0
	return s["atk"] * (1.0 + crit) * (1.0 + s["attack_speed"] / 100.0) / basic_cooldown


## Diferença de atributos ao trocar a peça do slot pelo item (positivo = melhora).
static func compare(level: int, equipped: Dictionary, item: Dictionary, items_db: Dictionary, sets_db: Dictionary, extra: Array = []) -> Dictionary:
	var now := compute(level, equipped.values(), items_db, sets_db, extra)
	var eq := equipped.duplicate()
	eq[item["slot"]] = item
	var then := compute(level, eq.values(), items_db, sets_db, extra)
	var out := {"power": power(then) - power(now), "dps": dps(then) - dps(now)}
	for k in now:
		out[k] = then[k] - now[k]
	return out


## Melhor item por slot (maior poder) entre equipado e mochila.
static func best_loadout(level: int, equipped: Dictionary, inventory: Array, items_db: Dictionary, sets_db: Dictionary) -> Dictionary:
	var eq := equipped.duplicate()
	var improved := true
	while improved:
		improved = false
		for it in inventory:
			if eq.get(it["slot"]) == it:
				continue
			if compare(level, eq, it, items_db, sets_db)["power"] > 0:
				eq[it["slot"]] = it
				improved = true
	return eq
