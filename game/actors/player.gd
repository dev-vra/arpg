## Sentinela controlada pelo jogador: joystick/WASD, ataque básico com auto-alvo,
## 4 skills em dados (data/skills.json), esquiva, poção e dano com defesa.
extends CharacterBody3D

signal died
signal hp_changed

const HeroVisual = preload("res://game/actors/hero_visual.gd")
const Stats = preload("res://core/stats.gd")
const Fx = preload("res://game/fx/fx.gd")

const SPEED := 6.2
const AUTO_AIM := 7.5
const POTION_CHARGES := 3

var visual
var world  # world.gd
var kit: Dictionary
var hp := 100.0
var joy := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var cooldowns := [0.0, 0.0, 0.0, 0.0]
var basic_cd := 0.0
var dodge_cd := 0.0
var potion_cd := 0.0
var potions := POTION_CHARGES
var lock_time := 0.0
var dash_time := 0.0
var dash_vel := Vector3.ZERO
var dash_hits := {}
var dash_skill: Dictionary = {}
var invuln := 0.0
var buff_time := 0.0
var buff_def := 0.0
var since_hit := 10.0
var dead := false
var attack_held := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.0
	cs.shape = cap
	cs.position.y = 1.0
	add_child(cs)
	visual = HeroVisual.new()
	add_child(visual)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffd6a0")
	lamp.light_energy = 0.8
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, 4.2, 2.6)
	add_child(lamp)
	kit = GameState.skills_db["sentinela"]
	add_to_group("player")
	GameState.changed.connect(_on_state_changed)
	visual.apply_loadout(GameState.equipped)
	hp = max_hp()


func max_hp() -> float:
	return GameState.stats.get("max_hp", 100.0)


func _on_state_changed() -> void:
	if visual and visual.model:
		visual.apply_loadout(GameState.equipped)
	hp = minf(hp, max_hp())
	hp_changed.emit()


func cd_mult() -> float:
	return 1.0 - GameState.stats.get("cooldown", 0.0) / 100.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	for i in 4:
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	basic_cd = maxf(0.0, basic_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	lock_time = maxf(0.0, lock_time - delta)
	invuln = maxf(0.0, invuln - delta)
	buff_time = maxf(0.0, buff_time - delta)
	since_hit += delta
	if since_hit > 4.0 and hp < max_hp():
		hp = minf(max_hp(), hp + max_hp() * 0.03 * delta)
		hp_changed.emit()

	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_vel
		move_and_slide()
		if not dash_skill.is_empty():
			for e in world.enemies_in_radius(global_position, float(dash_skill["radius"])):
				if not dash_hits.has(e):
					dash_hits[e] = true
					_hit(e, float(dash_skill["mult"]), Color("#9fe0ff"))
		if dash_time <= 0.0:
			dash_skill = {}
		return

	var dir := joy
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if kb.length() > 0.1:
		dir = Vector3(kb.x, 0, kb.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed: float = SPEED * (1.0 + GameState.stats.get("move_speed", 0.0) / 100.0)
	if lock_time > 0.0:
		speed *= 0.15
	velocity = Vector3(dir.x * speed, -1.0, dir.z * speed)
	move_and_slide()
	if dir.length() > 0.1 and lock_time <= 0.0:
		facing = dir.normalized()
		visual.play("Running_A", 1.1 * speed / SPEED)
	elif lock_time <= 0.0:
		visual.play("Idle")
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), minf(1.0, delta * 18.0))
	if attack_held:
		basic_attack()


# --- ações ---

func basic_attack() -> void:
	if dead or basic_cd > 0.0 or dash_time > 0.0:
		return
	var b: Dictionary = kit["basic"]
	var target = world.nearest_enemy(global_position, AUTO_AIM)
	if target:
		var to: Vector3 = target.global_position - global_position
		to.y = 0
		if to.length() > 0.1:
			facing = to.normalized()
			visual.rotation.y = atan2(facing.x, facing.z)
	var aspd: float = 1.0 + GameState.stats.get("attack_speed", 0.0) / 100.0
	basic_cd = float(b["cooldown"]) / aspd
	lock_time = 0.28 / aspd
	visual.play(b["anim"], 1.6 * aspd, 0.05)
	Fx.slash(world, global_position + facing * 0.6, facing, Color("#fff1c9"), float(b["range"]), float(b["arc_deg"]))
	for e in world.enemies_in_arc(global_position, facing, float(b["range"]) + 0.6, float(b["arc_deg"])):
		_hit(e, float(b["mult"]), Color("#fff1c9"))


