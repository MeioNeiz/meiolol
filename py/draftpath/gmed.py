"""Q3, mediation by g-computation (research/questions/draft-mediation): how much of the
draft's win effect runs through the state at minute t, interventional direct and
indirect effects on the probability scale.

Draft score d: the draft-only logit (platform + champion-roles), out of fold: K-fold
inside the block's fit games, the block's model for its scored games; in sd units of
the fit games. Mediator: the joint state at t (gold lead by role, gold curve, XP, kills,
objectives held), or gold alone (secondary). Outcome model Q: logistic on state, d and
d x state, fit on the block's fit games still going at t.

Main contrast d1 = mean + sd/2 vs d0 = mean - sd/2; mediator draws are the real states of
the block's scored games whose d lies within --window sd of d1 or d0 (no parametric
generator):
  total = Q(d1, M1) - Q(d0, M0); indirect = Q(d1, M1) - Q(d1, M0);
  direct = Q(d1, M0) - Q(d0, M0)
Curve: each quintile of d against the middle one, the same way. Pooled over the 5
folds' scored games, dev-val apart; game bootstrap (refit Q on resampled fit games,
resample scored games). Dev-val also printed with EUW1 and the other platforms apart
(same Q and bootstrap refits): description only, never a reading (no EUW slice rule).

Per champion-role (--champions, the dev block's fit games, train-fit description): swap
champion j for its role's average pick: draft coefficient to 0, d minus j's draft
weight, and each game's real state shifted by j's estimated state effect (ridge of
every state column on the draft): indirect = Q(j, M) - Q(j, M - delta_j), direct =
Q(j, M - delta_j) - Q(j*, M - delta_j), from j's team's view, averaged over j's games.

Skill bias table: state weights in Q scaled by k (only k of the state's win association
is the state's own; the rest player skill, unrelated to the draft).
Description, not cause: the state carries who plays better. A noisy mediator pulls the
indirect part toward 0, so its share is a lower bound.

usage: gmed.py SNAP [--minutes 5,10,14,20] [--boot 40] [--window 0.25] [--procs 6]
                    [--champions] [--min-games 300] [--out .]
"""

import argparse
import os
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import scipy.sparse as sp

import dp
import info

KS = [1.0, 0.9, 0.75, 0.5]
GOLD_COLS = 6  # gold by role (5) + gold curve, info.state_feats order


def sig(z):
    return 1 / (1 + np.exp(-z))


def q_design(F, d):
    return np.column_stack([F, d, F * d[:, None]])


def fit_q(F, d, y):
    X = q_design(F, d)
    return dp.logistic(sp.csr_matrix(X), y, np.full(X.shape[1], 1.0))


def q_prob(m, F, d, k=1.0):
    """P(win | state F, draft score d); state weights (and their d interactions) x k"""
    ns = F.shape[1]
    w = m[1].copy()
    w[:ns] *= k
    w[ns + 1 :] *= k
    return sig(m[0] + q_design(F, d) @ w)


def effects(m, F, d, d_lo, d_hi, window, k=1.0):
    """total, indirect, direct for d_hi vs d_lo; mediator draws from games near each"""
    M1 = np.abs(d - d_hi) < window
    M0 = np.abs(d - d_lo) < window
    if M1.sum() < 20 or M0.sum() < 20:
        return np.full(3, np.nan), int(M1.sum()), int(M0.sum())
    q11 = q_prob(m, F[M1], np.full(M1.sum(), d_hi), k).mean()
    q10 = q_prob(m, F[M0], np.full(M0.sum(), d_hi), k).mean()
    q00 = q_prob(m, F[M0], np.full(M0.sum(), d_lo), k).mean()
    return np.array([q11 - q00, q11 - q10, q10 - q00]) * 100, int(M1.sum()), int(M0.sum())


