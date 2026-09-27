## Projétil de mob: voa em linha reta, some em parede, fere o jogador.
extends Node3D

const Fx = preload("res://game/fx/fx.gd")
const SPEED := 11.0

var vel := Vector3.ZERO
var dmg := 1.0
var level := 1
var color := Color.WHITE
var life := 2.5


func setup(from: Vector3, to: Vector3, damage: float, lvl: int, c: Color) -> void:
	position = from
	var d := to - from
	d.y = 0
	vel = d.normalized() * SPEED
	dmg = damage
	level = lvl
	color = c


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	mi.mesh = s
	mi.material_override = Fx.glow_mat(color, 3.0)
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 3.0
	l.light_energy = 1.5
	add_child(l)


func _physics_process(delta: float) -> void:
	life -= delta
	var next := global_position + vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		if hit.collider.is_in_group("player"):
			hit.collider.take_damage(dmg, level)
		Fx.sparks(get_parent(), global_position - Vector3(0, 1, 0), color, 10)
		queue_free()
		return
	global_position = next
	if life <= 0.0:
		queue_free()
