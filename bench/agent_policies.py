#!/usr/bin/env python3
"""Deterministic path-search policies for the token-only benchmark.

These policies model visible tool traffic, not hidden LLM reasoning. Every
policy receives the same imperfect filename query and its output is capped as
an agent tool response would be. ``FUZZY_COLD`` includes skill instructions
and setup; ``FUZZY`` assumes those were loaded earlier in the session.
"""
import shlex
import subprocess

VOWELS = set("aeiou")


def is_subsequence(query: str, target: str) -> bool:
    it = iter(target.lower())
    return all(ch in it for ch in query.lower())


def derive_guesses(stem: str) -> dict:
    """Build four reproducible degrees of filename recall for one target."""
    words = [word for word in stem.split("_") if word] or [stem]
    joined = "".join(words)
    consonants = "".join(ch for ch in joined if ch.lower() not in VOWELS)
    fragment = consonants if len(consonants) >= 3 else joined[:4]
    second_word = words[1] if len(words) > 1 else words[0]

    levels = {
        "L0": {"label": "exact filename known", "query": stem, "fallback": stem},
        "L1": {"label": "wrong separators/casing", "query": joined, "fallback": words[0], "narrow": second_word},
        "L2": {"label": "one keyword known", "query": max(words, key=len), "fallback": max(words, key=len)},
        "L3": {"label": "abbreviation/fragment only", "query": fragment, "fallback": fragment},
    }
    for name, spec in levels.items():
        assert is_subsequence(spec["query"], stem), f"{name} query is not a subsequence of {stem!r}"
    return levels


def _truncate(output: str, max_lines: int, max_bytes: int) -> str:
    """Apply one deterministic tool-response cap to every shell baseline."""
    lines = output.splitlines(keepends=True)[:max_lines]
    capped = "".join(lines)
    if len(capped.encode("utf-8")) > max_bytes:
        capped = capped.encode("utf-8")[:max_bytes].decode("utf-8", errors="ignore")
    if capped != output:
        capped += "\n[tool output truncated]\n"
    return capped


def _run_shell(command: str, max_lines: int, max_bytes: int) -> str:
    proc = subprocess.run(command, shell=True, capture_output=True, text=True)
    return _truncate(proc.stdout, max_lines, max_bytes)


def _record(policy: str, commands: list[str], basename: str, max_lines: int, max_bytes: int) -> dict:
    outputs = []
    selected = ""
    for command in commands:
        output = _run_shell(command, max_lines, max_bytes)
        outputs.append(output)
        for line in output.splitlines():
            if basename in line:
                selected = line
                break
        if selected:
            break
    return {
        "policy": policy,
        "commands": commands[:len(outputs)],
        "outputs": outputs,
        "attempts": len(outputs),
        "found": bool(selected),
        "selected": selected,
    }


def _q(value: str) -> str:
    return shlex.quote(value)


def run_find_policy(root: str, basename: str, spec: dict, max_lines: int, max_bytes: int) -> dict:
    """Literal filename matching, with one broadening retry when meaningful."""
    root_q = _q(root)
    queries = [spec["query"]]
    if spec["fallback"] != spec["query"]:
        queries.append(spec["fallback"])
    commands = [f"find {root_q} -type f -iname {_q('*' + query + '*')}" for query in queries]
    return _record("FIND_INAME", commands, basename, max_lines, max_bytes)


def run_find_grep_policy(root: str, basename: str, spec: dict, max_lines: int, max_bytes: int) -> dict:
    """Path-list plus grep matching, with a second known-word filter for L1."""
    root_q = _q(root)
    query_q = _q(spec["query"])
    commands = [f"find {root_q} -type f | grep -i {query_q}"]
    if "narrow" in spec:
        commands.append(f"find {root_q} -type f | grep -i {_q(spec['fallback'])} | grep -i {_q(spec['narrow'])}")
    return _record("FIND_GREP", commands, basename, max_lines, max_bytes)


def run_rg_policy(root: str, basename: str, spec: dict, max_lines: int, max_bytes: int) -> dict:
    """The common ripgrep file-list pipeline, when ripgrep is installed."""
    root_q = _q(root)
    queries = [spec["query"]]
    if spec["fallback"] != spec["query"]:
        queries.append(spec["fallback"])
    commands = [f"rg --files {root_q} | rg -i {_q(query)}" for query in queries]
    return _record("RG_FILES", commands, basename, max_lines, max_bytes)


def run_fuzzy_policy(root: str, bin_path: str, basename: str, spec: dict, top_k: int, max_lines: int, max_bytes: int) -> dict:
    command = f"{_q(bin_path)} {_q(spec['query'])} {_q(root)} {top_k}"
    return _record("FUZZY", [command], basename, max_lines, max_bytes)