def run_block(args):
    snap, block, minutes, boot, window, gold_only = args
    t0 = time.time()
    nn = dp.load_nn(snap)
    st = dp.load_state(snap, nn)
    s = dp.sets(nn, block)
    y = nn.y
    rng = np.random.default_rng(13)
    l2 = info.pick(nn, None, s.inner, s.val, 0, {})
    m0 = dp.logistic(dp.design(nn, s.fit), y[s.fit], dp.penalty(nn, l2))
    d = info.cross_draft(nn, s.fit, l2, rng)
    d[s.scored] = m0[0] + dp.design(nn, s.scored) @ m0[1]
    mu, sd = d[s.fit].mean(), d[s.fit].std()
    dz = (d - mu) / sd
    out = {"block": block, "minutes": {}}
    for t in minutes:
        F, names, going = info.state_feats(st, t)
        if gold_only:
            F = F[:, :GOLD_COLS]
        fit, sc = s.fit[going[s.fit]], s.scored[going[s.scored]]
        res = {"n_fit": len(fit), "n_scored": len(sc), "y": y[sc], "dz": dz[sc]}
        # quintile cut points of d over fit games (going), medians as the contrast points
        qs = np.quantile(dz[fit], [0.2, 0.4, 0.6, 0.8])
        med = [np.median(dz[fit][(dz[fit] > lo) & (dz[fit] <= hi)]) for lo, hi in zip(np.r_[-np.inf, qs], np.r_[qs, np.inf])]
        res["quintile_d"] = med

        def all_effects(m, Fs, ds):
            e = {}
            for k in KS:
                e[("sd", k)] = effects(m, Fs, ds, -0.5, 0.5, window, k)[0]
            for qi in range(5):
                if qi != 2:
                    e[("q", qi)] = effects(m, Fs, ds, med[2], med[qi], window)[0]
            return e

        m = fit_q(F[fit], dz[fit], y[fit])
        res["coef"] = m[1]
        res["est"] = all_effects(m, F[sc], dz[sc])
        n1 = effects(m, F[sc], dz[sc], -0.5, 0.5, window)[1:]
        res["draws"] = n1
        # model-free check: observed win rate near d1 minus near d0
        near1, near0 = np.abs(dz[sc] - 0.5) < window, np.abs(dz[sc] + 0.5) < window
        res["observed_total"] = (y[sc][near1].mean() - y[sc][near0].mean()) * 100
        # separate stream so the pooled estimates match runs before the groups existed
        rng_g = np.random.default_rng(17)
        groups = {}
        if block == "dev":
            euw = nn.meta["platforms"].index("EUW1")
            for name, keep in (("dev EUW1", nn.platform[sc] == euw), ("dev other", nn.platform[sc] != euw)):
                g = sc[keep]
                near1, near0 = np.abs(dz[g] - 0.5) < window, np.abs(dz[g] + 0.5) < window
                groups[name] = {
                    "n_scored": len(g),
                    "games": g,
                    "est": all_effects(m, F[g], dz[g]),
                    "observed_total": (y[g][near1].mean() - y[g][near0].mean()) * 100,
                    "boot": [],
                }
        bs = []
        for _ in range(boot):
            fb, sb = rng.choice(fit, len(fit)), rng.choice(sc, len(sc))
            mb = fit_q(F[fb], dz[fb], y[fb])
            bs.append(all_effects(mb, F[sb], dz[sb]))
            for gr in groups.values():
                gb = rng_g.choice(gr["games"], len(gr["games"]))
                gr["boot"].append(all_effects(mb, F[gb], dz[gb]))
        res["boot"] = bs
        res["groups"] = groups
        out["minutes"][t] = res
        print(f"block {block} minute {t}: fit {len(fit)}, scored {len(sc)}, draws {n1}, sd {res['est'][('sd', 1.0)]}, {time.time() - t0:.0f} s", flush=True)
    return out


