## Colisão de nomes: nenhum nome exibido nos dados usa termos do Mu,
## do Torchlight Infinite ou do Diablo (lista em docs/naming.md).
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")

const FORBIDDEN := [
	"mu", "bless", "soul", "life", "chaos", "dragon", "wings", "fenrir", "blood castle",
	"devil square", "pentagram", "pactspirit", "vorax", "torchlight", "diablo", "sanctuary",
]


func _names(value, out: Array) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for k in value:
			if k == "name" and typeof(value[k]) == TYPE_STRING:
				out.append(value[k])
			else:
				_names(value[k], out)
	elif typeof(value) == TYPE_ARRAY:
		for v in value:
			_names(v, out)


func test_no_forbidden_terms_in_names() -> void:
	var names := []
	for d in [Config.economy(), Config.affixes(), Config.sets(), Config.shop()]:
		_names(d, names)
	check(names.size() > 10, "encontrou nomes")
	var re := RegEx.new()
	for term in FORBIDDEN:
		re.compile("(?i)\\b" + term + "\\b")
		for n in names:
			check(re.search(n) == null, "'%s' usa termo proibido '%s'" % [n, term])
