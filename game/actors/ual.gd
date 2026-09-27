## Biblioteca de animações universal (Quaternius UAL 1 e 2, CC0), compartilhada por
## todos os humanoides (mesmo esqueleto de 65 ossos). Carrega uma vez.
extends RefCounted

const SOURCES := ["res://assets/q/anims/UAL1_Standard.glb", "res://assets/q/anims/UAL2_Standard.glb"]
const LOOPING := ["Idle", "Jog", "Walk", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Swim", "Zombie_Walk", "Zombie_Idle", "Sitting_Idle", "Spell_Simple_Idle", "Pistol_Idle", "Dance", "Driving"]

static var _lib: AnimationLibrary


static func library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	for path in SOURCES:
		var src: Node = load(path).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		var lib := ap.get_animation_library("")
		for name in lib.get_animation_list():
			if _lib.has_animation(name):
				continue
			var a: Animation = lib.get_animation(name)
			for key in LOOPING:
				if name.begins_with(key) or name.contains("_" + key):
					a.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(name, a)
		src.free()
	return _lib
