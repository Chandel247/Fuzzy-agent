#!/usr/bin/env python3
"""Render token-only path-discovery results as markdown."""
import csv
import os
import sys
from collections import defaultdict

BENCH_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(BENCH_DIR, "results", "hypothesis.csv")
LEVELS = ["L0", "L1", "L2", "L3"]
POLICY_ORDER = ["FIND_INAME", "FIND_GREP", "RG_FILES", "FUZZY", "FUZZY_COLD"]


def mean(rows, field):
    return sum(int(row[field]) for row in rows) / len(rows)


def main():
    if not os.path.exists(CSV_PATH):
        print(f"No results at {CSV_PATH} -- run run_hypothesis.sh first", file=sys.stderr)
        sys.exit(1)
    with open(CSV_PATH, newline="") as results_file:
        rows = list(csv.DictReader(results_file))
    if not rows:
        print("hypothesis.csv is empty", file=sys.stderr)
        sys.exit(1)

    print(f"Tokenizer used: {rows[0]['tokenizer_used']}")
    print("Token totals include prompt, command, returned output, and completion. FUZZY_COLD also includes SKILL.md and cached-build setup; FUZZY is the warm-session cost.\n")
    by_size = defaultdict(list)
    for row in rows:
        by_size[int(row["size"])].append(row)
    for size in sorted(by_size):
        grouped = defaultdict(list)
        for row in by_size[size]:
            grouped[(row["level"], row["policy"])].append(row)
        print(f"## Corpus size: {size} paths\n")
        print("| recall | policy | mean tokens | mean attempts | success rate |")
        print("|---|---|---:|---:|---:|")
        for level in LEVELS:
            for policy in POLICY_ORDER:
                items = grouped.get((level, policy), [])
                if not items:
                    continue
                success = sum(row["found"] == "True" for row in items) / len(items)
                print(f"| {level} | {policy} | {mean(items, 'total_tokens'):.0f} | {mean(items, 'attempts'):.1f} | {success:.0%} |")
        print()
        for level in LEVELS:
            warm = grouped.get((level, "FUZZY"), [])
            baselines = [grouped[(level, policy)] for policy in POLICY_ORDER[:3] if grouped.get((level, policy))]
            if not warm or not baselines:
                continue
            successful = [items for items in baselines if all(row["found"] == "True" for row in items)]
            if successful and all(row["found"] == "True" for row in warm):
                best = min(mean(items, "total_tokens") for items in successful)
                print(f"- {level} warm fuzzy vs best successful baseline: {best / mean(warm, 'total_tokens'):.2f}x token ratio")
        print()


if __name__ == "__main__":
    main()
