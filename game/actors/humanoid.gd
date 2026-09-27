## Humanoide modular (Quaternius, CC0): corpo base + cabelo + peças de roupa por slot,
## todas no mesmo esqueleto, animadas pela biblioteca UAL. O corpo esconde a pele
## coberta pelas peças (máscara por osso no shader). Usado pelo herói, NPCs e mobs.
extends Node3D

const CHAR_SHADER = preload("res://game/shaders/character.gdshader")
const Ual = preload("res://game/actors/ual.gd")

const OUTFITS := "res://assets/q/outfits/%s.gltf"
const PROPS := "res://assets/q/props/%s.gltf"
## Ossos cobertos por cada região do corpo.
const REGION_BONES := {
	"torso": ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"],
	"arms": ["upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r"],
	"hands": ["hand_l", "hand_r"],
	"legs": ["pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"],
	"pelvis_thigh": ["pelvis", "thigh_l", "thigh_r"],
	"feet": ["foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"],
}

var sex := "Male"
var skin := Color("#c89478")
var skin_mix := 0.0
var hair := "Hair_Buzzed"
var hair_color := Color("#3b2a20")
var eye_glow := Color(0, 0, 0)

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var body_mat: ShaderMaterial
var parts := {}        # slot -> Array[Node]
var covered := {}      # slot -> Array[String] regiões
var mats: Array = []   # todos os ShaderMaterial (para clarão de dano)
var hair_nodes: Array = []


func _ready() -> void:
	model = load("res://assets/q/chars/Superhero_%s_FullBody.gltf" % sex).instantiate()
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false)
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", Ual.library())
	for mi in skeleton.get_children():
		if not (mi is MeshInstance3D):
			continue
		var is_body := str(mi.name).begins_with("SuperHero")
		for i in mi.mesh.get_surface_count():
			var m := _material_from(mi.mesh.surface_get_material(i), is_body)
			if is_body:
				body_mat = m
				m.set_shader_parameter("tint", skin)
				m.set_shader_parameter("tint_mix", skin_mix)
			elif str(mi.name) == "Eyes" and eye_glow.v > 0.0:
				m.set_shader_parameter("glow_color", eye_glow)
				m.set_shader_parameter("glow_strength", 3.0)
			mi.set_surface_override_material(i, m)
	_update_mask()
	if hair != "":
		hair_nodes = _graft("res://assets/q/chars/%s.gltf" % hair, {"color": hair_color, "mix": 0.7, "metal": 0.0, "glow": Color.BLACK, "strength": 0.0})
	play("Idle")


