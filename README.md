# Fuzzy Finder

A [Claude Code skill](https://docs.claude.com/en/docs/claude-code) that fuzzy-searches
file paths by partial, out-of-order, or misremembered names (fzf-style subsequence
scoring over the full relative path) and returns a ranked top-K list in one call.
It's a small, dependency-free C++ tool that lists files with `git ls-files` inside
a git repo (or walks the tree outside one), respects `.gitignore`, and matches
files only (directories are never returned).

The problem it solves: when you only half-remember a filename, a literal
`find`/`grep` guess either returns nothing or dumps a huge unranked list, costing
several follow-up tool calls and a lot of context to sift through. This resolves
that same fuzzy query in one ranked call.

Its main value is token efficiency for an agent with imprecise filename recall.

## Speed

Measured on one Apple-silicon Mac (hyperfine; full tables in `bench/results/`).
Absolute numbers depend heavily on the machine and filesystem.

- **Git repo with a large ignored directory** (`git_benchmark.md`: 10,000 committed
  files plus an ignored `node_modules/` with 50,000 files): **0.26–0.28 s**, down from
  **6.2 s** for the previous version (~22–24x). That's ~2.5x faster than
  `find | fzf -f` (0.68–0.71 s, which also wades through `node_modules/`) and about
  the same as, or slightly slower than, `git ls-files | fzf -f` (0.25 s).
- **Plain directories, no git** (`summary.md`): 1.4–2.1x faster than the previous
  version, e.g. 100,000 files in 1.63–1.73 s (was 3.26–3.40 s). On this machine
  that's ~1.5x faster than `find -iname`, `find | grep`, and `find | fzf -f` at
  1,000 files and ~2x faster at 10,000 and 100,000. Caveat: the previous version
  was already 5–20% faster than `find` on this machine, while earlier runs on
  another machine had it 15–40% slower, so the comparison with `find` is
  machine-dependent. The speed-up over the previous version is the robust number.
- **Very large repo with almost everything tracked** (100,000 files, all
  committed; one-off hyperfine run, not in `bench/results/`): ~2.1 s, down from
  ~1.1 min for the previous version, which piped every path through
  `git check-ignore` (~32x). It's still slightly slower than walking the same
  files as a plain directory (1.8 s), because git's own untracked-file scan
  (`ls-files --others`) takes about 2.0 s of that.

## Setup

```bash
BIN=$("/path/to/fuzzy_skill/scripts/build.sh")
"$BIN" <query> [directory] [top_k]
```

Requires a C++17 compiler (`c++`/`g++`/`clang++`) on `PATH`. See `SKILL.md` for
full usage, scoring notes, and output format.

## How it was tested

- **Latency & correctness** (`bench/run_benchmark.sh`) — compares this tool against
  `find -iname`, `find | grep`, and `fzf` across plain-directory corpora of
  1K/10K/100K files, on exact, fuzzy, out-of-order, and no-match queries. Results:
  `bench/results/summary.md`, `correctness.csv`.
- **Git-repo latency** (`bench/run_git_benchmark.sh`) — a committed 10K-file repo
  plus an ignored 50K-file `node_modules/`; compares the previous binary, this one,
  `git ls-files | fzf`, `find | fzf`, and `rg --files` (if installed). Results:
  `bench/results/git_benchmark.md`.
- **Regression tests** (`bench/regression_tests.sh`) — `.gitignore` handling (root
  and nested), untracked/deleted/submodule/conflicted paths, the non-git fallback,
  best-alignment vs greedy ranking, `/` path queries, deterministic ties, `top_k`
  validation, unicode names, and subdirectory targets. PASS/FAIL per case.
- **Token cost** (`bench/run_hypothesis.sh`) — simulates imperfect-recall search
  tasks (exact match, wrong separators/casing, abbreviation-only, unmatched query)
  and measures actual tokens spent per policy. Results: `bench/results/hypothesis_summary.md`.
  On abbreviation-only recall, `find -iname` and `find | grep` never found the file
  (0% success) while this tool always did. With wrong separators/casing they found it
  but cost 2.4–8.1x more tokens (10 to 1,000 paths).
- **Live agent pilot** (`bench/run_live_pilot.sh`) — runs a real local LLM agent
  end-to-end against both a bash-only policy and this tool, across recall
  difficulty levels. Results: `bench/results/live_pilot.csv` and per-run
  transcripts in `bench/results/live_pilot_transcripts/` (recorded with an earlier
  version of the tool; not re-run since).
- **Stress / robustness** (`bench/stress_tests.sh`) — edge cases: permission-denied
  subdirectories, deep nesting (100+ levels), unicode/space/punctuation filenames,
  empty corpus, single-file corpus, empty query, over-long query. Results:
  `bench/results/stress_results.txt`.

## Future improvements

- Case folding is ASCII-only (`é` doesn't match `e`). Unicode-aware folding
  would help non-English filenames.
- In very large, mostly tracked repos, git's untracked-file scan dominates the
  runtime. Using git's untracked cache or fsmonitor (when the repo enables
  them) could cut that.

## Files

- `SKILL.md` — the skill definition Claude Code loads (usage, scoring rules,
  when to prefer this over `Glob`/`find`/`grep`).
- `fuzzy_logic.cpp` — the implementation.
- `scripts/build.sh` — builds/caches the binary.
- `bench/` — the benchmark suite backing the claims above.

## License

[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) — see `LICENSE`.

- **Free for non-commercial use**: personal projects, study, and research.
- **No commercial use** without separate permission from the author.
- **Credit required**: keep the copyright notice and say if you changed anything.
- **Share-alike**: if you share a modified version, it must use this same license.

Versions published before this change were released under the MIT License and
remain available under MIT terms; this license applies from this commit onward.
