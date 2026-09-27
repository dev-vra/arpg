## Monta um mapa a partir da grade ASCII de data/maps.json e do tema em data/themes.json
## (kits Quaternius, CC0: natureza, vila e props).
## Legenda: # borda · . chão · P início · m grupo de mobs · B chefe · X saída · c baú
##          T luz · d decoração · F Forja · M Mentora · O portal
## Temas: forest (árvores e pedras como borda, grama espalhada, chão procedural),
##        ruins/plaza (muros de tijolo, piso de lajotas).
## Geometria repetida vai em MultiMesh por pedaço (chunk) de 4x4 células: poucas
## chamadas de desenho e no máximo 8 luzes por malha no renderer Mobile.
extends RefCounted

const CELL := 4.0
const CHUNK := 4
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const KITS := ["nature", "village", "props"]
const GROUND_SHADER = preload("res://game/shaders/ground.gdshader")

static var _mesh_cache := {}
static var _path_cache := {}

var rows: Array
var w: int
var h: int
var root: Node3D
var theme: Dictionary
var rng := RandomNumberGenerator.new()
var batches := {}   # "asset|chunk" -> Array[Transform3D]
var _corners := {}
var info := {"spawn": Vector3.ZERO, "mobs": [], "boss": [], "exits": [], "chests": [], "npcs": {}, "portal": [], "lights": []}


static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0, c.y * CELL)


## Acha o glTF de um asset pelo nome em qualquer kit.
static func asset_path(name: String) -> String:
	if _path_cache.has(name):
		return _path_cache[name]
	for kit in KITS:
		var p := "res://assets/q/%s/%s.gltf" % [kit, name]
		if ResourceLoader.exists(p):
			_path_cache[name] = p
			return p
	push_error("asset não encontrado: " + name)
	return ""


func build(parent: Node3D, map_def: Dictionary, themes: Dictionary, seed_value: int = 7) -> Dictionary:
	rows = map_def["rows"]
	h = rows.size()
	w = rows[0].length()
	theme = themes["themes"][map_def.get("theme", "forest")]
	rng.seed = seed_value
	root = Node3D.new()
	root.name = "Map"
	parent.add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	_ground()
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch := _at(c)
			if ch == "#":
				if _touches_floor(c):
					_box(body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(CELL, 4, CELL))
					_border(c)
				elif _near_floor(c, 2) and rng.randf() < 0.5:
					_border(c)
				continue
			var pos := cell_to_world(c)
			_floor(c)
			if theme.has("walls"):
				_walls(c)
			_scatter(c)
			match ch:
				"P": info["spawn"] = pos
				"m": info["mobs"].append(pos)
				"B": info["boss"].append(pos)
				"X": info["exits"].append(pos)
				"c": info["chests"].append(pos)
				"O": info["portal"].append(pos)
				"F", "M": info["npcs"][ch] = pos
				"T": _light(c)
				"d": _decor(pos, body)
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
	return _near_floor(c, 1)


func _near_floor(c: Vector2i, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if _at(c + Vector2i(dx, dy)) != "#":
				return true
	return false


func _pick(list: Array) -> String:
	return list[rng.randi_range(0, list.size() - 1)]


# --- chão ---

func _ground() -> void:
	var g: Dictionary = theme["ground"]
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2((w + 6) * CELL, (h + 6) * CELL)
	mi.mesh = plane
	mi.position = Vector3((w - 1) * CELL / 2.0, 0.0, (h - 1) * CELL / 2.0)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("color_a", Color(g["a"]))
	m.set_shader_parameter("color_b", Color(g["b"]))
	m.set_shader_parameter("color_c", Color(g["c"]))
	m.set_shader_parameter("scale", float(g["scale"]))
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	m.set_shader_parameter("noise", nt)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _floor(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	if theme.has("tiles") and rng.randf() < float(theme.get("tile_chance", 1.0)):
		# 4 lajotas de 2 m por célula.
		for ox in [-1.0, 1.0]:
			for oz in [-1.0, 1.0]:
				_add(_pick(theme["tiles"]), c, Transform3D(Basis(Vector3.UP, PI * 0.5 * rng.randi_range(0, 3)), pos + Vector3(ox, 0.02, oz)))
	elif theme.has("paths") and rng.randf() < float(theme.get("path_chance", 0.0)):
		_add(_pick(theme["paths"]), c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.4), pos + Vector3(rng.randf_range(-1, 1), 0.02, rng.randf_range(-1, 1))))


func _scatter(c: Vector2i) -> void:
	var list: Array = theme.get("scatter", [])
	if list.is_empty():
		return
	var sc: Array = theme["scatter_scale"]
	var pos := cell_to_world(c)
	for i in int(theme["scatter_per_cell"]):
		var off := Vector3(rng.randf_range(-1.9, 1.9), 0, rng.randf_range(-1.9, 1.9))
		var s := rng.randf_range(float(sc[0]), float(sc[1]))
		_add(_pick(list), c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos + off))


# --- bordas ---

