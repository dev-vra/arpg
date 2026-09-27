## Árvores de espírito: 3 árvores de 25 pontos (1 ponto por nível).
## Cada linha tem 2 nós Superiores (máx. 2), 1 neutro (máx. 1) e 2 Infernais (máx. 2).
## O primeiro ponto num lado alinha a árvore àquele espírito e tranca o outro lado:
## o espírito depende dos atributos que o jogador ativa. Linha r exige 5r pontos na árvore.
## Puro, sem cena. Estado: {"points": {node_id: n}}.
extends RefCounted


static func new_state() -> Dictionary:
	return {"points": {}}


static func node(db: Dictionary, id: String) -> Dictionary:
	for t in db["trees"]:
		for n in t["nodes"]:
			if n["id"] == id:
				return n
	return {}


static func tree_of(db: Dictionary, id: String) -> Dictionary:
	for t in db["trees"]:
		for n in t["nodes"]:
			if n["id"] == id:
				return t
	return {}


static func spent(st: Dictionary) -> int:
	var s := 0
	for k in st["points"]:
		s += int(st["points"][k])
	return s


static func available(level: int, st: Dictionary) -> int:
	return level - spent(st)


static func spent_in(tree: Dictionary, st: Dictionary) -> int:
	var s := 0
	for n in tree["nodes"]:
		s += int(st["points"].get(n["id"], 0))
	return s


## Lado ao qual a árvore está alinhada ("superior", "infernal" ou "").
static func alignment(tree: Dictionary, st: Dictionary) -> String:
	for n in tree["nodes"]:
		if n["side"] != "neutral" and int(st["points"].get(n["id"], 0)) > 0:
			return n["side"]
	return ""


## "" se pode investir; senão o motivo.
static func can_add(db: Dictionary, st: Dictionary, id: String, level: int) -> String:
	var n := node(db, id)
	if n.is_empty():
		return "no_node"
	var t := tree_of(db, id)
	if level < int(t["unlock_level"]):
		return "tree_locked"
	if available(level, st) <= 0:
		return "no_points"
	if int(st["points"].get(id, 0)) >= int(n["max"]):
		return "maxed"
	if spent_in(t, st) < int(n["row"]) * int(db["row_cost"]):
		return "row_locked"
	var al := alignment(t, st)
	if n["side"] != "neutral" and al != "" and al != n["side"]:
		return "other_spirit"
	return ""


static func add(db: Dictionary, st: Dictionary, id: String, level: int) -> bool:
	if can_add(db, st, id, level) != "":
		return false
	st["points"][id] = int(st["points"].get(id, 0)) + 1
	return true


## Devolve os pontos de uma árvore (troca de espírito).
static func reset_tree(db: Dictionary, st: Dictionary, tree_id: String) -> int:
	var back := 0
	for t in db["trees"]:
		if t["id"] == tree_id:
			for n in t["nodes"]:
				back += int(st["points"].get(n["id"], 0))
				st["points"].erase(n["id"])
	return back


## Espírito dominante: soma dos pontos alinhados por lado.
static func spirit(db: Dictionary, st: Dictionary) -> Dictionary:
	var out := {"superior": 0, "infernal": 0, "side": ""}
	for t in db["trees"]:
		var al := alignment(t, st)
		if al != "":
			for n in t["nodes"]:
				if n["side"] == al:
					out[al] += int(st["points"].get(n["id"], 0))
	if out["superior"] > out["infernal"]:
		out["side"] = "superior"
	elif out["infernal"] > out["superior"]:
		out["side"] = "infernal"
	return out


## Bônus totais: {"stats": {stat: valor}, "skills": {skill_id: {mod: valor}}}.
## Inclui o bônus de espírito por árvore alinhada (a partir de min_points; dobra ao completar).
static func bonuses(db: Dictionary, st: Dictionary) -> Dictionary:
	var stats := {}
	var skills := {}
	for t in db["trees"]:
		for n in t["nodes"]:
			var p := int(st["points"].get(n["id"], 0))
			if p == 0:
				continue
			for k in n.get("stats", {}):
				stats[k] = stats.get(k, 0.0) + float(n["stats"][k]) * p
			if n.has("skill"):
				var sid: String = n["skill"]["id"]
				if not skills.has(sid):
					skills[sid] = {}
				for k in n["skill"]:
					if k != "id":
						skills[sid][k] = skills[sid].get(k, 0.0) + float(n["skill"][k]) * p
		var al := alignment(t, st)
		var sb: Dictionary = db["spirit_bonus"]
		var pts := spent_in(t, st)
		if al != "" and pts >= int(sb["min_points"]):
			var mult := float(sb["complete_mult"]) if pts >= int(db["tree_points"]) else 1.0
			for k in sb[al]["stats"]:
				stats[k] = stats.get(k, 0.0) + float(sb[al]["stats"][k]) * mult
	return {"stats": stats, "skills": skills}
