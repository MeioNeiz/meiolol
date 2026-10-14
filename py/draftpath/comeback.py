"""Q4: draft-conditional comebacks, mixed early/late teams, lane-only matchups.

Per block, champion-role numbers from the fit games only, then the block's scored games:
- early_j: effect on the team gold lead at 15 (ridge, gold); win_j: draft-only win effect
- late_j: DE at 25 minus DE at 10 (the draft's win weight at equal state, log-odds)
- offsets for scored games: the block's state+draft model at 15 (DS15), draft-only (D)
(a) Comebacks: on scored games going at 15, logistic with offset DS15 logit:
    y ~ g + L + g x L, g = team gold lead at 15 (thousands), L = blue minus red sum of
    late_j (z over fit teams). g x L < 0: late drafts lose less of their lead's value
    (come back more). Also by tercile of L among teams 1500+ behind: observed vs DS15
(b) Mixed teams: offset D logit; y ~ M_blue - M_red, M = (early champions, top quarter of
    early_j in role) x (team late_j sum z); plus the two parts alone
(c) Lane matchups: per lane, canonical champion pair one-hot (signed), on top of the
    draft: held-out gain on that lane's gold lead at 14 and on win, folds pooled
Pooled over the 5 folds' scored games: robust (sandwich) se, sign per fold.

usage: comeback.py SNAP [--procs 6] [--out .] [--pair-min 30] [--from-raw FILE]
"""

import argparse
import os
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import scipy.sparse as sp

import dp
import info


def team_sum(nn, games, per_col):
    """blue minus red sum of per champion-role values, and each side's"""
    n_plat = len(nn.meta["platforms"])
    v = np.zeros((len(games), 10))
    for slot in range(10):
        v[:, slot] = per_col[n_plat + nn.champ[games, slot].astype(np.int64) * 5 + slot % 5]
    return v[:, :5].sum(1) - v[:, 5:].sum(1), v


def pair_design(nn, games, r, pairs):
    """signed one-hot of the lane pair at role r: +1 for (blue a, red b) as keyed, -1
    swapped; pairs: dict (lo, hi) -> column"""
    a = nn.champ[games, r].astype(np.int64)
    b = nn.champ[games, 5 + r].astype(np.int64)
    lo, hi = np.minimum(a, b), np.maximum(a, b)
    sign = np.where(a <= b, 1.0, -1.0)
    col = np.array([pairs.get((x, y), -1) for x, y in zip(lo, hi)])
    keep = (col >= 0) & (a != b)
    return sp.csr_matrix((sign[keep], (np.flatnonzero(keep), col[keep])), shape=(len(games), max(len(pairs), 1)))