## Borda natural: árvore alta ou pedra/arbusto. Do lado da câmera (+Z) só coisa baixa.
func _border(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var near_cam: bool = _at(c + Vector2i(0, -1)) != "#" or (_at(c + Vector2i(0, -2)) != "#" and _at(c + Vector2i(0, -1)) == "#")
	var tall_list: Array = theme.get("border_tall", theme.get("behind", []))
	var ts: Array = theme["tall_scale"]
	if theme.has("walls"):
		# Muros já fecham a borda; atrás deles, árvores só no fundo (norte).
		if not near_cam and not tall_list.is_empty() and rng.randf() < 0.35:
			var s := rng.randf_range(float(ts[0]), float(ts[1]))
			_add(_pick(tall_list), c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1.5, 0))))
		return
	if not near_cam and rng.randf() < float(theme.get("tall_chance", 0.5)):
		var s := rng.randf_range(float(ts[0]), float(ts[1]))
		_add(_pick(tall_list), c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))))
	for i in 2:
		var s2 := rng.randf_range(0.45, 0.85)
		_add(_pick(theme["border_low"]), c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s2), pos + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))))


## Muro em cada borda entre chão e '#': dois módulos de 2 m. Lado da câmera (+Z) é baixo.
func _walls(c: Vector2i) -> void:
	var center := cell_to_world(c)
	for d in DIRS:
		if _at(c + d) != "#":
			continue
		var low: bool = d == Vector2i(0, 1)
		var yaw := atan2(float(-d.x), float(-d.y))
		var basis := Basis(Vector3.UP, yaw)
		if low:
			basis = basis.scaled(Vector3(1, 0.3, 1))
		var edge := center + Vector3(d.x, 0, d.y) * (CELL / 2.0)
		var along := Vector3(-d.y, 0, d.x)
		for s in [-1.0, 1.0]:
			var name: String = theme["low_wall"] if low else _pick(theme["walls"])
			_add(name, c, Transform3D(basis, edge + along * s))
		for s in [-2.0, 2.0]:
			var p: Vector3 = edge + along * s
			var key := "%d_%d" % [roundi(p.x * 10), roundi(p.z * 10)]
			if not _corners.has(key):
				_corners[key] = true
				_add(theme["corner"], c, Transform3D(Basis().scaled(Vector3(1, 0.3 if low else 1.0, 1)), p))


# --- luzes e decoração ---

func _light(c: Vector2i) -> void:
	var L: Dictionary = theme["light"]
	var pos := cell_to_world(c)
	var anchor := pos
	for d in DIRS:
		if _at(c + d) == "#" and d != Vector2i(0, 1):
			anchor = pos + Vector3(d.x, 0, d.y) * 1.3
			break
	var n: Node3D = load(asset_path(L["prop"])).instantiate()
	n.position = anchor + (Vector3(0, 1.8, 0) if L["prop"].begins_with("Torch") else Vector3.ZERO)
	n.scale = Vector3.ONE * (1.6 if L["prop"].begins_with("Torch") else 1.4)
	root.add_child(n)
	var l := OmniLight3D.new()
	l.light_color = Color(L["color"])
	l.light_energy = float(L["energy"])
	l.omni_range = float(L["range"])
	l.omni_attenuation = 1.3
	l.position = anchor + Vector3(0, 2.4, 0)
	root.add_child(l)
	info["lights"].append(l)


func _decor(pos: Vector3, body: StaticBody3D) -> void:
	var n: Node3D = load(asset_path(_pick(theme["decor"]))).instantiate()
	n.position = pos + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * 1.3
	root.add_child(n)
	_box(body, n.position + Vector3(0, 0.7, 0), Vector3(1.4, 1.4, 1.4))


## Prop solto com colisão, para cenas montadas à mão (Forja, praça).
func place(name: String, pos: Vector3, yaw: float, scale: float = 1.0) -> Node3D:
	var n: Node3D = load(asset_path(name)).instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	root.add_child(n)
	return n


func _box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


# --- lotes em MultiMesh ---

func _add(name: String, c: Vector2i, xf: Transform3D) -> void:
	var key := "%s|%d_%d" % [name, floori(c.x / float(CHUNK)), floori(c.y / float(CHUNK))]
	if not batches.has(key):
		batches[key] = []
	batches[key].append(xf)


## Malhas de um asset com a transformação relativa à raiz, e sombra só nos grandes.
static func meshes_of(name: String) -> Array:
	if _mesh_cache.has(name):
		return _mesh_cache[name]
	var inst: Node3D = load(asset_path(name)).instantiate()
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
	var small := ["Grass", "Clover", "Fern", "Flower", "Pebble", "Mushroom", "RockPath", "Floor", "Prop_Brick"]
	for key in batches:
		var name: String = key.split("|")[0]
		var xfs: Array = batches[key]
		var cast := true
		for s in small:
			if name.begins_with(s):
				cast = false
		for pair in meshes_of(name):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = pair[0]
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i] * pair[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
