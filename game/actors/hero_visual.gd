## Boneco montado do herói sobre o humanoide modular (Quaternius, CC0).
## apply_loadout(equipped) lê só dados (data/visuals.json): cada slot vira peças de
## roupa (Camponês para Comum, Patrulheiro para Superior e Set), tingidas pela cor
## do set ou raridade, com brilho de refino; arma e escudo presos aos ossos; aura
## no set completo. Mesmo caminho para UI, jogo e co-op.
extends "res://game/actors/humanoid.gd"

const SetBonus = preload("res://core/set_bonus.gd")
const Fx = preload("res://game/fx/fx.gd")
const ARMOR_SLOTS := ["helm", "armor", "gloves", "pants", "boots"]

var aura_light: OmniLight3D
var aura_fx: CPUParticles3D
var _visuals: Dictionary
var _sig := {}   # slot -> assinatura do item montado (evita remontar sem mudança)


func _ready() -> void:
	_visuals = GameState.visuals
	configure(_visuals["hero"])
	super._ready()
	aura_light = OmniLight3D.new()
	aura_light.position = Vector3(0, 1.2, 0)
	aura_light.omni_range = 4.5
	aura_light.light_energy = 0.0
	add_child(aura_light)
	aura_fx = _make_aura()
	add_child(aura_fx)


func apply_loadout(equipped: Dictionary) -> void:
	for slot in ARMOR_SLOTS + ["weapon", "shield"]:
		if not equipped.has(slot) and _sig.has(slot):
			clear_slot(slot)
			_sig.erase(slot)
	for slot in equipped:
		var it: Dictionary = equipped[slot]
		var sig := "%s|%s|%s|%d" % [it.get("uid", ""), it["rarity"], it.get("set_id", ""), int(it["refine"])]
		if _sig.get(slot) == sig:
			continue
		_sig[slot] = sig
		var look := _look(it)
		if slot in ARMOR_SLOTS:
			var tier := "fine" if it["rarity"] != "common" else "common"
			var spec: Array = _visuals["outfits"][tier][slot]
			set_outfit(slot, _part_names(spec[0]), spec[1], look)
		elif _visuals["props"].has(slot):
			var p: Dictionary = _visuals["props"][slot]
			var xf := Transform3D(Basis.from_euler(Vector3(p["rot"][0], p["rot"][1], p["rot"][2]) * (PI / 180.0)), Vector3(p["pos"][0], p["pos"][1], p["pos"][2]))
			set_prop(slot, p["prop"], p["bone"], xf, look)
	_update_aura(equipped)


func _part_names(names: Array) -> Array:
	var out := []
	var subs: Dictionary = _visuals["sex_parts"][sex]
	for n in names:
		var s: String = n.replace("{S}", sex)
		for k in subs:
			s = s.replace("{%s}" % k, subs[k])
		out.append(s)
	return out


## Cor, metal e brilho de uma peça: set manda; senão, raridade.
func _look(it: Dictionary) -> Dictionary:
	var sid: String = it.get("set_id", "")
	var strength := glow_for(int(it.get("refine", 0)))
	if _visuals["sets"].has(sid):
		var v: Dictionary = _visuals["sets"][sid]
		return {"color": Color(v["color"]), "mix": float(v["mix"]), "metal": float(v["metal"]), "glow": Color(v["glow"]), "strength": strength}
	var r: Dictionary = _visuals["rarity_look"].get(it["rarity"], _visuals["rarity_look"]["superior"])
	var glow := Color(GameState.items_db["rarity_colors"].get(it["rarity"], "#ffffff"))
	return {"color": Color(r["color"]), "mix": float(r["mix"]), "metal": float(r["metal"]), "glow": glow, "strength": strength}


func glow_for(refine: int) -> float:
	var step := 0
	for t in _visuals["glow_thresholds"]:
		if refine >= int(t):
			step += 1
	return float(_visuals["glow_strength"][step])


func set_complete_id(equipped: Dictionary) -> String:
	var r := SetBonus.evaluate(equipped.values(), GameState.sets_db)
	for sid in r:
		if sid != "_total" and r[sid]["complete"]:
			return sid
	return ""


func _make_aura() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	p.mesh = q
	p.amount = 32
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 0.7
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.05
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.3
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.emitting = false
	return p


func _update_aura(equipped: Dictionary) -> void:
	var sid := set_complete_id(equipped)
	aura_fx.emitting = sid != ""
	aura_light.light_energy = 1.4 if sid != "" else 0.0
	if sid != "":
		var c := Color(_visuals["sets"][sid]["aura"])
		aura_light.light_color = c
		aura_fx.material_override = Fx.glow_mat(c, 2.5)
