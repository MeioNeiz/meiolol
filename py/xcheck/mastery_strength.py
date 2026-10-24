"""Champion-role strength at fixed mastery (lab-frontier D1).

One logistic model per game (blue's win): platform side + sum of champion-role strengths
theta (blue minus red, Gaussian prior sd PRIOR_SD) + beta * seat log mastery
m = log10(points + 1000) - 3 (as lanecard.Expertise), optionally + gamma * log10 total
points. Seats without a pre-game fetch get their champion-role's mean m among fetched
seats (shrunk to the role's by SHRINK seats), so theta stays the strength at m = 0 and an
unknown player counts at the champion's usual mastery. Fitted by Newton (dense Hessian),
beta's interval from it.

Reported: beta per tenfold points with its 95% interval (Fisher, and the spread over
time halves), strength vs the role at 50k points against the raw fit (no mastery), the
champion-roles that move most, and the lane card's double count: on dev-val (fit before
the dev cut) the paired log loss of raw strength + beta m (the shipped lane card's sum),
raw + beta (m - champion-role mean m) and the refit.

Usage: mastery_strength.py SNAP [--out DIR]
"""

import argparse
import json
import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd
import scipy.sparse as sp

ROLES = ["TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY"]
PRIOR_SD = 0.1
SHRINK = 50
M50K = np.log10(50_000 + 1000) - 3
PP = 25


def load(snap):
    with open(f"{snap}/split.tsv") as f:
        head = f.readline().split()
    cuts = dict(zip(head[1::2], map(int, head[2::2])))
    con = sqlite3.connect(f"file:{snap}/meiolol.db?mode=ro", uri=True)
    g = pd.read_sql_query(
        "SELECT match_id, platform, game_start, winning_team FROM matches "
        "WHERE queue_id = 420 AND remake = 0 AND winning_team IS NOT NULL AND game_start < ?",
        con,
        params=(cuts["test_cut_ms"],),
    )
    p = pd.read_sql_query(
        "SELECT p.match_id, p.slot, p.team_id, p.champion_id, p.position FROM participants p "
        "JOIN matches m USING (match_id) WHERE m.queue_id = 420 AND m.remake = 0 "
        "AND m.winning_team IS NOT NULL AND m.game_start < ?",
        con,
        params=(cuts["test_cut_ms"],),
    )
    p["role"] = p["position"].map({r: i for i, r in enumerate(ROLES)})
    p = p.dropna(subset=["role"])
    p["seat"] = (p["team_id"] != 100).astype(int) * 5 + p["role"].astype(int)
    ok = p.groupby("match_id")["seat"].agg(lambda s: len(s) == 10 and s.nunique() == 10)
    g = g[g["match_id"].map(ok).fillna(False).astype(bool)].reset_index(drop=True)
    p = p[p["match_id"].isin(g["match_id"])]
    mp = pd.read_csv(f"{snap}/mastery_pre.tsv", sep="\t", usecols=["match_id", "slot", "points", "total_points"])
    p = p.merge(mp, on=["match_id", "slot"], how="left")
    gi = pd.Series(np.arange(len(g)), index=g["match_id"])
    p["game"] = gi[p["match_id"]].to_numpy()
    p = p.sort_values(["game", "seat"])
    n = len(g)
    champ = p["champion_id"].to_numpy().reshape(n, 10)
    pts = p["points"].to_numpy(float).reshape(n, 10)
    tot = p["total_points"].to_numpy(float).reshape(n, 10)
    return g, champ, pts, tot, cuts


class Data:
    def __init__(self, g, champ, pts, tot, rows):
        self.y = (g["winning_team"].to_numpy()[rows] == 100).astype(float)
        self.plat, self.platforms = pd.factorize(g["platform"].to_numpy()[rows])
        self.champ = champ[rows]
        self.m = np.log10(pts[rows] + 1000) - 3
        self.t = np.log10(tot[rows] + 1e5) - 6
        self.known = ~np.isnan(pts[rows])


def cell_index(champ):
    role = np.tile(np.arange(5), 2)
    keys = champ * 5 + role
    return keys


def impute(m, known, keys, cell_ids, role_of_cell):
    """Unknown seats: their cell's mean m among known seats, shrunk to the role's"""
    k = keys[known]
    v = m[known]
    ncell = len(cell_ids)
    idx = np.searchsorted(cell_ids, k)
    s = np.bincount(idx, v, ncell)
    c = np.bincount(idx, minlength=ncell)
    rs = np.bincount(role_of_cell[idx], v, 5) / np.bincount(role_of_cell[idx], minlength=5)
    mean = (s + SHRINK * rs[role_of_cell]) / (c + SHRINK)
    out = m.copy()
    allidx = np.searchsorted(cell_ids, keys)
    out[~known] = mean[allidx[~known]]
    return out, mean, c


