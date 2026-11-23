
## Corpus size: 1000 files

| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |
|---|---|---|---|---|---|---|
| find_grep | common | 61.03 | 1.20 | 59.41 | 66.38 | 16387 |
| find_naive | common | 59.01 | 1.53 | 57.51 | 67.89 | 16946 |
| fuzzy_finder | common | 39.06 | 2.12 | 37.24 | 52.45 | 25603 |
| fzf_fuzzy | common | 62.22 | 1.75 | 60.62 | 71.64 | 16072 |
| find_grep | exact | 60.36 | 1.48 | 59.19 | 68.92 | 16566 |
| find_naive | exact | 58.27 | 0.77 | 57.11 | 60.70 | 17160 |
| fuzzy_finder | exact | 38.57 | 1.33 | 37.32 | 48.27 | 25925 |
| fzf_fuzzy | exact | 60.99 | 1.42 | 59.73 | 69.14 | 16396 |
| find_grep | fuzzy_ooo | 60.54 | 1.55 | 59.16 | 69.01 | 16518 |
| find_naive | fuzzy_ooo | 59.20 | 1.03 | 57.98 | 63.70 | 16892 |
| fuzzy_finder | fuzzy_ooo | 38.45 | 0.82 | 37.12 | 41.80 | 26008 |
| fzf_fuzzy | fuzzy_ooo | 63.18 | 3.87 | 60.15 | 78.76 | 15827 |
| find_grep | no_match | 60.72 | 1.51 | 57.93 | 67.35 | 16468 |
| find_naive | no_match | 59.24 | 1.44 | 56.64 | 65.99 | 16880 |
| fuzzy_finder | no_match | 38.05 | 1.79 | 34.88 | 48.62 | 26284 |
| fzf_fuzzy | no_match | 61.02 | 0.94 | 58.68 | 63.42 | 16387 |
| find_grep | single_char | 60.48 | 0.88 | 57.94 | 63.00 | 16535 |
| find_naive | single_char | 59.50 | 2.10 | 57.16 | 67.75 | 16807 |
| fuzzy_finder | single_char | 39.87 | 2.32 | 37.06 | 52.44 | 25082 |
| fzf_fuzzy | single_char | 60.68 | 1.97 | 58.50 | 69.40 | 16479 |
| find_grep | too_long | 61.71 | 1.45 | 59.75 | 68.94 | 16206 |
| find_naive | too_long | 59.83 | 0.92 | 58.25 | 61.90 | 16716 |
| fuzzy_finder | too_long | 40.66 | 1.77 | 36.86 | 49.94 | 24597 |
| fzf_fuzzy | too_long | 61.89 | 0.89 | 60.46 | 63.99 | 16157 |

## Corpus size: 10000 files

| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |
|---|---|---|---|---|---|---|
| find_grep | common | 445.01 | 7.13 | 435.16 | 457.51 | 22471 |
| find_naive | common | 444.99 | 13.59 | 431.80 | 475.60 | 22472 |
| fuzzy_finder | common | 222.97 | 10.34 | 218.08 | 255.69 | 44849 |
| fzf_fuzzy | common | 450.69 | 9.38 | 441.10 | 465.33 | 22188 |
| find_grep | exact | 449.80 | 15.48 | 442.10 | 487.84 | 22232 |
| find_naive | exact | 448.46 | 15.37 | 439.54 | 482.15 | 22298 |
| fuzzy_finder | exact | 217.60 | 1.25 | 214.69 | 219.27 | 45956 |
| fzf_fuzzy | exact | 455.38 | 15.80 | 448.09 | 494.36 | 21960 |
| find_grep | fuzzy_ooo | 450.17 | 15.50 | 442.95 | 488.35 | 22214 |
| find_naive | fuzzy_ooo | 454.76 | 21.55 | 437.58 | 490.87 | 21990 |
| fuzzy_finder | fuzzy_ooo | 221.32 | 12.89 | 214.90 | 263.48 | 45184 |
| fzf_fuzzy | fuzzy_ooo | 450.62 | 16.79 | 439.98 | 491.78 | 22192 |
| find_grep | no_match | 450.32 | 16.71 | 439.33 | 490.14 | 22207 |
| find_naive | no_match | 435.42 | 1.35 | 433.82 | 437.96 | 22966 |
| fuzzy_finder | no_match | 224.09 | 8.49 | 219.47 | 244.59 | 44624 |
| fzf_fuzzy | no_match | 446.77 | 12.43 | 438.81 | 475.94 | 22383 |
| find_grep | single_char | 445.18 | 1.64 | 441.69 | 447.24 | 22463 |
| find_naive | single_char | 438.48 | 1.86 | 434.92 | 440.86 | 22806 |
| fuzzy_finder | single_char | 221.89 | 9.19 | 217.53 | 249.32 | 45067 |
| fzf_fuzzy | single_char | 467.79 | 16.62 | 452.32 | 496.15 | 21377 |
| find_grep | too_long | 458.54 | 17.44 | 436.36 | 478.03 | 21808 |
| find_naive | too_long | 436.18 | 4.00 | 432.17 | 445.31 | 22926 |
| fuzzy_finder | too_long | 217.98 | 1.28 | 216.22 | 219.89 | 45876 |
| fzf_fuzzy | too_long | 440.98 | 3.04 | 437.41 | 444.67 | 22677 |

