## Mochila: boneco 3D com o equipamento montado (arraste para girar), slots
## equipados dos dois lados, grade de itens com miniaturas 3D e, à direita,
## detalhes com comparação (Poder, DPS e atributos) ou os atributos do herói.
extends "res://game/ui/panel_base.gd"

const HeroVisual = preload("res://game/actors/hero_visual.gd")
const LEFT_SLOTS := ["helm", "armor", "gloves", "pants"]
const RIGHT_SLOTS := ["weapon", "shield", "boots"]
const COMPARE_ROWS := [["power", "Poder"], ["dps", "DPS"], ["max_hp", "Vida"], ["atk", "Ataque"], ["def", "Defesa"],
	["crit_chance", "Crítico %"], ["crit_damage", "Dano crítico %"], ["attack_speed", "Vel. ataque %"],
	["move_speed", "Vel. movimento %"], ["life_steal", "Roubo de vida %"], ["block", "Bloqueio %"], ["cooldown", "Recarga %"], ["resist_all", "Resistência %"]]

var selected: Dictionary = {}
var slots_l: VBoxContainer
var slots_r: VBoxContainer
var grid: GridContainer
var head: HBoxContainer
var right: VBoxContainer
var doll
var _drag := false


func title() -> String:
	return "Mochila"


func build() -> void:
	panel_size = Vector2(1240, 680)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)
	# Boneco com slots dos lados.
	slots_l = VBoxContainer.new()
	slots_l.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cols.add_child(slots_l)
	cols.add_child(_doll())
	slots_r = VBoxContainer.new()
	slots_r.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cols.add_child(slots_r)
	# Grade.
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	head = HBoxContainer.new()
	mid.add_child(head)
	var acts := HBoxContainer.new()
	mid.add_child(acts)
	acts.add_child(UiTheme.button("Equipar melhores", _equip_best, 180))
	acts.add_child(UiTheme.button("Reciclar comuns", _salvage_commons, 180))
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	mid.add_child(scroll(grid))
	right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	cols.add_child(right)
	GameState.changed.connect(_render)
	_render()


func _doll() -> Control:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(240, 440)
	svc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	svc.stretch = false
	svc.gui_input.connect(_on_doll_input)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.size = Vector2i(240, 440)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#12151d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#56627e")
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sv.add_child(env)
	for d in [[Vector3(-30, 25, 0), Color("#ffe8cc"), 1.4], [Vector3(-10, 200, 0), Color("#7fa8ff"), 1.2]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_color = d[1]
		l.light_energy = d[2]
		sv.add_child(l)
	var floor_glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.01
	floor_glow.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.85, 0.65, 0.3, 0.25)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_glow.material_override = fm
	sv.add_child(floor_glow)
	doll = HeroVisual.new()
	doll.ready.connect(_dress_doll)
	sv.add_child(doll)
	var cam := Camera3D.new()
	cam.fov = 32
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.05, 3.6), Vector3(0, 0.92, 0))
	return svc


func _dress_doll() -> void:
	doll.apply_loadout(GameState.equipped)
	doll.play("Sword_Idle")


func _on_doll_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		_drag = e.pressed
	elif e is InputEventMouseMotion and _drag:
		doll.rotation.y += e.relative.x * 0.012


func _slot(slot: String) -> Control:
	if GameState.equipped.has(slot):
		var it: Dictionary = GameState.equipped[slot]
		return item_button(it, _select.bind(it), selected == it, 80)
	var b := Button.new()
	b.custom_minimum_size = Vector2(80, 80)
	b.icon = Thumbs.fallback(slot)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 44)
	b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.18))
	b.add_theme_stylebox_override("normal", UiTheme.frame("slot", 4, 14))
	b.tooltip_text = GameState.items_db["slots"][slot]["label"]
	b.disabled = true
	return b


func _render() -> void:
	if grid == null:
		return
	if doll and doll.skeleton:
		doll.apply_loadout(GameState.equipped)
	for box in [slots_l, slots_r, grid, head, right]:
		clear(box)
	for s in LEFT_SLOTS:
		slots_l.add_child(_slot(s))
	for s in RIGHT_SLOTS:
		slots_r.add_child(_slot(s))
	var cnt := Label.new()
	cnt.text = "%d/%d" % [GameState.inventory.size(), GameState.INVENTORY_SIZE]
	head.add_child(cnt)
	var w = GameState.character.wallet
	var money := rich("  [color=#ffd54f]Cinzas %s[/color]  [color=#ffe08a]Lume %d[/color]  [color=#ff7043]Brasa %d[/color]  [color=#c77dff]Prisma %d[/color]  [color=#4dd0e1]Sigilo %d[/color]" % [
		ItemText.short_zen(w.zen), w.amount("lume"), w.amount("brasa"), w.amount("prisma"), w.amount("sigilo")])
	money.add_theme_font_size_override("normal_font_size", 15)
	money.autowrap_mode = TextServer.AUTOWRAP_OFF
	money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(money)
	for it in GameState.inventory:
		var b := item_button(it, _select.bind(it), selected == it)
		if GameState.is_upgrade(it):
			b.text = ("+%d " % int(it["refine"]) if int(it["refine"]) > 0 else "") + "+"
			b.add_theme_color_override("font_color", Color("#3fd67a"))
		grid.add_child(b)
	if selected.is_empty():
		right.add_child(scroll(rich(ItemText.stats_block(GameState.stats))))
		return
	right.add_child(scroll(rich(ItemText.bbcode(selected) + _delta_text())))
	var actions := HBoxContainer.new()
	right.add_child(actions)
	if GameState.equipped.get(selected["slot"]) == selected:
		actions.add_child(UiTheme.button("Desequipar", _unequip, 150))
	else:
		actions.add_child(UiTheme.button("Equipar", _equip, 130))
		actions.add_child(UiTheme.button("Reciclar", _salvage_selected, 130))


func _select(it: Dictionary) -> void:
	selected = {} if selected == it else it
	_render()


func _equip() -> void:
	GameState.equip(selected)
	selected = {}


func _unequip() -> void:
	GameState.unequip(selected["slot"])
	selected = {}
	_render()


## Diferença para o item equipado no mesmo slot: poder, DPS e cada atributo que muda.
func _delta_text() -> String:
	if GameState.equipped.get(selected["slot"]) == selected:
		return ""
	var d := GameState.compare(selected)
	var cur = GameState.equipped.get(selected["slot"])
	var s := "\n[b]Se equipar[/b] [color=#8b8f99](no lugar de %s)[/color]\n" % (cur["name"] if cur else "nada")
	for row in COMPARE_ROWS:
		var v: float = d.get(row[0], 0.0)
		if absf(v) < 0.05:
			continue
		s += "[color=%s]%s%s[/color]  %s\n" % ["#3fd67a" if v > 0 else "#ff6b6b", "+" if v > 0 else "", ItemText._num(v), row[1]]
	return s


func _equip_best() -> void:
	var n := GameState.equip_best()
	GameState.toast.emit("%d peça(s) trocada(s) pelas melhores" % n if n > 0 else "Você já está com o melhor", Color("#3fd67a"))
	selected = {}
	_render()


func _salvage_selected() -> void:
	var v := GameState.salvage(selected)
	GameState.toast.emit("Reciclado: +%d Cinzas%s" % [v.get("zen", 0), (" +%d Lume" % v["lume"]) if v.has("lume") else ""], Color("#ffd54f"))
	selected = {}
	_render()


func _salvage_commons() -> void:
	var n := GameState.salvage_all_common()
	GameState.toast.emit("%d itens comuns reciclados" % n, Color("#ffd54f"))
	selected = {}
	_render()
