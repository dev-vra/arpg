## Unidade: chances de tier, desbloqueio, Fortuna e Piedade.
extends "res://tests/test_case.gd"

const H = preload("res://tests/helpers.gd")
const Config = preload("res://core/config.gd")
const TierTable = preload("res://core/tier_table.gd")
const TierUnlocks = preload("res://core/tier_unlocks.gd")

var eco := Config.economy()


func _sum(t: Dictionary) -> float:
	var s := 0.0
	for k in t:
		s += t[k]
	return s


func test_base_table_matches_spec() -> void:
	var t := TierTable.chances(eco, [1, 2, 3, 4, 5], false, 0)
	near(t[1], 3.0, 1e-6, "T1")
	near(t[2], 9.0, 1e-6, "T2")
	near(t[3], 20.0, 1e-6, "T3")
	near(t[4], 28.0, 1e-6, "T4")
	near(t[5], 40.0, 1e-6, "T5")


func test_new_character_only_t5() -> void:
	var c = H.character(1)
	eq(TierUnlocks.unlocked_tiers(c, eco), [5], "nível 1")
	var t := TierTable.chances(eco, [5], true, 10)
	near(t[5], 100.0, 1e-6, "só T5 liberado dá 100% T5 mesmo com Fortuna e Piedade")


func test_unlock_needs_level_and_challenge() -> void:
	var c = H.character(30, ["first_ember"])
	eq(TierUnlocks.unlocked_tiers(c, eco), [4, 5], "nível 30 sem Vale Oco")
	c.complete_challenge("hollow_vale_hard")
	eq(TierUnlocks.unlocked_tiers(c, eco), [3, 4, 5], "nível 30 com Vale Oco")
	var low = H.character(10, ["first_ember"])
	eq(TierUnlocks.unlocked_tiers(low, eco), [5], "desafio sem nível não libera")


func test_locked_tier_redistributed_proportionally() -> void:
	var t := TierTable.chances(eco, [3, 4, 5], false, 0)
	near(t[1] + t[2], 0.0, 1e-9, "bloqueados zerados")
	near(t[3], 20.0 * 100.0 / 88.0, 1e-6, "T3")
	near(t[5], 40.0 * 100.0 / 88.0, 1e-6, "T5")
	near(_sum(t), 100.0, 1e-6, "soma")


func test_requirements_text_for_locked() -> void:
	var reqs := TierUnlocks.requirements(H.character(1), eco)
	var t3 = reqs.filter(func(r): return r["tier"] == 3)[0]
	check(not t3["unlocked"], "T3 bloqueado")
	eq(t3["requirement"], "Nível 30 e desafio Vale Oco", "texto do requisito")


func test_fortune_moves_from_t5_t4_to_t1_t2() -> void:
	var t := TierTable.chances(eco, [1, 2, 3, 4, 5], true, 0)
	near(t[1], 5.0, 1e-6, "T1 com Fortuna")
	near(t[2], 13.0, 1e-6, "T2 com Fortuna")
	near(t[3], 20.0, 1e-6, "T3 intocado")
	check(t[5] < 40.0 and t[4] < 28.0, "doadores perdem")
	near(_sum(t), 100.0, 1e-6, "soma")


func test_fortune_only_acts_on_unlocked() -> void:
	var with_f := TierTable.chances(eco, [3, 4, 5], true, 0)
	var without := TierTable.chances(eco, [3, 4, 5], false, 0)
	for k in [3, 4, 5]:
		near(with_f[k], without[k], 1e-9, "T%d sem alvo liberado" % k)


func test_pity_grows_and_caps() -> void:
	var all := [1, 2, 3, 4, 5]
	var p0 := TierTable.chances(eco, all, false, 0)
	var p5 := TierTable.chances(eco, all, false, 5)
	var pmax := TierTable.chances(eco, all, false, 20)
	var pover := TierTable.chances(eco, all, false, 999)
	check(p5[1] > p0[1] and p5[2] > p0[2], "Piedade sobe T1 e T2")
	near(pmax[1], pover[1], 1e-9, "Piedade tem teto")
	near(_sum(p5), 100.0, 1e-6, "soma")
	for k in all:
		check(pmax[k] >= 0.0, "nenhuma chance negativa")
