#!/usr/bin/env bash
# Runs the token-only path-discovery benchmark. It compares literal find,
# find|grep, rg (when installed), and warm/cold fuzzy-skill searches.
#
# Usage: bench/run_hypothesis.sh [scratch_dir]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$SKILL_DIR/bench"
RESULTS_DIR="$BENCH_DIR/results"
SCRATCH="${1:-$(mktemp -d)}"

mkdir -p "$RESULTS_DIR" "$SCRATCH"

BIN="$("$SKILL_DIR/scripts/build.sh")"

# Prefer the venv with tiktoken installed (bench/.venv); fall back to
# system python3 (chars/4 heuristic) if it's missing.
if [[ -x "$BENCH_DIR/.venv/bin/python3" ]]; then
  PY="$BENCH_DIR/.venv/bin/python3"
else
  PY="python3"
fi

"$PY" "$BENCH_DIR/run_hypothesis.py" \
  --bin "$BIN" \
  --scratch "$SCRATCH" \
  --out "$RESULTS_DIR/hypothesis.csv" \
  --sizes 10,100,1000,10000,100000

echo "Results: $RESULTS_DIR/hypothesis.csv" >&2
echo "Corpora left in: $SCRATCH" >&2
