## HUD: vida/XP/moedas, avisos, barra de chefe, botão de interação, controles de toque,
## painéis (inventário, Forja, mapas, Mentora, menu) e atalhos de teclado.
extends CanvasLayer

const UiTheme = preload("res://game/ui/ui_theme.gd")
const ItemText = preload("res://game/ui/item_text.gd")
const TouchControls = preload("res://game/ui/touch_controls.gd")
const Minimap = preload("res://game/ui/minimap.gd")
const DialoguePanel = preload("res://game/ui/dialogue_panel.gd")
const PANELS := {
	"inventory": preload("res://game/ui/inventory_panel.gd"),
	"forge": preload("res://game/ui/forge_panel.gd"),
	"maps": preload("res://game/ui/maps_panel.gd"),
	"mentor": preload("res://game/ui/mentor_panel.gd"),
	"menu": preload("res://game/ui/menu_panel.gd"),
	"quests": preload("res://game/ui/quest_log_panel.gd"),
	"talents": preload("res://game/ui/talent_panel.gd"),
}

var world
var root: Control
var controls
var hp_bar: ProgressBar
var hp_label: Label
var xp_bar: ProgressBar
var level_label: Label
var money_label: RichTextLabel
var toasts: VBoxContainer
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_name: Label
var boss
var prompt: Button
var prompt_target
var panel_layer: Control
var panel: Control
var map_label: Label
var perf_label: Label
var quest_box: VBoxContainer
var talent_btn: Button
var minimap


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	controls = TouchControls.new()
	controls.player = world.player
	root.add_child(controls)
	_top_left()
	_top_right()
	_boss_bar()
	toasts = VBoxContainer.new()
	_place(toasts, Vector2(0.5, 0), Vector2(-300, 150), Vector2(600, 0))
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	prompt = Button.new()
	_place(prompt, Vector2(0.5, 1), Vector2(-170, -250), Vector2(340, 64))
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.visible = false
	prompt.pressed.connect(func(): if prompt_target: world.interact(prompt_target))
	root.add_child(prompt)
	panel_layer = Control.new()
	panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel_layer)
	perf_label = Label.new()
	perf_label.add_theme_font_size_override("font_size", 14)
	perf_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(perf_label, Vector2(0, 1), Vector2(14, -24), Vector2(360, 20))
	root.add_child(perf_label)
	GameState.changed.connect(refresh)
	GameState.toast.connect(show_toast)
	world.player.hp_changed.connect(refresh)
	refresh()


## Âncora num ponto relativo da tela e caixa fixa a partir dele.
func _place(c: Control, anchor: Vector2, offset: Vector2, box: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + box.x
	c.offset_bottom = offset.y + box.y
	c.custom_minimum_size = box


func _top_left() -> void:
	var pc := PanelContainer.new()
	pc.position = Vector2(14, 12)
	pc.custom_minimum_size = Vector2(470, 0)
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 20)
	v.add_child(level_label)
	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, 26)
	v.add_child(hp_wrap)
	hp_bar = ProgressBar.new()
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("fill", UiTheme.bar(Color("#c0392b")))
	hp_wrap.add_child(hp_bar)
	hp_label = Label.new()
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_wrap.add_child(hp_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 8)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("fill", UiTheme.bar(Color("#d9a441")))
	v.add_child(xp_bar)
	money_label = RichTextLabel.new()
	money_label.bbcode_enabled = true
	money_label.fit_content = true
	money_label.scroll_active = false
	money_label.add_theme_font_size_override("normal_font_size", 17)
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(money_label)
	quest_box = VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 2)
	v.add_child(quest_box)


## Caixa de missões clicável: toque rastreia (trilha no chão e no mapa); de novo abre o diário.
func _render_quests() -> void:
	for c in quest_box.get_children():
		c.queue_free()
	for id in GameState.tracked_quests():
		var q: Dictionary = GameState.Quests.find(GameState.quests_db, id)
		var prog: Array = GameState.Quests.progress(GameState.quests_db, GameState.quests, id)
		var ready: bool = GameState.quests["done"].has(id)
		var tracked: bool = GameState.tracked_quest == id
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		var giver: String = GameState.dialogues_db["npcs"][q.get("giver", "mentor")]["name"]
		b.text = "%s%s  %s" % ["> " if tracked else "   ", q["name"], ("entregar a " + giver) if ready else "%d/%d" % prog]
		b.add_theme_color_override("font_color", Color("#3fd67a") if ready else (Color("#ffd166") if tracked else Color("#c9c4b8")))
		b.pressed.connect(_on_quest_pressed.bind(id))
		quest_box.add_child(b)