def design(d, cell_ids, covs):
    n = len(d.y)
    keys = cell_index(d.champ)
    idx = np.searchsorted(cell_ids, keys)
    sign = np.concatenate([np.ones((n, 5)), -np.ones((n, 5))], 1)
    npl = len(d.platforms)
    rows = np.repeat(np.arange(n), 10)
    Xc = sp.csr_matrix((sign.ravel(), (rows, idx.ravel() + npl)), shape=(n, npl + len(cell_ids)))
    Xp = sp.csr_matrix((np.ones(n), (np.arange(n), d.plat)), shape=(n, npl + len(cell_ids)))
    X = Xc + Xp
    extra = [(c * sign).sum(1)[:, None] for c in covs]
    if extra:
        X = sp.hstack([X, sp.csr_matrix(np.hstack(extra))]).tocsr()
    return X, npl


def fit(X, y, npl, ncell, iters=12):
    k = X.shape[1]
    prior = np.zeros(k)
    prior[npl : npl + ncell] = 1 / PRIOR_SD**2
    prior[:npl] = 1e-6
    prior[npl + ncell :] = 1e-6
    b = np.zeros(k)
    for _ in range(iters):
        eta = X @ b
        p = 1 / (1 + np.exp(-eta))
        w = p * (1 - p)
        g = X.T @ (y - p) - prior * b
        H = (X.T @ sp.diags(w) @ X).toarray() + np.diag(prior)
        step = np.linalg.solve(H, g)
        b += step
        if np.abs(step).max() < 1e-7:
            break
    eta = X @ b
    p = 1 / (1 + np.exp(-eta))
    H = (X.T @ sp.diags(p * (1 - p)) @ X).toarray() + np.diag(prior)
    return b, np.linalg.inv(H)