## Corpus size: 100000 files

| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |
|---|---|---|---|---|---|---|
| find_grep | exact | 3450.61 | 19.84 | 3435.16 | 3483.03 | 28980 |
| find_naive | exact | 3412.36 | 29.29 | 3382.72 | 3446.51 | 29305 |
| fuzzy_finder | exact | 1730.46 | 2.00 | 1727.62 | 1732.63 | 57788 |
| fzf_fuzzy | exact | 3431.05 | 14.65 | 3411.26 | 3451.30 | 29146 |
| find_grep | fuzzy_ooo | 3445.38 | 39.07 | 3418.61 | 3514.16 | 29024 |
| find_naive | fuzzy_ooo | 3473.49 | 51.33 | 3445.32 | 3565.16 | 28790 |
| fuzzy_finder | fuzzy_ooo | 1719.85 | 9.88 | 1709.41 | 1735.93 | 58144 |
| fzf_fuzzy | fuzzy_ooo | 3377.49 | 107.84 | 3260.86 | 3497.75 | 29608 |
| find_grep | no_match | 3231.00 | 14.68 | 3212.11 | 3252.18 | 30950 |
| find_naive | no_match | 3195.86 | 16.99 | 3174.23 | 3216.56 | 31290 |
| fuzzy_finder | no_match | 1631.72 | 9.24 | 1622.11 | 1647.01 | 61285 |
| fzf_fuzzy | no_match | 3231.27 | 11.26 | 3217.07 | 3247.78 | 30948 |
| find_grep | single_char | 3243.64 | 9.82 | 3228.92 | 3253.41 | 30830 |
| find_naive | single_char | 3208.04 | 6.69 | 3202.09 | 3218.73 | 31172 |
| fuzzy_finder | single_char | 1676.91 | 35.72 | 1637.66 | 1722.33 | 59633 |
| fzf_fuzzy | single_char | 3311.83 | 20.75 | 3281.70 | 3335.11 | 30195 |

## Correctness: is the expected file actually found?

| size | tool | query | expected file | found | rank (line #) |
|---|---|---|---|---|---|
| 1000 | find_grep | exact | user_auth_service.py | true | 1 |
| 1000 | find_naive | exact | user_auth_service.py | true | 1 |
| 1000 | fuzzy_finder | exact | user_auth_service.py | true | 1 |
| 1000 | fzf_fuzzy | exact | user_auth_service.py | true | 1 |
| 1000 | find_grep | fuzzy_ooo | payment_gateway_handler.go | false | - |
| 1000 | find_naive | fuzzy_ooo | payment_gateway_handler.go | false | - |
| 1000 | fuzzy_finder | fuzzy_ooo | payment_gateway_handler.go | true | 1 |
| 1000 | fzf_fuzzy | fuzzy_ooo | payment_gateway_handler.go | true | 1 |
| 10000 | find_grep | exact | user_auth_service.py | true | 1 |
| 10000 | find_naive | exact | user_auth_service.py | true | 1 |
| 10000 | fuzzy_finder | exact | user_auth_service.py | true | 1 |
| 10000 | fzf_fuzzy | exact | user_auth_service.py | true | 1 |
| 10000 | find_grep | fuzzy_ooo | payment_gateway_handler.go | false | - |
| 10000 | find_naive | fuzzy_ooo | payment_gateway_handler.go | false | - |
| 10000 | fuzzy_finder | fuzzy_ooo | payment_gateway_handler.go | true | 1 |
| 10000 | fzf_fuzzy | fuzzy_ooo | payment_gateway_handler.go | true | 1 |
| 100000 | find_grep | exact | user_auth_service.py | true | 1 |
| 100000 | find_naive | exact | user_auth_service.py | true | 1 |
| 100000 | fuzzy_finder | exact | user_auth_service.py | true | 1 |
| 100000 | fzf_fuzzy | exact | user_auth_service.py | true | 1 |
| 100000 | find_grep | fuzzy_ooo | payment_gateway_handler.go | false | - |
| 100000 | find_naive | fuzzy_ooo | payment_gateway_handler.go | false | - |
| 100000 | fuzzy_finder | fuzzy_ooo | payment_gateway_handler.go | true | 1 |
| 100000 | fzf_fuzzy | fuzzy_ooo | payment_gateway_handler.go | true | 1 |