def champions(snap, minutes, boot, min_games, out_dir):
    """per champion-role swap, dev block's fit games (train-fit description)"""
    t0 = time.time()
    nn = dp.load_nn(snap)
    st = dp.load_state(snap, nn)
    s = dp.sets(nn, "dev")
    y = nn.y
    rng = np.random.default_rng(17)
    n_plat = len(nn.meta["platforms"])
    l2 = info.pick(nn, None, s.inner, s.val, 0, {})
    mD = dp.logistic(dp.design(nn, s.fit), y[s.fit], dp.penalty(nn, l2))
    d = info.cross_draft(nn, s.fit, l2, rng)
    f = open(os.path.join(out_dir, "gmed-champions.tsv"), "w")
    f.write("minute\tchampion\trole\tgames\ttotal\ttotal_sd\tindirect\tindirect_sd\tdirect\tdirect_sd\tgold_shift\tgold_shift_sd\n")
    for t in minutes:
        F, names, going = info.state_feats(st, t)
        fit = s.fit[going[s.fit]]
        ns = F.shape[1]
        cnt = np.zeros(dp.n_cols(nn), np.int64)
        for slot in range(10):
            np.add.at(cnt, n_plat + nn.champ[fit, slot].astype(np.int64) * 5 + slot % 5, 1)
        js = [j for j in range(n_plat, dp.n_cols(nn)) if cnt[j] >= min_games]
        l2s = info.pick(nn, np.column_stack([F, d, F * d[:, None]]), s.inner[going[s.inner]], s.val[going[s.val]], 2 * ns + 1, {})

        def fit_all(games):
            Xd = dp.design(nn, games)
            Xs = np.column_stack([F[games], d[games], F[games] * d[games, None]])
            mq = info.fit_logit(info.stack(Xs, Xd), y[games], l2s, Xs.shape[1], nn)
            # state shift per champion-role: ridge of every state column on the draft
            pen = dp.penalty(nn, 300)
            delta = np.stack([dp.ridge(Xd, F[games, c], pen)[1] for c in range(ns)], 1)  # [cols, ns]
            return mq, delta

        def swap(mq, delta, games):
            """per j: mean over its games of (total, indirect, direct), j's team's view"""
            Xd = dp.design(nn, games).tocsc()
            Fg, dg = F[games], d[games]
            w_state, w_d, w_int = mq[1][:ns], mq[1][ns], mq[1][ns + 1 : 2 * ns + 1]
            w_draft = mq[1][2 * ns + 1 :]
            base_draft = Xd @ w_draft
            res = np.full((dp.n_cols(nn), 4), np.nan)

            def z(Fx, dx, draft):
                return mq[0] + Fx @ w_state + dx * w_d + (Fx * dx[:, None]) @ w_int + draft

            for j in js:
                col = Xd[:, j].toarray().ravel()
                rows = np.flatnonzero(col != 0)
                if len(rows) == 0:
                    continue
                sgn = col[rows]
                Fr, dr, br = Fg[rows], dg[rows], base_draft[rows]
                Fs = Fr - sgn[:, None] * delta[j][None, :]
                ds = dr - sgn * mD[1][j]
                bs = br - sgn * w_draft[j]
                q_jj = sig(z(Fr, dr, br))
                q_js = sig(z(Fs, dr, br))
                q_ss = sig(z(Fs, ds, bs))
                # j's team's view: blue's chance x sign
                res[j] = [np.mean(sgn * (q_jj - q_ss)) * 100, np.mean(sgn * (q_jj - q_js)) * 100, np.mean(sgn * (q_js - q_ss)) * 100, delta[j][:5].sum() * 1000]
            return res

        mq, delta = fit_all(fit)
        est = swap(mq, delta, fit)
        bs = []
        for b in range(boot):
            gb = rng.choice(fit, len(fit))
            mb, db = fit_all(gb)
            bs.append(swap(mb, db, fit))
        sdv = np.nanstd(np.stack(bs), axis=0, ddof=1) if boot > 1 else np.full_like(est, np.nan)
        for j in js:
            c, r = (j - n_plat) // 5, (j - n_plat) % 5
            f.write(f"{t}\t{nn.champ_name(c)}\t{dp.ROLES[r]}\t{cnt[j]}" + "".join(f"\t{est[j][k]:.3f}\t{sdv[j][k]:.3f}" for k in range(4)) + "\n")
        f.flush()
        print(f"champions minute {t}: {len(js)} champion-roles, L2 {l2s}, {time.time() - t0:.0f} s", flush=True)
    f.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--minutes", default="5,10,14,20")
    ap.add_argument("--boot", type=int, default=40)
    ap.add_argument("--window", type=float, default=0.25)
    ap.add_argument("--procs", type=int, default=6)
    ap.add_argument("--gold-only", action="store_true")
    ap.add_argument("--champions", action="store_true")
    ap.add_argument("--min-games", type=int, default=300)
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    minutes = [int(m) for m in a.minutes.split(",")]
    if a.champions:
        champions(a.snap, minutes, a.boot, a.min_games, a.out)
        return
    with ProcessPoolExecutor(a.procs) as ex:
        outs = list(ex.map(run_block, [(a.snap, b, minutes, a.boot, a.window, a.gold_only) for b in dp.BLOCKS]))
    by = {o["block"]: o for o in outs}
    np.save(os.path.join(a.out, "gmed-raw.npy"), by, allow_pickle=True)
    tag = "gold" if a.gold_only else "state"
    f = open(os.path.join(a.out, f"gmed-{tag}.tsv"), "w")
    f.write("mediator\tminute\tcontrast\tk\tblocks\ttotal\ttotal_sd\tindirect\tindirect_sd\tdirect\tdirect_sd\tshare_indirect\tobserved_total\n")
    for t in minutes:
        rows = [("folds", [by[b]["minutes"][t] for b in dp.FOLDS]), ("dev", [by["dev"]["minutes"][t]])]
        rows += [(g, [r]) for g, r in by["dev"]["minutes"][t]["groups"].items()]
        for name, rs in rows:
            # pooled: mean of block estimates weighted by scored games; sd from the
            # block bootstraps combined the same way
            w = np.array([r["n_scored"] for r in rs], float)
            w /= w.sum()
            keys = list(rs[0]["est"].keys())
            obs = sum(wi * r["observed_total"] for wi, r in zip(w, rs))
            for key in keys:
                est = sum(wi * r["est"][key] for wi, r in zip(w, rs))
                nb = min(len(r["boot"]) for r in rs)
                boots = np.array([sum(wi * r["boot"][i][key] for wi, r in zip(w, rs)) for i in range(nb)])
                sdv = boots.std(0, ddof=1) if nb > 1 else np.full(3, np.nan)
                share = est[1] / est[0] if np.sign(est[1]) == np.sign(est[0]) else np.nan
                contrast = "per sd" if key[0] == "sd" else f"quintile {key[1] + 1} vs 3"
                k = key[1] if key[0] == "sd" else 1.0
                f.write(f"{tag}\t{t}\t{contrast}\t{k}\t{name}\t{est[0]:.3f}\t{sdv[0]:.3f}\t{est[1]:.3f}\t{sdv[1]:.3f}\t{est[2]:.3f}\t{sdv[2]:.3f}\t{share:.3f}\t{obs:.3f}\n")
                if key[0] == "sd" or name == "folds":
                    print(f"{tag} {t:>2} {name:<9} {contrast:<16} k {k}: total {est[0]:+.2f} ± {1.96 * sdv[0]:.2f}, indirect {est[1]:+.2f} ± {1.96 * sdv[1]:.2f}, direct {est[2]:+.2f} ± {1.96 * sdv[2]:.2f} pp, share {share:.2f}, observed total {obs:+.2f}")
    f.close()


if __name__ == "__main__":
    main()
