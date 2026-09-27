#!/usr/bin/env bash
# Roda os testes do núcleo em modo headless. Falha também em qualquer SCRIPT ERROR.
# Uso: GODOT=/caminho/godot ./run_tests.sh [filtro]
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
out=$(timeout 600 "$GODOT" --headless --path . -s tests/run_tests.gd -- "$@" 2>&1)
code=$?
echo "$out" | grep -vE "^(ERROR|WARNING): .*(leaked|in use|RID|Leaked)|^ +at: (~|cleanup|clear)"
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "FALHA: houve SCRIPT ERROR"
	exit 1
fi
exit $code
