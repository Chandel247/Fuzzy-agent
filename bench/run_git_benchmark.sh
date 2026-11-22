#!/usr/bin/env bash
# Git-repo benchmark: the case run_benchmark.sh can't show, because its
# corpora are plain directories. Builds a committed 10,000-file repo plus
# an ignored node_modules/ holding 50,000 files (like a real JS project),
# then times, with hyperfine:
#   - fuzzy_baseline: the pre-optimisation binary (walks everything, then
#     filters through `git check-ignore`)
#   - fuzzy_finder:   the current binary (`git ls-files`)
#   - fzf_git:        git ls-files | fzf -f   (reference)
#   - fzf_find:       find -type f | fzf -f   (reference; no ignore rules)
#   - rg_fzf:         rg --files | fzf -f     (reference; only if rg exists)
# Writes bench/results/git_benchmark.csv and bench/results/git_benchmark.md.
#
# Portability: bash 3.2 compatible.
#
# Usage: bench/run_git_benchmark.sh [scratch_dir]
#   BASELINE_BIN  pre-optimisation binary (default /tmp/fuzzy_baseline/fuzzy_finder;
#                 skipped with a warning if missing)
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$SKILL_DIR/bench"
RESULTS_DIR="$BENCH_DIR/results"
SCRATCH="${1:-$(mktemp -d)}"
BASELINE_BIN="${BASELINE_BIN:-/tmp/fuzzy_baseline/fuzzy_finder}"

mkdir -p "$RESULTS_DIR" "$SCRATCH"

for tool in hyperfine fzf git python3; do
  command -v "$tool" >/dev/null || { echo "$tool not found on PATH" >&2; exit 1; }
done

BIN="$("$SKILL_DIR/scripts/build.sh")"

HF_SHELL_ARGS=()
hf_major="$(hyperfine --version | awk '{print $2}' | cut -d. -f1)"
if [[ "$hf_major" =~ ^[0-9]+$ && "$hf_major" -ge 2 ]]; then
  HF_SHELL_ARGS=(--shell=default)
fi

# Same query strings as run_benchmark.sh's `exact` and `fuzzy_ooo`.
QUERY_LABELS=(exact fuzzy_ooo)
QUERY_STRINGS=("auth_service" "pymntgtwyhndlr")
NEEDLE_KEYS=(shallow mid)

TOOLS=(fuzzy_baseline fuzzy_finder fzf_git fzf_find)
if [[ ! -x "$BASELINE_BIN" ]]; then
  echo "warning: $BASELINE_BIN missing; skipping fuzzy_baseline" >&2
  TOOLS=(fuzzy_finder fzf_git fzf_find)
fi
if command -v rg >/dev/null; then TOOLS+=(rg_fzf); fi

cdir="$SCRATCH/git_corpus"
manifest="$SCRATCH/git_manifest.json"

echo "=== generating 10,000-file corpus + git repo ===" >&2
rm -rf "$cdir"
python3 "$BENCH_DIR/gen_corpus.py" --out "$cdir" --files 10000 --depth 6 --seed 42 > "$manifest"
git -C "$cdir" init -q
printf 'node_modules/\n' > "$cdir/.gitignore"
git -C "$cdir" add -A
git -C "$cdir" -c user.email=t@t -c user.name=t commit -qm corpus

echo "=== adding ignored node_modules/ with 50,000 files ===" >&2
python3 - "$cdir/node_modules" <<'PYEOF'
import os, sys
root = sys.argv[1]
# 500 packages x 4 nested dirs x 25 files = 50,000 files.
for p in range(500):
    for d in range(4):
        sub = os.path.join(root, f"pkg_{p:03d}", "lib", f"mod_{d}")
        os.makedirs(sub, exist_ok=True)
        for f in range(25):
            with open(os.path.join(sub, f"auth_service_{f}.js"), "w") as fh:
                fh.write("module.exports = {};\n")
PYEOF
nm_count=$(find "$cdir/node_modules" -type f | wc -l | tr -d ' ')
echo "node_modules files: $nm_count" >&2

