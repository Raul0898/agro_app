#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="${SCRIPT_DIR}/.."

if ! command -v firebase >/dev/null 2>&1; then
  echo "Error: firebase CLI no encontrado. Instala Firebase CLI para ejecutar este script." >&2
  exit 1
fi

if ! ACCOUNTS_JSON=$(firebase login:list --json 2>/dev/null); then
  firebase login:list
  exit 1
fi

ACCOUNT_COUNT=$(ACCOUNTS_JSON="${ACCOUNTS_JSON}" python3 - <<'PY'
import json
import os
import sys

def fail(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(2)

raw = os.environ.get("ACCOUNTS_JSON", "")
if not raw:
    fail("Error interno: no se pudo obtener la salida de firebase login:list --json.")
try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    fail(f"Error: no se pudo interpretar la salida de firebase login:list --json: {exc}")
if not isinstance(data, list):
    fail("Error: la salida de firebase login:list --json no es un arreglo.")
print(len(data))
PY
)

if [ "${ACCOUNT_COUNT}" -le 0 ]; then
  firebase login:list
  exit 1
fi

cd "${PROJECT_ROOT}"
firebase deploy --only firestore:indexes "$@"
