#!/usr/bin/env bash
# Regression suite for file listing (git ls-files vs. directory walk),
# ranking (best-alignment matcher, path queries, deterministic ties), and
# CLI validation. Each case prints one PASS / FAIL / OBSERVED line; the
# script exits non-zero if any case FAILs.
#
# Portability: bash 3.2 compatible (no declare -A, mapfile, ${var,,}).
# Git commits pass identity inline so global git config isn't needed.
#
# Usage: bench/regression_tests.sh [scratch_dir]
#        FUZZY_BIN=/path/to/fuzzy_finder bench/regression_tests.sh
set -uo pipefail  # no -e: each check handles its own failures

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="${1:-$(mktemp -d)}/regression"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

# FUZZY_BIN overrides the binary under test (default: build/cached build).
BIN="${FUZZY_BIN:-$("$SKILL_DIR/scripts/build.sh")}"
# Optional: the pre-optimisation binary, for the greedy-vs-DP comparison.
BASELINE_BIN="${BASELINE_BIN:-/tmp/fuzzy_baseline/fuzzy_finder}"

FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
observed() { echo "OBSERVED: $1"; }

command -v git >/dev/null || { echo "git not found on PATH" >&2; exit 1; }

gcommit() { git -C "$1" -c user.email=t@t -c user.name=t commit -qm "${2:-init}"; }
# Paths only (drop the score column).
paths_of() { cut -f2-; }

echo "== Regression suite (scratch: $SCRATCH) =="

# --- Fixture: a git repo with ignored trees and a nested .gitignore -----
repo="$SCRATCH/repo"
mkdir -p "$repo"
git -C "$repo" init -q
printf 'node_modules/\ndist/\n' > "$repo/.gitignore"
mkdir -p "$repo/node_modules/pkg" "$repo/dist" "$repo/src"
: > "$repo/node_modules/pkg/index.js"
: > "$repo/dist/app.js"
: > "$repo/src/app.js"
printf 'secret.txt\n' > "$repo/src/.gitignore"
: > "$repo/src/secret.txt"
: > "$repo/secret.txt"
: > "$repo/gone.py"
git -C "$repo" add -A
gcommit "$repo"

# --- 1. .gitignore'd trees never appear ---------------------------------
out=$("$BIN" app "$repo" 50 2>&1 | paths_of)
if [[ "$out" == "src/app.js" ]]; then
  pass "gitignore: query 'app' returns only src/app.js (node_modules/, dist/ excluded)"
else
  fail "gitignore: expected only src/app.js, got: $(echo "$out" | tr '\n' ' ')"
fi
out=$("$BIN" index "$repo" 50 2>&1 | paths_of)
if [[ -z "$out" ]]; then
  pass "gitignore: node_modules/pkg/index.js never listed"
else
  fail "gitignore: query 'index' returned: $(echo "$out" | tr '\n' ' ')"
fi

# --- 2. Nested .gitignore is respected ----------------------------------
out=$("$BIN" secret "$repo" 50 2>&1 | paths_of)
if [[ "$out" == "secret.txt" ]]; then
  pass "nested .gitignore: src/secret.txt excluded, root secret.txt returned"
else
  fail "nested .gitignore: expected only secret.txt, got: $(echo "$out" | tr '\n' ' ')"
fi

# --- 3. Untracked but not ignored files appear --------------------------
: > "$repo/fresh_untracked_notes.md"
out=$("$BIN" freshuntracked "$repo" 50 2>&1 | paths_of)
if [[ "$out" == "fresh_untracked_notes.md" ]]; then
  pass "untracked (not ignored) file is returned"
else
  fail "untracked file: expected fresh_untracked_notes.md, got: $(echo "$out" | tr '\n' ' ')"
fi

# --- 4. Tracked file deleted from disk (no git rm) never appears ---------
rm -f "$repo/gone.py"
out=$("$BIN" gone "$repo" 50 2>&1)
if [[ -z "$out" ]]; then
  pass "deleted tracked file: no results for 'gone'"
else
  fail "deleted tracked file still listed: $out"
fi

# --- 4b. Submodule (gitlink) entries are directories, never returned -----
sha=$(git -C "$repo" rev-parse HEAD)
mkdir -p "$repo/vendor_appkit"
git -C "$repo" update-index --add --cacheinfo "160000,$sha,vendor_appkit"
out=$("$BIN" appkit "$repo" 50 2>&1)
git -C "$repo" update-index --force-remove vendor_appkit
if [[ -z "$out" ]]; then
  pass "submodule entry: gitlink directory not returned"