def logloss(y, eta):
    return np.logaddexp(0, eta) - y * eta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    out = Path(a.out)
    g, champ, pts, tot, cuts = load(a.snap)
    start = g["game_start"].to_numpy()
    print(f"{len(g)} played games before the test cut; {np.mean(~np.isnan(pts)):.1%} of seats with a pre-game fetch")
    keys_all = cell_index(champ)
    cell_ids = np.unique(keys_all)
    role_of_cell = cell_ids % 5
    names = {}
    for f in sorted(Path(a.snap, "ddragon").glob("*/champion.json")):
        names |= {int(c["key"]): c["name"] for c in json.load(open(f))["data"].values()}

    def fits(rows):
        d = Data(g, champ, pts, tot, rows)
        keys = cell_index(d.champ)
        m, cell_m, cell_known = impute(d.m, d.known, keys, cell_ids, role_of_cell)
        t, _, _ = impute(d.t, d.known, keys, cell_ids, role_of_cell)
        res = {"d": d, "cell_m": cell_m, "cell_known": cell_known, "m": m}
        for name, covs in (("raw", []), ("mastery", [m]), ("mastery+total", [m, t])):
            X, npl = design(d, cell_ids, covs)
            b, cov = fit(X, d.y, npl, len(cell_ids))
            res[name] = (b, cov, npl, X)
        return res

    allrows = np.arange(len(g))
    R = fits(allrows)
    d = R["d"]
    ncell = len(cell_ids)
    games = np.bincount(np.searchsorted(cell_ids, keys_all).ravel(), minlength=ncell)
    print(f"\n{ncell} champion-roles; fit {len(d.y)} games (every dev-visible game, {d.known.mean():.1%} seats known)")
    print("\n| model | beta (logit a tenfold points) | 95% | 10k to 300k points (pp) | gamma (total) |")
    print("| --- | --- | --- | --- | --- |")
    for name in ("mastery", "mastery+total"):
        b, cov, npl, _ = R[name]
        j = npl + ncell
        se = np.sqrt(cov[j, j])
        span = np.log10(301_000) - np.log10(11_000)
        gam = f"{b[j + 1]:+.4f} ± {1.96 * np.sqrt(cov[j + 1, j + 1]):.4f}" if name == "mastery+total" else ""
        print(f"| {name} | {b[j]:.4f} | {b[j] - 1.96 * se:.4f} to {b[j] + 1.96 * se:.4f} | {PP * b[j] * span:.2f} | {gam} |")

    # time halves: slope stability
    half = np.median(start)
    print("\nbeta by time half (mastery model, refit on each):")
    for lab, rows in (("older", allrows[start < half]), ("newer", allrows[start >= half])):
        H = fits(rows)
        b, cov, npl, _ = H["mastery"]
        j = npl + ncell
        print(f"  {lab}: {len(rows)} games, beta {b[j]:.4f} ± {1.96 * np.sqrt(cov[j, j]):.4f}")

    # strengths vs the role (games-weighted), raw and at 50k
    rows = []
    br = R["raw"][0][R["raw"][2] : R["raw"][2] + ncell]
    bm = R["mastery"][0][R["mastery"][2] : R["mastery"][2] + ncell]
    beta = R["mastery"][0][R["mastery"][2] + ncell]
    for r in range(5):
        sel = role_of_cell == r
        wts = games[sel]
        rows.append(
            pd.DataFrame(
                {
                    "cell": cell_ids[sel],
                    "role": ROLES[r],
                    "games": wts,
                    "known": R["cell_known"][sel],
                    "mean_m": R["cell_m"][sel],
                    "raw_pp": PP * (br[sel] - np.average(br[sel], weights=wts)),
                    "at50k_pp": PP * (bm[sel] - np.average(bm[sel], weights=wts)),
                    "bias_pp": PP * beta * (R["cell_m"][sel] - np.average(R["cell_m"][sel], weights=wts)),
                }
            )
        )
    S = pd.concat(rows, ignore_index=True)
    S["champion"] = (S["cell"] // 5).map(lambda c: names.get(c, str(c)))
    S["move_pp"] = S["at50k_pp"] - S["raw_pp"]
    S.to_csv(out / "d1-strength.tsv", sep="\t", index=False, float_format="%.4f")
    big = S[S["known"] >= 300]
    print(f"\nchampion-roles with 300+ fetched seats: {len(big)}; move (50k minus raw) sd {big['move_pp'].std():.2f} pp, "
          f"predicted by beta x (mean m - role's) r = {np.corrcoef(big['move_pp'], -big['bias_pp'])[0, 1]:.3f}")
    rank_r = big.groupby("role").apply(lambda x: x["raw_pp"].rank().corr(x["at50k_pp"].rank()), include_groups=False)
    print("rank correlation raw vs at 50k by role: " + ", ".join(f"{k} {v:.3f}" for k, v in rank_r.items()))
    show = big.reindex(big["move_pp"].abs().sort_values(ascending=False).index).head(20)
    print("\n| champion | role | games | fetched seats | mean points | raw (pp) | at 50k (pp) | move (pp) |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for _, x in show.iterrows():
        pts_mean = 10 ** (x["mean_m"] + 3) - 1000
        print(f"| {x['champion']} | {x['role']} | {x['games']} | {x['known']} | {pts_mean / 1000:.0f}k | {x['raw_pp']:+.2f} | {x['at50k_pp']:+.2f} | {x['move_pp']:+.2f} |")

    # lane card double count on dev-val, fit before the dev cut
    fitrows = allrows[start < cuts["dev_cut_ms"]]
    valrows = allrows[start >= cuts["dev_cut_ms"]]
    F = fits(fitrows)
    V = Data(g, champ, pts, tot, valrows)
    keys = cell_index(V.champ)
    idx = np.searchsorted(cell_ids, keys)
    sign = np.concatenate([np.ones((len(V.y), 5)), -np.ones((len(V.y), 5))], 1)
    plat_map = {p: i for i, p in enumerate(F["d"].platforms)}

    def eta(name, extra):
        b, _, npl, _ = F[name]
        pl = np.array([b[plat_map[p]] if p in plat_map else 0.0 for p in V.platforms])[V.plat]
        return pl + (sign * (b[npl:][idx] + extra)).sum(1)

    bF = F["mastery"][0][F["mastery"][2] + ncell]
    # the lane card ranks a pool by beta m, so its level is free: centred on everyone's mean
    mk = np.where(V.known, V.m - F["d"].m[F["d"].known].mean(), 0.0)
    dev = np.where(V.known, V.m - F["cell_m"][idx], 0.0)
    variants = {
        "raw strength": eta("raw", 0),
        "raw + beta (m - everyone's mean m) (lane card now)": eta("raw", bF * mk),
        "raw + beta (m - champion-role mean m)": eta("raw", bF * dev),
        "refit: theta + beta m": eta("mastery", bF * np.where(V.known, V.m, F["cell_m"][idx])),
    }
    base = logloss(V.y, variants["raw strength"])
    print(f"\ndev-val {len(V.y)} games ({V.known.mean():.1%} seats fetched), fit {len(fitrows)}; beta {bF:.4f}")
    print("| scoring | log loss | vs raw (milli-nats, ± 95%) |")
    print("| --- | --- | --- |")
    for k, e in variants.items():
        ll = logloss(V.y, e)
        dd = (ll - base) * 1000
        print(f"| {k} | {ll.mean():.5f} | {dd.mean():+.3f} ± {1.96 * dd.std() / np.sqrt(len(dd)):.3f} |")
    lc = logloss(V.y, variants["raw + beta (m - everyone's mean m) (lane card now)"])
    for k in ("raw + beta (m - champion-role mean m)", "refit: theta + beta m"):
        dd = (logloss(V.y, variants[k]) - lc) * 1000
        print(f"  {k} vs lane card now: {dd.mean():+.3f} ± {1.96 * dd.std() / np.sqrt(len(dd)):.3f}")


if __name__ == "__main__":
    main()
