"""Draft ceiling by variance accounting (lab-frontier B1).

How much signal is left in held-out residuals r = y - p of a model, by block: champion-role
mains (10 cells a game), ally role pairs (20), lane matchups (5: same role, both sides) and
cross-role enemy pairs (20). Model: true logit = model logit + sum of cell effects b_c
(signed: + when the cell's first champion is blue). Then E[r] ~ w b (w = p(1 - p)), and
for two games g != h, E[r_g r_h] = w_g w_h * (sum over the cells they share of signed b^2).

Only games of one scored block share a cell: the forward folds nest, so a later block's
model has seen an earlier block's games, and pairs across blocks carry -lambda w w (the
model's step per game) instead of the residual's covariance; across-block pairs made
win-ratings' mains and v2's pairs look used up beyond their real excess.

Unknowns: s2_u, the variance of b in unit u = a block's cells in one band of scored games
(BANDS), since rare cells spread more (B4). Statistic per unit:
N_u = sum over its cells of (S_c^2 - sum r^2), S_c = sum of signed r. E[N] = M s2, where
M[v, u] is N_v's expectation with unit u's cells at +-1 (Rademacher, --draws) and
nothing else: M counts every overlap (games sharing a pair cell share its mains, often a
third champion or an enemy too; ignoring that inflated the 22 Oct estimate ~1.8x).
Per-game V = sum_u (cells of u a game holds) s2_u, one-game cells at their block's
smallest band; V/8 nats a game is what a perfect estimate of the four blocks would gain
over the model (a calibrated logit of sd s gains ~s^2/8 over a coin).

V/8 is an excess loss, the model's own cell noise included. The ceiling comes from a
reference with no pair estimates (--ref, win-ratings: mains only): LL_perfect = LL_ref -
V_ref/8. Every model's own LL_m - V_m/8 should land on the same LL_perfect.

Checks, on the real schedule of games:
- nulls: y* ~ Bernoulli(p); estimates ~0, their sd is the noise
- flips (--flip-models): a share f of labels flipped; expected from the estimate and M
  of the flipped model's weights
- planted (--plant N): y* from the reference's logit + planted cells (b ~ N(0, s2_u) at
  the reference's estimates); recovered against the realised per-game sum of b^2
- models of the planted truth: pair cells estimated from their games (b + e,
  e ~ N(0, 1/sum w)), shrunk as a posterior mean, or shrunk a quarter as much; V/8
  against the true excess (per-game sum of errors^2, and log loss minus the truth's)

Usage: ceiling.py SNAP_DB --pred NAME=PATH:COL ... [--ref NAME] [--sims N]
       [--flip-models A,B] [--blocks 1,2,3,4,5,dev] [--plant N] [--split-models A,B]
"""

import argparse
import sqlite3

import numpy as np
import pandas as pd

ROLES = {"TOP": 0, "JUNGLE": 1, "MIDDLE": 2, "BOTTOM": 3, "UTILITY": 4}
EPS = 1e-6
LN2 = np.log(2)
BLOCKS = ["main", "ally", "lane", "cross"]
# Scored games in a cell: band starts; one-game cells hold no pairs
BANDS = {"main": [2, 500, 2000], "ally": [2, 10, 50, 200], "lane": [2, 10, 50, 200], "cross": [2, 10, 50, 200]}


def champions(db, ids):
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    con.execute("CREATE TEMP TABLE want (match_id TEXT PRIMARY KEY)")
    con.executemany("INSERT INTO want VALUES (?)", ((i,) for i in ids))
    rows = con.execute(
        "SELECT p.match_id, p.team_id, p.position, p.champion_id FROM participants p JOIN want USING (match_id)"
    ).fetchall()
    df = pd.DataFrame(rows, columns=["match_id", "team", "pos", "champ"])
    df["role"] = df["pos"].map(ROLES)
    df = df.dropna(subset=["role"])
    df["slot"] = (df["team"] != 100).astype(int) * 5 + df["role"].astype(int)
    wide = df.pivot_table(index="match_id", columns="slot", values="champ", aggfunc="first")
    wide = wide.reindex(index=ids, columns=range(10))
    return wide.to_numpy()


