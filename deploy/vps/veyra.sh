#!/usr/bin/env bash
# Shorthand for docker compose with the VPS stack and the repository's .env.
#   ./deploy/vps/veyra.sh pull        # fetch the latest images
#   ./deploy/vps/veyra.sh up -d       # start or update everything
#   ./deploy/vps/veyra.sh ps          # what is running
#   ./deploy/vps/veyra.sh logs -f veyra
#   ./deploy/vps/veyra.sh down        # stop everything (data is kept)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ ! -f "$ROOT/.env" ]; then
  echo "no .env in $ROOT: run 'cp .env.example .env' and fill it in (deploy/vps/README.md)" >&2
  exit 1
fi
exec docker compose --project-directory "$ROOT/deploy/vps" \
  -f "$ROOT/deploy/vps/compose.yaml" --env-file "$ROOT/.env" "$@"
