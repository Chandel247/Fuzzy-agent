#!/usr/bin/env bash
# Builds the fuzzy finder binary once and caches it next to this script.
# Re-run is a no-op if the binary is already newer than the source.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$SKILL_DIR/fuzzy_logic.cpp"
BIN="$SKILL_DIR/bin/fuzzy_finder"

if [[ -x "$BIN" && "$BIN" -nt "$SRC" ]]; then
  echo "$BIN"
  exit 0
fi

mkdir -p "$SKILL_DIR/bin"

CXX="${CXX:-c++}"
"$CXX" -std=c++17 -O2 -o "$BIN" "$SRC"

echo "$BIN"
