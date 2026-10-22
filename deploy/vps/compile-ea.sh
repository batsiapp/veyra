#!/usr/bin/env bash
# Builds the VeyraProbe add-on and installs it into MT4 in the mt4 container.
#
# Fills the EA's address, token and live-orders default in from .env, so no
# secret is committed. On this VPS the address is always the private relay,
# http://172.30.0.20/ea/poll, unless VEYRA_EA_URL says otherwise.
# Restart MT4 afterwards (./deploy/vps/veyra.sh restart mt4).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
set -a
# shellcheck disable=SC1091
. "$ROOT/.env"
set +a

TOKEN="${VEYRA_EA_TOKEN:?set VEYRA_EA_TOKEN in .env}"
URL="${VEYRA_EA_URL:-http://172.30.0.20/ea/poll}"
ALLOW_LIVE="${VEYRA_EA_ALLOW_LIVE:-false}"
case "$ALLOW_LIVE" in
  true|false) ;;
  *) echo "VEYRA_EA_ALLOW_LIVE must be true or false" >&2; exit 1 ;;
esac
case "$TOKEN" in
  *[!A-Za-z0-9_-]*) echo "VEYRA_EA_TOKEN may only hold letters, digits, - and _" >&2; exit 1 ;;
esac

echo "compiling EA for $URL with live order placement: $ALLOW_LIVE" >&2
sed -e "s|__VEYRA_URL__|$URL|" -e "s/__VEYRA_TOKEN__/$TOKEN/" \
  -e "s/__VEYRA_ALLOW_LIVE__/$ALLOW_LIVE/" "$ROOT/ea/VeyraProbe.mq4" \
  | "$ROOT/deploy/vps/veyra.sh" exec -T mt4 compile-ea.sh

if [ "$ALLOW_LIVE" = "true" ]; then
  echo "EA compiled ARMED: live orders will be placed on approved commands."
else
  echo "EA compiled disarmed: execution commands only report dry runs."
fi
echo "Restart MT4 to load it: ./deploy/vps/veyra.sh restart mt4"
