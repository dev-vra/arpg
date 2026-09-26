## Estado de progressão de um personagem que o núcleo precisa conhecer:
## nível, desafios concluídos, contador de Piedade e carteira.
## A liberação de tiers é por personagem.
extends RefCounted

const Wallet = preload("res://core/wallet.gd")

var level: int = 1
var challenges: Array = []
var pity: int = 0
var wallet = Wallet.new()


func has_challenge(id: String) -> bool:
	return challenges.has(id)


func complete_challenge(id: String) -> void:
	if not challenges.has(id):
		challenges.append(id)


func to_dict() -> Dictionary:
	return {
		"level": level,
		"challenges": challenges.duplicate(),
		"pity": pity,
		"wallet": wallet.to_dict(),
	}


static func from_dict(d: Dictionary):
	var c = load("res://core/character_state.gd").new()
	c.level = int(d.get("level", 1))
	c.challenges = d.get("challenges", []).duplicate()
	c.pity = int(d.get("pity", 0))
	c.wallet = Wallet.from_dict(d.get("wallet", {}))
	return c
