#!/usr/bin/env bash
# Pilot for the live-agent verification: 1 needle x 4 levels x 2 conditions
# x 2 sizes (10, 1000) = 16 trials on qwen3.5:9b via local Ollama.
# Validates the harness mechanics before the full sweep. See
# bench/live_agent.py and the approved plan for design details.
#
# Usage: bench/run_live_pilot.sh [scratch_dir]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$SKILL_DIR/bench"
RESULTS_DIR="$BENCH_DIR/results"
SCRATCH="${1:-$(mktemp -d)}"

mkdir -p "$RESULTS_DIR" "$SCRATCH"

command -v ollama >/dev/null || { echo "ollama not found on PATH" >&2; exit 1; }
curl -s -m 2 http://localhost:11434/api/version >/dev/null || { echo "ollama server not reachable on localhost:11434" >&2; exit 1; }

BIN="$("$SKILL_DIR/scripts/build.sh")"

if [[ -x "$BENCH_DIR/.venv/bin/python3" ]]; then
  PY="$BENCH_DIR/.venv/bin/python3"
else
  PY="python3"
fi

"$PY" "$BENCH_DIR/live_agent.py" \
  --bin "$BIN" \
  --scratch "$SCRATCH" \
  --out "$RESULTS_DIR/live_pilot.csv" \
  --transcripts-dir "$RESULTS_DIR/live_pilot_transcripts" \
  --model qwen3.5:9b \
  --sizes 10,1000 \
  --needles shallow \
  --levels L0,L1,L2,L3 \
  --conditions BASH,FUZZY \
  --max-turns 8

echo "Results: $RESULTS_DIR/live_pilot.csv" >&2
echo "Transcripts: $RESULTS_DIR/live_pilot_transcripts" >&2
echo "Corpora left in: $SCRATCH" >&2
