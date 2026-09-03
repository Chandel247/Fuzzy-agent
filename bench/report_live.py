#!/usr/bin/env python3
"""Render live-agent results as markdown, alongside the scripted hypothesis
numbers for the same (size, level) cells for direct comparison."""
import csv
import os
import sys
from collections import defaultdict

BENCH_DIR = os.path.dirname(os.path.abspath(__file__))
LIVE_CSV = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BENCH_DIR, "results", "live_pilot.csv")
SCRIPTED_CSV = os.path.join(BENCH_DIR, "results", "hypothesis.csv")

LEVELS = ["L0", "L1", "L2", "L3"]
CONDITIONS = ["BASH", "FUZZY"]


def load(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def mean(rows, field):
    return sum(float(r[field]) for r in rows) / len(rows) if rows else float("nan")


def main():
    live_rows = load(LIVE_CSV)
    if not live_rows:
        print(f"No results at {LIVE_CSV}", file=sys.stderr)
        sys.exit(1)
    scripted_rows = load(SCRIPTED_CSV)

    by_size = defaultdict(list)
    for r in live_rows:
        by_size[int(r["size"])].append(r)

    scripted_by_size_level = defaultdict(list)
    for r in scripted_rows:
        if r["policy"] == "FUZZY":
            scripted_by_size_level[(int(r["size"]), r["level"])].append(r)

    print(f"\nLive results: {LIVE_CSV}\n")
    for size in sorted(by_size):
        grouped = defaultdict(list)
        for r in by_size[size]:
            grouped[(r["level"], r["condition"])].append(r)

        print(f"\n## Corpus size: {size} files\n")
        print("| level | condition | mean tokens | mean turns | success rate | mean elapsed (s) |")
        print("|---|---|---:|---:|---:|---:|")
        for level in LEVELS:
            for cond in CONDITIONS:
                items = grouped.get((level, cond), [])
                if not items:
                    continue
                success = sum(1 for i in items if i["found"] == "True") / len(items)
                print(
                    f"| {level} | {cond} | {mean(items, 'total_tokens'):.0f} | "
                    f"{mean(items, 'turns'):.1f} | {success * 100:.0f}% | {mean(items, 'elapsed_s'):.1f} |"
                )

        print("\n### Live BASH/FUZZY token ratio vs. scripted FUZZY tokens\n")
        for level in LEVELS:
            bash_items = grouped.get((level, "BASH"), [])
            fuzzy_items = grouped.get((level, "FUZZY"), [])
            if not bash_items or not fuzzy_items:
                continue
            bash_mean = mean(bash_items, "total_tokens")
            fuzzy_mean = mean(fuzzy_items, "total_tokens")
            ratio = bash_mean / fuzzy_mean if fuzzy_mean else float("inf")
            scripted = scripted_by_size_level.get((size, level))
            scripted_note = f", scripted FUZZY was {mean(scripted, 'total_tokens'):.0f} tok" if scripted else ""
            print(f"- {level}: live BASH={bash_mean:.0f} tok, live FUZZY={fuzzy_mean:.0f} tok, ratio={ratio:.2f}x{scripted_note}")


if __name__ == "__main__":
    main()
