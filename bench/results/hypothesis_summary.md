
Tokenizer used: tiktoken-cl100k_base


## Corpus size: 1000 files

| level | policy | mean tokens | mean attempts | success rate |
|---|---|---|---|---|
| L0 | FIND | 137 | 1.0 | 100% |
| L0 | FUZZY | 99 | 1.0 | 100% |
| L1 | FIND | 3436 | 2.0 | 100% |
| L1 | FUZZY | 99 | 1.0 | 100% |
| L2 | FIND | 4120 | 1.0 | 100% |
| L2 | FUZZY | 345 | 1.0 | 20% |
| L3 | FIND | 150 | 2.0 | 0% |
| L3 | FUZZY | 103 | 1.0 | 100% |

### Token ratio FIND/FUZZY (>1x means FUZZY is cheaper)

- L0: FIND=137 tok, FUZZY=99 tok, ratio=1.38x
- L1: FIND=3436 tok, FUZZY=99 tok, ratio=34.64x
- L2: FIND=4120 tok, FUZZY=345 tok, ratio=11.96x
- L3: FIND=150 tok, FUZZY=103 tok, ratio=1.45x

## Corpus size: 10000 files

| level | policy | mean tokens | mean attempts | success rate |
|---|---|---|---|---|
| L0 | FIND | 137 | 1.0 | 100% |
| L0 | FUZZY | 99 | 1.0 | 100% |
| L1 | FIND | 34307 | 2.0 | 100% |
| L1 | FUZZY | 99 | 1.0 | 100% |
| L2 | FIND | 34835 | 1.0 | 100% |
| L2 | FUZZY | 329 | 1.0 | 20% |
| L3 | FIND | 150 | 2.0 | 0% |
| L3 | FUZZY | 103 | 1.0 | 100% |

### Token ratio FIND/FUZZY (>1x means FUZZY is cheaper)

- L0: FIND=137 tok, FUZZY=99 tok, ratio=1.38x
- L1: FIND=34307 tok, FUZZY=99 tok, ratio=345.83x
- L2: FIND=34835 tok, FUZZY=329 tok, ratio=105.75x
- L3: FIND=150 tok, FUZZY=103 tok, ratio=1.45x

## Corpus size: 100000 files

| level | policy | mean tokens | mean attempts | success rate |
|---|---|---|---|---|
| L0 | FIND | 137 | 1.0 | 100% |
| L0 | FUZZY | 99 | 1.0 | 100% |
| L1 | FIND | 335966 | 2.0 | 100% |
| L1 | FUZZY | 99 | 1.0 | 100% |
| L2 | FIND | 317520 | 1.0 | 100% |
| L2 | FUZZY | 343 | 1.0 | 20% |
| L3 | FIND | 150 | 2.0 | 0% |
| L3 | FUZZY | 103 | 1.0 | 100% |

### Token ratio FIND/FUZZY (>1x means FUZZY is cheaper)

- L0: FIND=137 tok, FUZZY=99 tok, ratio=1.38x
- L1: FIND=335966 tok, FUZZY=99 tok, ratio=3386.76x
- L2: FIND=317520 tok, FUZZY=343 tok, ratio=925.71x
- L3: FIND=150 tok, FUZZY=103 tok, ratio=1.45x
