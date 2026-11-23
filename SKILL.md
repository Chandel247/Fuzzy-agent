---
name: fuzzy-finder
description: Fuzzy-search file paths (files only, not directories) by partial, out-of-order, or misremembered name (fzf-style best-alignment scoring over the full relative path; a `/` in the query matches directory separators), returning a ranked top-K list in one call. Respects .gitignore (uses `git ls-files` inside git repos). Use when you only half-remember a filename, since a literal find/grep guess on a fuzzy name either returns nothing or dumps a huge unranked list that costs many follow-up tool calls and a lot of context to sift through — this tool is built to resolve that case in a single round-trip instead.
---

# Fuzzy Finder

A small, dependency-free C++ tool that lists the files under a directory
(via `git ls-files` inside a git repo, otherwise by walking the tree) and
ranks every relative path against a query using subsequence fuzzy matching
(the same family of algorithm as `fzf`). It matches files only — directories
are never returned as results — and respects `.gitignore` the same way `git`
does.

**Why this exists:** its main value is token efficiency for an agent with
imprecise filename recall. When the query isn't a literal substring (wrong
separators/casing, only one keyword remembered, or just an abbreviation),
`find -iname`/`grep` either return nothing or return every file matching one
common keyword, forcing several follow-up tool calls and a lot of wasted
context to narrow down. This tool resolves that same query in one ranked
call. Measured on a real local agent (`bench/results/live_pilot.csv`, from
an earlier version of the tool), a literal `find`/`grep` fallback strategy
failed outright on abbreviation-only recall and cost up to ~35x more tokens
than this tool once recall degraded even slightly.

Speed is no longer a reason to avoid it (`bench/results/git_benchmark.md`,
`summary.md`; one Apple-silicon Mac, so absolute numbers vary by machine):
in a git repo with a large ignored `node_modules/` it answers in ~0.26 s
versus ~0.7 s for `find | fzf -f`, roughly the same as
`git ls-files | fzf -f`. In plain directories it was 1.5–2x faster than
`find -iname` on this machine. In a very large repo where nearly everything
is tracked, git's own untracked-file scan dominates (~2 s for 100K files,
about the same as a plain walk, but far below the ~1 min the previous
version needed there). Use it when:

- You remember part of a filename ("something like `userAuth`" ->
  `src/auth/UserAuthService.ts`) but not the exact spelling, casing, or path.
- `Glob`/`find` would require multiple exact-pattern guesses.
- You want to resolve a fuzzy name in one call instead of iterating with
  broader and broader `find`/`grep` patterns.

It is **not** a content search tool — it only matches against paths, not file
contents. For "find files containing X", use `Grep` instead. And if you
already know the exact name or an exact pattern, `Glob`/`find` will be
faster — reach for this tool specifically when the name is uncertain.

## Setup (once per session)

Build the binary (fast no-op if already built and up to date):

```bash
BIN=$("/absolute/path/to/fuzzy_skill/scripts/build.sh")
```

This compiles `fuzzy_logic.cpp` with `c++17` into `bin/fuzzy_finder` next to
the script and prints the binary's path. Requires a C++17 compiler (`c++`/
`g++`/`clang++`) on `PATH` — already present on macOS and virtually every
Linux dev image.

## Usage

```bash
"$BIN" <query> [directory] [top_k]
```

- `query` — required. Characters must appear **in order** somewhere in the
  candidate's relative path (not necessarily contiguous). Matching is
  case-insensitive, with bonuses for exact case, contiguous runs, word
  boundaries, and matches inside the filename. A `/` in the query matches a
  directory separator, so `comp/button` finds `src/components/Button.tsx`
  and `bench/stress` finds `bench/stress_tests.sh`.
- `directory` — optional, defaults to `.`. The tree to search.
- `top_k` — optional, defaults to `15`. Number of ranked results to print.
  Must be an integer from 1 to 100000; anything else prints the usage line
  and an error to stderr and exits with code 2.

