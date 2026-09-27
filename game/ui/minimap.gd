## Minimapa com névoa de descoberta: só aparece o que o jogador já viu (salvo por mapa).
## Norte para cima (igual à câmera). Marca jogador, inimigos por perto, chefe, saída,
## portal, NPCs, baús e o objetivo da missão rastreada com a trilha até ele.
## Modo "full" desenha o mapa inteiro (tela de mapa grande).
extends Control

signal opened

var world
var full := false
var view_cells := 11.0
var _grid_cache: Image
var _tex: ImageTexture
var _dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func mark_dirty() -> void:
	_dirty = true


## Textura da grade (1 pixel por célula): chão descoberto, borda descoberta, nada.
func _refresh_texture() -> void:
	var rows: Array = world.map_def["rows"]
	var w: int = rows[0].length()
	var h: int = rows.size()
	var disc: PackedByteArray = GameState.discovery(world.map_id, w * h)
	if _grid_cache == null or _grid_cache.get_width() != w:
		_grid_cache = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var floor_c := Color(0.42, 0.46, 0.55, 0.92)
	var wall_c := Color(0.09, 0.1, 0.13, 0.95)
	for y in h:
		for x in w:
			var seen := disc[y * w + x] == 1 or _near_seen(disc, w, h, x, y)
			if not seen:
				_grid_cache.set_pixel(x, y, Color(0, 0, 0, 0))
			elif rows[y][x] == "#":
				_grid_cache.set_pixel(x, y, wall_c)
			else:
				_grid_cache.set_pixel(x, y, floor_c if disc[y * w + x] == 1 else wall_c)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_grid_cache)
	else:
		_tex.update(_grid_cache)
	_dirty = false


func _near_seen(disc: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(x, y) + d
		if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and disc[c.y * w + c.x] == 1:
			return true
	return false


func _process(_d: float) -> void:
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and not full:
		opened.emit()
		accept_event()


## Converte posição do mundo para pixel do minimapa.
func _to_px(p: Vector3, origin: Vector2, cell_px: float) -> Vector2:
	var cell := 4.0
	return origin + Vector2(p.x / cell + 0.5, p.z / cell + 0.5) * cell_px


func _draw() -> void:
	if world == null or world.player == null:
		return
	if _dirty or _tex == null:
		_refresh_texture()
	var rows: Array = world.map_def["rows"]
	var w: int = rows[0].length()
	var h: int = rows.size()
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.04, 0.06, 0.78))
	var cell_px: float
	var origin: Vector2
	var pp: Vector3 = world.player.global_position
	if full:
		cell_px = minf(sz.x / w, sz.y / h)
		origin = (sz - Vector2(w, h) * cell_px) / 2.0
	else:
		cell_px = sz.x / (view_cells * 2.0)
		origin = sz / 2.0 - Vector2(pp.x / 4.0 + 0.5, pp.z / 4.0 + 0.5) * cell_px
	draw_texture_rect(_tex, Rect2(origin, Vector2(w, h) * cell_px), false)
	var disc: PackedByteArray = GameState.discovery(world.map_id, w * h)
	# Marcadores fixos (só se a célula foi vista).
	var info: Dictionary = world.info
	for p in info["exits"]:
		_marker(p, origin, cell_px, Color("#8dff9a"), 5.0, disc, w)
	for p in info["portal"]:
		_marker(p, origin, cell_px, Color("#7fd1ff"), 6.0, disc, w)
	for n in world.npc_nodes.values():
		_marker(n.global_position, origin, cell_px, Color("#ffd166"), 5.0, disc, w)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.kind == "chest" and not n.used:
			_marker(n.global_position, origin, cell_px, Color("#c08a4a"), 4.0, disc, w)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(pp) < 22.0 or (e.is_boss and _seen(e.global_position, disc, w)):
			var c := Color("#ff9f1c") if e.is_boss else Color("#ff4d4d")
			draw_circle(_to_px(e.global_position, origin, cell_px), 5.5 if e.is_boss else 2.6, c)
	# Objetivo da missão e trilha.
	var tgt: Dictionary = world.guide_target
	if not tgt.is_empty():
		var pts: PackedVector3Array = world.path_between(pp, tgt["pos"])
		var prev := _to_px(pp, origin, cell_px)
		for p in pts:
			var q := _to_px(p, origin, cell_px)
			draw_line(prev, q, Color(1, 0.82, 0.4, 0.7), 2.0, true)
			prev = q
		draw_line(prev, _to_px(tgt["pos"], origin, cell_px), Color(1, 0.82, 0.4, 0.7), 2.0, true)
		var tp := _to_px(tgt["pos"], origin, cell_px)
		var pulse := 6.0 + sin(Time.get_ticks_msec() * 0.008) * 2.0
		draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -pulse), tp + Vector2(pulse, 0), tp + Vector2(0, pulse), tp + Vector2(-pulse, 0)]), Color("#ffd166"))
	# Jogador: seta na direção em que olha.
	var me := _to_px(pp, origin, cell_px)
	var f: Vector3 = world.player.facing
	var fwd := Vector2(f.x, f.z).normalized() * 9.0
	var side := Vector2(-fwd.y, fwd.x) * 0.6
	draw_colored_polygon(PackedVector2Array([me + fwd, me - fwd * 0.6 + side, me - fwd * 0.3, me - fwd * 0.6 - side]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, sz), Color("#d9a441"), false, 2.0)
	if full:
		var font := get_theme_default_font()
		draw_string(font, Vector2(16, 34), world.map_def["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#d9a441"))
		var seen_n := 0
		var total := 0
		for y in h:
			for x in w:
				if rows[y][x] != "#":
					total += 1
					seen_n += disc[y * w + x]
		draw_string(font, Vector2(16, 64), "Explorado: %d%%" % int(100.0 * seen_n / maxf(1, total)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
		if not tgt.is_empty():
			draw_string(font, Vector2(16, 90), "Objetivo: " + tgt["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd166"))


func _seen(p: Vector3, disc: PackedByteArray, w: int) -> bool:
	var c := Vector2i(roundi(p.x / 4.0), roundi(p.z / 4.0))
	var i := c.y * w + c.x
	return i >= 0 and i < disc.size() and disc[i] == 1


func _marker(p: Vector3, origin: Vector2, cell_px: float, c: Color, r: float, disc: PackedByteArray, w: int) -> void:
	if _seen(p, disc, w):
		draw_circle(_to_px(p, origin, cell_px), r, c)
		draw_arc(_to_px(p, origin, cell_px), r + 1.5, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.5)
