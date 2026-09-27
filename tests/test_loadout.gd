## Montagem do boneco (lógica, sem render): peça esconde a parte do corpo,
## brilho sobe em +9/+12/+15, set completo liga a aura.
extends "res://tests/test_case.gd"

const Rig = preload("res://game/character/character_rig.gd")
const Item = preload("res://core/item.gd")


func _rig():
	var r = Rig.new()
	r._ready()
	return r


func test_piece_hides_body_part() -> void:
	var r = _rig()
	r.apply_loadout([Item.make("helm", 1, "ferro_vigilia")])
	check(not r.body["head"].visible, "cabeça escondida")
	check(r.armor["head"] != null, "elmo montado")
	check(r.body["torso"].visible, "tronco visível")
	r.apply_loadout([])
	check(r.body["head"].visible and r.armor["head"] == null, "desequipar restaura")
	r.free()


func test_glow_steps() -> void:
	var r = _rig()
	eq(r.glow_for(8), 0.0, "+8")
	check(r.glow_for(9) > 0.0, "+9 brilha")
	check(r.glow_for(12) > r.glow_for(9) and r.glow_for(15) > r.glow_for(12), "cresce")
	r.free()


func test_full_set_turns_on_aura() -> void:
	var r = _rig()
	var lo := []
	for s in ["helm", "armor", "gloves", "pants", "boots"]:
		lo.append(Item.make(s, 1, "ferro_vigilia"))
	r.apply_loadout(lo.slice(0, 4))
	check(not r.aura.visible, "4 peças sem aura")
	r.apply_loadout(lo)
	check(r.aura.visible, "set completo com aura")
	r.free()
