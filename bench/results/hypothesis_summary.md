Tokenizer used: tiktoken-cl100k_base
Token totals include prompt, command, returned output, and completion. FUZZY_COLD also includes SKILL.md and cached-build setup; FUZZY is the warm-session cost.

## Corpus size: 10 paths

| recall | policy | mean tokens | mean attempts | success rate |
|---|---|---:|---:|---:|
| L0 | FIND_INAME | 217 | 1.0 | 100% |
| L0 | FIND_GREP | 217 | 1.0 | 100% |
| L0 | FUZZY | 121 | 1.0 | 100% |
| L0 | FUZZY_COLD | 2213 | 1.0 | 100% |
| L1 | FIND_INAME | 298 | 2.0 | 100% |
| L1 | FIND_GREP | 289 | 2.0 | 100% |
| L1 | FUZZY | 121 | 1.0 | 100% |
| L1 | FUZZY_COLD | 2213 | 1.0 | 100% |
| L2 | FIND_INAME | 213 | 1.0 | 100% |
| L2 | FIND_GREP | 227 | 1.0 | 100% |
| L2 | FUZZY | 130 | 1.0 | 100% |
| L2 | FUZZY_COLD | 2222 | 1.0 | 100% |
| L3 | FIND_INAME | 95 | 1.0 | 0% |
| L3 | FIND_GREP | 94 | 1.0 | 0% |
| L3 | FUZZY | 128 | 1.0 | 100% |
| L3 | FUZZY_COLD | 2220 | 1.0 | 100% |

- L0 warm fuzzy vs best successful baseline: 1.79x token ratio
- L1 warm fuzzy vs best successful baseline: 2.39x token ratio
- L2 warm fuzzy vs best successful baseline: 1.64x token ratio

## Corpus size: 100 paths

| recall | policy | mean tokens | mean attempts | success rate |
|---|---|---:|---:|---:|
| L0 | FIND_INAME | 217 | 1.0 | 100% |
| L0 | FIND_GREP | 217 | 1.0 | 100% |
| L0 | FUZZY | 121 | 1.0 | 100% |
| L0 | FUZZY_COLD | 2213 | 1.0 | 100% |
| L1 | FIND_INAME | 781 | 2.0 | 100% |
| L1 | FIND_GREP | 355 | 2.0 | 100% |
| L1 | FUZZY | 121 | 1.0 | 100% |
| L1 | FUZZY_COLD | 2213 | 1.0 | 100% |
| L2 | FIND_INAME | 557 | 1.0 | 100% |
| L2 | FIND_GREP | 764 | 1.0 | 100% |
| L2 | FUZZY | 261 | 1.0 | 100% |
| L2 | FUZZY_COLD | 2353 | 1.0 | 100% |
| L3 | FIND_INAME | 95 | 1.0 | 0% |
| L3 | FIND_GREP | 94 | 1.0 | 0% |
| L3 | FUZZY | 128 | 1.0 | 100% |
| L3 | FUZZY_COLD | 2220 | 1.0 | 100% |

- L0 warm fuzzy vs best successful baseline: 1.79x token ratio
- L1 warm fuzzy vs best successful baseline: 2.93x token ratio
- L2 warm fuzzy vs best successful baseline: 2.14x token ratio

## Corpus size: 1000 paths

| recall | policy | mean tokens | mean attempts | success rate |
|---|---|---:|---:|---:|
| L0 | FIND_INAME | 220 | 1.0 | 100% |
| L0 | FIND_GREP | 220 | 1.0 | 100% |
| L0 | FUZZY | 122 | 1.0 | 100% |
| L0 | FUZZY_COLD | 2214 | 1.0 | 100% |
| L1 | FIND_INAME | 3407 | 2.0 | 100% |
| L1 | FIND_GREP | 991 | 2.0 | 100% |
| L1 | FUZZY | 122 | 1.0 | 100% |
| L1 | FUZZY_COLD | 2214 | 1.0 | 100% |
| L2 | FIND_INAME | 2712 | 1.0 | 100% |
| L2 | FIND_GREP | 3565 | 1.0 | 100% |
| L2 | FUZZY | 275 | 1.0 | 40% |
| L2 | FUZZY_COLD | 2367 | 1.0 | 40% |
| L3 | FIND_INAME | 96 | 1.0 | 0% |
| L3 | FIND_GREP | 95 | 1.0 | 0% |
| L3 | FUZZY | 140 | 1.0 | 100% |
| L3 | FUZZY_COLD | 2232 | 1.0 | 100% |

- L0 warm fuzzy vs best successful baseline: 1.80x token ratio
- L1 warm fuzzy vs best successful baseline: 8.11x token ratio

## Corpus size: 10000 paths

| recall | policy | mean tokens | mean attempts | success rate |
|---|---|---:|---:|---:|
| L0 | FIND_INAME | 220 | 1.0 | 100% |
| L0 | FIND_GREP | 220 | 1.0 | 100% |
| L0 | FUZZY | 122 | 1.0 | 100% |
| L0 | FUZZY_COLD | 2214 | 1.0 | 100% |
| L1 | FIND_INAME | 3776 | 2.0 | 20% |
| L1 | FIND_GREP | 1816 | 2.0 | 80% |
| L1 | FUZZY | 122 | 1.0 | 100% |
| L1 | FUZZY_COLD | 2214 | 1.0 | 100% |
| L2 | FIND_INAME | 2783 | 1.0 | 40% |
| L2 | FIND_GREP | 3614 | 1.0 | 20% |
| L2 | FUZZY | 285 | 1.0 | 40% |
| L2 | FUZZY_COLD | 2377 | 1.0 | 40% |
| L3 | FIND_INAME | 96 | 1.0 | 0% |
| L3 | FIND_GREP | 95 | 1.0 | 0% |
| L3 | FUZZY | 176 | 1.0 | 100% |
| L3 | FUZZY_COLD | 2268 | 1.0 | 100% |

- L0 warm fuzzy vs best successful baseline: 1.80x token ratio

## Corpus size: 100000 paths

| recall | policy | mean tokens | mean attempts | success rate |
|---|---|---:|---:|---:|
| L0 | FIND_INAME | 220 | 1.0 | 100% |
| L0 | FIND_GREP | 220 | 1.0 | 100% |
| L0 | FUZZY | 122 | 1.0 | 100% |
| L0 | FUZZY_COLD | 2214 | 1.0 | 100% |
| L1 | FIND_INAME | 3736 | 2.0 | 20% |
| L1 | FIND_GREP | 2907 | 2.0 | 40% |
| L1 | FUZZY | 122 | 1.0 | 100% |
| L1 | FUZZY_COLD | 2214 | 1.0 | 100% |
| L2 | FIND_INAME | 2767 | 1.0 | 40% |
| L2 | FIND_GREP | 3590 | 1.0 | 20% |
| L2 | FUZZY | 278 | 1.0 | 40% |
| L2 | FUZZY_COLD | 2370 | 1.0 | 40% |
| L3 | FIND_INAME | 96 | 1.0 | 0% |
| L3 | FIND_GREP | 95 | 1.0 | 0% |
| L3 | FUZZY | 178 | 1.0 | 100% |
| L3 | FUZZY_COLD | 2270 | 1.0 | 100% |

- L0 warm fuzzy vs best successful baseline: 1.80x token ratio