def cells(C, fold):
    """(game, cell id, sign) per block; C [n, 10] champion ids, slot = side * 5 + role. A cell
    is per scored block (fold): only games one model scored, none of which it saw, share it"""
    n = len(C)
    g = np.arange(n)
    blue, red = C[:, :5], C[:, 5:]
    out = {}
    # mains: key champ*5+role
    keys = [blue[:, r] * 5 + r for r in range(5)] + [red[:, r] * 5 + r for r in range(5)]
    signs = [np.ones(n)] * 5 + [-np.ones(n)] * 5
    out["main"] = (np.tile(g, 10), np.concatenate(keys), np.concatenate(signs))
    # ally pairs (i < j), per side
    gs, ks, ss = [], [], []
    for T, sg in ((blue, 1.0), (red, -1.0)):
        for i in range(5):
            for j in range(i + 1, 5):
                ks.append(((T[:, i] * 5 + i) * 5000) + T[:, j] * 5 + j)
                gs.append(g)
                ss.append(np.full(n, sg))
    out["ally"] = (np.concatenate(gs), np.concatenate(ks), np.concatenate(ss))
    # enemy pairs: cell (X,i,Y,j) ordered so the smaller (champ*5+role) comes first; sign + when
    # the first is blue
    for name, same in (("lane", True), ("cross", False)):
        gs, ks, ss = [], [], []
        for i in range(5):
            for j in range(5):
                if (i == j) != same:
                    continue
                a = blue[:, i] * 5 + i
                b = red[:, j] * 5 + j
                first_blue = a < b
                lo = np.where(first_blue, a, b)
                hi = np.where(first_blue, b, a)
                ks.append(lo * 5000 + hi)
                gs.append(g)
                ss.append(np.where(first_blue, 1.0, -1.0))
        out[name] = (np.concatenate(gs), np.concatenate(ks), np.concatenate(ss))
    return {k: (gg, np.unique(kk * 8 + fold[gg], return_inverse=True)[1], s) for k, (gg, kk, s) in out.items()}


class Design:
    """Cells of the scored games, their units (block, band) and per-game memberships"""

    def __init__(self, C, fold):
        self.n = len(C)
        self.B = cells(C, fold)
        self.units = []
        self.unit = {}
        self.members = []
        self.single = {}
        for k in BLOCKS:
            g, c, _ = self.B[k]
            size = np.bincount(c)
            band = np.searchsorted(BANDS[k], size, side="right") - 1
            nb = len(BANDS[k])
            first = len(self.units)
            self.units += [(k, b) for b in range(nb)]
            self.unit[k] = np.where(band >= 0, first + band, -1)
            per_entry = self.unit[k][c]
            self.members += list(np.bincount(per_entry[per_entry >= 0] - first, minlength=nb) / self.n)
            self.single[k] = (per_entry < 0).sum() / self.n
        self.members = np.array(self.members)
        self.U = len(self.units)
        self.first = {k: next(i for i, u in enumerate(self.units) if u[0] == k) for k in BLOCKS}

    def nstat(self, r):
        N = np.zeros(self.U)
        for k in BLOCKS:
            g, c, s = self.B[k]
            m = c.max() + 1
            S = np.bincount(c, s * r[g], m)
            R2 = np.bincount(c, r[g] ** 2, m)
            ok = self.unit[k] >= 0
            N += np.bincount(self.unit[k][ok], (S**2 - R2)[ok], self.U)
        return N

    def eta(self, b):
        """per-game signed sum of cell effects b[block] (arrays over each block's cells)"""
        out = np.zeros(self.n)
        for k in BLOCKS:
            g, c, s = self.B[k]
            out += np.bincount(g, s * b[k][c], self.n)
        return out

    def matrix(self, w, draws, rng):
        M = np.zeros((self.U, self.U))
        for u, (k, _) in enumerate(self.units):
            for _ in range(draws):
                b = {j: np.zeros(len(self.unit[j])) for j in BLOCKS}
                b[k] = np.where(self.unit[k] == u, rng.choice([-1.0, 1.0], len(self.unit[k])), 0.0)
                M[:, u] += self.nstat(w * self.eta(b)) / draws
        return M

    def summary(self, s2):
        """milli-nats a game per block and total"""
        out = {}
        for k in BLOCKS:
            us = [i for i, u in enumerate(self.units) if u[0] == k]
            out[k] = (self.members[us] @ s2[us] + self.single[k] * s2[self.first[k]]) / 8 * 1000
        return out | {"total": sum(out.values())}

    def by_band(self, s2):
        """milli-nats a game per band of the three pair blocks pooled; one-game cells first"""
        out = {"1": sum(self.single[k] * s2[self.first[k]] for k in BLOCKS[1:]) / 8 * 1000}
        for b, start in enumerate(BANDS["ally"]):
            us = [i for i, u in enumerate(self.units) if u[0] != "main" and u[1] == b]
            out[f"{start}+"] = self.members[us] @ s2[us] / 8 * 1000
        return out


