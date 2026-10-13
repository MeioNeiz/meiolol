"""Per game-minute win chance from the live state models, for other sessions (eventvalue).

Writes SNAP/state/preds-wcd.tsv: match_id, minute, block, p_wc, p_wcd, p_rich (blue
wins). Blocks: "cf", every dev-visible game with a timeline scored by a 5-fold
cross-fit by game (draft logit cross-fitted the same way); "dev" and "1".."5", the
protocol blocks (fit on the block's fit games, as statemodels.py). Minutes 1..40 while
going. Models as statemodels.py.

usage: statepreds.py SNAP [--blocks cf,dev,1,2,3,4,5]
"""

import argparse
import os

import numpy as np

import nnsets
import statecommon as sc
from statemodels import MINUTES, Smooth, log

K = 5


def fit_three(Xf, names, mf, yf, Xs, ms):
    idx = {n: i for i, n in enumerate(names)}
    wc = [idx[f"obj_{f}"] for f in sc.WC]
    cols = {"wc": wc, "wcd": wc + [idx["draft"]], "rich": list(range(len(names)))}
    return {k: Smooth().fit(Xf[:, c], mf, yf).predict(Xs[:, c], ms) for k, c in cols.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--blocks", default="cf,dev,1,2,3,4,5")
    a = ap.parse_args()
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    played = (data.flags & nnsets.PLAYED) != 0
    path = os.path.join(os.path.expanduser(a.snap), "state", "preds-wcd.tsv")
    with open(path + ".tmp", "w") as f:
        f.write("match_id\tminute\tblock\tp_wc\tp_wcd\tp_rich\n")
        for block in a.blocks.split(","):
            if block == "cf":
                games = np.flatnonzero(played & has_tl & (data.split <= 6))
                cut = nnsets.val_cut(data.start[games])
                fake = nnsets.Sets("cf", games, games[data.start[games] < cut], games[data.start[games] >= cut], np.array([], np.int64))
                logit, l2, _ = sc.draft_logits(data, fake)
                X, names, g, m = sc.rows_for(state, games, MINUTES, logit)
                y = data.y[g]
                part = np.random.default_rng(11).integers(0, K, data.n)[g]
                out = {k: np.zeros(len(y)) for k in ("wc", "wcd", "rich")}
                for j in range(K):
                    tr, te = part != j, part == j
                    for k, p in fit_three(X[tr], names, m[tr], y[tr], X[te], m[te]).items():
                        out[k][te] = p
            else:
                sets = nnsets.sets(data, block)
                logit, l2, _ = sc.draft_logits(data, sets)
                Xf, names, gf, mf = sc.rows_for(state, sets.fit[has_tl[sets.fit]], MINUTES, logit)
                X, _, g, m = sc.rows_for(state, sets.scored[has_tl[sets.scored]], MINUTES, logit)
                y = data.y[g]
                out = fit_three(Xf, names, mf, data.y[gf], X, m)
            log(f"block {block}: {len(np.unique(g))} games, {len(y)} rows; log loss " + ", ".join(f"{k} {sc.ll(y, p).mean():.5f}" for k, p in out.items()))
            for i in range(len(y)):
                f.write(f"{data.match_id[g[i]]}\t{m[i]}\t{block}\t{out['wc'][i]:.6f}\t{out['wcd'][i]:.6f}\t{out['rich'][i]:.6f}\n")
    os.replace(path + ".tmp", path)
    log(f"wrote {path}")


if __name__ == "__main__":
    main()
