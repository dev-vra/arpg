## Simulador de economia: agentes farmam, refinam e giram por política simples.
## Relata horas até o primeiro set completo e joias paradas (sem sumidouro).
## Uso: godot --headless --path . -s sim/economy_sim.gd
extends SceneTree

const Config = preload("res://core/config.gd")
const Rng = preload("res://core/rng.gd")
const Character = preload("res://core/character_state.gd")
const Item = preload("res://core/item.gd")
const Refine = preload("res://core/refine.gd")
const Spin = preload("res://core/affix_spin.gd")
const Sigil = preload("res://core/sigil.gd")
const SetBonus = preload("res://core/set_bonus.gd")

const REFINE_TARGET := 6


func _init() -> void:
	var eco := Config.economy()
	var affix := Config.affixes()
	var sets := Config.sets()
	var cfg: Dictionary = eco["sim"]
	var hours := []
	var earned := {}
	var left := {}
	for a in int(cfg["agents"]):
		var r := _agent(eco, affix, sets, Rng.new(1000 + a), float(cfg["max_hours"]))
		hours.append(r["hours"])
		for k in r["earned"]:
			earned[k] = earned.get(k, 0.0) + r["earned"][k]
			left[k] = left.get(k, 0.0) + r["left"].get(k, 0)
	hours.sort()
	var median: float = hours[hours.size() / 2]
	var p90: float = hours[int(hours.size() * 0.9)]
	var target: Array = cfg["target_first_set_hours"]
	print("Primeiro set completo: mediana %.1f h, p90 %.1f h (alvo %s h)" % [median, p90, str(target)])
	var ok: bool = median >= float(target[0]) and median <= float(target[1])
	for k in earned:
		var ratio: float = left[k] / maxf(earned[k], 1.0)
		print("  %-8s ganho %10.0f  parado %5.1f%%" % [k, earned[k], ratio * 100.0])
		if k != "zen" and ratio > float(cfg["max_unspent_ratio"]):
			print("  AVISO: %s acumula sem sumidouro" % k)
			ok = false
	print("RESULTADO: " + ("OK" if ok else "FORA DO ALVO"))
	quit(0 if ok else 1)


func _agent(eco: Dictionary, affix: Dictionary, sets: Dictionary, rng, max_hours: float) -> Dictionary:
	var d: Dictionary = eco["drops"]
	var c = Character.new()
	var equipped := {}
	var earned := {}
	var minutes := 0.0
	while minutes < max_hours * 60.0:
		minutes += float(d["run_minutes"])
		c.level = mini(1 + int(minutes / 60.0 * float(d["levels_per_hour"])), int(d["max_level"]))
		_challenges(c, equipped)
		for k in d["per_run"]:
			var avg := float(d["per_run"][k])
			var n := int(avg) + (1 if rng.randf() < avg - int(avg) else 0)
			if k == "zen":
				n = int(avg * rng.randf_range(0.5, 1.5))
			c.wallet.add(k, n)
			earned[k] = earned.get(k, 0) + n
		if rng.randf() < float(d["set_piece_chance"]):
			var slot: String = rng.pick(sets["sets"][d["set_id"]]["slots"])
			if not equipped.has(slot):
				var it := Item.make(slot, c.level, d["set_id"])
				Sigil.add_line(it, c, eco, affix, rng)
				equipped[slot] = it
		_spend(c, equipped, eco, affix, rng)
		if SetBonus.evaluate(equipped.values(), sets).get(d["set_id"], {}).get("complete", false):
			break
	return {"hours": minutes / 60.0, "earned": earned, "left": c.wallet.to_dict()["jewels"].merged({"zen": c.wallet.zen})}


func _challenges(c, equipped: Dictionary) -> void:
	if c.level >= 15 and not equipped.is_empty():
		c.complete_challenge("first_ember")
	if c.level >= 30:
		c.complete_challenge("hollow_vale_hard")
	if c.level >= 45:
		c.complete_challenge("map3_boss")


## Política: refina tudo até +6 (depois até o teto), cria linhas com Sigilo, gira com o que sobrar.
func _spend(c, equipped: Dictionary, eco: Dictionary, affix: Dictionary, rng) -> void:
	for it in equipped.values():
		while (it["refine"] < REFINE_TARGET or c.level >= 30) and Refine.refine(it, c, eco)["ok"]:
			pass
		while Sigil.add_line(it, c, eco, affix, rng)["ok"]:
			pass
		if it["affixes"].size() > 0:
			while Spin.spin(it, [0] if it["affixes"].size() > 1 else [], c, eco, affix, rng)["ok"]:
				pass
