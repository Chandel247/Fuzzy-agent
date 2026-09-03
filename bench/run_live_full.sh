#!/usr/bin/env bash
# Full live-agent sweep: 3 needles (shallow/mid/deep tiers) x 4 levels x
# 2 conditions x 5 sizes (10/100/1000/10000/100000) = 120 trials on
# qwen3.5:9b via local Ollama. Trimmed from all 5 needles per pilot
# checkpoint (200 trials measured at ~6-8h; this cuts to ~4h while still
# covering every size and memory level). Run only after reviewing
# bench/run_live_pilot.sh's results.
#
# Usage: bench/run_live_full.sh [scratch_dir] [model]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$SKILL_DIR/bench"
RESULTS_DIR="$BENCH_DIR/results"
SCRATCH="${1:-$(mktemp -d)}"
MODEL="${2:-qwen3.5:9b}"

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
  --out "$RESULTS_DIR/live_full.csv" \
  --transcripts-dir "$RESULTS_DIR/live_full_transcripts" \
  --model "$MODEL" \
  --sizes 10,100,1000,10000,100000 \
  --needles shallow,mid,deep \
  --levels L0,L1,L2,L3 \
  --conditions BASH,FUZZY \
  --max-turns 8

echo "Results: $RESULTS_DIR/live_full.csv" >&2
echo "Transcripts: $RESULTS_DIR/live_full_transcripts" >&2
echo "Corpora left in: $SCRATCH" >&2
