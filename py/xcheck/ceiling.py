"""Draft ceiling by variance accounting (lab-frontier B1).

How much signal is left in held-out residuals r = y - p of a model, by block: champion-role
mains (10 cells a game), ally role pairs (20), lane matchups (5: same role, both sides) and
cross-role enemy pairs (20). Model: true logit = model logit + sum of cell effects b_c
(signed: + when the cell's first champion is blue), b_c of block k with variance s2_k.
Then E[r] ~ w b (w = p(1 - p)), and for two games g != h sharing cell c,
E[s_g s_h r_g r_h] = w_g w_h * (sum of b^2 over every cell they share).

Per block B: N_B = sum over cells (S_c^2 - sum r^2), S_c = sum s r (games sharing a cell, all
pairs); D_B = sum over cells (W_c^2 - sum w^2). Games sharing a pair cell also share its
two mains, so (higher overlaps ignored):
  E[N_m] = s2_m (D_m + 2 sum_k D_k) + sum_k 2 D_k s2_k
  E[N_k] = D_k (2 s2_m + s2_k)          k in ally, lane, cross
solved for s2. Per-game signal variance V = 10 s2_m + 20 s2_a + 5 s2_l + 20 s2_x, worth
~V/8 nats of log loss a game (calibrated logit of sd s: gain over a coin ~s^2/8).

Checks: nulls (y* ~ Bernoulli(p): estimates ~0, their sd is the noise), and planted flips
(a share f of labels flipped at random shrinks the residual signal by (1 - 2f)^2).

Usage: ceiling.py SNAP_DB PREDS COL [COL...] [--sims N] [--blocks 2,3,4,5,dev]
"""

import argparse
import sqlite3

import numpy as np
import pandas as pd

ROLES = {"TOP": 0, "JUNGLE": 1, "MIDDLE": 2, "BOTTOM": 3, "UTILITY": 4}
EPS = 1e-6


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


def cells(C):
    """(game, cell id, sign) per block; C [n, 10] champion ids, slot = side * 5 + role"""
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
    for side, T, sg in ((0, blue, 1.0), (1, red, -1.0)):
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
    return {k: (gg, np.unique(kk, return_inverse=True)[1], s) for k, (gg, kk, s) in out.items()}


BLOCKS = ["main", "ally", "lane", "cross"]
PER_GAME = {"main": 10, "ally": 20, "lane": 5, "cross": 20}


def stats(blk, r, w):
    g, c, s = blk
    m = c.max() + 1
    S = np.bincount(c, s * r[g], m)
    R2 = np.bincount(c, r[g] ** 2, m)
    W = np.bincount(c, w[g], m)
    W2 = np.bincount(c, w[g] ** 2, m)
    return (S**2 - R2).sum(), (W**2 - W2).sum()


def solve(B, r, w):
    N, D = {}, {}
    for k in BLOCKS:
        N[k], D[k] = stats(B[k], r, w)
    pairs = BLOCKS[1:]
    # unknowns s2 in BLOCKS order
    A = np.zeros((4, 4))
    y = np.array([N[k] for k in BLOCKS])
    A[0, 0] = D["main"] + 2 * sum(D[k] for k in pairs)
    for i, k in enumerate(pairs, 1):
        A[0, i] = 2 * D[k]
        A[i, 0] = 2 * D[k]
        A[i, i] = D[k]
    s2 = np.linalg.solve(A, y)
    return dict(zip(BLOCKS, s2))


def summary(s2):
    V = sum(PER_GAME[k] * s2[k] for k in BLOCKS)
    return V, {k: PER_GAME[k] * s2[k] / 8 * 1000 for k in BLOCKS}, V / 8 * 1000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("db")
    ap.add_argument("preds")
    ap.add_argument("cols", nargs="+")
    ap.add_argument("--sims", type=int, default=20)
    ap.add_argument("--blocks", default="")
    ap.add_argument("--flip", type=float, default=0.1)
    a = ap.parse_args()
    P = pd.read_csv(a.preds, sep="\t", dtype={"fold": str})
    if a.blocks:
        P = P[P["fold"].isin(a.blocks.split(","))]
    C = champions(a.db, P["match_id"].tolist())
    ok = ~np.isnan(C).any(1)
    P, C = P[ok].reset_index(drop=True), C[ok].astype(np.int64)
    print(f"{len(P)} games ({(~ok).sum()} without five roles a side left out)")
    B = cells(C)
    for k in BLOCKS:
        print(f"  {k}: {B[k][1].max() + 1} cells")
    y = P["y"].to_numpy(float)
    rng = np.random.default_rng(7)
    print("\nmilli-nats a game a perfect estimate of the block would gain (V/8), null mean ± sd over sims")
    print("| model | main | ally | lane | cross | total | s total | flip f -> expected |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for col in a.cols:
        p = np.clip(P[col].to_numpy(float), EPS, 1 - EPS)
        w = p * (1 - p)
        V, per, tot = summary(solve(B, y - p, w))
        nulls = []
        for _ in range(a.sims):
            ys = (rng.random(len(p)) < p).astype(float)
            _, nper, ntot = summary(solve(B, ys - p, w))
            nulls.append([nper[k] for k in BLOCKS] + [ntot])
        nulls = np.array(nulls)
        sd = dict(zip(BLOCKS + ["total"], nulls.std(0, ddof=1)))
        mean = dict(zip(BLOCKS + ["total"], nulls.mean(0)))
        flip = rng.random(len(y)) < a.flip
        yf = np.where(flip, 1 - y, y)
        # flipped labels: E[y_f] = f + (1 - 2f) E[y]; residual against the shrunk model
        pf = a.flip + (1 - 2 * a.flip) * p
        _, _, tf = summary(solve(B, yf - pf, pf * (1 - pf)))
        print(
            f"| {col} | {per['main']:.2f} | {per['ally']:.2f} | {per['lane']:.2f} | {per['cross']:.2f} | "
            f"{tot:.2f} | {np.sqrt(max(V, 0)):.3f} | {tf:.2f} -> {tot * (1 - 2 * a.flip) ** 2:.2f} |"
        )
        print("| null mean ± sd | " + " | ".join(f"{mean[k]:+.2f} ± {sd[k]:.2f}" for k in BLOCKS + ["total"]) + " | | |")


if __name__ == "__main__":
    main()
