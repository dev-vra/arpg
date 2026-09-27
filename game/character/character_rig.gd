## Boneco montado. O corpo é dividido em partes; equipar uma peça esconde a parte
## que ela cobre e mostra a peça. apply_loadout lê só dados (mesmo caminho para
## tela de equipamento, jogo e co-op).
## Protótipo: formas geradas por código no lugar de malhas skinned.
extends Node3D

const Config = preload("res://core/config.gd")
const SetBonus = preload("res://core/set_bonus.gd")
const GLOW_SHADER = preload("res://game/shaders/refine_glow.gdshader")

# parte: [malha, tamanho, posição]
const PARTS := {
	"head":  ["sphere",  Vector3(0.36, 0.36, 0.36), Vector3(0, 1.62, 0)],
	"torso": ["box",     Vector3(0.52, 0.62, 0.30), Vector3(0, 1.15, 0)],
	"arms":  ["arms",    Vector3(0.14, 0.58, 0.14), Vector3(0, 1.12, 0)],
	"legs":  ["legs",    Vector3(0.18, 0.62, 0.18), Vector3(0, 0.45, 0)],
	"feet":  ["feet",    Vector3(0.18, 0.12, 0.28), Vector3(0, 0.06, 0.05)],
}
const ARMOR_SCALE := 1.18

var visuals: Dictionary = Config.load_json("res://data/visuals.json")
var sets_db: Dictionary = Config.sets()
var body := {}
var armor := {}
var aura: OmniLight3D


func _ready() -> void:
	for part in PARTS:
		body[part] = _build_part(part, 1.0, _mat(Color(visuals["body_color"]), Color.BLACK, 0.0))
		armor[part] = null
	aura = OmniLight3D.new()
	aura.position = Vector3(0, 1.0, 0)
	aura.omni_range = 3.0
	aura.visible = false
	add_child(aura)


## loadout: Array de itens (dicionários do núcleo). Slots fora do corpo são ignorados no protótipo.
func apply_loadout(loadout: Array) -> void:
	for part in PARTS:
		body[part].visible = true
		if armor[part] != null:
			armor[part].queue_free()
			armor[part] = null
	for it in loadout:
		var part: String = visuals["slot_part"].get(it["slot"], "")
		if part == "":
			continue
		var v: Dictionary = visuals["sets"].get(it.get("set_id", ""), visuals["default"])
		var m := _mat(Color(v["color"]), Color(v["glow"]), glow_for(int(it.get("refine", 0))))
		armor[part] = _build_part(part, ARMOR_SCALE, m)
		body[part].visible = false
	_update_aura(loadout)


func glow_for(refine: int) -> float:
	var step := 0
	for t in visuals["glow_thresholds"]:
		if refine >= int(t):
			step += 1
	return float(visuals["glow_strength"][step])


func is_set_complete(loadout: Array) -> String:
	var r := SetBonus.evaluate(loadout, sets_db)
	for sid in r:
		if sid != "_total" and r[sid]["complete"]:
			return sid
	return ""


func _update_aura(loadout: Array) -> void:
	var sid := is_set_complete(loadout)
	aura.visible = sid != ""
	if sid != "":
		aura.light_color = Color(visuals["sets"].get(sid, visuals["default"])["aura"])
		aura.light_energy = 2.5


func _mat(color: Color, glow: Color, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("glow_strength", strength)
	return m


## Braços, pernas e pés são pares; cada parte vira um nó com 1 ou 2 malhas.
func _build_part(part: String, scale_mult: float, mat: Material) -> Node3D:
	var def: Array = PARTS[part]
	var root := Node3D.new()
	root.name = part
	root.position = def[2]
	var size: Vector3 = def[1] * scale_mult
	var offsets := [Vector3.ZERO]
	match def[0]:
		"arms": offsets = [Vector3(-0.36, 0, 0), Vector3(0.36, 0, 0)]
		"legs", "feet": offsets = [Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0)]
	for o in offsets:
		var mi := MeshInstance3D.new()
		if def[0] == "sphere":
			var s := SphereMesh.new()
			s.radius = size.x / 2.0
			s.height = size.y
			mi.mesh = s
		elif def[0] == "arms" or def[0] == "legs":
			var c := CapsuleMesh.new()
			c.radius = size.x / 2.0
			c.height = size.y
			mi.mesh = c
		else:
			var b := BoxMesh.new()
			b.size = size
			mi.mesh = b
		mi.material_override = mat
		mi.position = o
		root.add_child(mi)
	add_child(root)
	return root
