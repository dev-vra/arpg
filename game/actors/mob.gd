## Mob esqueleto (KayKit, CC0) orientado a dados (data/mobs.json).
## IA: acorda ao ver o jogador, persegue (linha reta ou A* na grade),
## avisa o golpe (telegraph) e ataca; à distância mantém espaço e atira.
## Chefe tem golpe em área com aviso no chão.
extends CharacterBody3D

signal killed(mob)

const GEAR_SHADER = preload("res://game/shaders/gear.gdshader")
const Fx = preload("res://game/fx/fx.gd")
const Projectile = preload("res://game/actors/projectile.gd")

var def: Dictionary
var id := ""
var level := 1
var max_hp := 10.0
var hp := 10.0
var dmg := 1.0
var world
var model: Node3D
var anim: AnimationPlayer
var mats: Array = []
var state := "idle"
var t := 0.0
var attack_cd := 0.0
var slam_cd := 3.0
var stun_time := 0.0
var path: PackedVector3Array = []
var path_timer := 0.0
var bar: Node3D
var bar_fill: MeshInstance3D
var is_boss := false


func setup(mob_id: String, mob_def: Dictionary, lvl: int, diff: Dictionary) -> void:
	id = mob_id
	def = mob_def
	level = lvl
	is_boss = def.get("boss", false)
	max_hp = float(def["hp"]) * (1.0 + 0.16 * (lvl - 1)) * float(diff["hp"])
	hp = max_hp
	dmg = float(def["dmg"]) * (1.0 + 0.12 * (lvl - 1)) * float(diff["dmg"])


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemies")
	var sc := float(def.get("scale", 1.0))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5 * sc
	cap.height = 2.0 * sc
	cs.shape = cap
	cs.position.y = 1.0 * sc
	add_child(cs)
	model = load("res://assets/kaykit/chars/%s.glb" % def["model"]).instantiate()
	model.scale = Vector3.ONE * sc
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
	_attach(sk, "handslot.r", def.get("weapon", ""))
	_attach(sk, "handslot.l", def.get("offhand", ""))
	var tint := Color(def.get("tint", "#ffffff"))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var src = mi.mesh.surface_get_material(0)
		if not (src is StandardMaterial3D):
			continue
		var m := ShaderMaterial.new()
		m.shader = GEAR_SHADER
		m.set_shader_parameter("tex", src.albedo_texture)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("tint_mix", 0.4 if def.has("tint") else 0.0)
		if is_boss:
			m.set_shader_parameter("glow_color", tint)
			m.set_shader_parameter("glow_strength", 0.6)
		mi.material_override = m
		mats.append(m)
	if not is_boss:
		_make_bar(sc)
	play("Skeletons_Inactive_Standing_Pose" if randf() < 0.5 else "Idle")


func _attach(sk: Skeleton3D, bone: String, asset: String) -> void:
	if asset == "" or sk == null or sk.find_bone(bone) < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	ba.add_child(load("res://assets/kaykit/weapons/%s.gltf" % asset).instantiate())


func _make_bar(sc: float) -> void:
	bar = Node3D.new()
	bar.position.y = 2.7 * sc
	add_child(bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.12)
	bg.mesh = q
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.albedo_color = Color(0, 0, 0, 0.7)
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mb.no_depth_test = true
	bg.material_override = mb
	bar.add_child(bg)
	bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.0, 0.07)
	bar_fill.mesh = q2
	var mf := mb.duplicate()
	mf.albedo_color = Color("#e84855")
	mf.render_priority = 1
	bar_fill.material_override = mf
	bar.add_child(bar_fill)
	bar.visible = false


func play(name: String, speed: float = 1.0) -> void:
	if anim and anim.has_animation(name) and anim.current_animation != name:
		anim.play(name, 0.12, speed)


func _physics_process(delta: float) -> void:
	if state == "dead":
		return
	var player = world.player
	attack_cd = maxf(0.0, attack_cd - delta)
	slam_cd = maxf(0.0, slam_cd - delta)
	if stun_time > 0.0:
		stun_time -= delta
		velocity = Vector3.ZERO
		return
	if player == null or player.dead:
		play("Idle")
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0
	var dist := to.length()
	match state:
		"idle":
			if dist < (15.0 if is_boss else 11.0) and world.has_line_of_sight(global_position, player.global_position):
				state = "chase"
				play("Skeletons_Awaken_Standing", 2.0)
				t = 0.45
				if is_boss:
					world.boss_awake(self)
		"chase":
			if t > 0.0:
				t -= delta
				return
			var ranged: bool = def.get("ranged", false)
			var reach := float(def["range"]) * float(def.get("scale", 1.0)) * 0.55 + 0.9 if not ranged else float(def["range"])
			if is_boss and slam_cd <= 0.0 and dist < float(def["slam_radius"]) + 1.0:
				_start_slam()
			elif dist <= reach and attack_cd <= 0.0 and (not ranged or world.has_line_of_sight(global_position, player.global_position)):
				state = "windup"
				t = 0.38 if not ranged else 0.55
				_face(to)
				play("1H_Melee_Attack_Chop" if not ranged else "Spellcast_Shoot", 1.3)
				_telegraph()
			elif ranged and dist < reach * 0.55:
				_move(-to.normalized(), delta, 0.8)
			elif dist > reach * 0.9:
				_move(_steer(player.global_position), delta, 1.0)
			else:
				velocity = Vector3.ZERO
				play("Idle_Combat")
		"windup":
			t -= delta
			if t <= 0.0:
				_strike(player, dist)
		"slam":
			t -= delta
			if t <= 0.0:
				_do_slam(player)
		"recover":
			t -= delta
			if t <= 0.0:
				state = "chase"


