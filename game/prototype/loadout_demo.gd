## Protótipo do Gate 0: 1 corpo em partes, 5 peças, 1 set, apply_loadout e brilho por refino.
## Botões: equipar a próxima peça, refinar tudo +3, trocar de set.
extends Node3D

const Item = preload("res://core/item.gd")
const Rig = preload("res://game/character/character_rig.gd")

const SLOTS := ["helm", "armor", "gloves", "pants", "boots"]
const SETS := ["ferro_vigilia", "coroa_vale_oco", "mares_rubras"]

var rig
var loadout: Array = []
var set_index := 0
var refine := 0
var info: Label


func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(3.2, 3.4, 3.2)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1d22")
	env.environment.ambient_light_color = Color("#50555f")
	env.environment.glow_enabled = true
	add_child(env)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	floor_mi.mesh = plane
	add_child(floor_mi)

	rig = Rig.new()
	add_child(rig)

	var ui := VBoxContainer.new()
	ui.position = Vector2(16, 16)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ui)
	info = Label.new()
	ui.add_child(info)
	for b in [["Equipar próxima peça", _equip_next], ["Refinar +3", _refine_up], ["Trocar set", _next_set], ["Limpar", _clear]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(220, 56)
		btn.pressed.connect(b[1])
		ui.add_child(btn)
	_refresh()


func _process(delta: float) -> void:
	rig.rotate_y(delta * 0.5)


func _equip_next() -> void:
	if loadout.size() < SLOTS.size():
		var it := Item.make(SLOTS[loadout.size()], 10, SETS[set_index])
		it["refine"] = refine
		loadout.append(it)
	_refresh()


func _refine_up() -> void:
	refine = mini(refine + 3, 15)
	for it in loadout:
		it["refine"] = refine
	_refresh()


func _next_set() -> void:
	set_index = (set_index + 1) % SETS.size()
	for it in loadout:
		it["set_id"] = SETS[set_index]
	_refresh()


func _clear() -> void:
	loadout.clear()
	refine = 0
	_refresh()


func _refresh() -> void:
	rig.apply_loadout(loadout)
	var full: String = rig.is_set_complete(loadout)
	info.text = "Set: %s | peças %d/5 | refino +%d%s | FPS %d" % [
		SETS[set_index], loadout.size(), refine, " | SET COMPLETO" if full != "" else "", Engine.get_frames_per_second()]
