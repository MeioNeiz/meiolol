"""Q1, information over time: what the draft adds once the game state is known.

Per block and minute t (0, 5, ..., 30), on games still going at t (state-export's rule),
logistic models of blue winning:
- base: intercept; D: draft (platform + signed champion-role); S: state at t (gold lead
  per role, gold curve, XP lead, kills, objectives held; blue minus red); DS: both
- DS minus role r's champions (what that role's pick adds at equal state)
- S + beta x draft logit, the draft logit cross-fitted from D at minute 0 (K-fold inside
  the fit games, the block's D for scored games): beta 1 = the draft's whole minute-0
  edge still applies at equal state, 0 = absorbed into the state
D and DS refit on the games still going at t (the draft's edge given the game lasted).
L2 on the draft columns from inner val per block and minute. Per-game log loss pairs,
pooled over the 5 folds (better in k of 5) and dev-val apart.

usage: info.py SNAP [--minutes 0,5,...,30] [--procs 6] [--out .]
"""

import argparse
import os
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import scipy.sparse as sp

import dp

GRID = [10, 30, 100, 300, 1000, 3000, 10000]
K_CROSS = 5
OBJ = ["gold_curve", "xp", "towers", "inhibs_down", "dragons", "soul_point", "soul", "elder", "grubs", "herald", "baron"]


def state_feats(st, minute):
    """[n, F] blue-minus-red state at minute (NaN rows when not going), names"""
    cols = st.meta["minute_columns"]
    blk = st.block(minute)
    c = lambda name: blk[:, cols.index(name)].astype(np.float64)
    feats, names = [], []
    for r, role in enumerate(dp.ROLES):
        feats.append((c(f"s{r}_gold") - c(f"s{5 + r}_gold")) / 1000)
        names.append(f"gold_{role}")
    for o in OBJ:
        feats.append(c(f"obj_{o}"))
        names.append(o)
    feats.append((c("b_kills") - c("r_kills")) / 10)
    names.append("kills")
    going = c("going") == 1
    return np.stack(feats, 1), names, going


def fit_logit(X, y, l2_draft, n_state, nn, offset=None):
    """X = [state | draft design]; draft columns penalised by l2_draft"""
    pen = np.concatenate([np.full(n_state, 1.0), dp.penalty(nn, l2_draft)]) if X.shape[1] > n_state else np.full(n_state, 1.0)
    return dp.logistic(X, y, pen, offset)


def stack(S, D):
    if S is None:
        return D
    if D is None:
        return sp.csr_matrix(S)
    return sp.hstack([sp.csr_matrix(S), D]).tocsr()


def z_of(m, X, offset=None):
    return m[0] + X @ m[1] + (0 if offset is None else offset)


def cross_draft(nn, fit, l2, rng):
    """minute-0 draft logit for fit games, K-fold within fit"""
    out = np.zeros(nn.n)
    fold = rng.integers(0, K_CROSS, len(fit))
    for k in range(K_CROSS):
        tr, te = fit[fold != k], fit[fold == k]
        m = dp.logistic(dp.design(nn, tr), nn.y[tr], dp.penalty(nn, l2))
        out[te] = z_of(m, dp.design(nn, te))
    return out


def pick(nn, S_all, inner, val, n_state, draft_kw):
    y = nn.y
    best, best_l = None, np.inf
    for l2 in GRID:
        Xi = stack(None if S_all is None else S_all[inner], dp.design(nn, inner, **draft_kw))
        Xv = stack(None if S_all is None else S_all[val], dp.design(nn, val, **draft_kw))
        m = fit_logit(Xi, y[inner], l2, n_state, nn)
        l = dp.logloss(y[val], z_of(m, Xv)).mean()
        if l < best_l:
            best, best_l = l2, l
    return best


