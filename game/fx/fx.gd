## Efeitos visuais gerados por código (sem textura): arco de golpe, onda de choque,
## faíscas, números de dano e feixe de loot. Baratos para GPU de entrada.
extends RefCounted

static var _mats := {}


static func glow_mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "%s_%.1f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	m.vertex_color_use_as_albedo = true
	_mats[key] = m
	return m


## Faixa em arco no chão (golpe). angle_deg é a abertura, centrada em -Z local.
static func arc_mesh(radius: float, width: float, angle_deg: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 18
	var half := deg_to_rad(angle_deg / 2.0)
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var d0 := Vector3(sin(lerpf(-half, half, t0)), 0, -cos(lerpf(-half, half, t0)))
		var d1 := Vector3(sin(lerpf(-half, half, t1)), 0, -cos(lerpf(-half, half, t1)))
		# Borda externa forte, interna suave; pontas somem (sin).
		var o0 := Color(1, 1, 1, sin(PI * t0))
		var o1 := Color(1, 1, 1, sin(PI * t1))
		var i0 := Color(1, 1, 1, 0.0)
		var i1 := Color(1, 1, 1, 0.0)
		for v in [[d0 * (radius - width), i0], [d0 * radius, o0], [d1 * radius, o1], [d0 * (radius - width), i0], [d1 * radius, o1], [d1 * (radius - width), i1]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	return st.commit()


static func _fade_free(node: Node3D, time: float, grow: float) -> void:
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", node.scale * grow, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "transparency", 1.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(node.queue_free)


static func slash(parent: Node, pos: Vector3, facing: Vector3, color: Color, radius: float = 2.2, angle: float = 120.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = arc_mesh(radius, radius * 0.45, angle)
	mi.material_override = glow_mat(color, 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.9, 0)
	if facing.length() > 0.01:
		mi.look_at(mi.global_position + facing, Vector3.UP)
	mi.rotate_object_local(Vector3.FORWARD, randf_range(-0.35, 0.35))
	_fade_free(mi, 0.22, 1.15)
	slash_tex(parent, pos, facing, color, radius * 1.3)


static func ring(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.45) -> void:
	ground(parent, pos, "circle_03", radius * 1.2, color, time, 1.8)
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.82
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	mi.mesh = t
	mi.material_override = glow_mat(color, 2.2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3(radius * 0.25, 0.3, radius * 0.25)
	_fade_free(mi, time, 4.0)


static func disc(parent: Node, pos: Vector3, radius: float, color: Color, time: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.05
	mi.mesh = c
	mi.material_override = glow_mat(Color(color, 0.35), 1.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	var tw := mi.create_tween()
	tw.tween_property(mi, "transparency", 0.2, time)
	tw.tween_callback(mi.queue_free)
	return mi


static func sparks(parent: Node, pos: Vector3, color: Color, amount: int = 14) -> void:
	burst(parent, pos + Vector3(0, 1.0, 0), "spark_01", color, maxi(6, amount), 6.5, 0.4, 0.4, Vector3(0, -12, 0))


static func number(parent: Node, pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64 if big else 44
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.pixel_size = 0.006
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 2.2, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.3, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


static func beam(color: Color, height: float = 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.02
	c.bottom_radius = 0.16
	c.height = height
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = glow_mat(Color(color, 0.55), 1.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = height / 2.0
	return mi


# --- efeitos com textura (Kenney Particle Pack, CC0) ---

static var _tex_mats := {}


## Material aditivo com textura da pasta assets/fx, tingido pela cor.
static func tex_mat(tex: String, color: Color, billboard: int = BaseMaterial3D.BILLBOARD_DISABLED) -> StandardMaterial3D:
	var key := "%s_%s_%d" % [tex, color.to_html(), billboard]
	if _tex_mats.has(key):
		return _tex_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = load("res://assets/fx/%s.png" % tex)
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = billboard
	if billboard == BaseMaterial3D.BILLBOARD_PARTICLES:
		m.billboard_keep_scale = true
	_tex_mats[key] = m
	return m


## Decalque no chão (círculo, runa, marca) que cresce, gira e some.
static func ground(parent: Node, pos: Vector3, tex: String, size: float, color: Color, time: float, grow: float = 1.3, spin: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = tex_mat(tex, color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * grow, time).from(Vector3.ONE * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if spin != 0.0:
		tw.tween_property(mi, "rotation:y", spin, time)
	tw.tween_property(mi, "transparency", 1.0, time * 0.45).set_delay(time * 0.55)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Pilar de luz vertical (sempre de frente para a câmera no eixo Y).
static func pillar(parent: Node, pos: Vector3, height: float, width: float, color: Color, time: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, height)
	mi.mesh = q
	mi.material_override = tex_mat("light_02", color, BaseMaterial3D.BILLBOARD_FIXED_Y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height / 2.0, 0)
	mi.scale = Vector3(0.1, 1, 1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, time * 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(time * 0.4)
	tw.tween_property(mi, "scale", Vector3(0.05, 1.2, 1), time * 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Explosão de partículas com textura (estrelas, faíscas, magia).
static func burst(parent: Node, pos: Vector3, tex: String, color: Color, amount: int, speed: float, life: float, size: float, gravity: Vector3 = Vector3(0, -6, 0), spread: float = 180.0, ring: float = 0.0) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	p.material_override = tex_mat(tex, color, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	if ring > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = ring
		p.emission_ring_inner_radius = ring * 0.8
		p.emission_ring_height = 0.1
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Level up: runa dourada girando no chão, anel, pilar de luz, estrelas subindo,
## faíscas e um clarão. ~2 s.
static func level_up(parent: Node, pos: Vector3) -> void:
	var gold := Color(1.0, 0.82, 0.4)
	ground(parent, pos, "symbol_02", 4.2, gold, 2.0, 1.25, PI * 0.8)
	ground(parent, pos, "circle_05", 3.0, Color(1.0, 0.9, 0.6), 0.9, 2.4)
	pillar(parent, pos, 9.0, 2.6, Color(1.0, 0.85, 0.5, 0.9), 1.6)
	burst(parent, pos + Vector3(0, 0.3, 0), "star_06", gold, 36, 3.0, 1.6, 0.35, Vector3(0, 2.5, 0), 25.0, 1.0)
	burst(parent, pos + Vector3(0, 1.0, 0), "spark_05", Color(1.0, 0.95, 0.7), 28, 7.0, 0.7, 0.3, Vector3(0, -9, 0))
	burst(parent, pos + Vector3(0, 1.2, 0), "magic_03", Color(1.0, 0.75, 0.3, 0.8), 10, 1.0, 1.2, 1.1, Vector3(0, 1.5, 0), 60.0)
	var l := OmniLight3D.new()
	l.light_color = gold
	l.light_energy = 6.0
	l.omni_range = 10.0
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 2.0, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 1.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Golpe com textura de corte, deitado na direção do ataque.
static func slash_tex(parent: Node, pos: Vector3, facing: Vector3, color: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = tex_mat(["slash_01", "slash_02", "slash_03", "slash_04"][randi() % 4], color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 1.0, 0) + facing * size * 0.3
	if facing.length() > 0.01:
		mi.look_at(mi.global_position + facing, Vector3.UP)
	mi.rotate_object_local(Vector3.FORWARD, randf_range(-0.3, 0.3))
	_fade_free(mi, 0.2, 1.2)
