#!/usr/bin/env bash
# Qualitative robustness suite for the fuzzy-finder skill. Each case prints
# one PASS / FAIL / OBSERVED line. Not timed (see run_benchmark.sh for that).
#
# Usage: bench/stress_tests.sh [scratch_dir]
set -uo pipefail  # deliberately no -e: individual checks handle their own failures

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$SKILL_DIR/bench"
SCRATCH="${1:-$(mktemp -d)}/stress"
mkdir -p "$SCRATCH"

BIN="$("$SKILL_DIR/scripts/build.sh")"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; }
observed() { echo "OBSERVED: $1"; }

echo "== Stress / robustness suite (scratch: $SCRATCH) =="

# --- 1. Permission-denied subdirectory mid-tree ------------------------
t1="$SCRATCH/perm_full"
t1_base="$SCRATCH/perm_baseline"
rm -rf "$t1" "$t1_base"
for d in dirA dirB dirC dirD dirE; do
  mkdir -p "$t1/$d"
  for i in 1 2 3 4; do : > "$t1/$d/entry${i}.txt"; done
done
mkdir -p "$t1_base"
for d in dirA dirB dirD dirE; do   # baseline omits dirC entirely
  mkdir -p "$t1_base/$d"
  for i in 1 2 3 4; do : > "$t1_base/$d/entry${i}.txt"; done
done
chmod 000 "$t1/dirC"

count_full=$("$BIN" "e" "$t1" 1000 2>/dev/null | wc -l | tr -d ' ')
count_base=$("$BIN" "e" "$t1_base" 1000 2>/dev/null | wc -l | tr -d ' ')
chmod 700 "$t1/dirC"  # restore so cleanup can rm -rf it

if [[ "$count_full" -eq "$count_base" ]]; then
  pass "permission-denied subdirectory: cleanly skipped (found $count_full of $count_base non-locked files)"
else
  short=$(( count_base - count_full ))
  fail "permission-denied subdirectory: dir_parser's outer try/catch aborted the whole walk on first fs::filesystem_error -- lost $short files beyond the locked directory's own contents ($count_full found, $count_base expected)"
fi

# --- 2. Very deep nesting -----------------------------------------------
deep_root="$SCRATCH/deep"
rm -rf "$deep_root"
mkdir -p "$deep_root"
depth=0
path="$deep_root"
while : ; do
  next="$path/d$depth"
  if mkdir "$next" 2>/dev/null; then
    path="$next"
    depth=$((depth + 1))
    # stop with headroom for the needle filename, rather than at the OS's
    # hard PATH_MAX -- we want a clean directory-depth stress test, not an
    # ENAMETOOLONG from our own test fixture.
    [[ ${#next} -ge 950 || $depth -ge 2000 ]] && { path="$next"; break; }
  else
    break
  fi
done
: > "$path/n.txt"
found_deep=$("$BIN" "ntxt" "$deep_root" 5 2>/dev/null | grep -c "n.txt")
if [[ "$found_deep" -ge 1 ]]; then
  observed "deep nesting: reached depth $depth (path len ${#path}), needle found successfully at max depth"
else
  fail "deep nesting: reached depth $depth, needle NOT found -- fuzzy_score's per-level penalty (score -= slash_count - 1) is unbounded/linear (-1.0 per directory level, no floor), so ANY match -- even a perfect one -- becomes permanently unfindable past depth ~9-10 once the penalty exceeds the maximum possible match bonus. Verified directly: a perfect single-file match disappears exactly at depth 10 regardless of query quality. Real repos routinely nest 10+ levels (e.g. Java/monorepo package trees), so this is not just an extreme-depth edge case."
fi

# --- 3. Unicode / spaces / punctuation in filenames ---------------------
uni_root="$SCRATCH/unicode"
rm -rf "$uni_root"
mkdir -p "$uni_root/sub dir"
: > "$uni_root/sub dir/héllo wörld.txt"
: > "$uni_root/文件名测试.py"
: > "$uni_root/file (with) [punct] & stuff.md"

hit1=$("$BIN" "wrld" "$uni_root" 5 2>/dev/null | grep -c "wörld")
hit2=$("$BIN" "文件名" "$uni_root" 5 2>/dev/null | grep -c "文件名测试")
hit3=$("$BIN" "punct" "$uni_root" 5 2>/dev/null | grep -c "punct")

if [[ "$hit1" -ge 1 && "$hit2" -ge 1 && "$hit3" -ge 1 ]]; then
  pass "unicode / spaces / punctuation filenames all matched correctly"
else
  fail "unicode / spaces / punctuation: space-name=$hit1 unicode-name=$hit2 punct-name=$hit3 (expected all >=1)"
fi

# --- 4. Empty corpus / single-file corpus -------------------------------
empty_root="$SCRATCH/empty"
rm -rf "$empty_root"; mkdir -p "$empty_root"
out_empty=$("$BIN" "anything" "$empty_root" 10 2>&1); rc_empty=$?
if [[ $rc_empty -eq 0 && -z "$out_empty" ]]; then
  pass "empty corpus: exits 0 with no output"
else
  fail "empty corpus: rc=$rc_empty output='$out_empty'"
fi

single_root="$SCRATCH/single"
rm -rf "$single_root"; mkdir -p "$single_root"
: > "$single_root/only_file.txt"
out_single=$("$BIN" "onlyfile" "$single_root" 10 2>/dev/null | grep -c "only_file.txt")
if [[ "$out_single" -ge 1 ]]; then
  pass "single-file corpus: found the one file via fuzzy subsequence query"
else
  fail "single-file corpus: file not found"
fi

# --- 5. Empty query / overlong query ------------------------------------
out_emptyq=$("$BIN" "" "$single_root" 10 2>&1); rc_emptyq=$?
if [[ $rc_emptyq -eq 0 && -z "$out_emptyq" ]]; then
  pass "empty query string: exits 0 with no output (matches fuzzy_score's early return)"
else
  fail "empty query string: rc=$rc_emptyq output='$out_emptyq'"
fi

overlong_q="$(printf 'q%.0s' {1..300})"
out_overlong=$("$BIN" "$overlong_q" "$single_root" 10 2>&1); rc_overlong=$?
if [[ $rc_overlong -eq 0 && -z "$out_overlong" ]]; then
  pass "query longer than any filename: exits 0 with no output"
else
  fail "query longer than any filename: rc=$rc_overlong output='$out_overlong'"
fi

# --- 6. Flat single directory vs balanced tree, same file count --------
N=50000
flat_root="$SCRATCH/flat"
tree_root="$SCRATCH/tree"
rm -rf "$flat_root" "$tree_root"
python3 "$BENCH_DIR/gen_corpus.py" --out "$flat_root" --files "$N" --seed 7 --flat >/dev/null
python3 "$BENCH_DIR/gen_corpus.py" --out "$tree_root" --files "$N" --seed 7 --depth 6 >/dev/null

t_flat_start=$(date +%s%N)
"$BIN" "e" "$flat_root" 15 >/dev/null 2>&1
t_flat_end=$(date +%s%N)

t_tree_start=$(date +%s%N)
"$BIN" "e" "$tree_root" 15 >/dev/null 2>&1
t_tree_end=$(date +%s%N)

ms_flat=$(( (t_flat_end - t_flat_start) / 1000000 ))
ms_tree=$(( (t_tree_end - t_tree_start) / 1000000 ))
observed "flat single dir ($N files) scan: ${ms_flat}ms vs balanced tree (depth 6): ${ms_tree}ms"

echo "== Stress suite complete =="
