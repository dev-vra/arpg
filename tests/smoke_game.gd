## Teste de fumaça do jogo (precisa de cena): carrega o Bastião, abre os painéis,
## viaja ao Vale Oco, mata mobs e o chefe, coleta loot e usa a Forja.
## Uso: godot --headless --path . -s tests/smoke_game.gd
extends SceneTree

var errors := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		errors += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.reset_save()
	gs.current_map = "bastiao"
	change_scene_to_file("res://game/main.tscn")
	await _frames(10)
	var w = current_scene
	_ok(w != null and w.player != null, "Bastião carregou com jogador")
	_ok(get_nodes_in_group("interactable").size() >= 3, "NPCs e portal no Bastião")
	for p in ["inventory", "forge", "maps", "mentor", "menu"]:
		w.hud.open_panel(p)
		await _frames(3)
		_ok(w.hud.panel != null, "painel %s abre" % p)
		w.hud.close_panel()
	_ok(gs.accept_quest("q_primeiros_passos"), "aceitou missão inicial")
	await _frames(2)
	w.travel("vale_oco", "normal")
	await _frames(12)
	w = current_scene
	_ok(w.map_id == "vale_oco", "viajou ao Vale Oco")
	var mobs := get_nodes_in_group("enemies")
	_ok(mobs.size() > 10, "mobs nasceram (%d)" % mobs.size())
	# Anda e ataca um pouco para exercitar física, animação e IA.
	w.player.joy = Vector3(1, 0, 0.3)
	await _frames(30)
	w.player.joy = Vector3.ZERO
	w.player.basic_attack()
	for i in 4:
		w.player.cooldowns[i] = 0.0
		w.player.use_skill(i)
		await _frames(20)
	w.player.dodge()
	await _frames(20)
	# Mata tudo pela API de dano para testar morte, XP e drops.
	var lvl0: int = gs.character.level
	for m in get_nodes_in_group("enemies"):
		m.take_damage(1e9, false, m.global_position)
	await _frames(5)
	_ok(w.boss_dead, "chefe morreu")
	_ok(gs.quest_status("q_primeiros_passos") == "ready", "missão de abate concluída")
	var zq: int = gs.character.wallet.zen
	gs.turn_in_quest("q_primeiros_passos")
	_ok(gs.quest_status("q_primeiros_passos") == "completed" and gs.character.wallet.zen > zq, "entregou e recebeu recompensa")
	_ok(gs.accept_quest("q_dentes"), "aceitou missão de coleta")
	_ok(gs.character.level > lvl0, "subiu de nível (%d)" % gs.character.level)
	var drops := 0
	for n in w.get_children():
		if n.get_script() == load("res://game/world/loot_drop.gd"):
			drops += 1
			n.start = w.player.global_position
			n.target_offset = Vector3.ZERO
			n.global_position = w.player.global_position
	_ok(drops > 5, "drops no chão (%d)" % drops)
	var zen0: int = gs.character.wallet.zen
	await create_timer(1.5).timeout
	_ok(gs.character.wallet.zen > zen0, "Zen coletado pelo ímã")
	for n in w.get_children():
		if n.get_script() == load("res://game/world/loot_drop.gd"):
			n.global_position = w.player.global_position
	await create_timer(0.2).timeout
	_ok(gs.inventory.size() > 0, "itens coletados (%d)" % gs.inventory.size())
	# Forja: refina a arma equipada.
	gs.character.wallet.add("lume", 50)
	w.hud.open_panel("forge")
	await _frames(3)
	var before: int = gs.equipped["weapon"]["refine"]
	w.hud.panel._do_refine()
	_ok(gs.equipped["weapon"]["refine"] == before + 1, "refino pela Forja")
	w.hud.panel._set_mode("spin")
	gs.character.wallet.add("prisma", 5)
	gs.character.wallet.add("zen", 100000)
	w.hud.panel._do_spin()
	await _frames(3)
	w.hud.close_panel()
	_ok(gs.equip_best() >= 0 and gs.power() > 0, "equipar melhores")
	# Equipa o primeiro item e confere o boneco.
	if gs.inventory.size() > 0:
		gs.equip(gs.inventory[0])
	await _frames(3)
	_ok(true, "equipou item")
	# Dano no jogador até morrer.
	w.player.invuln = 0.0
	w.player.take_damage(1e9, 99)
	await _frames(3)
	_ok(w.player.dead, "jogador pode morrer")
	print("\nsmoke: %s" % ("OK" if errors == 0 else "%d falhas" % errors))
	quit(1 if errors > 0 else 0)