func _on_quest_pressed(id: String) -> void:
	if GameState.tracked_quest == id:
		open_panel("quests")
	else:
		GameState.tracked_quest = id
		GameState.toast.emit("Rastreando: siga as marcas douradas", Color("#ffd166"))
		_render_quests()
	var pts := GameState.talent_points()
	talent_btn.text = str(pts) if pts > 0 else ""
	talent_btn.add_theme_color_override("font_color", Color("#ffd166"))


func minimap_dirty() -> void:
	if minimap:
		minimap.mark_dirty()


func open_bigmap() -> void:
	close_panel()
	controls.release_all()
	controls.enabled = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.add_child(dim)
	var big = Minimap.new()
	big.world = world
	big.full = true
	var vp := root.get_viewport_rect().size
	big.position = Vector2(40, 30)
	big.size = vp - Vector2(80, 60)
	dim.add_child(big)
	var close := UiTheme.button("Fechar mapa", func(): close_panel(), 170)
	close.position = Vector2(vp.x - 230, 44)
	dim.add_child(close)
	panel = big


func open_dialogue(npc_id: String, intro: bool = false) -> void:
	close_panel()
	controls.release_all()
	controls.enabled = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.12)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.add_child(dim)
	var d = DialoguePanel.new()
	d.hud = self
	d.npc_id = npc_id
	d.intro = intro
	dim.add_child(d)
	panel = d


func _top_right() -> void:
	var h := HBoxContainer.new()
	_place(h, Vector2(1, 0), Vector2(-560, 8), Vector2(546, 0))
	minimap = Minimap.new()
	minimap.world = world
	_place(minimap, Vector2(1, 0), Vector2(-284, 70), Vector2(270, 230))
	minimap.opened.connect(open_bigmap)
	root.add_child(minimap)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 8)
	root.add_child(h)
	map_label = Label.new()
	map_label.add_theme_color_override("font_color", UiTheme.GOLD)
	map_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(map_label)
	h.add_child(UiTheme.icon_button("scroll-quill", "Missões (L)", func(): open_panel("quests")))
	talent_btn = UiTheme.icon_button("angel-wings", "Espíritos (K)", func(): open_panel("talents"))
	h.add_child(talent_btn)
	h.add_child(UiTheme.icon_button("open-treasure-chest", "Mochila (I)", func(): open_panel("inventory")))
	if world.map_def["kind"] == "field":
		h.add_child(UiTheme.icon_button("treasure-map", "Voltar ao Bastião", func(): world.travel("bastiao", "normal")))
	h.add_child(UiTheme.icon_button("crown", "Menu (Esc)", func(): open_panel("menu")))


func _boss_bar() -> void:
	boss_box = VBoxContainer.new()
	_place(boss_box, Vector2(0.5, 0), Vector2(-300, 70), Vector2(600, 0))
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = UiTheme.title("", 24)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(600, 18)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("fill", UiTheme.bar(Color("#e67e22")))
	boss_box.add_child(boss_bar)


func refresh() -> void:
	var p = world.player
	var c = GameState.character
	level_label.text = "Sentinela · Nível %d · Poder %d" % [c.level, GameState.power()]
	hp_bar.max_value = p.max_hp()
	hp_bar.value = p.hp
	hp_label.text = "%d / %d" % [ceili(p.hp), ceili(p.max_hp())]
	xp_bar.max_value = GameState.xp_needed()
	xp_bar.value = GameState.xp
	var w = c.wallet
	money_label.text = "[color=#ffd54f]Cinzas %s[/color]  [color=#ffe08a]Lume %d[/color]  [color=#ff7043]Brasa %d[/color]  [color=#c77dff]Prisma %d[/color]  [color=#4dd0e1]Sigilo %d[/color]" % [
		ItemText.short_zen(w.zen), w.amount("lume"), w.amount("brasa"), w.amount("prisma"), w.amount("sigilo")]
	map_label.text = world.map_def["name"]
	_render_quests()


