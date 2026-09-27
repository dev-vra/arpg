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
	if drop["kind"] == "quest":
		var qi: Dictionary = GameState.quests_db["quest_items"][drop["key"]]
		var qc := Color(qi["color"])
		add_child(Fx.beam(Color("#ffd166"), 2.6))
		var gem := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.18
		sp.height = 0.36
		gem.mesh = sp
		gem.material_override = Fx.glow_mat(qc, 2.0)
		gem.position.y = 0.45
		add_child(gem)
		var ql := Label3D.new()
		ql.text = "! " + qi["name"]
		ql.modulate = Color("#ffd166")
		ql.outline_size = 10
		ql.font_size = 40
		ql.pixel_size = 0.006
		ql.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ql.no_depth_test = true
		ql.position.y = 1.1
		add_child(ql)
	elif drop["kind"] == "currency":
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
	if drop["kind"] == "quest":
		if d < 1.6:
			GameState.quest_event({"type": "collect", "item": drop["key"]})
			queue_free()
	elif drop["kind"] == "currency":
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
			var up := "  (melhor: +%d poder)" % GameState.compare(it)["power"] if GameState.is_upgrade(it) else ""
			GameState.toast.emit("+ %s%s" % [it["name"], up], Color(GameState.items_db["rarity_colors"][it["rarity"]]))
			queue_free()
