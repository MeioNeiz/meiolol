"""Q1 robustness: does the draft still add as much beside a flexible state model?

Per block and minute: LightGBM on the full state (every state-export minute column,
seats as blue-minus-red by role, team columns as blue minus red), early stopping on the
block's val; its logit cross-fitted (K-fold inside the fit games, the block's model for
scored games) is the offset for a logistic draft layer (platform + signed
champion-roles, L2 on inner val). Compared with info.py's linear state on the same
games: linear S, GBDT S, GBDT S + draft, linear S + draft.

usage: infogbdt.py SNAP [--minutes 10,15,25] [--procs 3] [--threads 6] [--out .]
"""

import argparse
import os
import time
from concurrent.futures import ProcessPoolExecutor

import lightgbm as lgb
import numpy as np
import scipy.sparse as sp

import dp
import info

K = 5
PARAMS = dict(objective="binary", learning_rate=0.05, num_leaves=31, min_data_in_leaf=200, feature_fraction=0.8, bagging_fraction=0.8, bagging_freq=1, lambda_l2=1.0, verbose=-1)


def full_state(st, minute):
    cols = st.meta["minute_columns"]
    blk = st.block(minute).astype(np.float64)
    feats, names = [], []
    seat_stats = sorted({c.split("_", 1)[1] for c in cols if c[0] == "s" and c[1].isdigit()})
    for stat in seat_stats:
        for r, role in enumerate(dp.ROLES):
            feats.append(blk[:, cols.index(f"s{r}_{stat}")] - blk[:, cols.index(f"s{5 + r}_{stat}")])
            names.append(f"{stat}_{role}")
    for c in cols:
        if c.startswith("obj_"):
            feats.append(blk[:, cols.index(c)])
            names.append(c)
        elif c.startswith("b_"):
            feats.append(blk[:, cols.index(c)] - blk[:, cols.index("r_" + c[2:])])
            names.append(c[2:])
    return np.stack(feats, 1), names


def gbdt(Xtr, ytr, Xva, yva, threads):
    p = dict(PARAMS, num_threads=threads)
    dtr, dva = lgb.Dataset(Xtr, ytr), lgb.Dataset(Xva, yva)
    return lgb.train(p, dtr, 3000, valid_sets=[dva], callbacks=[lgb.early_stopping(100, verbose=False)])


def run_block(args):
    snap, block, minutes, threads = args
    t0 = time.time()
    nn = dp.load_nn(snap)
    st = dp.load_state(snap, nn)
    s = dp.sets(nn, block)
    y = nn.y
    rng = np.random.default_rng(23)
    out = {"block": block, "minutes": {}}
    for t in minutes:
        Fl, _, going = info.state_feats(st, t)
        Ff, names = full_state(st, t)
        g = lambda a: a[going[a]]
        fit, inner, val, sc = g(s.fit), g(s.inner), g(s.val), g(s.scored)
        res = {"games": sc}
        mu = y[fit].mean()
        res["base"] = dp.logloss(y[sc], np.full(len(sc), np.log(mu / (1 - mu))))
        # linear state and linear state + draft, as info.py
        mS = info.fit_logit(sp.csr_matrix(Fl[fit]), y[fit], 0, Fl.shape[1], nn)
        res["S_lin"] = dp.logloss(y[sc], info.z_of(mS, sp.csr_matrix(Fl[sc])))
        l2 = info.pick(nn, Fl, inner, val, Fl.shape[1], {})
        mDS = info.fit_logit(info.stack(Fl[fit], dp.design(nn, fit)), y[fit], l2, Fl.shape[1], nn)
        res["DS_lin"] = dp.logloss(y[sc], info.z_of(mDS, info.stack(Fl[sc], dp.design(nn, sc))))
        # GBDT state: rounds from inner -> val, then K-fold inside fit for offsets
        b = gbdt(Ff[inner], y[inner], Ff[val], y[val], threads)
        rounds = b.best_iteration
        p = dict(PARAMS, num_threads=threads)
        full = lgb.train(p, lgb.Dataset(Ff[fit], y[fit]), rounds)
        off = np.zeros(nn.n)
        off[sc] = full.predict(Ff[sc], raw_score=True)
        fold = rng.integers(0, K, len(fit))
        for k in range(K):
            m = lgb.train(p, lgb.Dataset(Ff[fit[fold != k]], y[fit[fold != k]]), rounds)
            off[fit[fold == k]] = m.predict(Ff[fit[fold == k]], raw_score=True)
        res["S_gbdt"] = dp.logloss(y[sc], off[sc])
        res["rounds"] = rounds
        # draft layer on the GBDT offset; L2 picked on inner -> val with the same offsets
        best, bl = None, np.inf
        for l2d in info.GRID:
            m = dp.logistic(dp.design(nn, inner), y[inner], dp.penalty(nn, l2d), off[inner])
            l = dp.logloss(y[val], m[0] + dp.design(nn, val) @ m[1] + off[val]).mean()
            if l < bl:
                best, bl = l2d, l
        m = dp.logistic(dp.design(nn, fit), y[fit], dp.penalty(nn, best), off[fit])
        res["DS_gbdt"] = dp.logloss(y[sc], m[0] + dp.design(nn, sc) @ m[1] + off[sc])
        res["l2"] = best
        imp = full.feature_importance("gain")
        res["top"] = [names[i] for i in np.argsort(-imp)[:12]]
        out["minutes"][t] = res
        print(f"block {block} minute {t}: {rounds} rounds, {time.time() - t0:.0f} s", flush=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--minutes", default="10,15,25")
    ap.add_argument("--procs", type=int, default=3)
    ap.add_argument("--threads", type=int, default=6)
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    minutes = [int(m) for m in a.minutes.split(",")]
    with ProcessPoolExecutor(a.procs) as ex:
        outs = list(ex.map(run_block, [(a.snap, b, minutes, a.threads) for b in dp.BLOCKS]))
    by = {o["block"]: o for o in outs}
    np.save(os.path.join(a.out, "infogbdt-raw.npy"), by, allow_pickle=True)
    comps = [("linear state vs base", "S_lin", "base"), ("GBDT state vs base", "S_gbdt", "base"), ("GBDT state vs linear state", "S_gbdt", "S_lin"), ("draft given linear state", "DS_lin", "S_lin"), ("draft given GBDT state", "DS_gbdt", "S_gbdt"), ("GBDT state + draft vs linear state + draft", "DS_gbdt", "DS_lin")]
    with open(os.path.join(a.out, "infogbdt.tsv"), "w") as f:
        f.write("minute\tcomparison\tblock\tdiff\tci\tgames\tfolds_better\n")
        for t in minutes:
            for label, x, ref in comps:
                for name, blocks in (("folds", dp.FOLDS), ("dev", ["dev"])):
                    d = np.concatenate([by[b]["minutes"][t][x] - by[b]["minutes"][t][ref] for b in blocks])
                    m, h, n = dp.paired(d)
                    k = sum(np.mean(by[b]["minutes"][t][x] - by[b]["minutes"][t][ref]) < 0 for b in blocks)
                    f.write(f"{t}\t{label}\t{name}\t{m:.6f}\t{h:.6f}\t{n}\t{k}/{len(blocks)}\n")
                    print(f"{t:>2} {label:<44} {name:<5} {dp.fmt(m, h)} ({k}/{len(blocks)}) n {n}")
            print(f"{t} top GBDT features (dev): {by['dev']['minutes'][t]['top']}")


if __name__ == "__main__":
    main()