func _material_from(src: Material, _is_body: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CHAR_SHADER
	if src is StandardMaterial3D:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		if src.normal_enabled and src.normal_texture:
			m.set_shader_parameter("normal_tex", src.normal_texture)
			m.set_shader_parameter("use_normal", true)
		m.set_shader_parameter("rough", src.roughness)
	var zeros := PackedFloat32Array()
	zeros.resize(65)
	m.set_shader_parameter("hide_bone", zeros)
	mats.append(m)
	return m


## Move as malhas de uma cena glTF para o nosso esqueleto (mesmos nomes de osso).
func _graft(path: String, look: Dictionary) -> Array:
	var src: Node = load(path).instantiate()
	var out := []
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		for i in mi.mesh.get_surface_count():
			var smat: Material = mi.mesh.surface_get_material(i)
			var m := _material_from(smat)
			if smat and smat.resource_name.contains("Regular"):
				# Pele exposta dentro da peça (mãos, pescoço) segue o tom do corpo.
				m.set_shader_parameter("tint", skin)
				m.set_shader_parameter("tint_mix", skin_mix)
			else:
				_apply_look(m, look)
			mi.set_surface_override_material(i, m)
		out.append(mi)
	src.free()
	return out


func _apply_look(m: ShaderMaterial, look: Dictionary) -> void:
	m.set_shader_parameter("tint", look.get("color", Color.WHITE))
	m.set_shader_parameter("tint_mix", look.get("mix", 0.0))
	m.set_shader_parameter("metal", look.get("metal", 0.0))
	m.set_shader_parameter("glow_color", look.get("glow", Color.BLACK))
	m.set_shader_parameter("glow_strength", look.get("strength", 0.0))


## Equipa um conjunto de peças de roupa num slot, cobrindo regiões do corpo.
func set_outfit(slot: String, part_names: Array, regions: Array, look: Dictionary) -> void:
	clear_slot(slot)
	var nodes := []
	for p in part_names:
		nodes += _graft(OUTFITS % p, look)
	parts[slot] = nodes
	covered[slot] = regions
	_update_mask()
	if slot == "helm":
		for h in hair_nodes:
			h.visible = false


## Prende um prop (arma, escudo) a um osso.
func set_prop(slot: String, prop: String, bone: String, xf: Transform3D, look: Dictionary) -> void:
	clear_slot(slot)
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var inst: Node3D = load(PROPS % prop).instantiate()
	inst.transform = xf
	ba.add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := _material_from(mi.mesh.surface_get_material(i))
			_apply_look(m, look)
			mi.set_surface_override_material(i, m)
	parts[slot] = [ba]


func clear_slot(slot: String) -> void:
	for n in parts.get(slot, []):
		for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
			for i in mi.get_surface_override_material_count():
				mats.erase(mi.get_surface_override_material(i))
		n.queue_free()
	parts.erase(slot)
	covered.erase(slot)
	_update_mask()
	if slot == "helm":
		for h in hair_nodes:
			h.visible = true


func _update_mask() -> void:
	if body_mat == null:
		return
	var hide := PackedFloat32Array()
	hide.resize(65)
	for slot in covered:
		for region in covered[slot]:
			for b in REGION_BONES.get(region, []):
				var i := skeleton.find_bone(b)
				if i >= 0 and i < 65:
					hide[i] = 1.0
				if region == "hands":
					for j in skeleton.get_bone_count():
						var n := skeleton.get_bone_name(j)
						if j < 65 and (n.ends_with("_l") or n.ends_with("_r")) and _is_finger(n):
							hide[j] = 1.0
	body_mat.set_shader_parameter("hide_bone", hide)
	body_mat.set_shader_parameter("use_mask", true)


func _is_finger(n: String) -> bool:
	for f in ["index", "middle", "pinky", "ring", "thumb"]:
		if n.begins_with(f):
			return true
	return false


func play(name: String, speed: float = 1.0, blend: float = 0.15) -> void:
	if anim and anim.has_animation(name) and (anim.current_animation != name or not anim.is_playing()):
		anim.play(name, blend, speed)


func play_once(name: String, speed: float = 1.0, blend: float = 0.08) -> void:
	if anim and anim.has_animation(name):
		anim.play(name, blend, speed)
		anim.seek(0.0, true)


func flash(v: float = 0.6) -> void:
	_set_flash(v)
	var tw := create_tween()
	tw.tween_method(_set_flash, v, 0.0, 0.18)


func _set_flash(v: float) -> void:
	for m in mats:
		if m:
			m.set_shader_parameter("hit_flash", v)


func set_glow_all(color: Color, strength: float) -> void:
	for m in mats:
		if m and m != body_mat:
			m.set_shader_parameter("glow_color", color)
			m.set_shader_parameter("glow_strength", strength)


## Configura aparência antes de entrar na árvore (sexo, pele, cabelo, olhos).
func configure(look: Dictionary) -> void:
	sex = look.get("sex", sex)
	skin = Color(look.get("skin", skin.to_html()))
	skin_mix = float(look.get("skin_mix", skin_mix))
	hair = look.get("hair", hair)
	if look.has("hair_color"):
		hair_color = Color(look["hair_color"])
	if look.has("eye_glow"):
		eye_glow = Color(look["eye_glow"])


## Veste peças descritas em dados: [[partes], [regiões], cor, mistura].
func dress(look: Dictionary, glow: Color = Color.BLACK, glow_strength: float = 0.0) -> void:
	var i := 0
	for entry in look.get("parts", []):
		set_outfit("part%d" % i, entry[0], entry[1], {"color": Color(entry[2]), "mix": float(entry[3]), "metal": 0.2, "glow": glow, "strength": glow_strength})
		i += 1
