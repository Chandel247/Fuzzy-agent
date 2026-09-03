---
name: fuzzy-finder
description: Fuzzy-search file paths (files only, not directories) by partial, out-of-order, or misremembered name (fzf-style subsequence scoring), returning a ranked top-K list in one call. Respects .gitignore. Use when you only half-remember a filename, since a literal find/grep guess on a fuzzy name either returns nothing or dumps a huge unranked list that costs many follow-up tool calls and a lot of context to sift through — this tool is built to resolve that case in a single round-trip instead.
---

# Fuzzy Finder

A small, dependency-free C++ tool that walks a directory tree and ranks every
file path against a query using subsequence fuzzy matching (the same family
of algorithm as `fzf`/`fd --fuzzy`). It matches files only — directories are
walked (to find the files inside them) but never returned as results
themselves — and respects `.gitignore` the same way `git`/`fzf` would.

**Why this exists:** benchmarking (`bench/`) showed this tool is *not* faster
than `find`/`grep`/`fzf` on raw latency — it's consistently slower, and the
gap widens as the repo grows. Its actual value is token efficiency for an
agent with imprecise filename recall. When the query isn't a literal
substring (wrong separators/casing, only one keyword remembered, or just an
abbreviation), `find -iname`/`grep` either return nothing or return every
file matching one common keyword, forcing several follow-up tool calls and
a lot of wasted context to narrow down. This tool resolves that same query
in one ranked call. Measured on a real local agent (`bench/results/live_pilot.csv`):
a literal `find`/`grep` fallback strategy failed outright on abbreviation-only
recall and cost up to ~35x more tokens than this tool once recall degraded
even slightly. Use it when:

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
  candidate filename (not necessarily contiguous). Matching is
  case-insensitive, with a bonus for exact-case and contiguous matches.
- `directory` — optional, defaults to `.`. The tree to search.
- `top_k` — optional, defaults to `15`. Number of ranked results to print.

Output is `<score>\t<relative path>`, one per line, best match first, one
line per candidate. No match for a query character anywhere in the remaining
filename means that file is dropped entirely (score `0`, not printed).

### Example

```bash
$ "$BIN" flogic . 5
13.2   fuzzy_logic.cpp
```

## Scoring notes (for interpreting results)

- Higher is better; only files that match every query character, in order,
  are returned.
- Shallower paths score higher (a small, bounded per-`/` penalty that can
  only affect ranking among matches, never eliminate one — a match is
  never dropped for being deeply nested).
- Consecutive matched characters and exact-case matches both add bonus
  points, so `UserAuth` beats `userauth` beats `u_s_e_r_a_u_t_h` for the
  same query.
- Automatically skips `build/`, `.git/`, and `.venv/` directories, and
  anything `.gitignore` excludes (via `git check-ignore`, so nested
  `.gitignore` files and negation patterns are respected correctly). Falls
  back to unfiltered results if the target directory isn't a git repo or
  `git` isn't installed.
- Results are files only — directories are never returned, even if the
  query matches a directory name.
- A directory it can't read (permissions) is skipped on its own; the rest
  of the walk still completes normally.

## When to prefer this over Glob/find/grep

- Prefer **this tool** when you have a fuzzy/partial name and no exact
  pattern in mind — it trades a slower single call for avoiding the several
  round-trips a `find`/`grep` guessing strategy would otherwise need.
- Prefer **Glob** or a direct `find -iname` when you know the exact
  extension/pattern (e.g. `**/*.test.ts`) — it's faster and this tool adds
  nothing there.
- Prefer **Grep** when the search target is file *contents*, not the path.

## Files

- `fuzzy_logic.cpp` — the implementation (directory walk + scoring + top-K
  min-heap selection).
- `scripts/build.sh` — builds/caches the binary; safe to call every time,
  it skips recompiling if the binary is already current.
- `bench/` — the performance, token-cost, and robustness benchmarks backing
  the claims above (`bench/results/summary.md`, `hypothesis_summary.md`,
  `live_pilot.csv`, `stress_results.txt`).