else
  fail "submodule entry returned: $out"
fi

# --- 5. Not a git repo: walk still works, node_modules skipped ----------
plain="$SCRATCH/plain"
mkdir -p "$plain"
( cd "$repo" && tar cf - --exclude .git . ) | ( cd "$plain" && tar xf - )
out_app=$("$BIN" app "$plain" 50 2>&1 | paths_of)
out_idx=$("$BIN" index "$plain" 50 2>&1 | paths_of)
if echo "$out_app" | grep -qx "src/app.js" && [[ -z "$out_idx" ]]; then
  pass "non-git directory: files found by walking; node_modules/ skipped"
else
  fail "non-git directory: app -> [$(echo "$out_app" | tr '\n' ' ')], index -> [$(echo "$out_idx" | tr '\n' ' ')]"
fi

# --- 6a. Best alignment beats greedy -----------------------------------
dp="$SCRATCH/dp"
mkdir -p "$dp"
: > "$dp/t_e_s_t_test.py"
: > "$dp/zzz.py"
out=$("$BIN" test "$dp" 10 2>&1)
new_score=$(echo "$out" | awk -F'\t' '$2=="t_e_s_t_test.py"{print $1}')
if [[ -n "$new_score" ]]; then
  greedy_score=""
  if [[ -x "$BASELINE_BIN" ]]; then
    greedy_score=$("$BASELINE_BIN" test "$dp" 10 2>/dev/null | awk -F'\t' '$2=="t_e_s_t_test.py"{print $1}')
  fi
  # 7.2 is what the old greedy matcher scored here (recorded from the
  # pre-optimisation binary); used when that binary isn't available.
  [[ -z "$greedy_score" ]] && greedy_score="7.2"
  if awk -v a="$new_score" -v b="$greedy_score" 'BEGIN{exit !(a>b)}'; then
    pass "best alignment: t_e_s_t_test.py found, score $new_score > greedy $greedy_score"
  else
    fail "best alignment: score $new_score not above greedy $greedy_score"
  fi
else
  fail "best alignment: t_e_s_t_test.py not returned for 'test' (got: $out)"
fi

# --- 6b. '/' in the query matches across directories --------------------
pq="$SCRATCH/pathq"
mkdir -p "$pq/auth" "$pq/other"
: > "$pq/auth/user_service.py"
: > "$pq/other/user_service.py"
first=$("$BIN" auth/user "$pq" 10 2>&1 | head -1 | paths_of)
if [[ "$first" == "auth/user_service.py" ]]; then
  pass "path query: 'auth/user' ranks auth/user_service.py first"
else
  fail "path query: first result was '$first'"
fi

# --- 6c. Filename match outranks letters spread across directories ------
fn="$SCRATCH/fname"
mkdir -p "$fn/wid/get" "$fn/src"
: > "$fn/wid/get/x.py"
: > "$fn/src/abc_widget.py"
first=$("$BIN" widget "$fn" 10 2>&1 | head -1 | paths_of)
if [[ "$first" == "src/abc_widget.py" ]]; then
  pass "filename bonus: src/abc_widget.py outranks wid/get/x.py for 'widget'"
else
  fail "filename bonus: first result was '$first'"
fi

# --- 7. Deterministic ties ----------------------------------------------
ties="$SCRATCH/ties"
for d in cc aa bb dd; do mkdir -p "$ties/$d"; : > "$ties/$d/tie_file.txt"; done
: > "$ties/tie_file.txt"
ref=$("$BIN" tiefile "$ties" 10 2>&1)
same=1
for i in 2 3 4 5; do
  [[ "$("$BIN" tiefile "$ties" 10 2>&1)" == "$ref" ]] || same=0
done
expected_order=$'tie_file.txt\naa/tie_file.txt\nbb/tie_file.txt\ncc/tie_file.txt\ndd/tie_file.txt'
if [[ $same -eq 1 && "$(echo "$ref" | paths_of)" == "$expected_order" ]]; then
  pass "ties: identical output over 5 runs, ordered by score, then length, then bytes"
else
  fail "ties: same=$same order=[$(echo "$ref" | paths_of | tr '\n' ' ')]"
