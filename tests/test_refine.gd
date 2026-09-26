## Unidade: refino sempre sobe, custo cresce, joia muda por faixa.
extends "res://tests/test_case.gd"

const H = preload("res://tests/helpers.gd")
const Config = preload("res://core/config.gd")
const Item = preload("res://core/item.gd")
const Refine = preload("res://core/refine.gd")

var eco := Config.economy()


func test_refine_always_goes_up() -> void:
	var c = H.character()
	c.wallet.add("lume", 100)
	c.wallet.add("brasa", 100)
	var it := Item.make("weapon", 10)
	for lvl in range(1, 13):
		var r := Refine.refine(it, c, eco)
		check(r["ok"], "refino para +%d" % lvl)
		eq(it["refine"], lvl, "nível após refino")


func test_jewel_by_band_and_growing_cost() -> void:
	var it := Item.make("weapon", 10)
	var prev := 0
	for lvl in range(0, 6):
		it["refine"] = lvl
		var cost := Refine.next_cost(it, eco)
		check(cost.has("lume"), "+%d→+%d usa Lume" % [lvl, lvl + 1])
		check(int(cost["lume"]) >= prev, "custo não diminui")
		prev = int(cost["lume"])
	for lvl in range(6, 12):
		it["refine"] = lvl
		check(Refine.next_cost(it, eco).has("brasa"), "+%d→+%d usa Brasa" % [lvl, lvl + 1])


func test_mvp_cap_at_12() -> void:
	var it := Item.make("weapon", 10)
	it["refine"] = 12
	var c = H.character()
	c.wallet.add("aurora", 99)
	var r := Refine.refine(it, c, eco)
	check(not r["ok"] and r["error"] == "max_level", "Aurora fica para a fase 4")
	eq(it["refine"], 12, "item intacto")


func test_insufficient_keeps_everything() -> void:
	var it := Item.make("weapon", 10)
	it["refine"] = 5
	var c = H.character()
	c.wallet.add("lume", 1)
	var r := Refine.refine(it, c, eco)
	check(not r["ok"] and r["error"] == "insufficient", "sem joias")
	eq(r["missing"], {"lume": 3}, "falta mostrada (custo 4, tem 1)")
	eq(it["refine"], 5, "nível intacto")
	eq(c.wallet.amount("lume"), 1, "joia não é consumida")


func test_preview_shows_certain_success() -> void:
	var it := Item.make("helm", 1)
	var p := Refine.preview(it, eco)
	eq(p["success_chance"], 1.0, "chance")
	eq(p["to"], 1, "destino")
