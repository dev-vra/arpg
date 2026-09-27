## Cena única de jogo: monta o mapa atual (GameState.current_map), jogador, mobs,
## NPCs, câmera e HUD. Viajar recarrega a cena com outro mapa.
extends Node3D

const MapBuilder = preload("res://game/world/map_builder.gd")
const Player = preload("res://game/actors/player.gd")
const Mob = preload("res://game/actors/mob.gd")
const LootDrop = preload("res://game/world/loot_drop.gd")
const Interactable = preload("res://game/world/interactable.gd")
const Hud = preload("res://game/ui/hud.gd")
const Loot = preload("res://core/loot.gd")

const CAM_OFFSET := Vector3(0, 10.5, 6.4)
const NPC_LOOKS := {
	"forge": {"sex": "Female", "skin": "#b98a6e", "hair": "Hair_Buns", "hair_color": "#6b2a1a", "anim": "Idle_FoldArms",
		"parts": [[["Female_Peasant_Body"], ["torso"], "#5a3a28", 0.5], [["Female_Peasant_Arms"], ["arms", "hands"], "#4a3024", 0.3], [["Female_Peasant_Legs"], ["legs"], "#2e2622", 0.6], [["Female_Peasant_Feet"], ["feet"], "#2e2622", 0.4]]},
	"mentor": {"sex": "Female", "skin": "#e0b8a0", "hair": "Hair_Long", "hair_color": "#d8d0c0", "anim": "Idle_Talking",
		"parts": [[["Female_Ranger_Head_Hood", "Female_Ranger_Body", "Female_Ranger_Acc_Pauldrons"], ["torso"], "#2c3e6b", 0.8], [["Female_Ranger_Arms"], ["arms", "hands"], "#22304f", 0.7], [["Female_Ranger_Legs"], ["legs"], "#1c2238", 0.7], [["Female_Ranger_Feet"], ["feet"], "#1c2238", 0.5]]},
}

var map_id: String
var map_def: Dictionary
var info: Dictionary
var player
var camera: Camera3D
var hud
var astar: AStarGrid2D
var shake_amt := 0.0
var shake_time := 0.0
var boss
var boss_dead := false
var kills := 0
var lights: Array = []
var builder


func _ready() -> void:
	map_id = GameState.current_map
	map_def = GameState.maps_db["maps"][map_id]
	_environment()
	builder = MapBuilder.new()
	info = builder.build(self, map_def, GameState.themes_db, hash(map_id))
	astar = info["astar"]
	lights = info["lights"]
	player = Player.new()
	player.world = self
	add_child(player)
	player.global_position = info["spawn"] + Vector3(0, 0.1, 0)
	player.died.connect(_on_player_died)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 120.0
	add_child(camera)
	camera.global_position = player.global_position + CAM_OFFSET
	camera.look_at(player.global_position + Vector3(0, 1, 0))
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	if map_def["kind"] == "hub":
		_spawn_hub()
	else:
		_spawn_field()
	GameState.toast.emit(map_def["name"] + (" · Difícil" if GameState.difficulty == "hard" and map_def["kind"] == "field" else ""), Color("#ffe3a0"))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(map_def.get("fog", "#0b0d10"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(map_def.get("ambient", "#2a2f3a"))
	env.ambient_light_energy = float(map_def.get("ambient_energy", 0.7))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 0.9
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(map_def.get("fog", "#0b0d10"))
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#a8bcff")
	moon.light_energy = float(map_def.get("moon", 0.5))
	moon.rotation_degrees = Vector3(-58, -32, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)


func _spawn_hub() -> void:
	var npcs: Dictionary = info["npcs"]
	if npcs.has("F"):
		var f: Vector3 = npcs["F"]
		_interactable("forge", "Vesna · Forja Cinzenta", f, NPC_LOOKS["forge"])
		builder.place("Anvil", f + Vector3(1.6, 0, 0.4), -0.4, 1.3)
		builder.place("Workbench", f + Vector3(-1.8, 0, -1.2), 0.3, 1.2)
		builder.place("WeaponStand", f + Vector3(0.2, 0, -1.8), 0.0, 1.3)
		var fire := OmniLight3D.new()
		fire.light_color = Color("#ff7a2a")
		fire.light_energy = 2.5
		fire.omni_range = 7.0
		fire.position = f + Vector3(1.6, 1.5, 0.4)
		add_child(fire)
		lights.append(fire)
	if npcs.has("M"):
		_interactable("mentor", "Ilse · Mentora", npcs["M"], NPC_LOOKS["mentor"])
		builder.place("Banner_1", npcs["M"] + Vector3(1.4, 0, -1.6), 0.0, 1.4)
		builder.place("Banner_2", npcs["M"] + Vector3(-1.4, 0, -1.6), 0.0, 1.4)
	for p in info["portal"]:
		_interactable("portal", "Portal dos Mapas", p)
	player.potions = player.POTION_CHARGES


func _spawn_field() -> void:
	var diff: Dictionary = GameState.economy["field_loot"]["difficulty"][GameState.difficulty]
	var lvl: int = int(map_def["level"]) + int(diff["level"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for pos in info["mobs"]:
		var n := rng.randi_range(3, 5)
		for i in n:
			var mid: String = map_def["mobs"][rng.randi_range(0, map_def["mobs"].size() - 1)]
			_spawn_mob(mid, lvl + rng.randi_range(0, 1), diff, pos + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6)))
	for pos in info["boss"]:
		boss = _spawn_mob(map_def["boss"], lvl + 2, diff, pos)
	for pos in info["chests"]:
		var c = _interactable("chest", "Baú", pos, {}, "Chest_Wood")
		c.radius = 2.4
	for pos in info["exits"]:
		_interactable("exit", "Voltar ao Bastião", pos)


func _spawn_mob(mid: String, lvl: int, diff: Dictionary, pos: Vector3):
	var m := Mob.new()
	m.setup(mid, GameState.mobs_db["mobs"][mid], lvl, diff)
	m.world = self
	add_child(m)
	m.global_position = pos
	m.rotation.y = randf() * TAU
	m.killed.connect(_on_mob_killed)
	return m


func _interactable(kind: String, title: String, pos: Vector3, look: Dictionary = {}, prop: String = ""):
	var n := Interactable.new()
	n.setup(kind, title, look, prop)
	add_child(n)
	n.global_position = pos
	return n


func _process(delta: float) -> void:
	if player == null:
		return
	var target: Vector3 = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 7.0))
	if shake_time > 0.0:
		shake_time -= delta
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amt * (shake_time / 0.35)
	for l in lights:
		l.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.011 + l.position.x) * 0.25
	hud.set_prompt(_nearest_interactable())


