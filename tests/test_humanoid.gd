## Boneco modular: equipar esconde a pele coberta (máscara por osso), trocar de
## raridade troca as peças, e o set completo liga a aura. Precisa da árvore de cena.
extends "res://tests/test_case.gd"

const HeroVisual = preload("res://game/actors/hero_visual.gd")
const Item = preload("res://core/item.gd")


func _hero():
	var v = HeroVisual.new()
	Engine.get_main_loop().root.add_child(v)
	return v


func _hidden(v, bone: String) -> bool:
	var mask: PackedFloat32Array = v.body_mat.get_shader_parameter("hide_bone")
	return mask[v.skeleton.find_bone(bone)] > 0.5


func test_armor_hides_torso_and_unequip_restores() -> void:
	var v = _hero()
	var armor := Item.make("armor", 1)
	v.apply_loadout({"armor": armor})
	check(_hidden(v, "spine_02"), "tronco escondido sob a armadura")
	check(not _hidden(v, "thigh_l"), "perna à mostra")
	check(v.parts.has("armor") and v.parts["armor"].size() > 0, "peça montada")
	v.apply_loadout({})
	check(not _hidden(v, "spine_02"), "desequipar mostra o tronco")
	v.free()


func test_helm_hides_hair() -> void:
	var v = _hero()
	v.apply_loadout({"helm": Item.make("helm", 1)})
	for n in v.hair_nodes:
		check(not n.visible, "cabelo some sob o capuz")
	v.free()


func test_full_set_lights_aura_and_rebuild_is_cached() -> void:
	var v = _hero()
	var eq := {}
	for s in ["helm", "armor", "gloves", "pants", "boots"]:
		eq[s] = Item.make(s, 1, "ferro_vigilia")
		eq[s]["uid"] = s
	v.apply_loadout(eq)
	check(v.aura_fx.emitting, "aura no set completo")
	var node = v.parts["armor"][0]
	v.apply_loadout(eq)
	check(v.parts["armor"][0] == node, "sem mudança não remonta")
	v.free()
