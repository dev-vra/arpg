## Gerador aleatório com semente injetável.
## Todo sorteio do núcleo passa por aqui, para testes e simulação reproduzíveis.
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Sorteia uma chave de um dicionário {chave: peso}. Pesos zero nunca saem.
func weighted_pick(weights: Dictionary):
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := _rng.randf() * total
	var last = null
	for k in weights:
		var w := float(weights[k])
		if w <= 0.0:
			continue
		last = k
		roll -= w
		if roll < 0.0:
			return k
	return last


func pick(values: Array):
	return values[_rng.randi_range(0, values.size() - 1)]