def run_block(args):
    snap, block, minutes = args
    t0 = time.time()
    nn = dp.load_nn(snap)
    st = dp.load_state(snap, nn)
    rng = np.random.default_rng(7)
    s = dp.sets(nn, block)
    y = nn.y
    # minute-0 draft model and cross-fitted logits
    l2_0 = pick(nn, None, s.inner, s.val, 0, {})
    m0 = dp.logistic(dp.design(nn, s.fit), y[s.fit], dp.penalty(nn, l2_0))
    draft_z = cross_draft(nn, s.fit, l2_0, rng)
    draft_z[s.scored] = z_of(m0, dp.design(nn, s.scored))
    out = {"block": block, "scored": s.scored, "minutes": {}}
    for t in minutes:
        F, names, going = state_feats(st, t)
        if t == 0:
            F, names = np.zeros((nn.n, 0)), []
        ns = F.shape[1]
        g = lambda a: a[going[a]]
        fit, inner, val, scored = g(s.fit), g(s.inner), g(s.val), g(s.scored)
        res = {"games": scored, "names": names}
        mu = y[fit].mean()
        res["base"] = dp.logloss(y[scored], np.full(len(scored), np.log(mu / (1 - mu))))
        l2_d = pick(nn, None, inner, val, 0, {})
        mD = fit_logit(dp.design(nn, fit), y[fit], l2_d, 0, nn)
        res["D"] = dp.logloss(y[scored], z_of(mD, dp.design(nn, scored)))
        res["l2_D"] = l2_d
        if ns:
            mS = fit_logit(sp.csr_matrix(F[fit]), y[fit], 0, ns, nn)
            res["S"] = dp.logloss(y[scored], z_of(mS, sp.csr_matrix(F[scored])))
            res["S_coef"] = mS[1]
            l2_ds = pick(nn, F, inner, val, ns, {})
            res["l2_DS"] = l2_ds
            mDS = fit_logit(stack(F[fit], dp.design(nn, fit)), y[fit], l2_ds, ns, nn)
            res["DS"] = dp.logloss(y[scored], z_of(mDS, stack(F[scored], dp.design(nn, scored))))
            res["DS_coef"] = mDS[1]
            for r, role in enumerate(dp.ROLES):
                m = fit_logit(stack(F[fit], dp.design(nn, fit, drop_role=r)), y[fit], l2_ds, ns, nn)
                res[f"DS-{role}"] = dp.logloss(y[scored], z_of(m, stack(F[scored], dp.design(nn, scored, drop_role=r))))
            # S + beta x minute-0 draft logit
            Xb = np.column_stack([F, draft_z])
            mB = dp.logistic(Xb[fit], y[fit], np.full(ns + 1, 1.0))
            res["SB"] = dp.logloss(y[scored], mB[0] + Xb[scored] @ mB[1])
            res["beta"] = mB[1][-1]
        else:
            for r, role in enumerate(dp.ROLES):
                m = fit_logit(dp.design(nn, fit, drop_role=r), y[fit], l2_d, 0, nn)
                res[f"D-{role}"] = dp.logloss(y[scored], z_of(m, dp.design(nn, scored, drop_role=r)))
        out["minutes"][t] = res
        print(f"block {block} minute {t}: {len(fit)} fit, {len(scored)} scored, {time.time() - t0:.0f} s", flush=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--minutes", default="0,5,10,15,20,25,30")
    ap.add_argument("--procs", type=int, default=6)
    ap.add_argument("--blocks", default=",".join(dp.BLOCKS))
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    minutes = [int(m) for m in a.minutes.split(",")]
    blocks = a.blocks.split(",")
    with ProcessPoolExecutor(a.procs) as ex:
        outs = list(ex.map(run_block, [(a.snap, b, minutes) for b in blocks]))
    by = {o["block"]: o for o in outs}
    np.save(os.path.join(a.out, "info-raw.npy"), by, allow_pickle=True)

    comps = [
        ("draft vs base", "D", "base"),
        ("state vs base", "S", "base"),
        ("draft given state", "DS", "S"),
        ("state given draft", "DS", "D"),
        ("draft logit x beta given state", "SB", "S"),
    ] + [(f"{r} pick given state", "DS", f"DS-{r}") for r in dp.ROLES] + [(f"{r} pick, draft only", "D", f"D-{r}") for r in dp.ROLES]
    with open(os.path.join(a.out, "info.tsv"), "w") as f:
        f.write("minute\tcomparison\tblock\tdiff\tci\tgames\tfolds_better\tbase_loss\n")
        for t in minutes:
            for label, x, ref in comps:
                fb = [b for b in dp.FOLDS if b in by and x in by[b]["minutes"][t] and ref in by[b]["minutes"][t]]
                if fb:
                    d = np.concatenate([by[b]["minutes"][t][x] - by[b]["minutes"][t][ref] for b in fb])
                    base = np.concatenate([by[b]["minutes"][t]["base"] for b in fb]).mean()
                    m, h, n = dp.paired(d)
                    k = sum(np.mean(by[b]["minutes"][t][x] - by[b]["minutes"][t][ref]) < 0 for b in fb)
                    f.write(f"{t}\t{label}\tfolds\t{m:.6f}\t{h:.6f}\t{n}\t{k}/{len(fb)}\t{base:.5f}\n")
                    print(f"{t:>2} {label:<32} folds {dp.fmt(m, h)} ({k}/{len(fb)}) n {n}")
                if "dev" in by and x in by["dev"]["minutes"][t] and ref in by["dev"]["minutes"][t]:
                    r = by["dev"]["minutes"][t]
                    m, h, n = dp.paired(r[x] - r[ref])
                    f.write(f"{t}\t{label}\tdev\t{m:.6f}\t{h:.6f}\t{n}\t\t{r['base'].mean():.5f}\n")
        f.write("\n# beta (draft logit's weight beside the state) by block\n")
        for t in minutes:
            betas = [by[b]["minutes"][t].get("beta") for b in blocks]
            f.write(f"# {t}\t" + "\t".join("" if v is None else f"{v:.3f}" for v in betas) + "\n")
            print(f"beta {t}: " + " ".join("-" if v is None else f"{v:.3f}" for v in betas))


if __name__ == "__main__":
    main()