def run_block(args):
    snap, block, pair_min = args
    t0 = time.time()
    nn = dp.load_nn(snap)
    st = dp.load_state(snap, nn)
    s = dp.sets(nn, block)
    y = nn.y
    out = {"block": block}
    F = {}
    going = {}
    for t in (10, 15, 25):
        F[t], _, going[t] = info.state_feats(st, t)
    g = lambda x, t: x[going[t][x]]

    # champion-role numbers from fit games
    l2_d = info.pick(nn, None, s.inner, s.val, 0, {})
    mD = dp.logistic(dp.design(nn, s.fit), y[s.fit], dp.penalty(nn, l2_d))
    fit15 = g(s.fit, 15)
    lead15 = F[15][:, :5].sum(1) * 1000
    early = dp.ridge(dp.design(nn, fit15), lead15[fit15], dp.penalty(nn, 300))[1]
    de = {}
    for t in (10, 15, 25):
        ft, it, vt = g(s.fit, t), g(s.inner, t), g(s.val, t)
        ns = F[t].shape[1]
        l2 = info.pick(nn, F[t], it, vt, ns, {})
        m = info.fit_logit(info.stack(F[t][ft], dp.design(nn, ft)), y[ft], l2, ns, nn)
        de[t] = (m, ns)
    late = np.concatenate([np.zeros(1), de[25][0][1][de[25][1] :] - de[10][0][1][de[10][1] :]])[1:]
    # z of team sums over fit games
    Lfit, _ = team_sum(nn, s.fit, late)
    Lsd = Lfit.std()

    # early champions: top quarter of early_j within role among champion-roles with 100+ fit games
    n_plat = len(nn.meta["platforms"])
    cnt = np.zeros(dp.n_cols(nn))
    for slot in range(10):
        np.add.at(cnt, n_plat + nn.champ[s.fit, slot].astype(np.int64) * 5 + slot % 5, 1)
    is_early = np.zeros(dp.n_cols(nn))
    for r in range(5):
        js = np.array([n_plat + c * 5 + r for c in range(len(nn.meta["champions"]))])
        js = js[cnt[js] >= 100]
        cut = np.quantile(early[js], 0.75)
        is_early[js[early[js] >= cut]] = 1

    sc = s.scored
    out["scored"] = sc
    out["y"] = y[sc]
    out["D"] = mD[0] + dp.design(nn, sc) @ mD[1]
    L, _ = team_sum(nn, sc, late)
    out["L"] = L / Lsd
    _, ev = team_sum(nn, sc, is_early)
    _, lv = team_sum(nn, sc, late)
    out["n_early_b"], out["n_early_r"] = ev[:, :5].sum(1), ev[:, 5:].sum(1)
    out["late_b"], out["late_r"] = lv[:, :5].sum(1) / Lsd, lv[:, 5:].sum(1) / Lsd
    out["E"] = team_sum(nn, sc, early)[0]
    sc15 = going[15][sc]
    m15, ns15 = de[15]
    z15 = np.full(len(sc), np.nan)
    z15[sc15] = m15[0] + info.stack(F[15][sc[sc15]], dp.design(nn, sc[sc15])) @ m15[1]
    out["DS15"] = z15
    out["gold15"] = np.where(sc15, F[15][sc, :5].sum(1), np.nan)
    out["going15"] = sc15
    print(f"block {block}: champion numbers and offsets, {time.time() - t0:.0f} s", flush=True)

    # (c) lane pairs
    lanes = {}
    tl = (nn.flags & dp.TIMELINE15) != 0
    g14 = nn.aux_col("gold14").astype(np.float64)
    for r, role in enumerate(dp.ROLES):
        a = nn.champ[s.fit, r].astype(np.int64)
        b = nn.champ[s.fit, 5 + r].astype(np.int64)
        lo, hi = np.minimum(a, b), np.maximum(a, b)
        keys, c = np.unique(lo * 1000 + hi, return_counts=True)
        keys = keys[(c >= pair_min) & (keys // 1000 != keys % 1000)]
        pairs = {(int(k // 1000), int(k % 1000)): i for i, k in enumerate(keys)}
        lead = g14[:, r] - g14[:, 5 + r]
        res = {"pairs": len(pairs)}
        ft = s.fit[tl[s.fit]]
        it, vt, sct = s.inner[tl[s.inner]], s.val[tl[s.val]], sc[tl[sc]]
        Xd = lambda gm: dp.design(nn, gm)
        Xp = lambda gm: sp.hstack([Xd(gm), pair_design(nn, gm, r, pairs)]).tocsr()
        pen = lambda l2: np.concatenate([dp.penalty(nn, 300), np.full(len(pairs), l2)])
        # lane gold: pick the pair L2 on inner/val
        best, bl = None, np.inf
        for l2 in [300, 1000, 3000, 10000, 30000]:
            m = dp.ridge(Xp(it), lead[it], pen(l2))
            l = np.mean((lead[vt] - (m[0] + Xp(vt) @ m[1])) ** 2)
            if l < bl:
                best, bl = l2, l
        m0 = dp.ridge(Xd(ft), lead[ft], dp.penalty(nn, 300))
        m1 = dp.ridge(Xp(ft), lead[ft], pen(best))
        res["lead_d"] = (lead[sct] - (m1[0] + Xp(sct) @ m1[1])) ** 2 - (lead[sct] - (m0[0] + Xd(sct) @ m0[1])) ** 2
        res["lead_base"] = (lead[sct] - lead[ft].mean()) ** 2
        res["l2_lead"] = best
        # win, same pair L2 grid on inner/val, draft L2 as D
        best, bl = None, np.inf
        for l2 in [300, 1000, 3000, 10000, 30000]:
            m = dp.logistic(Xp(s.inner), y[s.inner], np.concatenate([dp.penalty(nn, l2_d), np.full(len(pairs), l2)]))
            l = dp.logloss(y[s.val], m[0] + Xp(s.val) @ m[1]).mean()
            if l < bl:
                best, bl = l2, l
        mw = dp.logistic(Xp(s.fit), y[s.fit], np.concatenate([dp.penalty(nn, l2_d), np.full(len(pairs), best)]))
        res["win_d"] = dp.logloss(y[sc], mw[0] + Xp(sc) @ mw[1]) - dp.logloss(y[sc], out["D"])
        res["l2_win"] = best
        lanes[role] = res
    out["lanes"] = lanes
    print(f"block {block}: lanes, {time.time() - t0:.0f} s", flush=True)
    return out


def robust_logit(y, off, X):
    """logistic with offset, unpenalised; returns coef, sandwich se (intercept first)"""
    X1 = np.column_stack([np.ones(len(y)), X])
    m = dp.logistic(sp.csr_matrix(X), y, np.full(X.shape[1], 1e-6), off)
    w = np.concatenate([[m[0]], m[1]])
    p = 1 / (1 + np.exp(-(X1 @ w + off)))
    H = (X1 * (p * (1 - p))[:, None]).T @ X1
    sc = X1 * (y - p)[:, None]
    Hi = np.linalg.inv(H)
    V = Hi @ (sc.T @ sc) @ Hi
    return w, np.sqrt(np.diag(V)), p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--procs", type=int, default=6)
    ap.add_argument("--pair-min", type=int, default=30)
    ap.add_argument("--out", default=".")
    ap.add_argument("--from-raw", help="comeback-raw.npy of an earlier run: report only")
    a = ap.parse_args()
    if a.from_raw:
        by = np.load(a.from_raw, allow_pickle=True).item()
    else:
        with ProcessPoolExecutor(a.procs) as ex:
            outs = list(ex.map(run_block, [(a.snap, b, a.pair_min) for b in dp.BLOCKS]))
        by = {o["block"]: o for o in outs}
        np.save(os.path.join(a.out, "comeback-raw.npy"), by, allow_pickle=True)
    f = open(os.path.join(a.out, "comeback.tsv"), "w")
    f.write("part\tterm\tblocks\tcoef\tse\tpp\tfolds_sign\tgames\tnote\n")

    def cat(key, blocks=dp.FOLDS):
        return np.concatenate([by[b][key] for b in blocks])

    for blocks, name in ((dp.FOLDS, "folds"), (["dev"], "dev")):
        # (a) comebacks at 15
        go = cat("going15", blocks)
        yy, off = cat("y", blocks)[go], cat("DS15", blocks)[go]
        gl, L, E = cat("gold15", blocks)[go], cat("L", blocks)[go], cat("E", blocks)[go] / 1000
        X = np.column_stack([gl, L, gl * L, gl * E])
        w, se, p = robust_logit(yy, off, X)
        ame = np.mean(p * (1 - p)) * 100
        signs = []
        if name == "folds":
            for b in dp.FOLDS:
                o = by[b]
                gb = o["going15"]
                wb, _, _ = robust_logit(o["y"][gb], o["DS15"][gb], np.column_stack([o["gold15"][gb], o["L"][gb], o["gold15"][gb] * o["L"][gb], o["gold15"][gb] * o["E"][gb] / 1000]))
                signs.append(wb)
        for k, term in enumerate(["gold15 beyond DS15", "late (z) beyond DS15", "gold15 x late", "gold15 x early-gold draft"]):
            fs = "".join("+" if s_[k + 1] > 0 else "-" for s_ in signs)
            f.write(f"comeback\t{term}\t{name}\t{w[k + 1]:.5f}\t{se[k + 1]:.5f}\t{w[k + 1] * ame:.3f}\t{fs}\t{len(yy)}\tpp per unit at even\n")
            print(f"{name} comeback {term}: {w[k + 1]:+.4f} ± {1.96 * se[k + 1]:.4f} ({w[k + 1] * ame:+.2f} pp) {fs}")
        # tercile table: teams 1500+ behind at 15
        behind_blue = gl <= -1.5
        behind_red = gl >= 1.5
        pb = 1 / (1 + np.exp(-off))
        # behind team's view: its late z, its win, its predicted chance
        lt = np.concatenate([L[behind_blue], -L[behind_red]])
        won = np.concatenate([yy[behind_blue], 1 - yy[behind_red]])
        pred = np.concatenate([pb[behind_blue], 1 - pb[behind_red]])
        cuts = np.quantile(lt, [1 / 3, 2 / 3])
        for i, (lo, hi) in enumerate([(-np.inf, cuts[0]), (cuts[0], cuts[1]), (cuts[1], np.inf)]):
            sel = (lt > lo) & (lt <= hi)
            d = won[sel] - pred[sel]
            m_, h_, n_ = dp.paired(d)
            f.write(f"behind1500\tlate tercile {i + 1}\t{name}\t{won[sel].mean():.4f}\t{pred[sel].mean():.4f}\t{100 * m_:.2f}\t±{100 * h_:.2f}\t{n_}\twon, DS15 predicted, won minus predicted pp\n")
            print(f"{name} 1500+ behind at 15, late tercile {i + 1}: won {100 * won[sel].mean():.1f}%, DS15 {100 * pred[sel].mean():.1f}%, diff {100 * m_:+.2f} ± {100 * h_:.2f} pp, n {n_}")
        # (b) mixed teams
        yy, off = cat("y", blocks), cat("D", blocks)
        neb, ner, lb, lr = cat("n_early_b", blocks), cat("n_early_r", blocks), cat("late_b", blocks), cat("late_r", blocks)
        X = np.column_stack([neb - ner, lb - lr, neb * lb - ner * lr, ((neb >= 2) & (lb > 0.5)).astype(float) - ((ner >= 2) & (lr > 0.5)).astype(float)])
        w, se, p = robust_logit(yy, off, X)
        ame = np.mean(p * (1 - p)) * 100
        for k, term in enumerate(["early champions", "team late z", "early champions x team late z", "2+ early on a late team (z>0.5)"]):
            f.write(f"mixed\t{term}\t{name}\t{w[k + 1]:.5f}\t{se[k + 1]:.5f}\t{w[k + 1] * ame:.3f}\t\t{len(yy)}\tbeyond draft-only D\n")
            print(f"{name} mixed {term}: {w[k + 1]:+.4f} ± {1.96 * se[k + 1]:.4f} ({w[k + 1] * ame:+.2f} pp)")
        # (c) lanes
        for role in dp.ROLES:
            ld = np.concatenate([by[b]["lanes"][role]["lead_d"] for b in blocks])
            lb_ = np.concatenate([by[b]["lanes"][role]["lead_base"] for b in blocks])
            wd = np.concatenate([by[b]["lanes"][role]["win_d"] for b in blocks])
            m1, h1, n1 = dp.paired(ld)
            m2, h2, n2 = dp.paired(wd)
            k1 = sum(by[b]["lanes"][role]["lead_d"].mean() < 0 for b in blocks)
            k2 = sum(by[b]["lanes"][role]["win_d"].mean() < 0 for b in blocks)
            npairs = by[blocks[-1]]["lanes"][role]["pairs"]
            f.write(f"lane\t{role} pairs: lane gold 14 MSE\t{name}\t{m1:.1f}\t{h1:.1f}\t{100 * -m1 / lb_.mean():.3f}\t{k1}/{len(blocks)}\t{n1}\t{npairs} pairs, pp column = % of base MSE\n")
            f.write(f"lane\t{role} pairs: win log loss\t{name}\t{m2:.6f}\t{h2:.6f}\t\t{k2}/{len(blocks)}\t{n2}\t\n")
            print(f"{name} lane {role} ({npairs} pairs): lane gold {m1:+.0f} ± {h1:.0f} ({100 * -m1 / lb_.mean():.2f}% of base, {k1}/{len(blocks)}), win {dp.fmt(m2, h2)} ({k2}/{len(blocks)})")
    f.close()


if __name__ == "__main__":
    main()
