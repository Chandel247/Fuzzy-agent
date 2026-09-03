#!/usr/bin/env python3
"""Token-count estimator for the hypothesis-test harness.

Uses tiktoken (cl100k_base) when available for a real BPE-based count;
falls back to a chars/4 heuristic otherwise. This is a consistent relative
yardstick for comparing FIND vs FUZZY policies, not an exact count of
Claude's own tokenizer -- both policies are measured the same way, so the
comparison stays fair even though the absolute numbers are approximate.
"""
try:
    import tiktoken
    _ENC = tiktoken.get_encoding("cl100k_base")
    METHOD = "tiktoken-cl100k_base"
except ImportError:
    _ENC = None
    METHOD = "chars/4-heuristic"


def count_tokens(text: str) -> int:
    if not text:
        return 0
    if _ENC is not None:
        return len(_ENC.encode(text))
    return max(1, len(text) // 4)
