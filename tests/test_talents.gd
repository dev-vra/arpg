## Unidade: árvores de espírito (pontos por nível, linhas, alinhamento, bônus).
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")
const Talents = preload("res://core/talents.gd")
const Stats = preload("res://core/stats.gd")

var db := Config.data("talents")


func test_structure_25_points_per_tree() -> void:
	eq(db["trees"].size(), 3, "3 árvores")
	for t in db["trees"]:
		var sup := 0
		var inf := 0
		for n in t["nodes"]:
			check(int(n["max"]) in [1, 2], "máximo 1 ou 2")
			if n["side"] != "infernal":
				sup += int(n["max"])
			if n["side"] != "superior":
				inf += int(n["max"])
		eq(sup, 25, "%s completa com 25 (Superior)" % t["id"])
		eq(inf, 25, "%s completa com 25 (Infernal)" % t["id"])


func test_points_by_level_and_rows() -> void:
	var st := Talents.new_state()
	eq(Talents.available(1, st), 1, "1 ponto no nível 1")
	check(Talents.add(db, st, "juramento_0_s1", 3), "linha 0")
	eq(Talents.can_add(db, st, "juramento_1_s1", 3), "row_locked", "linha 1 exige 5 pontos")
	eq(Talents.can_add(db, st, "ascensao_0_s1", 20), "tree_locked", "árvore 2 só no 26")
	Talents.add(db, st, "juramento_0_s1", 3)
	eq(Talents.can_add(db, st, "juramento_0_s1", 3), "maxed", "máximo 2")
	Talents.add(db, st, "juramento_0_n", 3)
	eq(Talents.can_add(db, st, "juramento_0_n", 10), "maxed", "neutro máximo 1")
	eq(Talents.can_add(db, st, "juramento_0_s2", 3), "no_points", "sem pontos")


func test_alignment_locks_other_spirit_and_reset() -> void:
	var st := Talents.new_state()
	Talents.add(db, st, "juramento_0_i1", 10)
	eq(Talents.can_add(db, st, "juramento_0_s1", 10), "other_spirit", "lado Superior trancado")
	eq(Talents.can_add(db, st, "juramento_0_n", 10), "", "neutro livre")
	eq(Talents.spirit(db, st)["side"], "infernal", "espírito Infernal")
	eq(Talents.reset_tree(db, st, "juramento"), 1, "devolve pontos")
	eq(Talents.can_add(db, st, "juramento_0_s1", 10), "", "pode trocar de espírito")


func test_full_tree_and_bonuses_reach_stats() -> void:
	var st := Talents.new_state()
	var tree: Dictionary = db["trees"][0]
	var guard := 0
	while Talents.spent_in(tree, st) < 25 and guard < 200:
		guard += 1
		for n in tree["nodes"]:
			if n["side"] != "infernal":
				Talents.add(db, st, n["id"], 25)
	eq(Talents.spent_in(tree, st), 25, "árvore completa no nível 25")
	var b := Talents.bonuses(db, st)
	check(b["stats"].get("def_pct", 0.0) > 10.0, "bônus de defesa com espírito dobrado")
	check(b["skills"].has("brado"), "modificador de skill")
	var items := Config.data("items")
	var sets := Config.sets()
	var base := Stats.compute(25, [], items, sets)
	var with := Stats.compute(25, [], items, sets, [b["stats"]])
	check(with["def"] > base["def"] and with["max_hp"] > base["max_hp"], "talentos entram nos atributos")
