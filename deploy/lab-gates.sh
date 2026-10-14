#!/usr/bin/env bash
# Cheap checks on a finished lab-run run's predictions (deploy/lab-run.sh copies this into
# the run dir and job.sh runs it there after the program exits): in every preds*.tsv,
# dev.tsv and test.tsv down to two levels, each prediction column must have no NaN or
# inf and must not be constant. Prints `GATE ok|FAIL FILE ...` lines for the log; FAIL
# lines also go to `gates`, which `lab-run.sh wait` shows, with the program's GATE FAIL
# lines from the log. Seconds on 100k rows: well under 1% of a run
set -u
find . -maxdepth 3 \( -name 'preds*.tsv' -o -name dev.tsv -o -name test.tsv \) -type f \
    | LC_ALL=C sort | while IFS= read -r f; do
    awk -F '\t' -v file="${f#./}" '
        # Ids, labels and fold names: not predictions
        BEGIN { split("match_id platform y fold block slot outcome split game side", s, " ")
            for (i in s) skip[s[i]] = 1 }
        NR == 1 { for (i = 1; i <= NF; i++) if (!($i in skip)) { col[i] = $i; n_col++ }; next }
        {
            rows++
            for (i in col) {
                v = $i
                if (v ~ /^[-+]?(nan|NaN|inf|Inf|INF)/) { bad[i]++; continue }
                v += 0
                if (!(i in lo) || v < lo[i]) lo[i] = v
                if (!(i in hi) || v > hi[i]) hi[i] = v
            }
        }
        END {
            fail = 0
            for (i in col) {
                if (bad[i]) {
                    printf "GATE FAIL %s %s: %d of %d rows NaN or inf\n", file, col[i], bad[i], rows
                    fail = 1
                } else if (rows > 1 && lo[i] == hi[i]) {
                    printf "GATE FAIL %s %s: constant %g over %d rows\n", file, col[i], lo[i], rows
                    fail = 1
                }
            }
            if (!fail) printf "GATE ok %s: %d rows, %d prediction columns\n", file, rows, n_col
        }' "$f"
done > gates.all
cat gates.all
# With the program's own (src/lab/gates.zig: a fresh net's loss far from the base rate's)
{ grep -a '^GATE FAIL' log 2> /dev/null; grep '^GATE FAIL' gates.all; } > gates
rm -f gates.all
true
