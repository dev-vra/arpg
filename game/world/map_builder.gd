## Monta um mapa a partir da grade ASCII de data/maps.json com o kit de dungeon (KayKit, CC0).
## Legenda: # parede · . chão · P início · m grupo de mobs · B chefe · X saída · c baú
##          T tocha · d decoração · F Forja · M Mentora · O portal
## Geometria estática vai em MultiMesh por pedaço (chunk) de 4x4 células: poucas
## chamadas de desenho e no máximo 8 luzes por malha no renderer Mobile.
extends RefCounted

const CELL := 4.0
const CHUNK := 4
const DUNGEON := "res://assets/kaykit/dungeon/%s.glb"
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DECOR := ["barrel_large", "barrel_small_stack", "box_stacked", "crates_stacked", "keg", "trunk_large_A"]
const FIELD_DECOR := ["rubble_large", "barrel_large", "crates_stacked", "box_stacked", "sword_shield"]

static var _mesh_cache := {}

var rows: Array
var w: int
var h: int
var root: Node3D
var rng := RandomNumberGenerator.new()
var batches := {}   # "mesh|chunk" -> Array[Transform3D]
var _pillars := {}
var info := {"spawn": Vector3.ZERO, "mobs": [], "boss": [], "exits": [], "chests": [], "npcs": {}, "portal": [], "lights": []}


static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0, c.y * CELL)


func build(parent: Node3D, map_def: Dictionary, seed_value: int = 7) -> Dictionary:
	rows = map_def["rows"]
	h = rows.size()
	w = rows[0].length()
	rng.seed = seed_value
	root = Node3D.new()
	root.name = "Map"
	parent.add_child(root)
	var floors: Array = map_def["floor"]
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var field: bool = map_def["kind"] == "field"

	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch := _at(c)
			if ch == "#":
				if _touches_floor(c):
					_box(body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(CELL, 4, CELL))
				continue
			var pos := cell_to_world(c)
			var floor_name: String = floors[0] if rng.randf() < 0.7 else floors[rng.randi_range(0, floors.size() - 1)]
			_add(floor_name, c, Transform3D(Basis(Vector3.UP, PI * 0.5 * rng.randi_range(0, 3)), pos))
			_walls(c)
			match ch:
				"P": info["spawn"] = pos
				"m": info["mobs"].append(pos)
				"B": info["boss"].append(pos)
				"X": info["exits"].append(pos)
				"c": info["chests"].append(pos)
				"O": info["portal"].append(pos)
				"F", "M": info["npcs"][ch] = pos
				"T": _torch(c)
				"d": _decor(pos, DECOR, body, true)
			if field and ch == "." and _wall_count(c) >= 1 and rng.randf() < 0.18:
				_decor(pos + _toward_wall(c) * 1.25, FIELD_DECOR, body, false)
			if field and ch == "." and _wall_dir(c, Vector2i(0, -1)) and (x * 3 + y) % 5 == 0:
				_torch(c)

	# Chão: uma caixa só para colisão.
	var size := Vector3(w * CELL, 1, h * CELL)
	_box(body, Vector3((w - 1) * CELL / 2.0, -0.5, (h - 1) * CELL / 2.0), size)
	_flush()
	info["astar"] = _astar()
	info["size"] = Vector2(w * CELL, h * CELL)
	return info


func _at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return "#"
	return rows[c.y][c.x]


func _touches_floor(c: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if _at(c + Vector2i(dx, dy)) != "#":
				return true
	return false


func _wall_dir(c: Vector2i, d: Vector2i) -> bool:
	return _at(c + d) == "#"


func _wall_count(c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if _at(c + d) == "#":
			n += 1
	return n


func _toward_wall(c: Vector2i) -> Vector3:
	for d in DIRS:
		if _at(c + d) == "#":
			return Vector3(d.x, 0, d.y)
	return Vector3.ZERO


## Parede em cada borda entre chão e '#'. A borda de baixo (+Z, perto da câmera) é baixa.
func _walls(c: Vector2i) -> void:
	var center := cell_to_world(c)
	for d in DIRS:
		if _at(c + d) != "#":
			continue
		var low: bool = d == Vector2i(0, 1)
		var basis := Basis(Vector3.UP, PI / 2.0 if d.x != 0 else 0.0)
		if low:
			basis = basis.scaled(Vector3(1, 0.28, 1))
		var name := "wall"
		if not low and rng.randf() < 0.18:
			name = "wall_broken" if rng.randf() < 0.5 else "wall_arched"
		var edge := center + Vector3(d.x, 0, d.y) * (CELL / 2.0)
		_add(name, c, Transform3D(basis, edge))
		# Pilares nas pontas da parede.
		var along := Vector3(-d.y, 0, d.x) * (CELL / 2.0)
		for s in [-1, 1]:
			var p: Vector3 = edge + along * s
			var key := "pillar_%d_%d" % [roundi(p.x * 10), roundi(p.z * 10)]
			if not _pillars.has(key):
				_pillars[key] = true
				var pb := Basis().scaled(Vector3(0.6, 0.3 if low else 1.02, 0.6))
				_add("pillar", c, Transform3D(pb, p))


func _torch(c: Vector2i) -> void:
	var center := cell_to_world(c)
	for d in DIRS:
		if _at(c + d) == "#" and d != Vector2i(0, 1):
			var edge := center + Vector3(d.x, 0, d.y) * (CELL / 2.0 - 0.55)
			var t := _instance("torch_mounted")
			t.position = edge + Vector3(0, 2.4, 0)
			t.rotation.y = atan2(-d.x, -d.y)
			root.add_child(t)
			var l := OmniLight3D.new()
			l.light_color = Color("#ffa24d")
			l.light_energy = 2.2
			l.omni_range = 9.0
			l.omni_attenuation = 1.4
			l.position = edge - Vector3(d.x, 0, d.y) * 0.6 + Vector3(0, 2.9, 0)
			root.add_child(l)
			info["lights"].append(l)
			return


func _decor(pos: Vector3, pool: Array, body: StaticBody3D, solid: bool) -> void:
	var n := _instance(pool[rng.randi_range(0, pool.size() - 1)])
	n.position = pos + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	n.rotation.y = rng.randf() * TAU
	root.add_child(n)
	if solid:
		_box(body, n.position + Vector3(0, 0.7, 0), Vector3(1.4, 1.4, 1.4))


func _box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


func _instance(name: String) -> Node3D:
	return load(DUNGEON % name).instantiate()


# --- lotes em MultiMesh ---

func _add(mesh_name: String, c: Vector2i, xf: Transform3D) -> void:
	var key := "%s|%d_%d" % [mesh_name, c.x / CHUNK, c.y / CHUNK]
	if not batches.has(key):
		batches[key] = []
	batches[key].append(xf)


static func meshes_of(name: String) -> Array:
	if _mesh_cache.has(name):
		return _mesh_cache[name]
	var inst: Node3D = load(DUNGEON % name).instantiate()
	var out := []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = mi.transform
		var p := mi.get_parent()
		while p != inst and p is Node3D:
			xf = p.transform * xf
			p = p.get_parent()
		out.append([mi.mesh, xf])
	inst.free()
	_mesh_cache[name] = out
	return out


func _flush() -> void:
	for key in batches:
		var name: String = key.split("|")[0]
		var xfs: Array = batches[key]
		for pair in meshes_of(name):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = pair[0]
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i] * pair[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			root.add_child(mmi)


func _astar() -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, w, h)
	a.cell_size = Vector2(CELL, CELL)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	for y in h:
		for x in w:
			if rows[y][x] == "#":
				a.set_point_solid(Vector2i(x, y), true)
	return a
