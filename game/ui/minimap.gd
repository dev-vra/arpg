## Minimapa estilo Torchlight: a área explorada aparece como mancha translúcida com
## contorno suave (máscara borrada + shader), sem moldura. Ícones vetoriais para
## jogador, portal, saída, NPCs, baús, chefe, inimigos por perto e objetivo, com a
## trilha da missão rastreada. Norte para cima, igual à câmera. "full" = mapa grande.
extends Control

signal opened

const MASK_SHADER = preload("res://game/shaders/minimap.gdshader")
const PX := 8   # pixels da máscara por célula

var world
var full := false
var view_cells := 9.0
var layer: Control
var _mask: ImageTexture
var _dirty := true
var _origin := Vector2.ZERO
var _cell_px := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = MASK_SHADER
	layer.material = m
	layer.draw.connect(_draw_mask)
	add_child(layer)
	move_child(layer, 0)


func mark_dirty() -> void:
	_dirty = true


## Máscara da área explorada: células vistas em branco, borradas para bordas suaves.
func _refresh_mask() -> void:
	var rows: Array = world.map_def["rows"]
	var w: int = rows[0].length()
	var h: int = rows.size()
	var disc: PackedByteArray = GameState.discovery(world.map_id, w * h)
	var img := Image.create(w * PX, h * PX, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			if disc[y * w + x] == 1 and rows[y][x] != "#":
				img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), Color.WHITE)
	# Borra reduzindo e ampliando: vira forma arredondada, como mapa desenhado.
	img.resize(w * 2, h * 2, Image.INTERPOLATE_BILINEAR)
	img.resize(w * PX, h * PX, Image.INTERPOLATE_CUBIC)
	if _mask == null or _mask.get_width() != img.get_width():
		_mask = ImageTexture.create_from_image(img)
	else:
		_mask.update(img)
	_dirty = false


func _process(_d: float) -> void:
	if world == null or world.player == null:
		return
	if _dirty or _mask == null:
		_refresh_mask()
	var rows: Array = world.map_def["rows"]
	var w: int = rows[0].length()
	var h: int = rows.size()
	var pp: Vector3 = world.player.global_position
	if full:
		_cell_px = minf(size.x / w, (size.y - 60) / h)
		_origin = (size - Vector2(w, h) * _cell_px) / 2.0 + Vector2(0, 30)
	else:
		_cell_px = size.x / (view_cells * 2.0)
		_origin = size / 2.0 - Vector2(pp.x / 4.0 + 0.5, pp.z / 4.0 + 0.5) * _cell_px
	layer.queue_redraw()
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and not full:
		opened.emit()
		accept_event()


func _to_px(p: Vector3) -> Vector2:
	return _origin + Vector2(p.x / 4.0 + 0.5, p.z / 4.0 + 0.5) * _cell_px


func _draw_mask() -> void:
	if _mask:
		var rows: Array = world.map_def["rows"]
		layer.draw_texture_rect(_mask, Rect2(_origin, Vector2(rows[0].length(), rows.size()) * _cell_px), false)


func _draw() -> void:
	if world == null or world.player == null:
		return
	var rows: Array = world.map_def["rows"]
	var w: int = rows[0].length()
	var disc: PackedByteArray = GameState.discovery(world.map_id, w * rows.size())
	var pp: Vector3 = world.player.global_position
	var s := 1.4 if full else 1.25
	# Trilha da missão rastreada.
	var tgt: Dictionary = world.guide_target
	if not tgt.is_empty():
		var prev := _to_px(pp)
		for p in world.path_between(pp, tgt["pos"]) + PackedVector3Array([tgt["pos"]]):
			var q := _to_px(p)
			_dashed(prev, q, Color(1, 0.84, 0.45, 0.9))
			prev = q
	for p in world.info["exits"]:
		if _seen(p, disc, w):
			_icon_exit(_to_px(p), 7 * s)
	for p in world.info["portal"]:
		if _seen(p, disc, w):
			_icon_portal(_to_px(p), 7 * s)
	for n in world.npc_nodes.values():
		if _seen(n.global_position, disc, w):
			_icon_npc(_to_px(n.global_position), 7 * s, _npc_has_quest(n.npc_id))
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.kind == "chest" and not n.used and _seen(n.global_position, disc, w):
			_icon_chest(_to_px(n.global_position), 5.5 * s)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			if _seen(e.global_position, disc, w):
				_icon_boss(_to_px(e.global_position), 8 * s)
		elif e.global_position.distance_to(pp) < 20.0:
			draw_circle(_to_px(e.global_position), 2.4 * s, Color("#ff5a4d"))
	if not tgt.is_empty():
		_icon_star(_to_px(tgt["pos"]), (7.0 + sin(Time.get_ticks_msec() * 0.008) * 1.5) * s)
	_icon_player(_to_px(pp), world.player.facing, 8 * s)
	if full:
		_legend(disc, w)


