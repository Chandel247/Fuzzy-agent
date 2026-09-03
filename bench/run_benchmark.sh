#!/usr/bin/env bash
# Benchmarks the fuzzy-finder skill against the CLI equivalents of the tools
# a coding agent reaches for via Bash: `find -iname`, `find | grep -i`, and
# `find | fzf -f` (the real fuzzy-matching peer). Uses hyperfine for
# statistically rigorous timing. Writes bench/results/results.csv (timing)
# and bench/results/correctness.csv (does the expected file actually show up).
#
# Portability note: written for bash 3.2 (macOS's default /bin/bash) --
# deliberately avoids associative arrays (`declare -A`), which 3.2 lacks.
#
# Usage: bench/run_benchmark.sh [scratch_dir]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$SKILL_DIR/bench"
RESULTS_DIR="$BENCH_DIR/results"
SCRATCH="${1:-$(mktemp -d)}"

mkdir -p "$RESULTS_DIR" "$SCRATCH"

command -v hyperfine >/dev/null || { echo "hyperfine not found on PATH" >&2; exit 1; }
command -v fzf >/dev/null || { echo "fzf not found on PATH" >&2; exit 1; }

BIN="$("$SKILL_DIR/scripts/build.sh")"

RESULTS_CSV="$RESULTS_DIR/results.csv"
CORRECTNESS_CSV="$RESULTS_DIR/correctness.csv"
echo "size,tool,query_label,query,mean,stddev,min,max,files_per_sec" > "$RESULTS_CSV"
echo "size,tool,query_label,query,expected_relpath,found_anywhere,rank" > "$CORRECTNESS_CSV"

# Static queries: needle filenames are fixed by gen_corpus.py regardless of
# --files/--seed, so these query strings are valid for every corpus size.
# Parallel arrays instead of an associative array (bash 3.2 has no -A).
QUERY_LABELS=(exact common fuzzy_ooo single_char no_match too_long)
QUERY_STRINGS=(
  "auth_service"                 # literal substring of user_auth_service.py
  "user"                          # appears across many random filenames
  "pymntgtwyhndlr"                # ordered subsequence of payment_gateway_handler, NOT a substring
  "e"                             # cheap match, huge candidate set
  "zzqqxxyy0099"                  # matches nothing
  "$(printf 'q%.0s' {1..300})"    # longer than any filename
)
query_for_label() {
  local target="$1" i
  for i in "${!QUERY_LABELS[@]}"; do
    [[ "${QUERY_LABELS[$i]}" == "$target" ]] && { echo "${QUERY_STRINGS[$i]}"; return; }
  done
}

# query label -> which manifest needle key it should surface (correctness checks)
needle_for_label() {
  case "$1" in
    exact) echo "shallow" ;;
    fuzzy_ooo) echo "mid" ;;
    *) echo "" ;;
  esac
}

TOOLS=(fuzzy_finder find_naive find_grep fzf_fuzzy)

build_cmd() {
  local tool="$1" query="$2" dir="$3"
  case "$tool" in
    fuzzy_finder) echo "$BIN \"$query\" \"$dir\" 15" ;;
    find_naive)   echo "find \"$dir\" -iname \"*${query}*\"" ;;
    find_grep)    echo "find \"$dir\" -type f | grep -i \"$query\"" ;;
    fzf_fuzzy)    echo "find \"$dir\" -type f | fzf -f \"$query\"" ;;
  esac
}

run_size() {
  local size="$1" warmup="$2" minruns="$3"
  local -a query_labels=("${@:4}")
  local cdir="$SCRATCH/corpus_$size"
  local manifest="$SCRATCH/manifest_$size.json"

  echo "=== corpus size $size: generating ===" >&2
  rm -rf "$cdir"
  python3 "$BENCH_DIR/gen_corpus.py" --out "$cdir" --files "$size" --depth 6 --seed 42 > "$manifest"

  for label in "${query_labels[@]}"; do
    local query; query="$(query_for_label "$label")"
    for tool in "${TOOLS[@]}"; do
      local cmd; cmd="$(build_cmd "$tool" "$query" "$cdir")"
      local cell_json="$RESULTS_DIR/.cell_${size}_${tool}_${label}.json"

      echo "--- size=$size tool=$tool query=$label ---" >&2
      hyperfine --warmup "$warmup" --min-runs "$minruns" --ignore-failure \
        --export-json "$cell_json" "$cmd" >&2

      python3 - "$cell_json" "$size" "$tool" "$label" "$query" "$RESULTS_CSV" <<'PYEOF'
import json, sys, csv
cell_json, size, tool, label, query, out_csv = sys.argv[1:7]
d = json.load(open(cell_json))["results"][0]
mean, stddev, mn, mx = d["mean"], d["stddev"], d["min"], d["max"]
fps = int(size) / mean if mean > 0 else 0
with open(out_csv, "a", newline="") as f:
    csv.writer(f).writerow([size, tool, label, query, f"{mean:.6f}", f"{stddev:.6f}", f"{mn:.6f}", f"{mx:.6f}", f"{fps:.1f}"])
PYEOF
      rm -f "$cell_json"

      # correctness: does the expected needle show up, at what rank, untimed single run
      local needle_key; needle_key="$(needle_for_label "$label")"
      if [[ -n "$needle_key" ]]; then
        local expected_rel; expected_rel="$(python3 -c "import json;print(json.load(open('$manifest'))['needles']['$needle_key'])")"
        local expected_base; expected_base="$(basename "$expected_rel")"
        local output; output="$(eval "$cmd" 2>/dev/null || true)"
        local rank; rank="$(printf '%s\n' "$output" | grep -nF "$expected_base" | head -1 | cut -d: -f1 || true)"
        local found="false"; [[ -n "$rank" ]] && found="true"
        echo "$size,$tool,$label,$query,$expected_rel,$found,${rank:-}" >> "$CORRECTNESS_CSV"
      fi
    done
  done
}

run_size 1000   3 10 "${QUERY_LABELS[@]}"
run_size 10000  2 8  "${QUERY_LABELS[@]}"
run_size 100000 1 5  exact fuzzy_ooo single_char no_match

echo "Done. Results: $RESULTS_CSV  Correctness: $CORRECTNESS_CSV" >&2
echo "Corpora left in: $SCRATCH" >&2
