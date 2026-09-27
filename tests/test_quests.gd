## Unidade: missões (aceitar, abate, coleta, dungeon, entrega, cadeia) e comparação de itens.
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")
const Quests = preload("res://core/quests.gd")
const Rng = preload("res://core/rng.gd")
const Item = preload("res://core/item.gd")
const Stats = preload("res://core/stats.gd")

var db := Config.data("quests")


func test_chain_and_kill_progress() -> void:
	var st := Quests.new_state()
	eq(Quests.status(db, st, "q_dentes", 1), "locked", "exige a anterior")
	check(Quests.accept(db, st, "q_primeiros_passos", 1), "aceita")
	for i in 9:
		Quests.on_event(db, st, {"type": "kill", "mob": "servo", "map": "vale_oco"})
	Quests.on_event(db, st, {"type": "kill", "mob": "servo", "map": "criptas_rubras"})
	eq(Quests.progress(db, st, "q_primeiros_passos"), [9, 10], "outro mapa não conta")
	Quests.on_event(db, st, {"type": "kill", "mob": "espreitador", "map": "vale_oco"})
	eq(Quests.status(db, st, "q_primeiros_passos", 1), "ready", "pronta para entregar")
	var r := Quests.turn_in(db, st, "q_primeiros_passos")
	eq(r["zen"], 2000.0, "recompensa")
	eq(Quests.turn_in(db, st, "q_primeiros_passos"), {}, "não entrega duas vezes")
	eq(Quests.status(db, st, "q_dentes", 1), "available", "libera a próxima")


func test_collect_drops_only_while_active() -> void:
	var st := Quests.new_state()
	st["completed"].append("q_primeiros_passos")
	var rng = Rng.new(5)
	var got := 0
	for i in 50:
		got += Quests.drops_for_kill(db, st, "servo", rng).size()
	eq(got, 0, "sem missão ativa não cai")
	Quests.accept(db, st, "q_dentes", 1)
	for i in 50:
		for it in Quests.drops_for_kill(db, st, "servo", rng):
			got += 1
			Quests.on_event(db, st, {"type": "collect", "item": it})
	check(got >= 5, "caem dentes com a missão ativa")
	eq(Quests.drops_for_kill(db, st, "espreitador", rng), [], "só do mob certo")
	eq(Quests.status(db, st, "q_dentes", 1), "ready", "coleta completa")


func test_clear_and_min_level() -> void:
	var st := Quests.new_state()
	st["completed"] += ["q_primeiros_passos", "q_dentes", "q_carcereiro"]
	eq(Quests.status(db, st, "q_selos", 3), "locked", "nível mínimo")
	eq(Quests.status(db, st, "q_selos", 8), "available", "com nível")
	st["completed"] = ["q_primeiros_passos", "q_dentes"]
	Quests.accept(db, st, "q_carcereiro", 1)
	Quests.on_event(db, st, {"type": "clear", "map": "criptas_rubras"})
	eq(Quests.status(db, st, "q_carcereiro", 1), "active", "outra dungeon não conta")
	Quests.on_event(db, st, {"type": "clear", "map": "vale_oco"})
	eq(Quests.status(db, st, "q_carcereiro", 1), "ready", "dungeon limpa")


func test_compare_and_best_loadout() -> void:
	var items := Config.data("items")
	var sets := Config.sets()
	var weak := Item.make("weapon", 1)
	var strong := Item.make("weapon", 30)
	var eq := {"weapon": weak}
	var d := Stats.compare(10, eq, strong, items, sets)
	check(d["power"] > 0 and d["dps"] > 0 and d["atk"] > 0, "arma melhor aumenta poder e DPS")
	check(Stats.compare(10, {"weapon": strong}, weak, items, sets)["power"] < 0, "pior é negativo")
	var best := Stats.best_loadout(10, eq, [strong, Item.make("helm", 5)], items, sets)
	eq(best["weapon"], strong, "troca pela melhor")
	check(best.has("helm"), "preenche slot vazio")
