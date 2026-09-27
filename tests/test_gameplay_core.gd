## Unidade: atributos, loot de campo, XP, reciclagem, save assinado e mapas.
extends "res://tests/test_case.gd"

const H = preload("res://tests/helpers.gd")
const Config = preload("res://core/config.gd")
const Rng = preload("res://core/rng.gd")
const Item = preload("res://core/item.gd")
const Stats = preload("res://core/stats.gd")
const Loot = preload("res://core/loot.gd")
const Progression = preload("res://core/progression.gd")
const Salvage = preload("res://core/salvage.gd")
const SaveFile = preload("res://core/save_file.gd")

var eco := Config.economy()
var items := Config.data("items")
var sets := Config.sets()
var maps := Config.data("maps")


func _ctx(seed_value: int, c = null) -> Dictionary:
	return {"economy": eco, "affixes": Config.affixes(), "items": items, "sets": sets,
		"character": c if c != null else H.character(1), "rng": Rng.new(seed_value)}


func test_equipment_raises_stats_and_refine_helps() -> void:
	var naked := Stats.compute(10, [], items, sets)
	var armor := Item.make("armor", 10)
	var dressed := Stats.compute(10, [armor], items, sets)
	check(dressed["def"] > naked["def"] and dressed["max_hp"] > naked["max_hp"], "armadura soma")
	armor["refine"] = 9
	check(Stats.compute(10, [armor], items, sets)["def"] > dressed["def"], "refino soma")


func test_set_bonus_in_stats() -> void:
	var lo := []
	for s in ["helm", "armor", "gloves", "pants", "boots"]:
		lo.append(Item.make(s, 1, "ferro_vigilia"))
	var four := Stats.compute(1, lo.slice(0, 4), items, sets)
	var five := Stats.compute(1, lo, items, sets)
	check(five["atk"] > four["atk"], "bônus de 5 peças entra (atk %)")


func test_mitigation_never_zero() -> void:
	var d := Stats.mitigate(100.0, 100000.0, 1)
	check(d > 0.0 and d < 100.0, "mitiga sem zerar")


func test_field_loot_valid() -> void:
	var ctx := _ctx(9)
	var map: Dictionary = maps["maps"]["vale_oco"]
	var got_item := false
	for i in 400:
		for drop in Loot.roll_kill(ctx, map, "normal", false):
			if drop["kind"] == "item":
				got_item = true
				var it: Dictionary = drop["item"]
				check(it["affixes"].size() >= 1, "item com linhas")
				check(it["name"] != "", "item com nome")
				for line in it["affixes"]:
					eq(line["tier"], 5, "nível 1 só dropa T5")
			else:
				check(drop["amount"] > 0, "moeda positiva")
	check(got_item, "algum item em 400 abates")


func test_boss_drops_items_and_set_piece_eventually() -> void:
	var ctx := _ctx(4)
	var map: Dictionary = maps["maps"]["vale_oco"]
	var set_pieces := 0
	for i in 30:
		for drop in Loot.roll_kill(ctx, map, "normal", true):
			if drop["kind"] == "item" and drop["item"]["set_id"] != "":
				set_pieces += 1
				check(map["sets"].has(drop["item"]["set_id"]), "set do mapa")
	check(set_pieces > 5, "chefe dropa peças de set (%d)" % set_pieces)


func test_xp_levels_up() -> void:
	var st := {"level": 1, "xp": 0}
	var need := Progression.xp_to_next(1, eco)
	eq(Progression.add_xp(st, need * 3, eco) >= 1, true, "sobe")
	check(Progression.xp_to_next(10, eco) > Progression.xp_to_next(2, eco), "curva cresce")


func test_salvage_pays() -> void:
	var c = H.character()
	var it := Item.make("helm", 10)
	it["rarity"] = "superior"
	var v := Salvage.salvage(it, c, eco)
	check(c.wallet.amount("zen") == v["zen"] and v["zen"] > 0, "Cinzas")
	eq(c.wallet.amount("lume"), 1, "Lume")


func test_signed_save_roundtrip_and_tamper() -> void:
	var path := "user://test_save.json"
	check(SaveFile.write(path, {"level": 7}), "grava")
	eq(SaveFile.read(path).get("level"), 7.0, "lê")
	var txt := FileAccess.get_file_as_string(path).replace("7", "99")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	eq(SaveFile.read(path), {}, "save editado é recusado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_maps_well_formed() -> void:
	for id in maps["maps"]:
		var m: Dictionary = maps["maps"][id]
		var rows: Array = m["rows"]
		var spawn := 0
		for r in rows:
			eq(r.length(), rows[0].length(), "%s linhas iguais" % id)
			spawn += r.count("P")
		eq(spawn, 1, "%s um spawn" % id)
		if m["kind"] == "field":
			var mobs: Dictionary = Config.data("mobs")["mobs"]
			check(mobs.has(m["boss"]), "%s chefe existe" % id)
			for mid in m["mobs"]:
				check(mobs.has(mid), "%s mob %s existe" % [id, mid])
