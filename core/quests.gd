## Missões: aceitar, progredir por eventos (abate, coleta, dungeon limpa) e entregar.
## Puro, sem cena. Estado serializável:
## {"active": {id: progresso}, "done": [ids prontos para entregar], "completed": [ids entregues]}
## Itens de missão não ocupam a mochila; caem só com a missão ativa.
extends RefCounted


static func new_state() -> Dictionary:
	return {"active": {}, "done": [], "completed": []}


static func find(db: Dictionary, id: String) -> Dictionary:
	for q in db["quests"]:
		if q["id"] == id:
			return q
	return {}


static func status(db: Dictionary, st: Dictionary, id: String, level: int) -> String:
	if st["completed"].has(id):
		return "completed"
	if st["done"].has(id):
		return "ready"
	if st["active"].has(id):
		return "active"
	var q := find(db, id)
	for r in q.get("requires", []):
		if not st["completed"].has(r):
			return "locked"
	if level < int(q.get("min_level", 1)):
		return "locked"
	return "available"


static func accept(db: Dictionary, st: Dictionary, id: String, level: int) -> bool:
	if status(db, st, id, level) != "available":
		return false
	st["active"][id] = 0
	return true


## Evento: {"type": "kill", "mob", "map"} | {"type": "collect", "item"} | {"type": "clear", "map"}.
## Retorna ids que avançaram.
static func on_event(db: Dictionary, st: Dictionary, ev: Dictionary) -> Array:
	var moved := []
	for id in st["active"].keys():
		var g: Dictionary = find(db, id)["goal"]
		if not _matches(g, ev):
			continue
		st["active"][id] = mini(int(st["active"][id]) + 1, int(g["count"]))
		moved.append(id)
		if int(st["active"][id]) >= int(g["count"]):
			st["active"].erase(id)
			st["done"].append(id)
	return moved


static func _matches(g: Dictionary, ev: Dictionary) -> bool:
	if g["type"] != ev["type"]:
		return false
	match g["type"]:
		"kill":
			return (g["mob"] == "any" or g["mob"] == ev.get("mob")) and (not g.has("map") or g["map"] == ev.get("map"))
		"collect":
			return g["item"] == ev.get("item")
		"clear":
			return g["map"] == ev.get("map")
	return false


## Itens de missão que caem deste abate (só para missões de coleta ativas).
static func drops_for_kill(db: Dictionary, st: Dictionary, mob_id: String, rng) -> Array:
	var out := []
	for id in st["active"]:
		var g: Dictionary = find(db, id)["goal"]
		if g["type"] == "collect" and g["mob"] == mob_id and rng.randf() < float(g["chance"]):
			out.append(g["item"])
	return out


## Entrega: move para concluídas e devolve a recompensa (quem chama aplica).
static func turn_in(db: Dictionary, st: Dictionary, id: String) -> Dictionary:
	if not st["done"].has(id):
		return {}
	st["done"].erase(id)
	st["completed"].append(id)
	return find(db, id)["reward"]


static func progress(db: Dictionary, st: Dictionary, id: String) -> Array:
	var g: Dictionary = find(db, id)["goal"]
	var n := int(g["count"]) if st["done"].has(id) or st["completed"].has(id) else int(st["active"].get(id, 0))
	return [n, int(g["count"])]