func _face(dir: Vector3) -> void:
	if dir.length() > 0.05:
		model.rotation.y = atan2(dir.x, dir.z)


func _move(dir: Vector3, delta: float, mult: float) -> void:
	var sep := Vector3.ZERO
	for o in world.enemies_in_radius(global_position, 1.3):
		if o != self:
			sep += (global_position - o.global_position).normalized()
	var v := (dir + sep * 0.5)
	v.y = 0
	v = v.normalized() * float(def["speed"]) * mult
	velocity = Vector3(v.x, -1.0, v.z)
	move_and_slide()
	_face(v)
	play("Running_A" if def["speed"] > 3.5 else "Walking_A", 1.0)


## Direto se há visão; senão segue o caminho A* da grade.
func _steer(target: Vector3) -> Vector3:
	if world.has_line_of_sight(global_position, target):
		path = []
		return (target - global_position).normalized()
	path_timer -= get_physics_process_delta_time()
	if path.is_empty() or path_timer <= 0.0:
		path = world.path_between(global_position, target)
		path_timer = 0.6
	while path.size() > 0 and global_position.distance_to(Vector3(path[0].x, global_position.y, path[0].z)) < 1.2:
		path.remove_at(0)
	if path.is_empty():
		return (target - global_position).normalized()
	var p := path[0]
	return (Vector3(p.x, global_position.y, p.z) - global_position).normalized()


func _telegraph() -> void:
	for m in mats:
		m.set_shader_parameter("hit_flash", 0.0)
	var tw := create_tween()
	var base_glow := Color(def.get("tint", "#ffffff"))
	_set_param(Color("#ff3b3b"), "glow_color")
	tw.tween_method(_glow_back, 0.0, 1.4, 0.3)
	tw.tween_method(_glow_back, 1.4, 0.6 if is_boss else 0.0, 0.2)
	tw.tween_callback(func(): _set_param(base_glow, "glow_color"))


func _strike(player, dist: float) -> void:
	state = "recover"
	t = 0.35
	attack_cd = float(def["attack_cd"])
	if def.get("ranged", false):
		var p := Projectile.new()
		p.setup(global_position + Vector3(0, 1.4 * float(def.get("scale", 1.0)), 0), player.global_position + Vector3(0, 1.0, 0), dmg, level, Color(def.get("bolt_color", "#9b6bff")))
		world.add_child(p)
		return
	var reach := float(def["range"]) * float(def.get("scale", 1.0)) * 0.55 + 1.4
	Fx.slash(world, global_position, (player.global_position - global_position).normalized(), Color("#ff6b6b"), 1.8, 90.0)
	if dist <= reach:
		player.take_damage(dmg, level)


func _start_slam() -> void:
	state = "slam"
	t = 1.0
	slam_cd = float(def["slam_cd"])
	play("2H_Melee_Attack_Chop", 0.9)
	var warn := Fx.disc(world, global_position, float(def["slam_radius"]), Color("#ff2d2d"), 1.0)
	warn.scale = Vector3(0.2, 1, 0.2)
	warn.create_tween().tween_property(warn, "scale", Vector3.ONE, 0.95)


func _do_slam(player) -> void:
	state = "recover"
	t = 0.6
	var r := float(def["slam_radius"])
	world.shake(0.5, 0.35)
	Fx.ring(world, global_position, r, Color("#ff5a3a"), 0.55)
	Fx.sparks(world, global_position, Color("#ff9a5a"), 36)
	if player.global_position.distance_to(global_position) <= r:
		player.take_damage(dmg * 1.8, level)


func _set_param(value, param: String) -> void:
	for m in mats:
		m.set_shader_parameter(param, value)


func _flash(v: float) -> void:
	_set_param(v, "hit_flash")


func _glow_back(v: float) -> void:
	_set_param(v, "glow_strength")


func stun(time: float) -> void:
	if is_boss:
		time *= 0.35
	stun_time = maxf(stun_time, time)
	if state != "dead":
		play("Hit_B", 0.6)
		if state == "idle":
			state = "chase"


## Retorna o dano aplicado (para roubo de vida).
func take_damage(amount: float, crit: bool, from: Vector3) -> float:
	if state == "dead":
		return 0.0
	if state == "idle":
		state = "chase"
		if is_boss:
			world.boss_awake(self)
	var dealt := minf(amount, hp)
	hp -= amount
	for m in mats:
		m.set_shader_parameter("hit_flash", 0.7)
	var tw := create_tween()
	tw.tween_method(_flash, 0.7, 0.0, 0.15)
	Fx.number(world, global_position, str(int(ceil(amount))) + ("!" if crit else ""), Color("#ffd166") if crit else Color.WHITE, crit)
	if not is_boss:
		var push := (global_position - from)
		push.y = 0
		global_position += push.normalized() * 0.25
		if state == "chase" and randf() < 0.35:
			play("Hit_A", 1.6)
	if bar:
		bar.visible = true
		bar_fill.scale.x = maxf(0.0, hp / max_hp)
		bar_fill.position.x = -(1.0 - bar_fill.scale.x) * 0.5
	if hp <= 0.0:
		_die()
	return dealt


func _die() -> void:
	state = "dead"
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	if bar:
		bar.visible = false
	play("Death_A" if randf() < 0.5 else "Death_B")
	killed.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(self, "position:y", position.y - 1.5, 1.2)
	tw.tween_callback(queue_free)
