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


static func ring(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.45) -> void:
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
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	p.mesh = q
	p.material_override = glow_mat(color, 3.0)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.particle_flag_align_y = true
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos + Vector3(0, 1.0, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)


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
