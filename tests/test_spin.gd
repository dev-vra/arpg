## Unidade: giro de atributos, trava de linha, custo em Prisma e Cinzas, Sigilo.
extends "res://tests/test_case.gd"

const H = preload("res://tests/helpers.gd")
const Config = preload("res://core/config.gd")
const Rng = preload("res://core/rng.gd")
const Spin = preload("res://core/affix_spin.gd")
const Sigil = preload("res://core/sigil.gd")

var eco := Config.economy()
var affix := Config.affixes()


func _rich(c) -> void:
	c.wallet.add("prisma", 1000)
	c.wallet.add("sigilo", 100)
	c.wallet.add("zen", 100000000)


func test_cost_grows_with_level_and_locks() -> void:
	var it := H.item_with_lines("weapon", ["atk_flat", "atk_pct", "crit_chance"])
	var c0 := Spin.cost(it, [], eco)
	var c1 := Spin.cost(it, [0], eco)
	var c2 := Spin.cost(it, [0, 1], eco)
	eq(c0["prisma"], 1, "1 Prisma por giro")
	eq(c0["zen"], 1500, "1000 + 50 × nível 10")
	check(c1["zen"] > c0["zen"] and c2["zen"] > c1["zen"], "trava soma Cinzas")
	it["item_level"] = 40
	check(Spin.cost(it, [], eco)["zen"] > c0["zen"], "nível do item soma Cinzas")


func test_locks_are_kept_and_limited() -> void:
	var c = H.maxed_character()
	_rich(c)
	var rng = Rng.new(42)
	var it := H.item_with_lines("weapon", ["atk_flat", "atk_pct", "crit_chance", "crit_damage"])
	var locked0: Dictionary = it["affixes"][0].duplicate()
	var locked2: Dictionary = it["affixes"][2].duplicate()
	for i in 50:
		var r := Spin.spin(it, [0, 2], c, eco, affix, rng)
		check(r["ok"], "giro %d" % i)
		eq(it["affixes"][0], locked0, "linha 0 travada")
		eq(it["affixes"][2], locked2, "linha 2 travada")
	var r3 := Spin.spin(it, [0, 1, 2], c, eco, affix, rng)
	eq(r3.get("error"), "too_many_locks", "limite de 2 travas")


func test_spin_never_fails_and_no_duplicate_stats() -> void:
	var c = H.maxed_character()
	_rich(c)
	var rng = Rng.new(7)
	var it := H.item_with_lines("helm", ["hp_flat", "hp_pct", "def_flat", "def_pct", "cooldown", "resist_all"])
	for i in 200:
		var r := Spin.spin(it, [], c, eco, affix, rng)
		check(r["ok"], "giro sempre entrega")
		var seen := {}
		for line in it["affixes"]:
			check(not seen.has(line["stat"]), "atributo repetido")
			seen[line["stat"]] = true
			check(line["tier"] >= 1 and line["tier"] <= 5, "tier válido")
			var d: Dictionary = affix["stats"][line["stat"]]
			check(line["value"] >= d["min"] and line["value"] <= d["max"], "valor na faixa")


func test_spin_respects_unlocked_tiers() -> void:
	var c = H.character(1)
	_rich(c)
	var rng = Rng.new(3)
	var it := H.item_with_lines("weapon", ["atk_flat", "atk_pct", "crit_chance"])
	for i in 100:
		Spin.spin(it, [], c, eco, affix, rng)
		for line in it["affixes"]:
			eq(line["tier"], 5, "só T5 liberado")


func test_spin_charges_prisma_and_zen() -> void:
	var c = H.maxed_character()
	c.wallet.add("prisma", 1)
	c.wallet.add("zen", 1500)
	var it := H.item_with_lines("weapon", ["atk_flat"])
	var r := Spin.spin(it, [], c, eco, affix, Rng.new(1))
	check(r["ok"], "giro pago")
	eq(c.wallet.amount("prisma"), 0, "Prisma consumida")
	eq(c.wallet.amount("zen"), 0, "Cinzas consumido")
	var r2 := Spin.spin(it, [], c, eco, affix, Rng.new(1))
	eq(r2.get("error"), "insufficient", "sem recursos")


func test_pity_counts_and_resets() -> void:
	var c = H.character(30, ["first_ember", "hollow_vale_hard"])
	_rich(c)
	var rng = Rng.new(11)
	var it := H.item_with_lines("weapon", ["atk_flat"])
	var saw_reset := false
	var prev := 0
	for i in 300:
		var r := Spin.spin(it, [], c, eco, affix, rng)
		if r["best_tier"] <= 3:
			eq(c.pity, 0, "zera ao sair T3 ou melhor")
			if prev > 0:
				saw_reset = true
		else:
			eq(c.pity, mini(prev + 1, 20), "soma sem T3+")
		prev = c.pity
	check(saw_reset, "Piedade zerou ao menos uma vez")


func test_preview_lists_chances_and_locked_tiers() -> void:
	var c = H.character(15, ["first_ember"])
	var it := H.item_with_lines("weapon", ["atk_flat", "atk_pct"])
	var p := Spin.preview(it, [0], c, eco)
	eq(p["error"], "", "válido")
	near(p["chances"][4] + p["chances"][5], 100.0, 1e-6, "só T4 e T5")
	eq(p["tiers"].filter(func(t): return not t["unlocked"]).size(), 3, "3 bloqueados")


func test_sigil_adds_line_up_to_six() -> void:
	var c = H.maxed_character()
	_rich(c)
	var rng = Rng.new(5)
	var it := H.item_with_lines("weapon", [])
	for i in 6:
		var r := Sigil.add_line(it, c, eco, affix, rng)
		check(r["ok"], "Sigilo %d" % i)
	eq(it["affixes"].size(), 6, "6 linhas")
	eq(Sigil.add_line(it, c, eco, affix, rng).get("error"), "max_lines", "limite")
	eq(c.wallet.amount("sigilo"), 94, "6 Sigilos gastos")
