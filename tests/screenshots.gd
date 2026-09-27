## Capturas para revisão visual (precisa de tela; use xvfb-run no Linux).
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/screenshots.gd -- <pasta>
extends SceneTree

const Loot = preload("res://core/loot.gd")


func _init() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var gs = root.get_node("GameState")
	gs.reset_save()
	gs.character.level = 20
	var ctx: Dictionary = gs.loot_ctx()
	for s in ["helm", "armor", "gloves", "pants", "boots"]:
		var it: Dictionary = Loot.make_item(ctx, s, 20, "ancestral", "ferro_vigilia")
		it["refine"] = 12
		gs.equipped[s] = it
	var sh: Dictionary = Loot.make_item(ctx, "shield", 20, "superior", "")
	gs.equipped["shield"] = sh
	gs.equipped["weapon"]["refine"] = 9
	gs.recompute()
	gs.current_map = "bastiao"
	change_scene_to_file("res://game/main.tscn")
	await _shot(out + "/1_hub.png")
	current_scene.travel("vale_oco", "normal")
	await create_timer(0.5).timeout
	var w = current_scene
	var near = null
	for m in get_nodes_in_group("enemies"):
		if near == null or m.global_position.distance_to(w.player.global_position) < near.global_position.distance_to(w.player.global_position):
			near = m
	w.player.global_position = near.global_position + Vector3(-3.5, 0, 2.5)
	await create_timer(0.6).timeout
	w.player.use_skill(1)
	await create_timer(0.12).timeout
	await _shot(out + "/2_combat.png")
	w.hud.open_panel("forge")
	w.hud.panel._set_mode("spin")
	await _shot(out + "/3_forge.png")
	quit()
