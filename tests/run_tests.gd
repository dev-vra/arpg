## Roda todas as suítes tests/test_*.gd em modo headless.
## Uso: godot --headless --path . -s tests/run_tests.gd [-- filtro]
extends SceneTree


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var dir := DirAccess.open("res://tests")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()

	var passed := 0
	var failed := 0
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL %s (não carregou; veja o erro acima)" % f)
			continue
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_") or (filter != "" and not (f + name).contains(filter)):
				continue
			suite.failures = []
			var t0 := Time.get_ticks_msec()
			suite.call(name)
			var ms := Time.get_ticks_msec() - t0
			if suite.failures.is_empty():
				passed += 1
				print("  ok   %s::%s (%d ms)" % [f, name, ms])
			else:
				failed += 1
				print("  FAIL %s::%s" % [f, name])
				for msg in suite.failures:
					print("       - " + msg)
	print("\n%d passaram, %d falharam" % [passed, failed])
	quit(1 if failed > 0 else 0)