Output is `<score>\t<relative path>`, one per line, best match first, with
the score printed to exactly 2 decimals. Paths are relative to `directory`.
If any query character can't be matched in order, that file is dropped
entirely (score `0`, not printed). An empty query prints nothing and exits 0.

### Example

```bash
$ "$BIN" flogic . 5
20.20	fuzzy_logic.cpp

$ "$BIN" bench/stress . 3
35.20	bench/stress_tests.sh
34.50	bench/results/stress_results.txt
30.70	bench/results/results.csv
```

## Scoring notes (for interpreting results)

- Higher is better; only files that match every query character, in order,
  are returned.
- The candidate is the whole relative path (with `/` separators), not just
  the filename. The tool picks the **best-scoring alignment** of the query
  against the path (fzf-style dynamic programming), not the first
  occurrence of each character, so `test` scores `t_e_s_t_test.py` on its
  contiguous `test`, not on the scattered `t_e_s_t`.
- Each matched character earns `+1.0`, plus `+0.8` for exact case, `+0.6`
  if it directly follows the previous matched character, `+0.5` at a word
  boundary (start of path, after `/ _ - .` or a space, or a camelCase
  lower→upper change), and `+1.0` if it falls inside the **filename** (after
  the last `/`). So a match in the filename beats the same letters spread
  across directory names, and `UserAuth` beats `userauth` beats
  `u_s_e_r_a_u_t_h` for the same query.
- Shallower paths score higher: a small per-`/` penalty
  (`0.1 × (slashes − 1)`), capped at half the score, so a match is never
  dropped for being deeply nested.
- Ties are broken deterministically: shorter path first, then byte-wise
  path order. Output is identical from run to run.
- Case folding is ASCII-only: `é` doesn't match `e`, and non-ASCII letters
  only match themselves exactly.
- Queries longer than 64 characters or paths longer than 1024 characters
  use the same bonuses along the greedy (first-occurrence) alignment, to
  stay fast.

## File listing notes

- **Inside a git work tree**, files come from
  `git ls-files --cached --others --exclude-standard`: tracked files plus
  untracked files that aren't ignored. Every `.gitignore` level, negation
  patterns, and global excludes are applied by git itself, and ignored trees
  like `node_modules/` are never visited. Paths under `build/`, `.git/`, or
  `.venv/` are still dropped. Tracked files deleted from disk and submodule
  directories are never returned.
- **Outside a git repo** (or if `git` isn't installed), it walks the tree
  and skips `build/`, `.git/`, `.venv/`, `node_modules/`, and
  `__pycache__/`. No `.gitignore` filtering happens there.
- Results are files only — directories are never returned, even if the
  query matches a directory name.
- A directory it can't read (permissions) is skipped on its own; the rest
  of the walk still completes normally.

## When to prefer this over Glob/find/grep

- Prefer **this tool** when you have a fuzzy/partial name and no exact
  pattern in mind — one ranked call replaces the several round-trips a
  `find`/`grep` guessing strategy would otherwise need. Add a `/` to the
  query (`comp/button`) when you remember part of the directory too.
- Prefer **Glob** or a direct `find -iname` when you know the exact
  extension/pattern (e.g. `**/*.test.ts`) — it's faster and this tool adds
  nothing there.
- Prefer **Grep** when the search target is file *contents*, not the path.

## Files

- `fuzzy_logic.cpp` — the implementation (`git ls-files` listing or
  directory walk + best-alignment scoring + top-K min-heap selection).
- `scripts/build.sh` — builds/caches the binary; safe to call every time,
  it skips recompiling if the binary is already current.
- `bench/` — the performance, token-cost, and robustness benchmarks backing
  the claims above (`bench/results/summary.md`, `git_benchmark.md`,
  `hypothesis_summary.md`, `live_pilot.csv`, `stress_results.txt`), plus
  `bench/regression_tests.sh`.
