## Controles de toque com multitoque próprio: joystick flutuante na metade esquerda,
## ataque (segurar repete), 4 skills com recarga em pizza, esquiva e poção.
## Funciona com mouse no desktop (toque emulado).
extends Control

var player
var enabled := true
var touches := {}      # índice -> {"kind": "joy"|"btn", "id": String}
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_active := false
const JOY_R := 95.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func buttons() -> Array:
	var s := size
	var a := Vector2(s.x - 135, s.y - 135)
	var out := [{"id": "attack", "pos": a, "r": 74.0, "label": "", "icon": "broadsword", "color": Color("#d9a441")}]
	var offs := [Vector2(-185, 25), Vector2(-165, -110), Vector2(-75, -190), Vector2(55, -200)]
	var kit: Array = GameState.skills_db["sentinela"]["skills"]
	for i in 4:
		out.append({"id": "skill%d" % i, "pos": a + offs[i], "r": 50.0, "label": "", "icon": kit[i]["icon"], "color": Color("#8fb8ff"), "skill": i})
	out.append({"id": "dodge", "pos": a + Vector2(-300, 40), "r": 42.0, "label": "", "icon": "dodge", "color": Color("#9fe0c0")})
	out.append({"id": "potion", "pos": a + Vector2(-290, -80), "r": 36.0, "label": "", "icon": "health-potion", "color": Color("#ff5a6e")})
	return out


func _input(event: InputEvent) -> void:
	if not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for b in buttons():
				if event.position.distance_to(b["pos"]) <= b["r"] + 12.0:
					touches[event.index] = {"kind": "btn", "id": b["id"]}
					_press(b["id"], true)
					get_viewport().set_input_as_handled()
					return
			if event.position.x < size.x * 0.5 and event.position.y > 120:
				touches[event.index] = {"kind": "joy"}
				joy_origin = event.position
				joy_pos = event.position
				joy_active = true
				get_viewport().set_input_as_handled()
		elif touches.has(event.index):
			var t: Dictionary = touches[event.index]
			if t["kind"] == "joy":
				joy_active = false
				player.joy = Vector3.ZERO
			else:
				_press(t["id"], false)
			touches.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and touches.has(event.index) and touches[event.index]["kind"] == "joy":
		joy_pos = event.position
		var v: Vector2 = (joy_pos - joy_origin).limit_length(JOY_R) / JOY_R
		player.joy = Vector3(v.x, 0, v.y)
		queue_redraw()


func release_all() -> void:
	touches.clear()
	joy_active = false
	if player:
		player.joy = Vector3.ZERO
		player.attack_held = false
	queue_redraw()


func _press(id: String, down: bool) -> void:
	match id:
		"attack":
			player.attack_held = down
			if down:
				player.basic_attack()
		"dodge":
			if down:
				player.dodge()
		"potion":
			if down:
				player.drink_potion()
		_:
			if down and id.begins_with("skill"):
				player.use_skill(int(id.substr(5)))


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not enabled or player == null:
		return
	if joy_active:
		draw_circle(joy_origin, JOY_R, Color(1, 1, 1, 0.07))
		draw_arc(joy_origin, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.25), 3.0, true)
		draw_circle(joy_origin + (joy_pos - joy_origin).limit_length(JOY_R), 38, Color(1, 1, 1, 0.35))
	else:
		var hint := Vector2(170, size.y - 170)
		draw_arc(hint, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.08), 2.0, true)
	var font := get_theme_default_font()
	for b in buttons():
		var pos: Vector2 = b["pos"]
		var r: float = b["r"]
		var col: Color = b["color"]
		var cd := 0.0
		var cd_max := 1.0
		var extra := ""
		if b.has("skill"):
			cd = player.cooldowns[b["skill"]]
			cd_max = float(GameState.skills_db["sentinela"]["skills"][b["skill"]]["cooldown"]) * player.cd_mult()
		elif b["id"] == "dodge":
			cd = player.dodge_cd
			cd_max = float(GameState.skills_db["sentinela"]["dodge"]["cooldown"])
		elif b["id"] == "potion":
			extra = str(player.potions)
		draw_circle(pos, r, Color(0.06, 0.07, 0.09, 0.72))
		draw_arc(pos, r, 0, TAU, 48, col if cd <= 0.0 else col.darkened(0.55), 3.0, true)
		if cd > 0.0:
			var frac := clampf(cd / cd_max, 0.0, 1.0)
			var pts := PackedVector2Array([pos])
			for i in 33:
				var a := -PI / 2 + TAU * frac * i / 32.0
				pts.append(pos + Vector2(cos(a), sin(a)) * (r - 3))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		var locked: bool = b.has("skill") and not GameState.skill_unlocked(b["skill"])
		var tex: Texture2D = _tex(b.get("icon", ""))
		if tex:
			var isz := r * 1.15
			draw_texture_rect(tex, Rect2(pos - Vector2(isz, isz) / 2.0, Vector2(isz, isz)), false, Color(1, 1, 1, 0.25 if (cd > 0.0 or locked) else 0.95))
		if locked:
			draw_circle(pos, r - 3, Color(0, 0, 0, 0.55))
			var lv := "Nv %d" % int(GameState.skills_db["sentinela"]["skills"][b["skill"]]["unlock_level"])
			var ls := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
			draw_string(font, pos + Vector2(-ls.x / 2, 7), lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color("#c9c4b8"))
			continue
		var fs := int(r * 0.8)
		if cd <= 0.0:
			if extra != "":
				draw_string(font, pos + Vector2(r * 0.45, r * 0.9), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
			continue
		var label: String = b["label"] if cd <= 0.0 else ("%.0f" % ceil(cd) if cd >= 1.0 else "%.1f" % cd)
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, pos + Vector2(-ts.x / 2, ts.y / 3), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE if cd <= 0.0 else Color(1, 1, 1, 0.7))
		if extra != "":
			draw_string(font, pos + Vector2(r * 0.45, r * 0.9), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _icon(id: String, p: Vector2, r: float) -> void:
	var w := Color.WHITE
	match id:
		"attack":
			var a := p + Vector2(-r, r) * 0.42
			var b := p + Vector2(r, -r) * 0.48
			draw_line(a, b, w, 7.0, true)
			draw_line(p + Vector2(-r * 0.36, -r * 0.02), p + Vector2(r * 0.02, r * 0.36), w, 6.0, true)
			draw_circle(a, 6.0, w)
		"dodge":
			draw_arc(p, r * 0.45, -PI * 0.9, PI * 0.35, 20, w, 5.0, true)
			var tip := p + Vector2(cos(PI * 0.35), sin(PI * 0.35)) * r * 0.45
			draw_colored_polygon(PackedVector2Array([tip + Vector2(10, -8), tip + Vector2(-10, -6), tip + Vector2(2, 12)]), w)
		"potion":
			draw_circle(p + Vector2(0, r * 0.12), r * 0.42, Color("#ff5a6e"))
			draw_rect(Rect2(p + Vector2(-r * 0.14, -r * 0.55), Vector2(r * 0.28, r * 0.3)), w)


var _tex_cache := {}


func _tex(name: String) -> Texture2D:
	if name == "":
		return null
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/ui/icons/%s.svg" % name)
	return _tex_cache[name]
