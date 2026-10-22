#!/usr/bin/env bash
# Keeps the MT4 terminal running. Waits until MT4 is installed into the Wine
# prefix, then starts it and restarts it whenever it exits.
set -u

find_terminal() {
  find "$WINEPREFIX/drive_c" -iname terminal.exe -path '*MetaTrader*' -o \
       -iname terminal.exe -path '*MT4*' 2>/dev/null | head -n 1
}

if [ ! -f "$WINEPREFIX/system.reg" ]; then
  echo "run-terminal: creating Wine prefix"
  wineboot --init >/dev/null 2>&1 || true
  wineserver --wait || true
fi

while true; do
  TERMINAL="$(find_terminal)"
  if [ -z "$TERMINAL" ]; then
    echo "run-terminal: MT4 not installed yet; run install-mt4.sh (see deploy/vps/README.md)"
    sleep 60
    continue
  fi
  echo "run-terminal: starting $TERMINAL"
  cd "$(dirname "$TERMINAL")"
  wine "$TERMINAL" >/dev/null 2>&1
  # wine returns when the Windows process exits; wait for wineserver to settle.
  wineserver --wait >/dev/null 2>&1 || true
  echo "run-terminal: terminal exited; restarting in 10 s"
  sleep 10
done
