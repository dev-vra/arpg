## Capturas para revisão visual (precisa de tela; use xvfb-run no Linux).
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/screenshots.gd -- <pasta>
extends SceneTree

const Loot = preload("res://core/loot.gd")


func _init() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(path)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("shot %s  draw_calls=%d  primitivas=%d" % [path, dc, tris])


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
	gs.flags["intro_seen"] = true
	change_scene_to_file("res://game/main.tscn")
	await create_timer(0.5).timeout
	current_scene.hud.open_dialogue("mentor")
	await create_timer(1.5).timeout
	await _shot(out + "/1_dialogue.png")
	current_scene.hud.close_panel()
	gs.accept_quest("q_primeiros_passos")
	current_scene.travel("vale_oco", "normal")
	await create_timer(0.5).timeout
	var w = current_scene
	var near = null
	for m in get_nodes_in_group("enemies"):
		if near == null or m.global_position.distance_to(w.player.global_position) < near.global_position.distance_to(w.player.global_position):
			near = m
	w.player.global_position = near.global_position + Vector3(-3.5, 0, 2.5)
	await create_timer(0.6).timeout
	gs.add_xp(gs.xp_needed())
	await create_timer(0.55).timeout
	await _shot(out + "/6_levelup.png")
	w.player.use_skill(1)
	await create_timer(0.12).timeout
	await _shot(out + "/2_combat.png")
	w.hud.open_bigmap()
	await _shot(out + "/4_bigmap.png")
	w.hud.close_panel()
	for i in 3:
		gs.inventory.append(Loot.make_item(ctx, ["weapon", "helm", "boots"][i], 25, "superior", ""))
	w.hud.open_panel("inventory")
	w.hud.panel._select(gs.inventory[0])
	await _shot(out + "/3_inventory.png")
	for id in ["juramento_0_s1", "juramento_0_s1", "juramento_0_s2", "juramento_0_s2", "juramento_0_n", "juramento_1_s1", "juramento_1_s2"]:
		gs.add_talent(id)
	w.hud.open_panel("talents")
	w.hud.panel._select("juramento_1_s1")
	await _shot(out + "/5_talents.png")

	quit()