build_cmd() {
  local tool="$1" query="$2"
  case "$tool" in
    fuzzy_baseline) echo "$BASELINE_BIN \"$query\" \"$cdir\" 15" ;;
    fuzzy_finder)   echo "$BIN \"$query\" \"$cdir\" 15" ;;
    fzf_git)        echo "git -C \"$cdir\" ls-files --cached --others --exclude-standard | fzf -f \"$query\"" ;;
    fzf_find)       echo "find \"$cdir\" -type f | fzf -f \"$query\"" ;;
    rg_fzf)         echo "rg --files \"$cdir\" | fzf -f \"$query\"" ;;
  esac
}

CSV="$RESULTS_DIR/git_benchmark.csv"
echo "tool,query_label,query,mean,stddev,min,max,expected_relpath,rank" > "$CSV"

for qi in "${!QUERY_LABELS[@]}"; do
  label="${QUERY_LABELS[$qi]}"
  query="${QUERY_STRINGS[$qi]}"
  expected_rel="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['needles'][sys.argv[2]])" "$manifest" "${NEEDLE_KEYS[$qi]}")"
  for tool in "${TOOLS[@]}"; do
    cmd="$(build_cmd "$tool" "$query")"
    cell_json="$RESULTS_DIR/.git_cell_${tool}_${label}.json"
    echo "--- tool=$tool query=$label ---" >&2
    hyperfine ${HF_SHELL_ARGS[@]+"${HF_SHELL_ARGS[@]}"} --warmup 3 --min-runs 10 --ignore-failure \
      --export-json "$cell_json" "$cmd" >&2

    # Rank of the expected file (exact path match on the last column), untimed.
    output="$(eval "$cmd" 2>/dev/null || true)"
    # awk reads all input (no early exit) so printf never gets SIGPIPE,
    # which pipefail + set -e would turn into a fatal error.
    rank="$(printf '%s\n' "$output" | awk -F'\t' -v want="$expected_rel" '{p=$NF; sub(/^.*git_corpus\//, "", p); if (p==want && !r) r=NR} END{if (r) print r}')"

    python3 - "$cell_json" "$tool" "$label" "$query" "$expected_rel" "${rank:-}" "$CSV" <<'PYEOF'
import csv, json, sys
cell_json, tool, label, query, expected, rank, out_csv = sys.argv[1:8]
d = json.load(open(cell_json))["results"][0]
if "mean" not in d and "summary" in d:  # hyperfine 2.x schema
    d = d["summary"]["time_wall_clock"]
with open(out_csv, "a", newline="") as f:
    csv.writer(f).writerow([tool, label, query, f"{d['mean']:.6f}", f"{(d['stddev'] or 0):.6f}",
                            f"{d['min']:.6f}", f"{d['max']:.6f}", expected, rank])
PYEOF
    rm -f "$cell_json"
  done
done

python3 - "$CSV" "$RESULTS_DIR/git_benchmark.md" "$nm_count" <<'PYEOF'
import csv, sys
src, dst, nm = sys.argv[1], sys.argv[2], sys.argv[3]
rows = list(csv.DictReader(open(src)))
lines = [
    "# Git-repo benchmark",
    "",
    f"Committed 10,000-file corpus (`gen_corpus.py --seed 42 --depth 6`) plus an",
    f"ignored `node_modules/` holding {int(nm):,} files. hyperfine, warmup 3, min-runs 10.",
    "Generated by `bench/run_git_benchmark.sh`; do not hand-edit.",
    "",
    "| query | tool | mean (ms) | stddev (ms) | min (ms) | max (ms) | vs fuzzy_baseline | expected file rank |",
    "|---|---|---:|---:|---:|---:|---:|---:|",
]
base = {r["query_label"]: float(r["mean"]) for r in rows if r["tool"] == "fuzzy_baseline"}
for r in rows:
    mean = float(r["mean"])
    b = base.get(r["query_label"])
    speed = f"{b / mean:.1f}x faster" if b and r["tool"] != "fuzzy_baseline" and mean < b else \
            (f"{mean / b:.1f}x slower" if b and r["tool"] != "fuzzy_baseline" else "-")
    lines.append(
        f"| {r['query_label']} | {r['tool']} | {mean*1000:.1f} | {float(r['stddev'])*1000:.1f} | "
        f"{float(r['min'])*1000:.1f} | {float(r['max'])*1000:.1f} | {speed} | {r['rank'] or 'not found'} |"
    )
open(dst, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PYEOF

echo "Done. Results: $CSV, $RESULTS_DIR/git_benchmark.md" >&2
echo "Corpus left in: $cdir" >&2