func use_skill(i: int) -> void:
	if dead or i >= kit["skills"].size() or cooldowns[i] > 0.0 or dash_time > 0.0:
		return
	var s: Dictionary = kit["skills"][i]
	cooldowns[i] = float(s["cooldown"]) * cd_mult()
	var target = world.nearest_enemy(global_position, AUTO_AIM + 3.0)
	if target and s["kind"] != "buff":
		var to: Vector3 = target.global_position - global_position
		to.y = 0
		if to.length() > 0.1:
			facing = to.normalized()
			visual.rotation.y = atan2(facing.x, facing.z)
	visual.play(s["anim"], 1.5, 0.05)
	match s["kind"]:
		"dash":
			dash_skill = s
			dash_hits = {}
			dash_time = 0.24
			invuln = 0.3
			dash_vel = facing * float(s["distance"]) / dash_time
			Fx.slash(world, global_position, facing, Color("#9fe0ff"), 2.4, 70.0)
		"spin":
			lock_time = 0.45
			for k in 3:
				Fx.slash(world, global_position, facing.rotated(Vector3.UP, TAU * k / 3.0), Color("#ffe08a"), float(s["radius"]), 150.0)
			Fx.ring(world, global_position, float(s["radius"]), Color("#ffd166"))
			for e in world.enemies_in_radius(global_position, float(s["radius"])):
				_hit(e, float(s["mult"]), Color("#ffe08a"))
		"buff":
			lock_time = 0.5
			buff_time = float(s["duration"])
			buff_def = float(s["def_bonus_pct"])
			hp = minf(max_hp(), hp + max_hp() * float(s["heal_pct"]) / 100.0)
			hp_changed.emit()
			Fx.ring(world, global_position, 3.0, Color("#7dffb0"), 0.7)
			Fx.sparks(world, global_position, Color("#7dffb0"), 24)
			Fx.number(world, global_position, "+%d%% DEF" % int(buff_def), Color("#7dffb0"))
		"slam":
			lock_time = 0.6
			var center := global_position + facing * float(s["forward"])
			world.shake(0.35, 0.25)
			Fx.ring(world, center, float(s["radius"]), Color("#ff9f5a"), 0.5)
			Fx.disc(world, center, float(s["radius"]), Color("#ff7a3a"), 0.35)
			Fx.sparks(world, center, Color("#ffb36b"), 30)
			for e in world.enemies_in_radius(center, float(s["radius"])):
				_hit(e, float(s["mult"]), Color("#ffb36b"))
				e.stun(float(s["stun"]))


func dodge() -> void:
	if dead or dodge_cd > 0.0 or dash_time > 0.0:
		return
	var d: Dictionary = kit["dodge"]
	dodge_cd = float(d["cooldown"])
	var dir := joy if joy.length() > 0.1 else facing
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if kb.length() > 0.1:
		dir = Vector3(kb.x, 0, kb.y)
	dir = dir.normalized()
	facing = dir
	visual.rotation.y = atan2(dir.x, dir.z)
	dash_time = float(d["duration"])
	dash_vel = dir * float(d["distance"]) / dash_time
	dash_skill = {}
	invuln = dash_time + 0.1
	visual.play(d["anim"], 1.8, 0.04)


func drink_potion() -> void:
	if dead or potions <= 0 or potion_cd > 0.0 or hp >= max_hp():
		return
	potions -= 1
	potion_cd = 1.0
	hp = minf(max_hp(), hp + max_hp() * 0.45)
	hp_changed.emit()
	Fx.sparks(world, global_position, Color("#ff5a6e"), 18)


# --- dano ---

func _hit(enemy, mult: float, color: Color) -> void:
	var s: Dictionary = GameState.stats
	var dmg: float = s["atk"] * mult * randf_range(0.9, 1.1)
	var crit: bool = randf() * 100.0 < s["crit_chance"]
	if crit:
		dmg *= 1.0 + s["crit_damage"] / 100.0
	var dealt: float = enemy.take_damage(dmg, crit, global_position)
	if s["life_steal"] > 0.0 and dealt > 0.0:
		hp = minf(max_hp(), hp + dealt * s["life_steal"] / 100.0)
		hp_changed.emit()
	Fx.sparks(world, enemy.global_position, color, 8 if not crit else 16)


func take_damage(raw: float, attacker_level: int) -> void:
	if dead or invuln > 0.0:
		return
	var s: Dictionary = GameState.stats
	if randf() * 100.0 < s["block"]:
		Fx.number(world, global_position, "Bloqueio", Color("#9fd3ff"))
		visual.play("Block_Hit", 1.5, 0.05)
		return
	var defense: float = s["def"] * (1.0 + (buff_def / 100.0 if buff_time > 0.0 else 0.0))
	var dmg := Stats.mitigate(raw, defense, attacker_level)
	hp -= dmg
	since_hit = 0.0
	visual.flash()
	Fx.number(world, global_position, str(int(ceil(dmg))), Color("#ff5a5a"))
	world.shake(0.12, 0.12)
	hp_changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		visual.play("Death_A", 1.0, 0.05)
		died.emit()
