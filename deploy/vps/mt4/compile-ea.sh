#!/usr/bin/env bash
# Compiles the VeyraProbe source given on stdin into every MT4 data folder in
# the Wine prefix. The host-side deploy/vps/compile-ea.sh fills in the URL,
# token and live-orders choice and pipes the result here.
set -euo pipefail

SRC="/tmp/VeyraProbe.mq4"
cat > "$SRC"
if ! grep -q 'VeyraProbe' "$SRC"; then
  echo "no EA source received on stdin" >&2
  exit 1
fi

METAEDITOR="$(find "$WINEPREFIX/drive_c" -iname metaeditor.exe 2>/dev/null | head -n 1)"
if [ -z "$METAEDITOR" ]; then
  echo "MetaEditor not found: install MT4 first (install-mt4.sh)" >&2
  exit 1
fi

# MT4 keeps its MQL4 folder either beside terminal.exe or under
# AppData/Roaming/MetaQuotes/Terminal/<id>. Install into every one found.
mapfile -t EXPERT_DIRS < <(find "$WINEPREFIX/drive_c" -type d -path '*MQL4/Experts' 2>/dev/null)
if [ "${#EXPERT_DIRS[@]}" -eq 0 ]; then
  echo "no MQL4/Experts folder found: start MT4 once so it creates its data folder" >&2
  exit 1
fi

status=0
for dir in "${EXPERT_DIRS[@]}"; do
  cp "$SRC" "$dir/VeyraProbe.mq4"
  rm -f "$dir/VeyraProbe.ex4"
  WIN_SRC="$(winepath -w "$dir/VeyraProbe.mq4")"
  WIN_LOG="$(winepath -w /tmp/veyra_compile.log)"
  rm -f /tmp/veyra_compile.log
  # MetaEditor exits non-zero even on success under Wine; the log and the
  # produced .ex4 are the result.
  wine "$METAEDITOR" /compile:"$WIN_SRC" /log:"$WIN_LOG" >/dev/null 2>&1 || true
  RESULT="$(iconv -f UTF-16 -t UTF-8 /tmp/veyra_compile.log 2>/dev/null || cat /tmp/veyra_compile.log 2>/dev/null || true)"
  echo "$dir:"
  echo "$RESULT" | tail -n 3
  if grep -q "0 errors" <<<"$RESULT" && [ -f "$dir/VeyraProbe.ex4" ]; then
    echo "compiled: $dir/VeyraProbe.ex4"
  else
    echo "compile failed in $dir" >&2
    status=1
  fi
done
rm -f "$SRC"
exit "$status"
