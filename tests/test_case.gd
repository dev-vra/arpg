## Base mínima dos testes: métodos test_* e asserções que acumulam falhas.
extends RefCounted

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(a, b, msg: String = "") -> void:
	if a != b:
		failures.append("%s esperado %s, veio %s" % [msg, str(b), str(a)])


func near(a: float, b: float, tol: float, msg: String = "") -> void:
	if absf(a - b) > tol:
		failures.append("%s esperado %.3f ± %.3f, veio %.3f" % [msg, b, tol, a])