fi
# Eviction must be deterministic too: top_k smaller than the tie group.
ref2=$("$BIN" tiefile "$ties" 2 2>&1 | paths_of | tr '\n' ' ')
if [[ "$ref2" == "tie_file.txt aa/tie_file.txt " ]]; then
  pass "ties: top_k=2 keeps the same first two entries (deterministic eviction)"
else
  fail "ties: top_k=2 returned [$ref2]"
fi

# --- 8. Invalid top_k ----------------------------------------------------
for k in abc 0 -1 10x ""; do
  err=$("$BIN" x "$dp" "$k" 2>&1 >/dev/null); rc=$?
  if [[ $rc -eq 2 ]] && echo "$err" | grep -q "Usage:"; then
    pass "invalid top_k '$k': exit 2 with usage on stderr"
  else
    fail "invalid top_k '$k': rc=$rc stderr='$err'"
  fi
done
out=$("$BIN" test "$dp" 1 2>&1); rc=$?
if [[ $rc -eq 0 && $(echo "$out" | wc -l | tr -d ' ') -eq 1 ]]; then
  pass "valid top_k=1: exit 0, one result"
else
  fail "valid top_k=1: rc=$rc output='$out'"
fi

# --- 9. Unicode filename (ASCII-only case folding) ----------------------
uni="$SCRATCH/unicode"
mkdir -p "$uni"
: > "$uni/naïve_résumé.txt"
crashed=0
matched=""
for q in resume nave "naïve" "résumé" "NAÏVE"; do
  out=$("$BIN" "$q" "$uni" 10 2>&1); rc=$?
  [[ $rc -ne 0 ]] && crashed=1
  echo "$out" | grep -q "naïve_résumé.txt" && matched="$matched '$q'"
done
if [[ $crashed -eq 0 ]] && echo "$matched" | grep -qE "'(resume|nave)'"; then
  pass "unicode filename: no crash; matching queries:$matched"
else
  fail "unicode filename: crashed=$crashed matching queries:[$matched]"
fi
observed "unicode: case folding is ASCII-only, so 'é' never matches 'e' and 'Ï' never matches 'ï'"

# --- 10. Subdirectory target inside a git repo --------------------------
out=$(cd "$repo" && "$BIN" app src 10 2>&1 | paths_of)
out_secret=$(cd "$repo" && "$BIN" secret src 10 2>&1)
if [[ "$out" == "app.js" && -z "$out_secret" ]]; then
  pass "subdirectory target: 'src' returns paths relative to src; src/.gitignore still applied"
else
  fail "subdirectory target: app -> [$(echo "$out" | tr '\n' ' ')], secret -> [$out_secret]"
fi

# --- 11. Conflicted (unmerged) paths are listed once ---------------------
mrepo="$SCRATCH/merge"
mkdir -p "$mrepo"
git -C "$mrepo" init -q
echo base > "$mrepo/conflict_me.txt"
git -C "$mrepo" add -A; gcommit "$mrepo"
main_branch=$(git -C "$mrepo" rev-parse --abbrev-ref HEAD)
git -C "$mrepo" checkout -q -b other
echo theirs > "$mrepo/conflict_me.txt"; git -C "$mrepo" -c user.email=t@t -c user.name=t commit -qam theirs
git -C "$mrepo" checkout -q "$main_branch"
echo ours > "$mrepo/conflict_me.txt"; git -C "$mrepo" -c user.email=t@t -c user.name=t commit -qam ours
git -C "$mrepo" -c user.email=t@t -c user.name=t merge -q other >/dev/null 2>&1
stages=$(git -C "$mrepo" ls-files --cached | grep -c conflict_me)
count=$("$BIN" conflictme "$mrepo" 10 2>&1 | grep -c conflict_me)
if [[ $count -eq 1 ]]; then
  pass "merge conflict: path listed by git $stages times, returned once"
else
  fail "merge conflict: returned $count times (git lists it $stages times)"
fi

# --- 12. Empty query ----------------------------------------------------
out=$("$BIN" "" "$repo" 10 2>&1); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then
  pass "empty query: exit 0, no output"
else
  fail "empty query: rc=$rc output='$out'"
fi

echo "== Regression suite complete: $FAILS failure(s) =="
[[ $FAILS -eq 0 ]]
