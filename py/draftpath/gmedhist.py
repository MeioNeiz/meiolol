"""Q3 skill check: the g-computation mediation (gmed.py) with and without player history,
on the same games: the 5 folds' scored games that have a history score.

History score h per game: logit(win-exp) - logit(win-ratings), both netcheck candidate
preds for scored games, fitted on older games (data/runs/playernet-20261013/r-exp and
r-rat games-cand.tsv, internal scope). No fit-game preds exist, so the outcome model Q
is cross-fitted over the folds: fold k's games are scored by a Q fit on the other four.
With history: Q also takes h and h x d, and mediator draws are matched within h tercile
(effects per tercile, averaged by size). How far the indirect share moves with h is how
much measured skill sits in it; unmeasured skill can move it further.

usage: gmedhist.py SNAP --exp FILE --rat FILE [--minutes 5,10,14,20] [--boot 40]
"""

import argparse
import os
import time

import numpy as np
import pandas as pd
import scipy.sparse as sp

import dp
import gmed
import info


def read_preds(path):
    t = pd.read_csv(path, sep="\t", dtype={"match_id": str, "block": str})
    return t.set_index("match_id")["pred"]


def fit_q(F, d, h, y):
    X = np.column_stack([gmed.q_design(F, d)] + ([h, h * d] if h is not None else []))
    return dp.logistic(sp.csr_matrix(X), y, np.full(X.shape[1], 1.0))


def q_prob(m, F, d, h):
    X = np.column_stack([gmed.q_design(F, d)] + ([h, h * d] if h is not None else []))
    return gmed.sig(m[0] + X @ m[1])


def effects(models, fold, F, d, h, y, window, strata):
    """per sd contrast, Q per game from its fold's model; mediator draws matched within
    stratum; returns total, indirect, direct (pp)"""
    out = np.zeros(3)
    wsum = 0
    for st in np.unique(strata):
        sel = strata == st
        M1 = sel & (np.abs(d - 0.5) < window)
        M0 = sel & (np.abs(d + 0.5) < window)
        if M1.sum() < 20 or M0.sum() < 20:
            continue

        def q(mask, dv):
            p = np.zeros(mask.sum())
            idx = np.flatnonzero(mask)
            for k, m in models.items():
                kk = fold[idx] == k
                if kk.any():
                    ii = idx[kk]
                    p[kk] = q_prob(m, F[ii], np.full(len(ii), dv), None if h is None else h[ii])
            return p.mean()

        q11, q10, q00 = q(M1, 0.5), q(M0, 0.5), q(M0, -0.5)
        w = sel.sum()
        out += w * np.array([q11 - q00, q11 - q10, q10 - q00]) * 100
        wsum += w
    return out / wsum


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--exp", required=True)
    ap.add_argument("--rat", required=True)
    ap.add_argument("--minutes", default="5,10,14,20")
    ap.add_argument("--boot", type=int, default=40)
    ap.add_argument("--window", type=float, default=0.25)
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    t0 = time.time()
    nn = dp.load_nn(a.snap)
    st = dp.load_state(a.snap, nn)
    pe, pr = read_preds(a.exp), read_preds(a.rat)
    rng = np.random.default_rng(19)
    idx = pd.Series(np.arange(nn.n), index=nn.match_id)
    games, fold, dz = [], [], []
    for b in dp.FOLDS:
        s = dp.sets(nn, b)
        l2 = info.pick(nn, None, s.inner, s.val, 0, {})
        m0 = dp.logistic(dp.design(nn, s.fit), nn.y[s.fit], dp.penalty(nn, l2))
        dfit = m0[0] + dp.design(nn, s.fit) @ m0[1]
        d = m0[0] + dp.design(nn, s.scored) @ m0[1]
        games.append(s.scored)
        fold.append(np.full(len(s.scored), int(b)))
        dz.append((d - dfit.mean()) / dfit.std())
        print(f"block {b}: {len(s.scored)} scored, {time.time() - t0:.0f} s", flush=True)
    games, fold, dz = np.concatenate(games), np.concatenate(fold), np.concatenate(dz)
    mids = [nn.match_id[g] for g in games]
    he, hr = pe.reindex(mids).to_numpy(), pr.reindex(mids).to_numpy()
    has = np.isfinite(he) & np.isfinite(hr)
    h = np.log(he / (1 - he)) - np.log(hr / (1 - hr))
    print(f"history score on {has.sum()} of {len(games)} fold games; sd {np.nanstd(h):.3f}", flush=True)
    f = open(os.path.join(a.out, "gmed-history.tsv"), "w")
    f.write("minute\tmodel\tgames\ttotal\ttotal_sd\tindirect\tindirect_sd\tdirect\tdirect_sd\tshare_indirect\n")
    for t in [int(m) for m in a.minutes.split(",")]:
        F, _, going = info.state_feats(st, t)
        keep = has & going[games]
        g, fo, d, hh, y = games[keep], fold[keep], dz[keep], h[keep], nn.y[games[keep]]
        Fg = F[g]
        terc = np.digitize(hh, np.quantile(hh, [1 / 3, 2 / 3]))

        def run(sample, with_h):
            models = {}
            for k in range(1, 6):
                tr = sample[fo[sample] != k]
                models[k] = fit_q(Fg[tr], d[tr], hh[tr] if with_h else None, y[tr])
            return effects(models, fo[sample], Fg[sample], d[sample], hh[sample] if with_h else None, y[sample], a.window, terc[sample] if with_h else np.zeros(len(sample)))

        allg = np.arange(len(g))
        for with_h in (False, True):
            est = run(allg, with_h)
            bs = np.array([run(rng.choice(allg, len(allg)), with_h) for _ in range(a.boot)])
            sdv = bs.std(0, ddof=1)
            share = est[1] / est[0] if np.sign(est[1]) == np.sign(est[0]) else np.nan
            name = "with history" if with_h else "without"
            f.write(f"{t}\t{name}\t{len(g)}\t{est[0]:.3f}\t{sdv[0]:.3f}\t{est[1]:.3f}\t{sdv[1]:.3f}\t{est[2]:.3f}\t{sdv[2]:.3f}\t{share:.3f}\n")
            f.flush()
            print(f"minute {t} {name}: total {est[0]:+.2f} ± {1.96 * sdv[0]:.2f}, indirect {est[1]:+.2f} ± {1.96 * sdv[1]:.2f}, direct {est[2]:+.2f} ± {1.96 * sdv[2]:.2f} pp, share {share:.2f}, {time.time() - t0:.0f} s", flush=True)
    f.close()


if __name__ == "__main__":
    main()
