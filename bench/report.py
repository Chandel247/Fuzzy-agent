#!/usr/bin/env python3
"""Prints markdown summary tables from bench/results/{results,correctness}.csv."""
import csv
import os
import sys
from collections import defaultdict

BENCH_DIR = os.path.dirname(os.path.abspath(__file__))
RESULTS_CSV = os.path.join(BENCH_DIR, "results", "results.csv")
CORRECTNESS_CSV = os.path.join(BENCH_DIR, "results", "correctness.csv")


def load_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def fmt_ms(seconds_str):
    return f"{float(seconds_str) * 1000:.2f}"


def main():
    if not os.path.exists(RESULTS_CSV):
        print(f"No results at {RESULTS_CSV} -- run run_benchmark.sh first", file=sys.stderr)
        sys.exit(1)

    rows = load_csv(RESULTS_CSV)
    by_size = defaultdict(list)
    for r in rows:
        by_size[int(r["size"])].append(r)

    for size in sorted(by_size):
        print(f"\n## Corpus size: {size} files\n")
        print("| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |")
        print("|---|---|---|---|---|---|---|")
        for r in sorted(by_size[size], key=lambda r: (r["query_label"], r["tool"])):
            print(
                f"| {r['tool']} | {r['query_label']} | {fmt_ms(r['mean'])} | "
                f"{fmt_ms(r['stddev'])} | {fmt_ms(r['min'])} | {fmt_ms(r['max'])} | "
                f"{float(r['files_per_sec']):.0f} |"
            )

    if os.path.exists(CORRECTNESS_CSV):
        crows = load_csv(CORRECTNESS_CSV)
        if crows:
            print("\n## Correctness: is the expected file actually found?\n")
            print("| size | tool | query | expected file | found | rank (line #) |")
            print("|---|---|---|---|---|---|")
            for r in sorted(crows, key=lambda r: (int(r["size"]), r["query_label"], r["tool"])):
                print(
                    f"| {r['size']} | {r['tool']} | {r['query_label']} | "
                    f"{os.path.basename(r['expected_relpath'])} | {r['found_anywhere']} | "
                    f"{r['rank'] or '-'} |"
                )


if __name__ == "__main__":
    main()
