
## Corpus size: 1000 files

| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |
|---|---|---|---|---|---|---|
| find_grep | common | 93.74 | 1.79 | 90.64 | 98.98 | 10667 |
| find_naive | common | 92.08 | 1.82 | 89.47 | 97.90 | 10860 |
| fuzzy_finder | common | 106.54 | 2.64 | 103.63 | 115.18 | 9386 |
| fzf_fuzzy | common | 98.85 | 2.65 | 95.17 | 107.49 | 10117 |
| find_grep | exact | 93.97 | 1.62 | 91.24 | 98.74 | 10642 |
| find_naive | exact | 92.16 | 1.79 | 89.61 | 96.78 | 10851 |
| fuzzy_finder | exact | 107.96 | 2.83 | 104.48 | 118.47 | 9263 |
| fzf_fuzzy | exact | 97.85 | 2.64 | 94.77 | 104.67 | 10220 |
| find_grep | fuzzy_ooo | 105.84 | 26.55 | 91.91 | 246.32 | 9448 |
| find_naive | fuzzy_ooo | 92.00 | 1.91 | 89.48 | 98.03 | 10870 |
| fuzzy_finder | fuzzy_ooo | 107.97 | 2.04 | 104.77 | 112.60 | 9262 |
| fzf_fuzzy | fuzzy_ooo | 102.00 | 1.11 | 99.46 | 103.86 | 9804 |
| find_grep | no_match | 102.66 | 2.40 | 100.04 | 111.93 | 9740 |
| find_naive | no_match | 100.16 | 1.00 | 98.17 | 101.91 | 9984 |
| fuzzy_finder | no_match | 117.73 | 1.84 | 116.03 | 124.29 | 8494 |
| fzf_fuzzy | no_match | 103.18 | 2.56 | 101.11 | 115.45 | 9692 |
| find_grep | single_char | 101.86 | 3.09 | 99.23 | 113.68 | 9818 |
| find_naive | single_char | 100.06 | 1.02 | 98.15 | 102.22 | 9994 |
| fuzzy_finder | single_char | 117.72 | 2.85 | 115.87 | 130.51 | 8494 |
| fzf_fuzzy | single_char | 106.61 | 13.08 | 101.85 | 169.51 | 9380 |
| find_grep | too_long | 101.96 | 0.82 | 100.46 | 104.55 | 9807 |
| find_naive | too_long | 103.52 | 13.18 | 98.95 | 170.68 | 9660 |
| fuzzy_finder | too_long | 116.81 | 0.96 | 115.44 | 119.31 | 8561 |
| fzf_fuzzy | too_long | 106.63 | 13.97 | 101.17 | 173.58 | 9378 |

## Corpus size: 10000 files

| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |
|---|---|---|---|---|---|---|
| find_grep | common | 682.89 | 2.82 | 680.97 | 689.59 | 14644 |
| find_naive | common | 686.36 | 6.63 | 678.84 | 696.19 | 14570 |
| fuzzy_finder | common | 924.71 | 22.06 | 879.53 | 944.06 | 10814 |
| fzf_fuzzy | common | 705.21 | 3.61 | 702.22 | 712.43 | 14180 |
| find_grep | exact | 750.46 | 30.59 | 736.54 | 825.93 | 13325 |
| find_naive | exact | 750.42 | 20.69 | 730.87 | 775.60 | 13326 |
| fuzzy_finder | exact | 943.16 | 3.22 | 938.87 | 948.00 | 10603 |
| fzf_fuzzy | exact | 744.85 | 1.37 | 741.65 | 746.12 | 13426 |
| find_grep | fuzzy_ooo | 683.68 | 3.65 | 681.12 | 692.36 | 14627 |
| find_naive | fuzzy_ooo | 682.32 | 6.82 | 674.28 | 694.05 | 14656 |
| fuzzy_finder | fuzzy_ooo | 873.52 | 8.90 | 863.03 | 887.49 | 11448 |
| fzf_fuzzy | fuzzy_ooo | 698.32 | 5.81 | 688.36 | 704.84 | 14320 |
| find_grep | no_match | 685.14 | 1.37 | 683.66 | 687.25 | 14596 |
| find_naive | no_match | 682.61 | 5.74 | 677.02 | 695.05 | 14650 |
| fuzzy_finder | no_match | 889.03 | 24.31 | 861.76 | 925.85 | 11248 |
| fzf_fuzzy | no_match | 691.85 | 1.08 | 690.33 | 693.22 | 14454 |
| find_grep | single_char | 692.86 | 11.13 | 679.88 | 714.42 | 14433 |
| find_naive | single_char | 695.66 | 13.84 | 679.33 | 721.22 | 14375 |
| fuzzy_finder | single_char | 885.26 | 16.25 | 867.20 | 909.34 | 11296 |
| fzf_fuzzy | single_char | 710.26 | 11.13 | 698.03 | 728.78 | 14079 |
| find_grep | too_long | 690.90 | 5.33 | 684.28 | 699.25 | 14474 |
| find_naive | too_long | 682.99 | 6.09 | 678.82 | 695.61 | 14642 |
| fuzzy_finder | too_long | 872.15 | 5.28 | 865.83 | 879.47 | 11466 |
| fzf_fuzzy | too_long | 693.73 | 4.21 | 689.04 | 701.25 | 14415 |

## Corpus size: 100000 files

| tool | query | mean (ms) | stddev (ms) | min (ms) | max (ms) | files/sec |
|---|---|---|---|---|---|---|
| find_grep | exact | 5344.24 | 22.80 | 5322.83 | 5380.39 | 18712 |
| find_naive | exact | 5296.21 | 24.20 | 5267.63 | 5330.68 | 18881 |
| fuzzy_finder | exact | 7409.21 | 118.48 | 7305.18 | 7601.54 | 13497 |
| fzf_fuzzy | exact | 5406.67 | 10.02 | 5397.28 | 5422.58 | 18496 |
| find_grep | fuzzy_ooo | 5324.40 | 9.90 | 5311.26 | 5336.19 | 18781 |
| find_naive | fuzzy_ooo | 5324.28 | 46.88 | 5290.67 | 5405.15 | 18782 |
| fuzzy_finder | fuzzy_ooo | 7308.13 | 16.41 | 7287.48 | 7326.98 | 13683 |
| fzf_fuzzy | fuzzy_ooo | 5386.94 | 11.73 | 5368.71 | 5399.08 | 18563 |
| find_grep | no_match | 5441.40 | 70.48 | 5366.65 | 5514.20 | 18378 |
| find_naive | no_match | 5302.75 | 31.51 | 5248.48 | 5328.29 | 18858 |
| fuzzy_finder | no_match | 7303.79 | 24.98 | 7282.05 | 7344.33 | 13692 |
| fzf_fuzzy | no_match | 5388.54 | 13.00 | 5370.61 | 5401.73 | 18558 |
| find_grep | single_char | 5411.02 | 48.44 | 5335.39 | 5464.03 | 18481 |
| find_naive | single_char | 5308.18 | 32.69 | 5270.86 | 5355.48 | 18839 |
| fuzzy_finder | single_char | 7302.58 | 20.66 | 7284.08 | 7335.67 | 13694 |
| fzf_fuzzy | single_char | 5468.52 | 12.95 | 5450.65 | 5483.04 | 18286 |

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
