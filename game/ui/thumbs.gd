## Miniaturas 3D dos itens: renderiza a peça (roupa ou prop) num SubViewport
## transparente, com luz de estúdio e a cor do set/raridade, e guarda em cache.
## Uma por frame, em fila; quem pediu é avisado por thumb_ready(key, textura).
## Sem renderizador (headless) devolve o ícone do slot.
extends Node

signal thumb_ready(key: String, tex: Texture2D)

const CHAR_SHADER = preload("res://game/shaders/character.gdshader")
const GearLook = preload("res://game/actors/gear_look.gd")
const SIZE := 160
const PROP := {"weapon": "Sword_Bronze", "shield": "Shield_Wooden"}
const SLOT_ICONS := {"weapon": "broadsword", "shield": "round-shield", "helm": "visored-helm", "armor": "breastplate", "gloves": "gauntlet", "pants": "leg-armor", "boots": "boots"}

var cache := {}
var queue: Array = []   # [key, item]
var busy := false
var vp: SubViewport
var stage: Node3D
var cam: Camera3D


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8090b0")
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	for d in [[Vector3(-35, 30, 0), Color("#fff0dc"), 1.5], [Vector3(-15, 200, 0), Color("#8fb4ff"), 1.1]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_color = d[1]
		l.light_energy = d[2]
		vp.add_child(l)
	cam = Camera3D.new()
	cam.fov = 28
	vp.add_child(cam)
	stage = Node3D.new()
	vp.add_child(stage)


func fallback(slot: String) -> Texture2D:
	return load("res://assets/ui/icons/%s.svg" % SLOT_ICONS.get(slot, "gems"))


## Textura pronta ou null (e entra na fila; thumb_ready avisa depois).
func get_thumb(item: Dictionary) -> Texture2D:
	var key := GearLook.thumb_key(item)
	if cache.has(key):
		return cache[key]
	for q in queue:
		if q[0] == key:
			return null
	queue.append([key, item])
	return null


func _process(_d: float) -> void:
	if busy or queue.is_empty():
		return
	busy = true
	var job: Array = queue.pop_front()
	_render(job[0], job[1])


func _render(key: String, item: Dictionary) -> void:
	for c in stage.get_children():
		c.queue_free()
	var look := GearLook.look(item)
	var slot: String = item["slot"]
	var paths := []
	if PROP.has(slot):
		paths.append("res://assets/q/props/%s.gltf" % PROP[slot])
	else:
		for n in GearLook.outfit(item, "Male")[0]:
			paths.append("res://assets/q/outfits/%s.gltf" % n)
	var aabb := AABB()
	var first := true
	for p in paths:
		var inst: Node3D = load(p).instantiate()
		stage.add_child(inst)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, _mat(mi.mesh.surface_get_material(i), look))
			var b: AABB = mi.global_transform * mi.get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
	# Luvas vêm em pose T: enquadra só o antebraço e a mão direita.
	if slot == "gloves":
		aabb = AABB(Vector3(aabb.position.x, aabb.position.y, aabb.position.z), Vector3(0.5, aabb.size.y, aabb.size.z))
	# Enquadra: 3/4 de frente, levemente de cima.
	var center := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.05)
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	cam.position = center + Vector3(0.45, 0.3, 1.0).normalized() * dist
	cam.look_at(center)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var tex: Texture2D = fallback(slot)
	if img and not img.is_empty() and not img.is_invisible():
		tex = ImageTexture.create_from_image(img)
	cache[key] = tex
	busy = false
	thumb_ready.emit(key, tex)


func _mat(src: Material, look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CHAR_SHADER
	if src is StandardMaterial3D:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		if src.normal_enabled and src.normal_texture:
			m.set_shader_parameter("normal_tex", src.normal_texture)
			m.set_shader_parameter("use_normal", true)
	var skin: bool = src != null and src.resource_name.contains("Regular")
	m.set_shader_parameter("tint", Color("#c89478") if skin else look["color"])
	m.set_shader_parameter("tint_mix", 0.0 if skin else look["mix"])
	m.set_shader_parameter("metal", look["metal"])
	m.set_shader_parameter("glow_color", look["glow"])
	m.set_shader_parameter("glow_strength", look["strength"])
	m.set_shader_parameter("rim_strength", 0.35)
	var zeros := PackedFloat32Array()
	zeros.resize(65)
	m.set_shader_parameter("hide_bone", zeros)
	return m