func _npc_has_quest(npc: String) -> bool:
	for q in GameState.npc_quests(npc):
		if GameState.quest_status(q["id"]) in ["available", "ready"]:
			return true
	return false


func _seen(p: Vector3, disc: PackedByteArray, w: int) -> bool:
	var c := Vector2i(roundi(p.x / 4.0), roundi(p.z / 4.0))
	var i := c.y * w + c.x
	return c.x >= 0 and c.x < w and i >= 0 and i < disc.size() and disc[i] == 1


# --- ícones vetoriais ---

func _disc(c: Vector2, r: float, fill: Color, ring: Color) -> void:
	draw_circle(c + Vector2(1, 1.5), r + 1.5, Color(0, 0, 0, 0.45))
	draw_circle(c, r + 1.5, ring)
	draw_circle(c, r, fill)


func _icon_player(c: Vector2, f: Vector3, r: float) -> void:
	_disc(c, r, Color("#2a2418"), Color("#e8b54a"))
	var fwd := Vector2(f.x, f.z).normalized() * r * 0.8
	var side := Vector2(-fwd.y, fwd.x) * 0.65
	draw_colored_polygon(PackedVector2Array([c + fwd, c - fwd * 0.55 + side, c - fwd * 0.25, c - fwd * 0.55 - side]), Color.WHITE)


func _icon_portal(c: Vector2, r: float) -> void:
	_disc(c, r, Color("#0e2238"), Color("#7fd1ff"))
	draw_arc(c, r * 0.55, 0, TAU, 20, Color("#bfeaff"), 2.0, true)


func _icon_exit(c: Vector2, r: float) -> void:
	_disc(c, r, Color("#10281a"), Color("#8dff9a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.5, 0), c + Vector2(-r * 0.5, 0)]), Color("#c8ffd0"))
	draw_rect(Rect2(c + Vector2(-r * 0.18, 0), Vector2(r * 0.36, r * 0.5)), Color("#c8ffd0"))


func _icon_npc(c: Vector2, r: float, has_quest: bool) -> void:
	_disc(c, r, Color("#2a2210"), Color("#ffd166"))
	if has_quest:
		draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.6), Vector2(r * 0.24, r * 0.75)), Color("#ffd166"))
		draw_circle(c + Vector2(0, r * 0.45), r * 0.14, Color("#ffd166"))
	else:
		draw_circle(c, r * 0.35, Color("#ffd166"))


func _icon_chest(c: Vector2, r: float) -> void:
	draw_rect(Rect2(c - Vector2(r, r * 0.7) + Vector2(1, 1.5), Vector2(r * 2, r * 1.4)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(c - Vector2(r, r * 0.7), Vector2(r * 2, r * 1.4)), Color("#8a5a2b"))
	draw_rect(Rect2(c - Vector2(r, r * 0.7), Vector2(r * 2, r * 1.4)), Color("#ffcf7a"), false, 1.5)
	draw_line(c + Vector2(-r, -r * 0.1), c + Vector2(r, -r * 0.1), Color("#ffcf7a"), 1.5)


func _icon_boss(c: Vector2, r: float) -> void:
	_disc(c, r, Color("#3a0e0e"), Color("#ff6b4a"))
	var pts := PackedVector2Array([c + Vector2(-r * 0.6, r * 0.3), c + Vector2(-r * 0.6, -r * 0.35), c + Vector2(-r * 0.3, 0), c + Vector2(0, -r * 0.55), c + Vector2(r * 0.3, 0), c + Vector2(r * 0.6, -r * 0.35), c + Vector2(r * 0.6, r * 0.3)])
	draw_colored_polygon(pts, Color("#ffb36b"))


func _icon_star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, Color("#ffd166"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#5a3a00"), 1.2, true)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var d := a.distance_to(b)
	var dir := (b - a) / maxf(d, 0.001)
	var t := 0.0
	while t < d:
		draw_line(a + dir * t, a + dir * minf(t + 4.0, d), col, 2.0, true)
		t += 7.0


func _legend(disc: PackedByteArray, w: int) -> void:
	var font := get_theme_default_font()
	var rows: Array = world.map_def["rows"]
	var seen_n := 0
	var total := 0
	for y in rows.size():
		for x in w:
			if rows[y][x] != "#":
				total += 1
				seen_n += disc[y * w + x]
	draw_string(font, Vector2(20, 36), world.map_def["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#e8b54a"))
	draw_string(font, Vector2(20, 64), "Explorado %d%%" % int(100.0 * seen_n / maxf(1, total)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
	if not world.guide_target.is_empty():
		draw_string(font, Vector2(20, 90), "Objetivo: " + world.guide_target["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd166"))
