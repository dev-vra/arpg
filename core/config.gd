## Carrega os arquivos de dados (JSON) usados pelo núcleo.
## Tudo em data/ é versionado; mudar número não exige build.
extends RefCounted

const ECONOMY_PATH := "res://data/economy.json"
const AFFIXES_PATH := "res://data/affixes.json"
const SETS_PATH := "res://data/sets.json"
const SHOP_PATH := "res://data/shop.json"


static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Não foi possível abrir %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON inválido em %s" % path)
		return {}
	return parsed


static func economy() -> Dictionary:
	return load_json(ECONOMY_PATH)


static func affixes() -> Dictionary:
	return load_json(AFFIXES_PATH)


static func sets() -> Dictionary:
	return load_json(SETS_PATH)


static func shop() -> Dictionary:
	return load_json(SHOP_PATH)
