## Drop no chão. Moedas e joias são puxadas até o jogador (ímã);
## itens mostram nome na cor da raridade e feixe de luz, e são pegos ao encostar.
extends Node3D

const Fx = preload("res://game/fx/fx.gd")

const JEWEL_COLORS := {"lume": "#ffe08a", "brasa": "#ff7043", "aurora": "#9ad7ff", "prisma": "#c77dff", "sigilo": "#4dd0e1", "fagulha": "#ffab40", "zen": "#ffd54f"}

var drop: Dictionary
var player
var t := 0.0
var magnet := false
var start: Vector3
var target_offset: Vector3


func setup(d: Dictionary, pos: Vector3, p) -> void:
	drop = d
	player = p
	start = pos
	target_offset = Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
	position = pos


func _ready() -> void:
	if drop["kind"] == "currency":
		var mi := MeshInstance3D.new()
		var c := Color(JEWEL_COLORS.get(drop["key"], "#ffffff"))
		if drop["key"] == "zen":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.16
			cyl.height = 0.05
			mi.mesh = cyl
			mi.rotation.x = PI / 2
		else:
			var pr := PrismMesh.new()
			pr.size = Vector3(0.28, 0.4, 0.28)
			mi.mesh = pr
		mi.material_override = Fx.glow_mat(c, 2.2)
		mi.position.y = 0.4
		add_child(mi)
		if drop["key"] != "zen":
			add_child(Fx.beam(c, 1.2))
	else:
		var it: Dictionary = drop["item"]
		var c := Color(GameState.items_db["rarity_colors"].get(it["rarity"], "#ffffff"))
		add_child(Fx.beam(c, 3.5 if it["rarity"] != "common" else 1.8))
		var box := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.45, 0.2, 0.45)
		box.mesh = b
		box.material_override = Fx.glow_mat(c, 1.2)
		box.position.y = 0.15
		add_child(box)
		var l := Label3D.new()
		l.text = it.get("name", "Item")
		l.modulate = c
		l.outline_size = 10
		l.font_size = 40
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position.y = 1.1
		add_child(l)


func _process(delta: float) -> void:
	t += delta
	if t < 0.45:
		var k := t / 0.45
		position = start + target_offset * k + Vector3(0, sin(k * PI) * 1.6, 0)
		return
	if player == null or player.dead:
		return
	var d: float = global_position.distance_to(player.global_position)
	if drop["kind"] == "currency":
		if d < 4.0:
			magnet = true
		if magnet:
			var goal: Vector3 = player.global_position + Vector3(0, 1, 0)
			global_position = global_position.move_toward(goal, delta * (8.0 + t * 4.0))
			if global_position.distance_to(goal) < 0.5:
				GameState.add_currency(drop["key"], int(drop["amount"]))
				queue_free()
	elif d < 1.3:
		if GameState.add_item(drop["item"]):
			var it: Dictionary = drop["item"]
			GameState.toast.emit("+ %s" % it["name"], Color(GameState.items_db["rarity_colors"][it["rarity"]]))
			queue_free()
