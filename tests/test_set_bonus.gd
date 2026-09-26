## Unidade: bônus de set em degraus e mistura de sets.
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")
const Item = preload("res://core/item.gd")
const SetBonus = preload("res://core/set_bonus.gd")

var sets := Config.sets()


func _piece(slot: String, sid: String) -> Dictionary:
	return Item.make(slot, 10, sid)


func test_steps_2_to_5() -> void:
	var slots := ["helm", "armor", "gloves", "pants", "boots"]
	var equipped := []
	for i in slots.size():
		equipped.append(_piece(slots[i], "ferro_vigilia"))
		var r := SetBonus.evaluate(equipped, sets)
		var n := i + 1
		if n < 2:
			check(r["ferro_vigilia"]["active_steps"].is_empty(), "1 peça sem bônus")
		else:
			eq(r["ferro_vigilia"]["active_steps"].back(), n, "degrau %d" % n)
	var full := SetBonus.evaluate(equipped, sets)
	check(full["ferro_vigilia"]["complete"], "set completo")
	eq(full["_total"]["def_flat"], 20.0, "bônus de 2")
	eq(full["_total"]["def_pct"], 10.0, "bônus de 5")


func test_mixed_sets() -> void:
	var equipped := [
		_piece("helm", "ferro_vigilia"), _piece("armor", "ferro_vigilia"),
		_piece("gloves", "mares_rubras"), _piece("pants", "mares_rubras"), _piece("boots", "mares_rubras"),
	]
	var r := SetBonus.evaluate(equipped, sets)
	eq(r["ferro_vigilia"]["active_steps"], [2], "Ferro-Vigília 2 peças")
	eq(r["mares_rubras"]["active_steps"], [2, 3], "Marés Rubras 3 peças")
	check(not r["ferro_vigilia"]["complete"], "incompleto")


func test_duplicate_slot_counts_once() -> void:
	var equipped := [_piece("helm", "ferro_vigilia"), _piece("helm", "ferro_vigilia")]
	var r := SetBonus.evaluate(equipped, sets)
	eq(r["ferro_vigilia"]["pieces"], 1, "mesmo slot conta uma vez")
