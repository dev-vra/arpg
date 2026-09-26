## Fábricas compartilhadas pelos testes.
extends RefCounted

const Config = preload("res://core/config.gd")
const Character = preload("res://core/character_state.gd")
const Item = preload("res://core/item.gd")


static func character(level: int = 1, challenges: Array = []):
	var c = Character.new()
	c.level = level
	c.challenges = challenges.duplicate()
	return c


## Personagem com todos os tiers liberados.
static func maxed_character():
	return character(60, ["first_ember", "hollow_vale_hard", "map3_boss", "season_endgame"])


static func item_with_lines(slot: String, stats: Array, tier: int = 5) -> Dictionary:
	var it := Item.make(slot, 10)
	for s in stats:
		it["affixes"].append({"stat": s, "tier": tier, "value": 1.0})
	return it
