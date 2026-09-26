## Bônus de set em degraus (2, 3, 4, 5 peças). Misturar sets vale:
## cada set conta suas peças separadamente.
extends RefCounted


## Retorna {set_id: {pieces, active_steps, stats, complete}} e o total somado em "_total".
static func evaluate(equipped: Array, sets_db: Dictionary) -> Dictionary:
	var slots_by_set := {}
	for item in equipped:
		var sid: String = item.get("set_id", "")
		if sid == "" or not sets_db["sets"].has(sid):
			continue
		if not slots_by_set.has(sid):
			slots_by_set[sid] = {}
		slots_by_set[sid][item["slot"]] = true

	var out := {}
	var total := {}
	for sid in slots_by_set:
		var def: Dictionary = sets_db["sets"][sid]
		var pieces: int = slots_by_set[sid].size()
		var steps := []
		var stats := {}
		for key in def["bonuses"]:
			var need := int(key)
			if pieces >= need:
				steps.append(need)
				for stat in def["bonuses"][key]:
					var v := float(def["bonuses"][key][stat])
					stats[stat] = stats.get(stat, 0.0) + v
					total[stat] = total.get(stat, 0.0) + v
		steps.sort()
		out[sid] = {
			"pieces": pieces,
			"active_steps": steps,
			"stats": stats,
			"complete": pieces >= def["slots"].size(),
		}
	out["_total"] = total
	return out
