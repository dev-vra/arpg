## Biblioteca de animação única para todos os bonecos KayKit (mesmo rig).
## Só o Skeleton_Minion importa animações (a 15 fps); os outros modelos vêm sem
## e recebem esta biblioteca em tempo de execução. Economiza ~8 MB no APK.
extends RefCounted

const SOURCE := "res://assets/kaykit/chars/Skeleton_Minion.glb"
const LOOPING := ["Idle", "Running", "Walking", "Blocking", "Spellcasting", "_Idle", "Inactive"]

static var _lib: AnimationLibrary


static func library() -> AnimationLibrary:
	if _lib:
		return _lib
	var src: Node = load(SOURCE).instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	_lib = ap.get_animation_library("")
	for name in _lib.get_animation_list():
		for key in LOOPING:
			if key in name:
				_lib.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	src.free()
	return _lib


## Garante um AnimationPlayer com a biblioteca compartilhada no modelo.
static func attach(model: Node) -> AnimationPlayer:
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		model.add_child(ap)
	if not ap.has_animation_library(""):
		ap.add_animation_library("", library())
	return ap
