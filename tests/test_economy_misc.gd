## Unidade: carteira, lotes e preços em Lume.
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")
const Wallet = preload("res://core/wallet.gd")
const JewelLot = preload("res://core/jewel_lot.gd")
const Character = preload("res://core/character_state.gd")

var eco := Config.economy()


func test_lot_packing() -> void:
	eq(JewelLot.pack(65, eco), {"lots": [30, 30], "loose": 5}, "65")
	eq(JewelLot.pack(50, eco), {"lots": [30, 20], "loose": 0}, "50")
	eq(JewelLot.pack(9, eco), {"lots": [], "loose": 9}, "9")


func test_price_in_lume() -> void:
	eq(JewelLot.price_in_lume("brasa", 10, eco), 40, "10 Brasa")
	eq(JewelLot.price_in_lume("lume", 30, eco), 30, "lote de Lume")


func test_wallet_spend_is_atomic() -> void:
	var w = Wallet.new()
	w.add("lume", 5)
	w.add("zen", 10)
	check(not w.spend({"lume": 2, "zen": 50}), "falta Zen")
	eq(w.amount("lume"), 5, "nada gasto")
	check(w.spend({"lume": 2, "zen": 10}), "paga")
	eq(w.amount("lume"), 3, "Lume")


func test_character_roundtrip() -> void:
	var c = Character.new()
	c.level = 22
	c.pity = 4
	c.complete_challenge("first_ember")
	c.wallet.add("prisma", 3)
	var back = Character.from_dict(c.to_dict())
	eq(back.to_dict(), c.to_dict(), "save de ida e volta")
