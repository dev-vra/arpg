## Texto de item em BBCode: nome na cor da raridade, base, linhas com tier colorido, set.
extends RefCounted

const Stats = preload("res://core/stats.gd")
const SetBonus = preload("res://core/set_bonus.gd")

const STAT_ORDER := ["atk", "max_hp", "def", "crit_chance", "crit_damage", "attack_speed", "move_speed", "life_steal", "block", "cooldown", "resist_all"]
const STAT_LABEL := {"atk": "Ataque", "max_hp": "Vida", "def": "Defesa", "crit_chance": "Crítico %", "crit_damage": "Dano crítico %",
	"attack_speed": "Vel. ataque %", "move_speed": "Vel. movimento %", "life_steal": "Roubo de vida %", "block": "Bloqueio %",
	"cooldown": "Recarga %", "resist_all": "Resistência %",
	"dmg_boss_pct": "dano contra chefes %", "execute_pct": "dano contra inimigos com menos de 35% de vida %",
	"low_life_dr_pct": "redução de dano com menos de 40% de vida %", "on_kill_heal_pct": "vida recuperada ao matar %",
	"dmg_taken_pct": "dano recebido %", "area_pct": "área de todas as skills %", "hp_regen_pct": "regeneração de vida por segundo %",
	"thorns_pct": "dano refletido em quem te acerta %", "crit_full_hp": "chance de crítico com vida cheia %",
	"speed_on_kill": "vel. movimento por 3 s ao matar %", "heal_mult_pct": "curas recebidas %",
	"life_drain_pct": "vida perdida por segundo em combate %", "no_regen": "sem regeneração fora de combate",
	"block_cap": "bloqueio máximo %", "atk_flat": "Ataque", "atk_pct": "Ataque %", "hp_flat": "Vida", "hp_pct": "Vida %",
	"def_flat": "Defesa", "def_pct": "Defesa %"}


static func rarity_color(it: Dictionary) -> String:
	return GameState.items_db["rarity_colors"].get(it["rarity"], "#ffffff")


static func tier_color(t: int) -> String:
	return GameState.items_db["tier_colors"][str(t)]


static func stat_name(stat: String) -> String:
	if GameState.affixes["stats"].has(stat):
		return GameState.affixes["stats"][stat]["name"]
	return stat


static func line(l: Dictionary) -> String:
	return "[color=%s]T%d[/color]  %s [b]+%s[/b]" % [tier_color(int(l["tier"])), int(l["tier"]), stat_name(l["stat"]), _num(float(l["value"]))]


static func bbcode(it: Dictionary) -> String:
	var db: Dictionary = GameState.items_db
	var s := "[font_size=24][color=%s][b]%s[/b][/color][/font_size]" % [rarity_color(it), it.get("name", "Item")]
	if int(it["refine"]) > 0:
		s += " [color=#ffd166][b]+%d[/b][/color]" % int(it["refine"])
	s += "\n[color=#8b8f99]%s · %s · nível %d%s[/color]\n" % [db["rarity_labels"].get(it["rarity"], ""), db["slots"][it["slot"]]["label"],
		int(it["item_level"]), " · [color=#ffd54f]Fortuna[/color]" if it.get("fortune", false) else ""]
	for k in Stats.item_base(it, db):
		s += "%s [b]+%s[/b]\n" % [stat_name(k), _num(Stats.item_base(it, db)[k])]
	for l in it["affixes"]:
		s += line(l) + "\n"
	var sid: String = it.get("set_id", "")
	if sid != "":
		var sdef: Dictionary = GameState.sets_db["sets"][sid]
		var have: int = SetBonus.evaluate(GameState.equipped_list(), GameState.sets_db).get(sid, {}).get("pieces", 0)
		s += "\n[color=#3fd67a]Set %s (%d/%d)[/color]\n" % [sdef["name"], have, sdef["slots"].size()]
		var keys: Array = sdef["bonuses"].keys()
		keys.sort()
		for k in keys:
			var on: bool = have >= int(k)
			var parts := []
			for st in sdef["bonuses"][k]:
				parts.append("%s +%s" % [stat_name(st), _num(float(sdef["bonuses"][k][st]))])
			s += "[color=%s]%s peças: %s[/color]\n" % ["#3fd67a" if on else "#5c616b", k, ", ".join(parts)]
	return s


static func stats_block(s: Dictionary) -> String:
	var out := "[color=#d9a441][b]Poder %d[/b][/color]   DPS [b]%d[/b]\n" % [Stats.power(s), int(Stats.dps(s))]
	for k in STAT_ORDER:
		out += "%s [b]%s[/b]\n" % [STAT_LABEL[k], _num(s[k])]
	return out


static func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return "%.1f" % v


static func short_zen(v: int) -> String:
	if v >= 1000000:
		return "%.1fM" % (v / 1000000.0)
	if v >= 10000:
		return "%.1fk" % (v / 1000.0)
	return str(v)
