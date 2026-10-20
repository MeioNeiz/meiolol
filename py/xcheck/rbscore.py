"""Scores draft-model pairs against an in-game model's win chance instead of the result.

Per-game log loss is linear in the outcome, so the paired difference d(y) = ll(y, pB) -
ll(y, pA) of two draft models has the same mean as d(q) with q = P(blue wins | state at
minute m, draft), when q is that true conditional chance. d(q) drops the outcome noise
left after minute m, so its interval is narrower; misfit in q (draft effects the state
model misses) biases it. Per pair and minute: both estimates, the paired bias d(y) - d(q)
and how many games d(q) saves for the same interval.

d(y) - d(q) = (q - y)(logit pB - logit pA) exactly, so recalibrating q on results along
that direction (q fitted with both models' logits) gives back d(y) and its noise.

q: statemodels.py preds.npz (out-of-fold per block), its `game` indexing SNAP/nn rows.
Pairs: TSV lines label, A, B (netcheck-format games-*.tsv: match_id, slot, outcome, y,
pred, block), paths relative to --root. B minus A, negative is B better.

usage: rbscore.py SNAP PREDS.npz PAIRS.tsv [--root DIR] [--model richc]
                  [--minutes 10,15,20]
"""

import argparse
import os

import numpy as np

import nnsets


def ll(t, p):
    p = np.clip(p, 1e-7, 1 - 1e-7)
    return -(t * np.log(p) + (1 - t) * np.log(1 - p))


def games_file(path):
    with open(path) as f:
        head = f.readline().rstrip("\n").split("\t")
        rows = [ln.rstrip("\n").split("\t") for ln in f if ln.strip()]
    c = {k: i for i, k in enumerate(head)}
    return {r[c["match_id"]]: (float(r[c["y"]]), float(r[c["pred"]]), r[c["block"]]) for r in rows}


def mean_ci(d):
    return d.mean(), 1.96 * d.std(ddof=1) / np.sqrt(len(d))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("preds")
    ap.add_argument("pairs")
    ap.add_argument("--root", default="~/ml/runs")
    ap.add_argument("--model", default="richc")
    ap.add_argument("--minutes", default="10,15,20")
    a = ap.parse_args()
    root = os.path.expanduser(a.root)
    minutes = [int(m) for m in a.minutes.split(",")]

    data = nnsets.load(a.snap)
    z = np.load(a.preds)
    n_blocks = 1 + max(int(k.rsplit(".", 1)[1]) for k in z.files)
    q = {m: {} for m in minutes}
    for i in range(n_blocks):
        block, game, minute, y, p = (z[f"{k}.{i}"] for k in ("block", "game", "minute", "y", a.model))
        for m in minutes:
            s = minute == m
            for b, g, yy, pp in zip(block[s], game[s], y[s], p[s]):
                q[m][data.match_id[g]] = (float(pp), float(yy), str(b))

    out = ["# Draft pairs scored against the in-game win chance", "",
           f"q = {a.model} at minute m, out of fold ({a.preds}). Milli-nats a game, B minus A, "
           "± 95%; folds = blocks 1-5 pooled. y: the usual score on the games q covers; "
           "q: scored against q; bias: d(y) - d(q) paired; x games: (ci_y / ci_q)^2; "
           "k/5: folds where y and q agree in sign", ""]
    out += ["| pair | m | games | y (all games) | y | q | bias | x games | k/5 |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    with open(a.pairs) as f:
        pairs = [ln.rstrip("\n").split("\t") for ln in f if ln.strip() and not ln.startswith("#")]
    for label, fa, fb in pairs:
        A, B = games_file(os.path.join(root, fa)), games_file(os.path.join(root, fb))
        ids = [k for k in A if k in B and A[k][2] in "12345"]
        y_all = np.array([A[k][0] for k in ids])
        d_all = ll(y_all, np.array([B[k][1] for k in ids])) - ll(y_all, np.array([A[k][1] for k in ids]))
        for m in minutes:
            ids_m = [k for k in ids if k in q[m]]
            bad_block = sum(q[m][k][2] != A[k][2] for k in ids_m)
            bad_y = sum(q[m][k][1] != A[k][0] for k in ids_m)
            if bad_block or bad_y:
                out.append(f"| {label} | {m} | refused: {bad_block} block and {bad_y} result mismatches |")
                continue
            y = np.array([A[k][0] for k in ids_m])
            qq = np.array([q[m][k][0] for k in ids_m])
            pa = np.array([A[k][1] for k in ids_m])
            pb = np.array([B[k][1] for k in ids_m])
            blocks = np.array([A[k][2] for k in ids_m])
            dy, dq = ll(y, pb) - ll(y, pa), ll(qq, pb) - ll(qq, pa)
            (my, cy), (mq, cq), (mb, cb) = mean_ci(dy), mean_ci(dq), mean_ci(dy - dq)
            ma, ca = mean_ci(d_all)
            agree = sum(np.sign(dy[blocks == b].mean()) == np.sign(dq[blocks == b].mean()) for b in "12345")
            out.append(f"| {label} | {m} | {len(ids_m)} | {1e3 * ma:+.2f} ± {1e3 * ca:.2f} | "
                       f"{1e3 * my:+.2f} ± {1e3 * cy:.2f} | {1e3 * mq:+.2f} ± {1e3 * cq:.2f} | "
                       f"{1e3 * mb:+.2f} ± {1e3 * cb:.2f} | {(cy / cq) ** 2:.1f} | {agree} |")
        print("\n".join(out[-len(minutes):]), flush=True)
    with open("report.md", "w") as f:
        f.write("\n".join(out) + "\n")
    print("\n".join(out), flush=True)


if __name__ == "__main__":
    main()
