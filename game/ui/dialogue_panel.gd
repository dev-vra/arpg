## Janela de interação com NPC: retrato 3D vivo, fala com efeito de digitação e opções
## (missões para aceitar/acompanhar/entregar, conversas da lore, serviços como a Forja).
extends PanelContainer

const UiTheme = preload("res://game/ui/ui_theme.gd")
const ItemText = preload("res://game/ui/item_text.gd")
const Humanoid = preload("res://game/actors/humanoid.gd")
const Quests = preload("res://core/quests.gd")

var hud
var npc_id := ""
var intro := false
var npc: Dictionary
var text: RichTextLabel
var options: VBoxContainer
var _tw: Tween


func _ready() -> void:
	npc = GameState.dialogues_db["npcs"][npc_id]
	var vp := get_viewport().get_visible_rect().size
	var s := Vector2(minf(1180, vp.x - 24), 236)
	custom_minimum_size = s
	size = s
	position = Vector2((vp.x - s.x) / 2.0, vp.y - s.y - 10)
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.06, 0.065, 0.085, 0.94), UiTheme.GOLD.darkened(0.3), 12, 2, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	row.add_child(_portrait())
	# Centro: nome + fala + pular.
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var head := HBoxContainer.new()
	mid.add_child(head)
	head.add_child(UiTheme.title(npc["name"], 26))
	var title_l := Label.new()
	title_l.text = "  " + npc["title"]
	title_l.add_theme_color_override("font_color", UiTheme.MUTED)
	title_l.add_theme_font_size_override("font_size", 16)
	title_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title_l)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 20)
	text.add_theme_font_size_override("italics_font_size", 20)
	text.gui_input.connect(_on_text_input)
	mid.add_child(text)
	var skip := Button.new()
	skip.text = "»"
	skip.flat = true
	skip.tooltip_text = "Pular"
	skip.add_theme_font_size_override("font_size", 30)
	skip.add_theme_color_override("font_color", UiTheme.GOLD)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(_skip)
	mid.add_child(skip)
	# Direita: opções.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(minf(380, s.x * 0.36), 0)
	row.add_child(right)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	options = VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 6)
	sc.add_child(options)
	if intro and npc.has("intro"):
		_say(npc["intro"], [["Entendido.", _root]])
	else:
		_root()


func _on_text_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_skip()


## Pular: completa a fala; se já estava completa e só há uma opção, segue.
func _skip() -> void:
	if text.visible_ratio < 1.0:
		if _tw:
			_tw.kill()
		text.visible_ratio = 1.0
	elif options.get_child_count() == 1:
		options.get_child(0).emit_signal("pressed")


## Retrato: humanoide com a mesma aparência, num mundo 3D próprio, do peito para cima.
func _portrait() -> Control:
	var box := VBoxContainer.new()
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(190, 212)
	svc.stretch = true
	svc.add_theme_stylebox_override("panel", UiTheme.box(Color("#10131a"), UiTheme.GOLD, 10, 2, 0))
	box.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.size = Vector2i(190, 212)
	svc.add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#161b26")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#5a6a90")
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sv.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 35, 0)
	key.light_color = Color("#ffd6a8")
	key.light_energy = 1.3
	sv.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_color = Color("#7fb0ff")
	rim.light_energy = 1.0
	sv.add_child(rim)
	var h := Humanoid.new()
	h.configure(npc["look"])
	# Veste quando entrar na árvore (o esqueleto só existe depois do _ready).
	h.ready.connect(func():
		h.dress(npc["look"])
		h.play(npc["look"].get("anim", "Idle")))
	sv.add_child(h)
	var cam := Camera3D.new()
	cam.fov = 30
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0.04, 1.62, 0.78), Vector3(0, 1.56, 0))
	return box


func _say(line: String, opts: Array) -> void:
	text.text = "[i]\"%s\"[/i]" % line
	text.visible_ratio = 0.0
	_tw = text.create_tween()
	_tw.tween_property(text, "visible_ratio", 1.0, clampf(line.length() / 70.0, 0.3, 2.0))
	for c in options.get_children():
		c.queue_free()
	for o in opts:
		var b := UiTheme.button(o[0], o[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 44
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 17)
		if o.size() > 2:
			b.add_theme_color_override("font_color", o[2])
		options.add_child(b)


func _root() -> void:
	var opts := []
	for q in GameState.npc_quests(npc_id):
		var st := GameState.quest_status(q["id"])
		match st:
			"available":
				opts.append(["[Nova missão] %s" % q["name"], _offer.bind(q), UiTheme.GOLD])
			"active":
				opts.append(["[Em andamento] %s" % q["name"], _progress.bind(q), Color("#5aa0ff")])
			"ready":
				opts.append(["[Entregar] %s" % q["name"], _complete.bind(q), Color("#3fd67a")])
	if npc["services"].has("forge"):
		opts.append(["Quero usar a Forja", func(): hud.open_panel("forge")])
	for t in npc.get("topics", []):
		opts.append([t["label"], _topic.bind(t)])
	opts.append(["Até logo.", func(): hud.close_panel()])
	var greet: Array = npc["greet"]
	_say(greet[randi() % greet.size()], opts)


func _reward_text(q: Dictionary) -> String:
	var parts := []
	var r: Dictionary = q["reward"]
	for k in r:
		if k == "item":
			parts.append("peça %s" % GameState.sets_db["sets"].get(r[k].get("set", ""), {}).get("name", "rara"))
		elif k == "xp":
			parts.append("%d XP" % int(r[k]))
		else:
			parts.append("%s %s" % [ItemText.short_zen(int(r[k])), "Cinzas" if k == "zen" else GameState.economy["jewels"][k]["name"]])
	return ", ".join(parts)


func _offer(q: Dictionary) -> void:
	_say(q["offer"], [["Aceitar: %s  (%s)" % [q["name"], _reward_text(q)], _accept.bind(q), UiTheme.GOLD], ["Agora não.", _root]])


func _accept(q: Dictionary) -> void:
	GameState.accept_quest(q["id"])
	_say("Conto com você. Siga as marcas douradas no chão.", [["Voltar", _root]])


func _progress(q: Dictionary) -> void:
	var p := Quests.progress(GameState.quests_db, GameState.quests, q["id"])
	var track := "Rastrear esta missão" if GameState.tracked_quest != q["id"] else "Já rastreando"
	_say("%s  (%d/%d)" % [q["progress_text"], p[0], p[1]], [[track, _track.bind(q)], ["Voltar", _root]])


func _track(q: Dictionary) -> void:
	GameState.tracked_quest = q["id"]
	_root()


func _complete(q: Dictionary) -> void:
	_say(q["complete_text"], [["Receber: %s" % _reward_text(q), _turn_in.bind(q), Color("#3fd67a")]])


func _turn_in(q: Dictionary) -> void:
	GameState.turn_in_quest(q["id"])
	_root()


func _topic(t: Dictionary) -> void:
	_say(t["text"], [["Voltar", _root]])
