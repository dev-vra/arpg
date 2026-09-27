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
const Fx = preload("res://game/fx/fx.gd")

const CAM_OFFSET := Vector3(0, 10.5, 6.4)

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
var guide: MultiMeshInstance3D
var guide_target: Dictionary = {}
var _tick := 0.0
var npc_nodes := {}


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
	GameState.leveled.connect(_on_level_up)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 120.0
	add_child(camera)
	camera.global_position = player.global_position + CAM_OFFSET
	camera.look_at(player.global_position + Vector3(0, 1, 0))
	info["w"] = map_def["rows"][0].length()
	info["h"] = map_def["rows"].size()
	guide = _make_guide()
	add_child(guide)
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
		npc_nodes["forge"] = _npc("forge", f)
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
		npc_nodes["mentor"] = _npc("mentor", npcs["M"])
		builder.place("Banner_1", npcs["M"] + Vector3(1.4, 0, -1.6), 0.0, 1.4)
		builder.place("Banner_2", npcs["M"] + Vector3(-1.4, 0, -1.6), 0.0, 1.4)
	for p in info["portal"]:
		_interactable("portal", "Portal dos Mapas", p)
	player.potions = player.POTION_CHARGES
	if not GameState.flags.get("intro_seen", false):
		GameState.flags["intro_seen"] = true
		hud.open_dialogue.call_deferred("mentor", true)


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


func _npc(id: String, pos: Vector3):
	var d: Dictionary = GameState.dialogues_db["npcs"][id]
	var n = _interactable(id, "%s · %s" % [d["name"], d["title"]], pos, d["look"])
	n.npc_id = id
	return n


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
	_tick += delta
	if _tick >= 0.3:
		_tick = 0.0
		if GameState.reveal(map_id, info["w"], info["h"], _cell(player.global_position), 3):
			hud.minimap_dirty()
		_update_guide()


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
	player.on_kill()
	GameState.add_xp(int(float(m.def["xp"]) * (1.0 + 0.1 * (m.level - 1))))
	var drops := Loot.roll_kill(GameState.loot_ctx(), map_def, GameState.difficulty, m.is_boss)
	for qi in GameState.quest_drops(m.id):
		drops.append({"kind": "quest", "key": qi})
	spawn_drops(drops, m.global_position)
	GameState.quest_event({"type": "kill", "mob": m.id, "map": map_id})
	if m.is_boss:
		boss_dead = true
		hud.show_boss(null)
		shake(0.6, 0.5)
		GameState.toast.emit("%s derrotado!" % m.def["name"], Color("#ff9f1c"))
		if map_id == "vale_oco" and GameState.difficulty == "hard" and GameState.character.level >= 30:
			GameState.complete_challenge("hollow_vale_hard")
		if map_def.has("challenge") and GameState.character.level >= 45:
			GameState.complete_challenge(map_def["challenge"])
		GameState.quest_event({"type": "clear", "map": map_id})
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
		"forge", "mentor":
			hud.open_dialogue(n.kind)
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


func _on_level_up(level: int) -> void:
	if player == null or player.dead:
		return
	Fx.level_up(self, player.global_position)
	player.hp = player.max_hp()
	player.hp_changed.emit()
	shake(0.25, 0.3)
	hud.level_banner(level)


func _on_player_died() -> void:
	GameState.save_game()
	hud.show_death()



# --- rastreio de missão: alvo e trilha no chão ---

## Onde está o objetivo da missão rastreada, a partir deste mapa.
func quest_target() -> Dictionary:
	var id: String = GameState.tracked_quest
	if id == "" or not GameState.tracked_quests().has(id):
		return {}
	var q: Dictionary = GameState.Quests.find(GameState.quests_db, id)
	var g: Dictionary = q["goal"]
	if GameState.quests["done"].has(id):
		var giver: String = q.get("giver", "mentor")
		if npc_nodes.has(giver):
			return {"pos": npc_nodes[giver].global_position, "label": "Entregar a %s" % GameState.dialogues_db["npcs"][giver]["name"]}
		return _way_home()
	var want_map := ""
	var want_mob := ""
	match g["type"]:
		"kill":
			want_map = g.get("map", "")
			want_mob = "" if g["mob"] == "any" else g["mob"]
		"collect":
			want_mob = g["mob"]
			want_map = _map_with_mob(want_mob)
		"clear":
			want_map = g["map"]
	if map_def["kind"] == "hub":
		if info["portal"].is_empty():
			return {}
		return {"pos": info["portal"][0], "label": "Portal: %s" % GameState.maps_db["maps"][want_map]["name"]}
	if want_map != "" and want_map != map_id:
		return _way_home()
	if g["type"] == "clear":
		if boss and is_instance_valid(boss) and boss.state != "dead":
			return {"pos": boss.global_position, "label": boss.def["name"]}
		return {}
	var best = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if want_mob != "" and e.id != want_mob:
			continue
		if best == null or e.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = e
	return {"pos": best.global_position, "label": best.def["name"]} if best else {}


func _way_home() -> Dictionary:
	return {"pos": info["exits"][0], "label": "Voltar ao Bastião"} if not info["exits"].is_empty() else {}


func _map_with_mob(mob: String) -> String:
	for id in GameState.maps_db["maps"]:
		if GameState.maps_db["maps"][id].get("mobs", []).has(mob):
			return id
	return ""


func _make_guide() -> MultiMeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.38, 0.42, 0.04)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 48
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Fx.glow_mat(Color("#ffd166", 0.75), 0.9)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Setas douradas no chão, a cada 1,8 m, do jogador até o objetivo (caminho A*).
func _update_guide() -> void:
	guide_target = quest_target()
	var mm := guide.multimesh
	if guide_target.is_empty() or player.dead:
		mm.visible_instance_count = 0
		return
	var pts := PackedVector3Array([player.global_position])
	var goal: Vector3 = guide_target["pos"]
	if player.global_position.distance_to(goal) > 10.0 or not has_line_of_sight(player.global_position, goal):
		var path := path_between(player.global_position, goal)
		# Pula o centro da célula atual (evita setas para trás).
		if path.size() > 1:
			path.remove_at(0)
		pts.append_array(path)
	pts.append(goal)
	var n := 0
	var carry := 1.4
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		a.y = 0.08
		b.y = 0.08
		var seg := a.distance_to(b)
		var dir := (b - a).normalized() if seg > 0.01 else Vector3.FORWARD
		var t := carry
		while t < seg and n < mm.instance_count:
			var pos := a + dir * t
			if pos.distance_to(guide_target["pos"]) < 1.5:
				break
			var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)
			mm.set_instance_transform(n, Transform3D(basis, pos))
			n += 1
			t += 1.8
		carry = t - seg
	mm.visible_instance_count = n
