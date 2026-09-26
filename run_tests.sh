#!/usr/bin/env bash
# Roda os testes do núcleo em modo headless.
# Uso: GODOT=/caminho/godot ./run_tests.sh [filtro]
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
exec timeout 600 "$GODOT" --headless --path . -s tests/run_tests.gd -- "$@"
