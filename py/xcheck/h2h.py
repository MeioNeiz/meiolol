"""Same-split head-to-head of draft models from their per-game predictions (P2, A1).

    h2h.py NAME=PATH[:COLUMN] ...

PATH: netcheck's preds.tsv (fold, match_id, platform, y, cand, seed..., ens; COLUMN
cand, ens or seedN, default ens) or effects' games-MODEL.tsv (match_id, slot, outcome, y,
pred, block; its win rows). Games scored by every member, per block (dev-val, folds 1-5,
the folds pooled): log loss, accuracy, and milli-nats a game against the first member and
the one before, paired by game (se over games). Prints a markdown table.
"""

import csv
import math
import sys
from collections import defaultdict


def load(spec):
    name, _, rest = spec.partition("=")
    path, _, col = rest.partition(":")
    out = {}
    with open(path) as f:
        r = csv.DictReader(f, delimiter="\t")
        effects = "outcome" in (r.fieldnames or [])
        for row in r:
            if effects:
                if row["outcome"] != "win":
                    continue
                block, p = row["block"], float(row["pred"])
            else:
                block, p = row["fold"], float(row[col or "ens"])
            out[(block, row["match_id"])] = (int(float(row["y"])), p)
    return name, out


def ll(y, p):
    p = min(max(p, 1e-6), 1 - 1e-6)
    return -(y * math.log(p) + (1 - y) * math.log(1 - p))


def mean_se(xs):
    n = len(xs)
    m = sum(xs) / n
    v = sum((x - m) ** 2 for x in xs) / (n - 1)
    return m, math.sqrt(v / n)


def main(specs):
    members = [load(s) for s in specs]
    keys = set(members[0][1])
    for _, d in members[1:]:
        keys &= set(d)
    for _, d in members:
        for k in keys:
            assert d[k][0] == members[0][1][k][0], f"labels differ at {k}"
    by_block = defaultdict(list)
    for k in keys:
        by_block[k[0]].append(k)
    folds = [k for b in "12345" for k in by_block.get(b, [])]
    blocks = [("dev-val", by_block.get("dev", []))] + [(f"fold {b}", by_block.get(b, [])) for b in "12345"]
    blocks.append(("folds pooled", folds))
    print(f"games scored by all {len(members)}: {len(keys):,}\n")
    print("| model | block | games | log loss | accuracy | vs first, mnats | vs previous, mnats |")
    print("| --- | --- | --- | --- | --- | --- | --- |")
    for bname, ks in blocks:
        if not ks:
            continue
        losses = []
        for name, d in members:
            ls = [ll(*d[k]) for k in ks]
            acc = sum((d[k][1] > 0.5) == (d[k][0] == 1) for k in ks) / len(ks)
            cells = []
            for ref in (losses[0] if losses else None, losses[-1] if losses else None):
                if ref is None:
                    cells.append("")
                    continue
                m, se = mean_se([a - b for a, b in zip(ls, ref)])
                cells.append(f"{1000 * m:+.2f} ± {1960 * se:.2f}")
            losses.append(ls)
            print(f"| {name} | {bname} | {len(ks):,} | {sum(ls) / len(ls):.5f} | {100 * acc:.1f}% | {cells[0]} | {cells[1]} |")


if __name__ == "__main__":
    main(sys.argv[1:])
