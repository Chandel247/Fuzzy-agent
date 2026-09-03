# Fuzzy Finder

A [Claude Code skill](https://docs.claude.com/en/docs/claude-code) that fuzzy-searches
file paths by partial, out-of-order, or misremembered names (fzf-style subsequence
scoring) and returns a ranked top-K list in one call. It's a small, dependency-free
C++ tool that walks a directory tree, respects `.gitignore`, and matches files only
(directories are walked but never returned).

The problem it solves: when you only half-remember a filename, a literal
`find`/`grep` guess either returns nothing or dumps a huge unranked list, costing
several follow-up tool calls and a lot of context to sift through. This resolves
that same fuzzy query in one ranked call.

It is not faster than `find`/`grep`/`fzf` on raw latency — benchmarks show it's
consistently slower, and the gap widens as the repo grows. Its value is token
efficiency for an agent with imprecise filename recall, not search speed.

## Setup

```bash
BIN=$("/path/to/fuzzy_skill/scripts/build.sh")
"$BIN" <query> [directory] [top_k]
```

Requires a C++17 compiler (`c++`/`g++`/`clang++`) on `PATH`. See `SKILL.md` for
full usage, scoring notes, and output format.

## How it was tested

- **Latency & correctness** (`bench/run_benchmark.sh`) — compares this tool against
  `find -iname`, `find | grep`, and `fzf` across corpora of 1K/10K/100K files, on
  exact, fuzzy, out-of-order, and no-match queries. Results: `bench/results/summary.md`,
  `correctness.csv`.
- **Token cost** (`bench/run_hypothesis.sh`) — simulates imperfect-recall search
  tasks (exact match, wrong separators/casing, abbreviation-only, unmatched query)
  and measures actual tokens spent per policy. Results: `bench/results/hypothesis_summary.md`.
  On abbreviation-only recall, the `find`/`grep` fallback strategy cost up to ~35x
  more tokens than this tool.
- **Live agent pilot** (`bench/run_live_pilot.sh`) — runs a real local LLM agent
  end-to-end against both a bash-only policy and this tool, across recall
  difficulty levels. Results: `bench/results/live_pilot.csv` and per-run
  transcripts in `bench/results/live_pilot_transcripts/`.
- **Stress / robustness** (`bench/stress_tests.sh`) — edge cases: permission-denied
  subdirectories, deep nesting (100+ levels), unicode/space/punctuation filenames,
  empty corpus, single-file corpus, empty query, over-long query. Results:
  `bench/results/stress_results.txt`.

## Future improvements

- The fuzzy-matching algorithm itself is a straightforward subsequence scorer.
  It works correctly but is slower than comparable tools (`fzf`, `fd --fuzzy`) at
  scale; a future revision should replace it with a better and faster matching
  algorithm.

## Files

- `SKILL.md` — the skill definition Claude Code loads (usage, scoring rules,
  when to prefer this over `Glob`/`find`/`grep`).
- `fuzzy_logic.cpp` — the implementation.
- `scripts/build.sh` — builds/caches the binary.
- `bench/` — the benchmark suite backing the claims above.
