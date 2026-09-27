## Ponto de interação (NPC, portal, baú, saída). O mundo mostra o botão quando o
## jogador chega perto e chama world.interact(kind).
extends Node3D

const Fx = preload("res://game/fx/fx.gd")
const Humanoid = preload("res://game/actors/humanoid.gd")

var kind := ""
var title := ""
var look: Dictionary = {}
var prop := ""
var used := false
var radius := 3.2


## look: aparência de NPC humanoide (com "anim"); prop: nome de prop do kit.
func setup(k: String, t: String, npc_look: Dictionary = {}, prop_name: String = "") -> void:
	kind = k
	title = t
	look = npc_look
	prop = prop_name


func _ready() -> void:
	add_to_group("interactable")
	if not look.is_empty():
		var h := Humanoid.new()
		h.configure(look)
		add_child(h)
		h.dress(look)
		if look.has("weapon"):
			h.set_prop("weapon", look["weapon"], "hand_r", Transform3D(), {})
		h.play(look.get("anim", "Idle"))
	elif prop != "":
		var m: Node3D = load("res://assets/q/props/%s.gltf" % prop).instantiate()
		m.scale = Vector3.ONE * 1.6
		add_child(m)
	if kind in ["portal", "exit"]:
		_portal_fx(Color("#7fd1ff") if kind == "portal" else Color("#8dff9a"))
	var l := Label3D.new()
	l.text = title
	l.font_size = 42
	l.outline_size = 10
	l.pixel_size = 0.006
	l.modulate = Color("#ffe3a0")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 2.6
	add_child(l)


func _portal_fx(c: Color) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.15
	t.outer_radius = 1.4
	ring.mesh = t
	ring.material_override = Fx.glow_mat(c, 0.45)
	ring.rotation.x = PI / 2
	ring.position.y = 1.5
	add_child(ring)
	var core := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 1.15
	d.bottom_radius = 1.15
	d.height = 0.02
	core.mesh = d
	core.material_override = Fx.glow_mat(Color(c, 0.12), 0.8)
	core.rotation.x = PI / 2
	core.position.y = 1.5
	add_child(core)
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	p.mesh = q
	p.material_override = Fx.glow_mat(c, 1.6)
	p.amount = 24
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.FORWARD
	p.emission_ring_radius = 1.3
	p.emission_ring_inner_radius = 1.1
	p.emission_ring_height = 0.1
	p.gravity = Vector3(0, 0.6, 0)
	p.position.y = 1.5
	add_child(p)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.1
	l.omni_range = 6.0
	l.position = Vector3(0, 1.6, 1.0)
	add_child(l)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.06, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_SINE)
