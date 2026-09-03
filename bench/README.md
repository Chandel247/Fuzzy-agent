# Token Benchmark

`run_hypothesis.sh` measures visible token traffic for filename/path discovery,
not wall-clock performance. It generates corpora of 10, 100, 1,000, 10,000,
and 100,000 paths, then uses the same imperfect filename recall task against:

- `find -type f -iname` (`FIND_INAME`)
- `find -type f | grep -i` (`FIND_GREP`)
- `rg --files | rg -i` (`RG_FILES`, only when `rg` is installed)
- the fuzzy-finder skill (`FUZZY` warm session and `FUZZY_COLD` fresh session)

All shell output is capped to 200 lines / 12,000 bytes before tokenization, so
each policy faces the same simulated agent tool-response limit. Results include
prompt, command, returned-output, and deterministic completion tokens. Cold
fuzzy trials additionally include `SKILL.md` and the cached-build command.

Run the benchmark and report:

```bash
bench/run_hypothesis.sh
bench/.venv/bin/python3 bench/report_tokens.py
```

This is a deterministic policy benchmark, not a live-agent evaluation. Native
`Glob` cannot be invoked from this shell harness and should be measured from a
tool-runtime transcript separately. Do not compare runtime or files/second
across machines with this benchmark.