func shake(amount: float, time: float) -> void:
	shake_amt = maxf(shake_amt if shake_time > 0.0 else 0.0, amount)
	shake_time = maxf(shake_time, time)


# --- consultas para atores ---

func enemies_in_radius(pos: Vector3, r: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector3 = e.global_position - pos
		d.y = 0
		if d.length() <= r + 0.4 * float(e.def.get("scale", 1.0)):
			out.append(e)
	return out


func enemies_in_arc(pos: Vector3, facing: Vector3, r: float, arc_deg: float) -> Array:
	var out := []
	var cos_half := cos(deg_to_rad(arc_deg / 2.0))
	for e in enemies_in_radius(pos, r):
		var d: Vector3 = e.global_position - pos
		d.y = 0
		if d.length() < 1.0 or d.normalized().dot(facing) >= cos_half:
			out.append(e)
	return out


func nearest_enemy(pos: Vector3, r: float):
	var best = null
	var best_d := r
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == "idle" and not has_line_of_sight(pos, e.global_position):
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 1.2, 0), b + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func path_between(a: Vector3, b: Vector3) -> PackedVector3Array:
	var ca := _cell(a)
	var cb := _cell(b)
	if not astar.is_in_boundsv(ca) or not astar.is_in_boundsv(cb) or astar.is_point_solid(ca) or astar.is_point_solid(cb):
		return PackedVector3Array()
	var out := PackedVector3Array()
	for c in astar.get_id_path(ca, cb):
		out.append(MapBuilder.cell_to_world(c))
	return out


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / MapBuilder.CELL), roundi(p.z / MapBuilder.CELL))


# --- eventos ---

func boss_awake(b) -> void:
	hud.show_boss(b)


func _on_mob_killed(m) -> void:
	kills += 1
	GameState.add_xp(int(float(m.def["xp"]) * (1.0 + 0.1 * (m.level - 1))))
	var drops := Loot.roll_kill(GameState.loot_ctx(), map_def, GameState.difficulty, m.is_boss)
	spawn_drops(drops, m.global_position)
	if m.is_boss:
		boss_dead = true
		hud.show_boss(null)
		shake(0.6, 0.5)
		GameState.toast.emit("%s derrotado!" % m.def["name"], Color("#ff9f1c"))
		if map_id == "vale_oco" and GameState.difficulty == "hard" and GameState.character.level >= 30:
			GameState.complete_challenge("hollow_vale_hard")
		if map_def.has("challenge") and GameState.character.level >= 45:
			GameState.complete_challenge(map_def["challenge"])
		GameState.save_game()


func spawn_drops(drops: Array, pos: Vector3) -> void:
	for d in drops:
		var n := LootDrop.new()
		n.setup(d, pos + Vector3(0, 0.2, 0), player)
		add_child(n)


func _nearest_interactable():
	if player.dead:
		return null
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.used and n.global_position.distance_to(player.global_position) < n.radius:
			return n
	return null


func interact(n) -> void:
	match n.kind:
		"forge":
			hud.open_panel("forge")
		"mentor":
			hud.open_panel("mentor")
		"portal":
			hud.open_panel("maps")
		"exit":
			travel("bastiao", "normal")
		"chest":
			n.used = true
			var weight := 3
			var drops := []
			for i in weight:
				drops += Loot.roll_kill(GameState.loot_ctx(), map_def, GameState.difficulty, false)
			spawn_drops(drops, n.global_position)
			n.get_child(0).scale = Vector3(1.1, 0.8, 1.1)


func travel(to_map: String, difficulty: String) -> void:
	GameState.current_map = to_map
	GameState.difficulty = difficulty
	GameState.save_game()
	get_tree().call_deferred("reload_current_scene")


func _on_player_died() -> void:
	GameState.save_game()
	hud.show_death()
