## Aparência de uma peça (usada pelo boneco e pelas miniaturas):
## quais malhas vestir no slot e com que cor, metal e brilho.
extends RefCounted

const ARMOR_SLOTS := ["helm", "armor", "gloves", "pants", "boots"]


static func glow_for(refine: int) -> float:
	var v: Dictionary = GameState.visuals
	var step := 0
	for t in v["glow_thresholds"]:
		if refine >= int(t):
			step += 1
	return float(v["glow_strength"][step])


## Cor, metal e brilho: set manda; senão, raridade.
static func look(it: Dictionary) -> Dictionary:
	var v: Dictionary = GameState.visuals
	var sid: String = it.get("set_id", "")
	var strength := glow_for(int(it.get("refine", 0)))
	if v["sets"].has(sid):
		var s: Dictionary = v["sets"][sid]
		return {"color": Color(s["color"]), "mix": float(s["mix"]), "metal": float(s["metal"]), "glow": Color(s["glow"]), "strength": strength}
	var r: Dictionary = v["rarity_look"].get(it["rarity"], v["rarity_look"]["superior"])
	var glow := Color(GameState.items_db["rarity_colors"].get(it["rarity"], "#ffffff"))
	return {"color": Color(r["color"]), "mix": float(r["mix"]), "metal": float(r["metal"]), "glow": glow, "strength": strength}


## Nomes das malhas de roupa do slot para este item e sexo, e regiões cobertas.
static func outfit(it: Dictionary, sex: String) -> Array:
	var v: Dictionary = GameState.visuals
	var tier := "fine" if it["rarity"] != "common" else "common"
	var spec: Array = v["outfits"][tier][it["slot"]]
	var names := []
	var subs: Dictionary = v["sex_parts"][sex]
	for n in spec[0]:
		var s: String = n.replace("{S}", sex)
		for k in subs:
			s = s.replace("{%s}" % k, subs[k])
		names.append(s)
	return [names, spec[1]]


## Chave de cache da miniatura: muda quando a aparência muda.
static func thumb_key(it: Dictionary) -> String:
	var l := look(it)
	return "%s|%s|%s|%d" % [it["slot"], "fine" if it["rarity"] != "common" else "common", l["color"].to_html(), int(l["strength"] * 10)]
