#!/usr/bin/env python3
"""Run token-only path-discovery trials over generated corpora.

The CSV records every visible token component. It deliberately does not
measure elapsed time: runtime varies by machine and implementation, while the
question under test is how much context each search strategy returns to an
agent.
"""
import argparse
import csv
import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from agent_policies import derive_guesses, run_find_grep_policy, run_find_policy, run_fuzzy_policy, run_rg_policy
from token_cost import count_tokens, METHOD


def gen_corpus(bench_dir, out_dir, size, seed=42, depth=6):
    manifest_path = out_dir + ".manifest.json"
    with open(manifest_path, "w") as manifest_file:
        subprocess.run(
            [sys.executable, os.path.join(bench_dir, "gen_corpus.py"), "--out", out_dir,
             "--files", str(size), "--depth", str(depth), "--seed", str(seed)],
            stdout=manifest_file,
            check=True,
        )
    with open(manifest_path) as manifest_file:
        return json.load(manifest_file)


def setup_cost(skill_dir: str) -> tuple[int, int]:
    """Return one-session skill-document and build-command token costs."""
    with open(os.path.join(skill_dir, "SKILL.md")) as skill_file:
        skill_tokens = count_tokens(skill_file.read())
    command = f'BIN=$("{os.path.join(skill_dir, "scripts", "build.sh")}")'
    output = subprocess.run(command, shell=True, capture_output=True, text=True, check=True).stdout
    return skill_tokens, count_tokens(command) + count_tokens(output)


def completion_tokens(trial: dict) -> int:
    response = f"Found: {trial['selected']}" if trial["found"] else "No matching path found."
    return count_tokens(response)


def write_trial(writer, size, needle_key, level, trial, prompt_tokens, skill_tokens, setup_tokens):
    command_tokens = sum(count_tokens(command) for command in trial["commands"])
    output_tokens = sum(count_tokens(output) for output in trial["outputs"])
    response_tokens = completion_tokens(trial)
    total = prompt_tokens + skill_tokens + setup_tokens + command_tokens + output_tokens + response_tokens
    writer.writerow([
        size, needle_key, level, trial["policy"], trial["attempts"], trial["found"],
        prompt_tokens, skill_tokens, setup_tokens, command_tokens, output_tokens,
        response_tokens, total, METHOD,
    ])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bin", required=True, help="path to built fuzzy_finder")
    parser.add_argument("--scratch", required=True, help="directory for generated corpora")
    parser.add_argument("--out", required=True, help="output CSV path")
    parser.add_argument("--sizes", default="10,100,1000,10000,100000")
    parser.add_argument("--top-k", type=int, default=15)
    parser.add_argument("--max-lines", type=int, default=200, help="visible tool-output line cap")
    parser.add_argument("--max-bytes", type=int, default=12000, help="visible tool-output byte cap")
    args = parser.parse_args()

    bench_dir = os.path.dirname(os.path.abspath(__file__))
    skill_dir = os.path.dirname(bench_dir)
    os.makedirs(args.scratch, exist_ok=True)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    skill_tokens, build_tokens = setup_cost(skill_dir)
    have_rg = shutil.which("rg") is not None

    with open(args.out, "w", newline="") as output_file:
        writer = csv.writer(output_file)
        writer.writerow([
            "size", "needle_key", "level", "policy", "attempts", "found", "prompt_tokens",
            "skill_tokens", "setup_tokens", "command_tokens", "output_tokens", "completion_tokens",
            "total_tokens", "tokenizer_used",
        ])
        for size in [int(value) for value in args.sizes.split(",")]:
            corpus_dir = os.path.join(args.scratch, f"token_corpus_{size}")
            print(f"=== generating corpus size={size} ===", file=sys.stderr)
            manifest = gen_corpus(bench_dir, corpus_dir, size)
            for needle_key, relpath in manifest["needles"].items():
                basename = os.path.basename(relpath)
                levels = derive_guesses(os.path.splitext(basename)[0])
                for level, spec in levels.items():
                    prompt = f"Locate the file matching this imperfectly remembered filename: {spec['query']}"
                    prompt_tokens = count_tokens(prompt)
                    common = (corpus_dir, basename, spec, args.max_lines, args.max_bytes)
                    write_trial(writer, size, needle_key, level, run_find_policy(*common), prompt_tokens, 0, 0)
                    write_trial(writer, size, needle_key, level, run_find_grep_policy(*common), prompt_tokens, 0, 0)
                    if have_rg:
                        write_trial(writer, size, needle_key, level, run_rg_policy(*common), prompt_tokens, 0, 0)
                    fuzzy = run_fuzzy_policy(corpus_dir, args.bin, basename, spec, args.top_k, args.max_lines, args.max_bytes)
                    write_trial(writer, size, needle_key, level, fuzzy, prompt_tokens, 0, 0)
                    # A cold session pays for the skill text and cached-build command once.
                    cold = dict(fuzzy, policy="FUZZY_COLD")
                    write_trial(writer, size, needle_key, level, cold, prompt_tokens, skill_tokens, build_tokens)

    print(f"Done: {args.out} (rg baseline: {'enabled' if have_rg else 'unavailable'})", file=sys.stderr)


if __name__ == "__main__":
    main()
