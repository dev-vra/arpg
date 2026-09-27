## HUD: vida/XP/moedas, avisos, barra de chefe, botão de interação, controles de toque,
## painéis (inventário, Forja, mapas, Mentora, menu) e atalhos de teclado.
extends CanvasLayer

const UiTheme = preload("res://game/ui/ui_theme.gd")
const ItemText = preload("res://game/ui/item_text.gd")
const TouchControls = preload("res://game/ui/touch_controls.gd")
const PANELS := {
	"inventory": preload("res://game/ui/inventory_panel.gd"),
	"forge": preload("res://game/ui/forge_panel.gd"),
	"maps": preload("res://game/ui/maps_panel.gd"),
	"mentor": preload("res://game/ui/mentor_panel.gd"),
	"menu": preload("res://game/ui/menu_panel.gd"),
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


func _top_right() -> void:
	var h := HBoxContainer.new()
	_place(h, Vector2(1, 0), Vector2(-620, 12), Vector2(606, 0))
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 8)
	root.add_child(h)
	map_label = Label.new()
	map_label.add_theme_color_override("font_color", UiTheme.GOLD)
	map_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(map_label)
	h.add_child(UiTheme.button("Mochila", func(): open_panel("inventory"), 120))
	if world.map_def["kind"] == "field":
		h.add_child(UiTheme.button("Base", func(): world.travel("bastiao", "normal"), 90))
	h.add_child(UiTheme.button("Menu", func(): open_panel("menu"), 90))


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
	money_label.text = "[color=#ffd54f]Zen %s[/color]  [color=#ffe08a]Lume %d[/color]  [color=#ff7043]Brasa %d[/color]  [color=#c77dff]Prisma %d[/color]  [color=#4dd0e1]Sigilo %d[/color]" % [
		ItemText.short_zen(w.zen), w.amount("lume"), w.amount("brasa"), w.amount("prisma"), w.amount("sigilo")]
	map_label.text = world.map_def["name"]


func _process(_d: float) -> void:
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
