#!/usr/bin/env python3
"""Live-agent verification harness: a real local LLM (via Ollama) decides its
own tool calls to locate a needle file, instead of the scripted policies in
agent_policies.py. Reports real token counts straight from Ollama's response
(`prompt_eval_count` / `eval_count`), not an estimate.

Two conditions, one sandboxed `run_shell` tool + a `submit_answer` tool:
  BASH  - system prompt only mentions find/grep/ls/wc/head/cat.
  FUZZY - system prompt additionally describes the fuzzy_finder binary.

Safety: run_shell rejects path traversal, command substitution/chaining
beyond pipes, and redirection; each pipe segment's binary must be on an
allowlist. This still executes model-authored shell commands, so it is not
a full jail -- acceptable for a local, user-run experiment against synthetic
corpora, matching the plan's stated protections.
"""
import argparse
import csv
import json
import os
import shlex
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from agent_policies import derive_guesses
from run_hypothesis import gen_corpus

OLLAMA_URL = "http://localhost:11434/api/chat"
BASE_ALLOWED = {"find", "grep", "ls", "wc", "head", "cat"}
FORBIDDEN_SUBSTRINGS = ["..", "`", "$(", ";", "&&", "||", ">>", ">"]

BASH_SYSTEM = """You are a coding assistant searching a directory tree for one specific file.

You have two tools:
- run_shell(command): runs a read-only shell command (find, grep, ls, wc, head, cat) rooted at the target directory. Pipes are allowed; redirection (including `2>/dev/null`) and command chaining are not supported and will be rejected -- stderr is already hidden from you automatically, so don't bother redirecting it.
- submit_answer(path): reports the relative path of the file you believe matches the query. Call this exactly once, when you are done.

As soon as any tool result contains a file that plausibly matches the query, call submit_answer with it immediately. Do not re-verify a match you already have with more searches -- that only wastes your turn budget for no benefit.

Keep any reasoning brief (a sentence or two) before acting -- long deliberation is wasted here, just act on the first plausible match.

You have at most {max_turns} tool calls before you must submit your best guess."""

FUZZY_SYSTEM = BASH_SYSTEM + """

A fuzzy-search tool is also available: run it via run_shell as
`{fuzzy_bin} "<query>" "{corpus_dir}" 15`
It ranks path names against your query using subsequence fuzzy matching -- it
tolerates missing separators, wrong casing, and dropped letters (like fzf).
It prints up to 15 best matches as "<score>\\t<relative_path>" lines, best
first. Prefer it when your query is not a literal substring of the filename."""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "run_shell",
            "description": "Run a read-only shell command to search for files.",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string", "description": "The shell command to run."}},
                "required": ["command"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "submit_answer",
            "description": "Submit the relative path of the file you found. Call exactly once.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string", "description": "Relative path to the matched file."}},
                "required": ["path"],
            },
        },
    },
]

SUBMIT_ONLY_TOOLS = [t for t in TOOLS if t["function"]["name"] == "submit_answer"]


def is_safe_command(command: str, allowed_binaries: set) -> bool:
    for token in FORBIDDEN_SUBSTRINGS:
        if token in command:
            return False
    for segment in command.split("|"):
        segment = segment.strip()
        if not segment:
            return False
        try:
            parts = shlex.split(segment)
        except ValueError:
            return False
        if not parts:
            return False
        if os.path.basename(parts[0]) not in allowed_binaries:
            return False
    return True


def execute_run_shell(command: str, cwd: str, allowed_binaries: set, extra_path_dir: str = None,
                       max_bytes: int = 8000, timeout: int = 15) -> str:
    if not is_safe_command(command, allowed_binaries):
        allowed = ", ".join(sorted(allowed_binaries))
        return f"ERROR: command rejected by sandbox. Only these binaries are allowed: {allowed}. No redirection, `;`, `&&`, `||`, backticks, `$()`, or `..` path traversal -- pipes only."
    env = None
    if extra_path_dir:
        env = dict(os.environ)
        env["PATH"] = extra_path_dir + os.pathsep + env.get("PATH", "")
    try:
        proc = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        return "ERROR: command timed out after 15s"
    output = proc.stdout
    if proc.returncode != 0 and proc.stderr:
        output += f"\n[stderr]: {proc.stderr[:500]}"
    encoded = output.encode("utf-8")
    if len(encoded) > max_bytes:
        output = encoded[:max_bytes].decode("utf-8", errors="ignore") + "\n[...output truncated]"
    return output


