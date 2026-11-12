#!/usr/bin/env bash
set -euo pipefail

URL="${1:?Uso: $0 <url-app>}"

N_ROOT=100     # GET /       → 200
N_API=50       # GET /api/   → 200
N_404=20       # GET /appi/  → 404
N_405=10       # POST /      → 405

send() {
  local method=$1 path=$2 count=$3
  local code
  for ((i = 1; i <= count; i++)); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -X "$method" "$URL$path")
  done
  echo "$code → $method $path  (x$count)"
}

send GET  /      "$N_ROOT"
send GET  /api/  "$N_API"
send GET  /appi/ "$N_404"
send POST /      "$N_405"

echo "Totale: $((N_ROOT + N_API + N_404 + N_405)) richieste"