def logit(p):
    return np.log(p / (1 - p))


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def logloss(y, p):
    return -(y * np.log(p) + (1 - y) * np.log(1 - p))


def spread(xs, keys=BLOCKS + ["total"]):
    xs = pd.DataFrame(xs)
    return " | ".join(f"{xs[k].mean():+.2f} ± {xs[k].std(ddof=1):.2f}" for k in keys)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("db")
    ap.add_argument("--pred", action="append", required=True, help="NAME=PATH:COL")
    ap.add_argument("--ref", default="")
    ap.add_argument("--sims", type=int, default=20)
    ap.add_argument("--draws", type=int, default=4)
    ap.add_argument("--flip", type=float, default=0.1)
    ap.add_argument("--flip-models", default="")
    ap.add_argument("--blocks", default="1,2,3,4,5,dev")
    ap.add_argument("--plant", type=int, default=0)
    ap.add_argument("--split-models", default="")
    a = ap.parse_args()

    P = None
    for spec in a.pred:
        name, rest = spec.split("=", 1)
        path, col = rest.rsplit(":", 1)
        d = pd.read_csv(path, sep="\t", dtype={"fold": str}, usecols=["fold", "match_id", "y", col])
        d = d.rename(columns={col: name})
        P = d if P is None else P.merge(d.drop(columns=["fold", "y"]), on="match_id", how="inner")
    assert P is not None
    names = [s.split("=", 1)[0] for s in a.pred]
    P = P[P["fold"].isin(a.blocks.split(","))].reset_index(drop=True)
    C = champions(a.db, P["match_id"].tolist())
    ok = ~np.isnan(C).any(1)
    P, C = P[ok].reset_index(drop=True), C[ok].astype(np.int64)
    print(f"{len(P)} games in blocks {a.blocks} ({(~ok).sum()} without five roles a side left out); "
          + ", ".join(f"{f} {c}" for f, c in P["fold"].value_counts().sort_index().items()))
    fold = pd.factorize(P["fold"])[0]
    X = Design(C, fold)
    print("| unit | cells a game | |")
    print("| --- | --- | --- |")
    for (k, b), m in zip(X.units, X.members):
        print(f"| {k} {BANDS[k][b]}+ | {m:.2f} | |")
    for k in BLOCKS:
        print(f"| {k} one-game cells | {X.single[k]:.2f} | |")
    y = P["y"].to_numpy(float)
    rng = np.random.default_rng(7)
    preds = {m: np.clip(P[m].to_numpy(float), EPS, 1 - EPS) for m in names}

    est, ll, Ms, s2s, null_bands = {}, {}, {}, {}, {}
    print("\nmilli-nats a game a perfect estimate of each block would gain over the model (V/8), "
          f"null sd over {a.sims} Bernoulli draws below each")
    print("| model | main | ally | lane | cross | total | log loss | LL - V/8 (perfect) | s of the model |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for m in names:
        p = preds[m]
        w = p * (1 - p)
        Ms[m] = X.matrix(w, a.draws, rng)
        s2s[m] = np.linalg.solve(Ms[m], X.nstat(y - p))
        est[m] = X.summary(s2s[m])
        ll[m] = logloss(y, p)
        perfect = ll[m].mean() - est[m]["total"] / 1000
        s = np.sqrt(max(8 * (LN2 - ll[m].mean()), 0))
        print(f"| {m} | " + " | ".join(f"{est[m][k]:.2f}" for k in BLOCKS + ["total"])
              + f" | {ll[m].mean():.5f} | {perfect:.5f} | {s:.3f} |")
        Minv = np.linalg.inv(Ms[m])
        ns2 = [Minv @ X.nstat((rng.random(len(p)) < p) - p) for _ in range(a.sims)]
        null_bands[m] = pd.DataFrame([X.by_band(v) for v in ns2]).std(ddof=1)
        print("| null | " + spread([X.summary(v) for v in ns2]) + " | | | |", flush=True)

    bands = ["1"] + [f"{b}+" for b in BANDS["ally"]]
    print("\npair blocks' V/8 by the cell's scored games in its block (one-game cells at the smallest band's s2), "
          "± null sd")
    print("| model | " + " | ".join(bands) + " |")
    print("| --- |" + " --- |" * len(bands))
    for m in names:
        bb = X.by_band(s2s[m])
        print(f"| {m} | " + " | ".join(f"{bb[k]:.2f} ± {null_bands[m][k]:.2f}" for k in bands) + " |")

    if a.ref:
        r = a.ref
        lp = ll[r].mean() - est[r]["total"] / 1000
        print(f"\nper band of {r} (sd of a cell's effect, pp at an even game; null sd)")
        print("| unit | s2 | sd (pp) |")
        print("| --- | --- | --- |")
        for (k, b), v in zip(X.units, s2s[r]):
            print(f"| {k} {BANDS[k][b]}+ | {v:.2e} | {25 * np.sqrt(max(v, 0)):.2f} |")
        print(f"\nceiling from {r} (no pair estimates): log loss with the four blocks known "
              f"{ll[r].mean():.5f} - {est[r]['total'] / 1000:.5f} = {lp:.5f}, s {np.sqrt(8 * (LN2 - lp)):.3f}")
        print("| model | log loss vs ref (milli-nats, ± 95%) | left = LL - LL_perfect | own V/8 | own - left | "
              "captured: main | ally | lane | cross |")
        print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
        for m in names:
            dd = (ll[m] - ll[r]) * 1000
            left = (ll[m].mean() - lp) * 1000
            print(f"| {m} | {dd.mean():+.2f} ± {1.96 * dd.std() / np.sqrt(len(dd)):.2f} | {left:.2f} | "
                  f"{est[m]['total']:.2f} | {est[m]['total'] - left:+.2f} | "
                  + " | ".join(f"{est[r][k] - est[m][k]:+.2f}" for k in BLOCKS) + " |")

    flips = [m for m in a.flip_models.split(",") if m]
    if flips:
        f = a.flip
        print(f"\nflips (f = {f}, {a.sims} draws): estimate against the expected shrink")
        print("| model | check | main | ally | lane | cross | total |")
        print("| --- | --- | --- | --- | --- | --- | --- |")
        for m in flips:
            p = preds[m]
            pf = f + (1 - 2 * f) * p
            Mf = X.matrix(pf * (1 - pf), a.draws, rng)
            exp = X.summary(np.linalg.solve(Mf, (1 - 2 * f) ** 2 * Ms[m] @ s2s[m]))
            print(f"| {m} | expected | " + " | ".join(f"{exp[k]:.2f}" for k in BLOCKS + ["total"]) + " |")
            Mfi = np.linalg.inv(Mf)
            xs = [X.summary(Mfi @ X.nstat(np.where(rng.random(len(y)) < f, 1 - y, y) - pf)) for _ in range(a.sims)]
            print(f"| {m} | flipped | " + spread(xs) + " |", flush=True)

    split = [m for m in a.split_models.split(",") if m]
    if split:
        folds = sorted(P["fold"].unique())
        print("\nby block (each alone: cells share games only within it), total V/8")
        print("| model | " + " | ".join(folds) + " |")
        print("| --- |" + " --- |" * len(folds))
        for m in split:
            vals = []
            for fo in folds:
                sel = (P["fold"] == fo).to_numpy()
                Xf = Design(C[sel], fold[sel])
                p = preds[m][sel]
                Mf = Xf.matrix(p * (1 - p), max(a.draws // 2, 1), rng)
                vals.append(Xf.summary(np.linalg.solve(Mf, Xf.nstat(y[sel] - p)))["total"])
            print(f"| {m} | " + " | ".join(f"{v:.2f}" for v in vals) + " |", flush=True)

    if a.plant and a.ref:
        p0 = preds[a.ref]
        w0 = p0 * (1 - p0)
        M0i = np.linalg.inv(Ms[a.ref])
        target = np.maximum(s2s[a.ref], 0)
        print(f"\nplanted cells on {a.ref}'s logit at its per-unit estimates, {a.plant} draws")
        print("| check | main | ally | lane | cross | total |")
        print("| --- | --- | --- | --- | --- | --- |")
        rows = {k: [] for k in ("realised", "recovered", "post-true", "post-V", "post-LL", "under-true", "under-V", "under-LL")}
        for _ in range(a.plant):
            b, sd = {}, {}
            for k in BLOCKS:
                u = X.unit[k]
                sd[k] = np.sqrt(np.where(u >= 0, target[np.maximum(u, 0)], target[X.first[k]]))
                b[k] = rng.normal(0, 1, len(u)) * sd[k]
            pt = np.clip(sigmoid(logit(p0) + X.eta(b)), EPS, 1 - EPS)
            ys = (rng.random(len(pt)) < pt).astype(float)

            def per_game(e):
                out = {}
                for k in BLOCKS:
                    g, c, _ = X.B[k]
                    out[k] = (e[k][c] ** 2).sum() / X.n / 8 * 1000
                return out | {"total": sum(out.values())}

            rows["realised"].append(per_game(b))
            rows["recovered"].append(X.summary(M0i @ X.nstat(ys - p0)))
            for lab, k_noise in (("post", 1.0), ("under", 0.25)):
                bh, err = {}, {}
                for k in BLOCKS:
                    g, c, _ = X.B[k]
                    W = np.maximum(np.bincount(c, w0[g], len(X.unit[k])), 1e-3)
                    if k == "main":
                        bh[k] = b[k]
                    else:
                        lam = sd[k] ** 2 / (sd[k] ** 2 + k_noise / W)
                        bh[k] = lam * (b[k] + rng.normal(0, 1, len(W)) / np.sqrt(W))
                    err[k] = b[k] - bh[k]
                pm = np.clip(sigmoid(logit(p0) + X.eta(bh)), EPS, 1 - EPS)
                Mm = X.matrix(pm * (1 - pm), 1, rng)
                rows[f"{lab}-true"].append(per_game(err))
                rows[f"{lab}-V"].append(X.summary(np.linalg.solve(Mm, X.nstat(ys - pm))))
                rows[f"{lab}-LL"].append({"total": (logloss(ys, pm).mean() - logloss(ys, pt).mean()) * 1000})
            print(".", end="", flush=True)
        print()
        labels = {"realised": "planted, realised", "recovered": "recovered",
                  "post-true": "model, posterior-mean shrink: true excess", "post-V": "model, posterior-mean shrink: V/8",
                  "under-true": "model, shrunk 1/4 as much: true excess", "under-V": "model, shrunk 1/4 as much: V/8"}
        for key, lab in labels.items():
            print(f"| {lab} | " + spread(rows[key]) + " |")
        for key, lab in (("post-LL", "posterior-mean"), ("under-LL", "shrunk 1/4 as much")):
            print(f"| model, {lab}: log loss minus the truth's | | | | | " + spread(rows[key], ["total"]) + " |")


if __name__ == "__main__":
    main()
