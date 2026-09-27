#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-${PORT:-8000}}"

bash "$SITE_DIR/gen_site.sh"

echo "[run] serving $SITE_DIR/_site at http://127.0.0.1:$PORT"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SITE_DIR/_site"