func _process(_d: float) -> void:
	# Medidor para o teste em aparelho (Gate 0): FPS, draw calls e primitivas.
	perf_label.text = "%d FPS · %d draw calls · %dk tris" % [Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
	if boss and is_instance_valid(boss):
		boss_bar.value = boss.hp
	if panel == null and not world.player.dead:
		controls.enabled = true


func show_boss(b) -> void:
	boss = b
	boss_box.visible = b != null
	if b:
		boss_name.text = b.def["name"]
		boss_bar.max_value = b.max_hp
		boss_bar.value = b.hp


func show_toast(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	toasts.add_child(l)
	if toasts.get_child_count() > 4:
		toasts.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func set_prompt(target) -> void:
	prompt_target = target
	prompt.visible = target != null and panel == null
	if target:
		var verb := {"forge": "Falar", "mentor": "Falar", "portal": "Usar", "exit": "Usar", "chest": "Abrir"}
		prompt.text = "%s: %s  (E)" % [verb.get(target.kind, "Usar"), target.title]


func open_panel(name: String) -> void:
	close_panel()
	controls.release_all()
	controls.enabled = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.add_child(dim)
	panel = PANELS[name].new()
	panel.hud = self
	dim.add_child(panel)


func close_panel() -> void:
	if panel:
		panel.get_parent().queue_free()
		panel = null


func show_death() -> void:
	controls.release_all()
	controls.enabled = false
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.add_child(dim)
	var v := VBoxContainer.new()
	_place(v, Vector2(0.5, 0.5), Vector2(-220, -90), Vector2(440, 0))
	v.add_theme_constant_override("separation", 14)
	dim.add_child(v)
	var t := UiTheme.title("Você caiu", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := Label.new()
	l.text = "Nada foi perdido: itens e joias ficam com você."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(UiTheme.button("Voltar ao Bastião", func(): world.travel("bastiao", "normal")))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var p = world.player
	var k: int = event.physical_keycode
	if event.pressed and k == KEY_ESCAPE:
		if panel:
			close_panel()
		else:
			open_panel("menu")
		return
	if panel:
		if event.pressed and k == KEY_I:
			close_panel()
		return
	if k == KEY_SPACE or k == KEY_J:
		p.attack_held = event.pressed
		if event.pressed:
			p.basic_attack()
	if not event.pressed:
		return
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4:
			p.use_skill(k - KEY_1)
		KEY_SHIFT, KEY_K:
			p.dodge()
		KEY_Q:
			p.drink_potion()
		KEY_E:
			if prompt_target:
				world.interact(prompt_target)
		KEY_I:
			open_panel("inventory")
		KEY_M:
			open_bigmap()
		KEY_L:
			open_panel("quests")
		KEY_K:
			open_panel("talents")



## Faixa de level up: "NÍVEL X" dourado que surge grande e assenta, com divisória
## brilhante e aviso de ponto de espírito e de skill nova.
func level_banner(level: int) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(box, Vector2(0.5, 0.3), Vector2(-360, -70), Vector2(720, 150))
	root.add_child(box)
	var t := Label.new()
	t.text = "NÍVEL %d" % level
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color("#ffd98a"))
	t.add_theme_color_override("font_outline_color", Color("#5a3a00"))
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_shadow_color", Color(1, 0.7, 0.2, 0.6))
	t.add_theme_constant_override("shadow_outline_size", 24)
	box.add_child(t)
	var div := TextureRect.new()
	div.texture = load("res://assets/ui/frames/divider.png")
	div.stretch_mode = TextureRect.STRETCH_SCALE
	div.custom_minimum_size = Vector2(520, 14)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	div.modulate = Color("#ffd166")
	box.add_child(div)
	var sub := Label.new()
	var extra := ""
	for sk in GameState.skills_db["sentinela"]["skills"]:
		if int(sk.get("unlock_level", 1)) == level:
			extra = "  ·  Nova skill: %s" % sk["name"]
	sub.text = "+1 ponto de Espírito%s" % extra
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color("#e8e2d6"))
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 8)
	box.add_child(sub)
	box.pivot_offset = Vector2(360, 75)
	box.scale = Vector2(1.8, 1.8)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.set_parallel(true)
	tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(box, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(box.queue_free)
	var lvl_tw := level_label.create_tween()
	lvl_tw.tween_property(level_label, "modulate", Color(1.6, 1.3, 0.6), 0.2)
	lvl_tw.tween_property(level_label, "modulate", Color.WHITE, 0.8)
