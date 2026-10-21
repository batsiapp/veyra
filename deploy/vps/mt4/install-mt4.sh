#!/usr/bin/env bash
# Downloads an MT4 installer and opens it on the virtual screen. Finish the
# installer in the browser viewer (noVNC). Pass your broker's installer URL;
# without one, MetaQuotes' generic installer is used.
set -euo pipefail

URL="${1:-https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4setup.exe}"
DEST="/tmp/mt4setup.exe"

echo "downloading $URL"
curl --fail --location --silent --show-error --output "$DEST" "$URL"
echo "installer started: finish it in the browser viewer (http://127.0.0.1:6080 through your SSH tunnel)"
wine "$DEST" >/dev/null 2>&1 || true
echo "installer closed. The terminal starts automatically within a minute."
