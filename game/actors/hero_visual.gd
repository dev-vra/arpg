## Boneco montado do herói sobre o Knight (KayKit, CC0).
## apply_loadout(equipped) lê só dados: tinge as partes do corpo, liga elmo, capa,
## arma e escudo, prende peças extras aos ossos conforme o estilo do set
## e acende a aura quando o set fecha. Mesmo caminho para UI, jogo e co-op.
extends Node3D

const GEAR_SHADER = preload("res://game/shaders/gear.gdshader")
const SetBonus = preload("res://core/set_bonus.gd")
const Fx = preload("res://game/fx/fx.gd")

const SHIELD_BY_RARITY := {"common": "Round_Shield", "superior": "Rectangle_Shield", "ancestral": "Badge_Shield", "socketed": "Badge_Shield", "relic": "Spike_Shield"}
const CLOTH := Color("#6b5a48")

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var mats := {}
var extras: Array = []
var aura_light: OmniLight3D
var aura_fx: CPUParticles3D
var _visuals: Dictionary


func _ready() -> void:
	_visuals = GameState.visuals
	model = load("res://assets/kaykit/chars/Knight.glb").instantiate()
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false)
	anim = model.find_child("AnimationPlayer", true, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var src: StandardMaterial3D = mi.mesh.surface_get_material(0)
		var m := ShaderMaterial.new()
		m.shader = GEAR_SHADER
		m.set_shader_parameter("tex", src.albedo_texture)
		mi.material_override = m
		mats[str(mi.name)] = m
	for n in ["2H_Sword", "1H_Sword_Offhand", "Knight_Helmet", "Knight_Cape", "1H_Sword"] + SHIELD_BY_RARITY.values():
		_show(n, false)
	aura_light = OmniLight3D.new()
	aura_light.position = Vector3(0, 1.2, 0)
	aura_light.omni_range = 4.5
	aura_light.light_energy = 0.0
	add_child(aura_light)
	aura_fx = _make_aura()
	add_child(aura_fx)
	play("Idle")


func play(name: String, speed: float = 1.0, blend: float = 0.12) -> void:
	if anim and anim.has_animation(name):
		anim.play(name, blend, speed)


func flash() -> void:
	for m in mats.values():
		m.set_shader_parameter("hit_flash", 0.6)
	var tw := create_tween()
	tw.tween_method(_set_flash, 0.6, 0.0, 0.18)


func _set_flash(v: float) -> void:
	for m in mats.values():
		m.set_shader_parameter("hit_flash", v)


func apply_loadout(equipped: Dictionary) -> void:
	for e in extras:
		e.queue_free()
	extras.clear()
	for part in ["Knight_Body", "Knight_ArmLeft", "Knight_ArmRight", "Knight_LegLeft", "Knight_LegRight"]:
		_paint(part, CLOTH, 0.8, 0.0, Color.BLACK, 0.0)
	_paint("Knight_Head", Color.WHITE, 0.0, 0.0, Color.BLACK, 0.0)
	_show("Knight_Helmet", false)
	_show("Knight_Cape", false)
	_show("1H_Sword", false)
	for s in SHIELD_BY_RARITY.values():
		_show(s, false)

	for slot in equipped:
		var it: Dictionary = equipped[slot]
		var look := _look(it)
		match slot:
			"helm":
				_show("Knight_Helmet", true)
				_paint_look("Knight_Helmet", look)
				_crest(look)
			"armor":
				_paint_look("Knight_Body", look)
				_show("Knight_Cape", true)
				_paint("Knight_Cape", look["color"].darkened(0.25), 0.85, 0.0, look["glow"], look["strength"] * 0.5)
				for side in ["l", "r"]:
					_extra("upperarm." + side, _pauldron(look), Vector3(0, 0.02, 0), look)
			"gloves":
				_paint_look("Knight_ArmLeft", look)
				_paint_look("Knight_ArmRight", look)
				for side in ["l", "r"]:
					_extra("lowerarm." + side, _cyl(0.1, 0.16), Vector3(0, 0.2, 0), look)
			"pants":
				_paint_look("Knight_LegLeft", look)
				_paint_look("Knight_LegRight", look)
				for side in ["l", "r"]:
					_extra("lowerleg." + side, _sphere(0.085), Vector3(0, 0.0, -0.06), look)
			"boots":
				for side in ["l", "r"]:
					_extra("lowerleg." + side, _cyl(0.1, 0.1), Vector3(0, 0.1, 0), look)
			"weapon":
				_show("1H_Sword", true)
				_paint_look("1H_Sword", look)
			"shield":
				var sn: String = SHIELD_BY_RARITY.get(it["rarity"], "Round_Shield")
				_show(sn, true)
				_paint_look(sn, look)
	_update_aura(equipped)


## Cor, estilo e brilho de uma peça: set manda; senão, raridade.
func _look(it: Dictionary) -> Dictionary:
	var sid: String = it.get("set_id", "")
	var v: Dictionary = _visuals["sets"].get(sid, {})
	var color: Color
	var glow: Color
	var style := "plain"
	var mix := 0.55
	var metal := 0.35
	if not v.is_empty():
		color = Color(v["color"])
		glow = Color(v["glow"])
		style = v.get("style", "plates")
		mix = 0.8
		metal = 0.7
	else:
		color = Color(GameState.items_db["rarity_colors"].get(it["rarity"], "#aaaaaa")).lerp(Color("#8a8f96"), 0.55)
		glow = Color(GameState.items_db["rarity_colors"].get(it["rarity"], "#ffffff"))
	return {"color": color, "glow": glow, "style": style, "mix": mix, "metal": metal, "strength": glow_for(int(it.get("refine", 0)))}


func glow_for(refine: int) -> float:
	var step := 0
	for t in _visuals["glow_thresholds"]:
		if refine >= int(t):
			step += 1
	return float(_visuals["glow_strength"][step])


func _paint_look(part: String, look: Dictionary) -> void:
	_paint(part, look["color"], look["mix"], look["metal"], look["glow"], look["strength"])


func _paint(part: String, color: Color, mix: float, metal: float, glow: Color, strength: float) -> void:
	var m: ShaderMaterial = mats.get(part)
	if m == null:
		return
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("tint_mix", mix)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("glow_strength", strength)


func _show(node_name: String, on: bool) -> void:
	var n := model.find_child(node_name, true, false)
	if n:
		n.visible = on


# --- peças extras presas aos ossos (mudam a silhueta) ---

func _extra(bone: String, mesh: Mesh, offset: Vector3, look: Dictionary) -> void:
	if look["style"] == "plain" or skeleton.find_bone(bone) < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	var m := ShaderMaterial.new()
	m.shader = GEAR_SHADER
	m.set_shader_parameter("tex", mats["Knight_Body"].get_shader_parameter("tex"))
	m.set_shader_parameter("tint", look["color"].lightened(0.1))
	m.set_shader_parameter("tint_mix", 1.0)
	m.set_shader_parameter("metal", 0.85)
	m.set_shader_parameter("glow_color", look["glow"])
	m.set_shader_parameter("glow_strength", maxf(look["strength"], 0.15))
	mi.material_override = m
	ba.add_child(mi)
	extras.append(ba)


func _pauldron(look: Dictionary) -> Mesh:
	match look["style"]:
		"crown":
			var s := SphereMesh.new()
			s.radius = 0.17
			s.height = 0.26
			return s
		"fins":
			var p := PrismMesh.new()
			p.size = Vector3(0.34, 0.3, 0.26)
			return p
	var b := BoxMesh.new()
	b.size = Vector3(0.34, 0.2, 0.34)
	return b


func _crest(look: Dictionary) -> void:
	match look["style"]:
		"plates":
			var b := BoxMesh.new()
			b.size = Vector3(0.07, 0.32, 0.62)
			_extra("head", b, Vector3(0, 1.08, 0), look)
		"crown":
			for i in 5:
				var a := TAU * i / 5.0
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.07
				c.height = 0.26
				_extra("head", c, Vector3(cos(a) * 0.32, 1.02, sin(a) * 0.32), look)
		"fins":
			for x in [-0.5, 0.5]:
				var p := PrismMesh.new()
				p.size = Vector3(0.1, 0.4, 0.3)
				_extra("head", p, Vector3(x, 0.78, 0.05), look)


func _cyl(r: float, h: float) -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.1
	c.height = h
	return c


func _sphere(r: float) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


# --- aura do set completo ---

func _make_aura() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	p.mesh = q
	p.amount = 28
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 0.75
	p.emission_ring_inner_radius = 0.55
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


func set_complete_id(equipped: Dictionary) -> String:
	var r := SetBonus.evaluate(equipped.values(), GameState.sets_db)
	for sid in r:
		if sid != "_total" and r[sid]["complete"]:
			return sid
	return ""


func _update_aura(equipped: Dictionary) -> void:
	var sid := set_complete_id(equipped)
	aura_fx.emitting = sid != ""
	aura_light.light_energy = 1.6 if sid != "" else 0.0
	if sid != "":
		var c := Color(_visuals["sets"][sid]["aura"])
		aura_light.light_color = c
		aura_fx.material_override = Fx.glow_mat(c, 2.5)
