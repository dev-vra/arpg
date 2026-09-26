## Contrato do catálogo da loja: nenhum produto altera atributo, chance ou acesso.
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")

var shop := Config.shop()


func _scan(value, forbidden: Array, path: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for k in value:
			check(not forbidden.has(str(k).to_lower()), "chave proibida '%s' em %s" % [k, path])
			_scan(value[k], forbidden, path + "." + str(k))
	elif typeof(value) == TYPE_ARRAY:
		for i in value.size():
			_scan(value[i], forbidden, "%s[%d]" % [path, i])


func test_no_power_in_catalog() -> void:
	var forbidden: Array = shop["forbidden_keys"]
	for p in shop["products"]:
		check(shop["allowed_kinds"].has(p["kind"]), "tipo não permitido: %s" % p["kind"])
		_scan(p, forbidden, p["id"])


func test_convenience_has_cap() -> void:
	for p in shop["products"]:
		if p["kind"] in ["character_slot", "stash_tab"]:
			check(shop["caps"].has(p["kind"]), "conveniência sem teto: %s" % p["id"])


func test_contract_catches_violation() -> void:
	var bad := {"id": "x", "kind": "equipment_skin", "grants": {"stats": {"atk": 5}}}
	var before := failures.size()
	_scan(bad, shop["forbidden_keys"], "x")
	var caught := failures.size() > before
	failures.resize(before)
	check(caught, "o contrato precisa pegar produto com atributo")