def ollama_chat(model: str, messages: list, tools: list, timeout: int = 300, num_predict: int = 1024) -> dict:
    payload = json.dumps({
        "model": model,
        "messages": messages,
        "tools": tools,
        "stream": False,
        "options": {"num_predict": num_predict},
    }).encode("utf-8")
    req = urllib.request.Request(OLLAMA_URL, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def check_claim(claimed_path: str, corpus_dir: str, expected_basename: str) -> bool:
    if not claimed_path:
        return False
    path = claimed_path.strip()
    if os.path.isabs(path) and path.startswith(corpus_dir):
        path = os.path.relpath(path, corpus_dir)
    path = path.lstrip("./")
    return os.path.basename(path) == expected_basename


def run_trial(model: str, condition: str, corpus_dir: str, needle_key: str, expected_basename: str,
              level: str, spec: dict, fuzzy_bin: str, max_turns: int = 8) -> dict:
    allowed = set(BASE_ALLOWED)
    if condition == "FUZZY":
        allowed.add(os.path.basename(fuzzy_bin))
        system_prompt = FUZZY_SYSTEM.format(max_turns=max_turns, fuzzy_bin=fuzzy_bin, corpus_dir=corpus_dir)
    else:
        system_prompt = BASH_SYSTEM.format(max_turns=max_turns)

    user_prompt = (
        f"Find the file matching this imperfectly remembered filename: \"{spec['query']}\"\n"
        f"Search inside this directory: {corpus_dir}"
    )
    messages = [{"role": "system", "content": system_prompt}, {"role": "user", "content": user_prompt}]

    prompt_tokens = 0
    eval_tokens = 0
    claimed_path = None
    turns_used = 0
    error = None
    start = time.time()

    fuzzy_dir = os.path.dirname(fuzzy_bin) if condition == "FUZZY" else None

    for turn_idx in range(max_turns):
        is_last_turn = turn_idx == max_turns - 1
        turn_tools = SUBMIT_ONLY_TOOLS if is_last_turn else TOOLS
        if is_last_turn:
            messages.append({
                "role": "user",
                "content": "This is your last turn. You must call submit_answer now with your best guess.",
            })
        try:
            resp = ollama_chat(model, messages, turn_tools)
        except (urllib.error.URLError, TimeoutError) as exc:
            error = f"ollama request failed: {exc}"
            break
        prompt_tokens += resp.get("prompt_eval_count", 0)
        eval_tokens += resp.get("eval_count", 0)
        msg = resp.get("message", {})
        messages.append(msg)
        turns_used += 1

        tool_calls = msg.get("tool_calls") or []
        if not tool_calls:
            break

        done = False
        for call in tool_calls:
            fn_name = call.get("function", {}).get("name")
            raw_args = call.get("function", {}).get("arguments", {})
            if isinstance(raw_args, str):
                try:
                    raw_args = json.loads(raw_args)
                except json.JSONDecodeError:
                    raw_args = {}
            if fn_name == "submit_answer":
                claimed_path = raw_args.get("path", "")
                messages.append({"role": "tool", "content": "Answer recorded."})
                done = True
            elif fn_name == "run_shell":
                out = execute_run_shell(raw_args.get("command", ""), corpus_dir, allowed, extra_path_dir=fuzzy_dir)
                messages.append({"role": "tool", "content": out})
            else:
                messages.append({"role": "tool", "content": f"ERROR: unknown tool {fn_name}"})
        if done:
            break

    elapsed = time.time() - start
    found = check_claim(claimed_path, corpus_dir, expected_basename)

    return {
        "model": model,
        "condition": condition,
        "needle_key": needle_key,
        "level": level,
        "turns": turns_used,
        "claimed_path": claimed_path,
        "found": found,
        "prompt_tokens": prompt_tokens,
        "eval_tokens": eval_tokens,
        "total_tokens": prompt_tokens + eval_tokens,
        "elapsed_s": round(elapsed, 2),
        "error": error,
        "messages": messages,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", required=True, help="path to built fuzzy_finder")
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--transcripts-dir", default=None)
    ap.add_argument("--model", default="qwen3.5:9b")
    ap.add_argument("--sizes", default="10,1000")
    ap.add_argument("--needles", default="shallow", help='comma list or "all"')
    ap.add_argument("--levels", default="L0,L1,L2,L3")
    ap.add_argument("--conditions", default="BASH,FUZZY")
    ap.add_argument("--max-turns", type=int, default=8)
    args = ap.parse_args()

    bench_dir = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(args.scratch, exist_ok=True)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    if args.transcripts_dir:
        os.makedirs(args.transcripts_dir, exist_ok=True)

    levels_wanted = args.levels.split(",")
    conditions_wanted = args.conditions.split(",")

    with open(args.out, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "size", "needle_key", "level", "condition", "model", "turns", "found",
            "claimed_path", "prompt_tokens", "eval_tokens", "total_tokens", "elapsed_s", "error",
        ])

        for size in [int(s) for s in args.sizes.split(",")]:
            corpus_dir = os.path.join(args.scratch, f"live_corpus_{size}")
            print(f"=== generating corpus size={size} ===", file=sys.stderr)
            manifest = gen_corpus(bench_dir, corpus_dir, size)

            wanted_needles = list(manifest["needles"].keys()) if args.needles == "all" else args.needles.split(",")
            for needle_key in wanted_needles:
                relpath = manifest["needles"][needle_key]
                basename = os.path.basename(relpath)
                stem = os.path.splitext(basename)[0]
                levels = derive_guesses(stem)

                for level_name in levels_wanted:
                    spec = levels[level_name]
                    for condition in conditions_wanted:
                        print(f"--- size={size} needle={needle_key} level={level_name} condition={condition} ---", file=sys.stderr)
                        trial = run_trial(args.model, condition, corpus_dir, needle_key, basename,
                                           level_name, spec, args.bin, args.max_turns)
                        writer.writerow([
                            size, needle_key, level_name, condition, trial["model"], trial["turns"],
                            trial["found"], trial["claimed_path"], trial["prompt_tokens"],
                            trial["eval_tokens"], trial["total_tokens"], trial["elapsed_s"], trial["error"] or "",
                        ])
                        f.flush()
                        if args.transcripts_dir:
                            tpath = os.path.join(
                                args.transcripts_dir,
                                f"{size}_{needle_key}_{level_name}_{condition}.json",
                            )
                            with open(tpath, "w") as tf:
                                json.dump(trial, tf, indent=2)

    print(f"Done: {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
