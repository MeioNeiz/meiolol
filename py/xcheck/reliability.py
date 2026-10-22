"""How much of a site table's win rates is signal (lab-frontier B4).

Per table (champion-role, lane matchup, bot-support duo; per patch and over all games),
cells' win rates vary for two reasons: true differences (sd tau) and luck (binomial,
p(1-p)/n). Rare cells differ more (off-role picks), so per band of cell games: tau^2 by
method of moments (weighted var of the cell rates around the table mean minus the mean
luck variance), the reliability of a cell of the band's median n, n tau^2 / (n tau^2 +
p(1-p)), and split-half reliability (halves hashed by game, Spearman-Brown 2r / (1 + r)),
which needs no model.

Usage: reliability.py SNAP_DB
"""

import sqlite3
import sys

import numpy as np
import pandas as pd

ROLES = {"TOP": 0, "JUNGLE": 1, "MIDDLE": 2, "BOTTOM": 3, "UTILITY": 4}


def load(db):
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    q = """SELECT p.match_id, m.patch, p.team_id, p.position, p.champion_id, m.winning_team
           FROM participants p JOIN matches m USING (match_id)
           WHERE m.queue_id = 420 AND m.remake = 0 AND m.duration_s >= 900"""
    df = pd.DataFrame(con.execute(q).fetchall(), columns=["match_id", "patch", "team", "pos", "champ", "winner"])
    df["role"] = df["pos"].map(ROLES)
    df = df.dropna(subset=["role"])
    df["slot"] = (df["team"] != 100).astype(int) * 5 + df["role"].astype(int)
    wide = df.pivot_table(index="match_id", columns="slot", values="champ", aggfunc="first").dropna()
    meta = df.drop_duplicates("match_id").set_index("match_id").loc[wide.index]
    C = wide.to_numpy().astype(np.int64)
    blue_win = (meta["winner"].to_numpy() == 100).astype(float)
    half = (pd.util.hash_array(wide.index.to_numpy()) % 2).astype(int)
    return C, blue_win, meta["patch"].to_numpy(), half


def tables(C, y):
    """(cell key, win 0/1) per appearance, one frame per table"""
    blue, red = C[:, :5], C[:, 5:]
    out = {}
    k, w = [], []
    for r in range(5):
        k += [blue[:, r] * 5 + r, red[:, r] * 5 + r]
        w += [y, 1 - y]
    out["champion-role"] = (np.concatenate(k), np.concatenate(w), np.tile(np.arange(len(y)), 10))
    k, w = [], []
    for r in range(5):
        k += [(blue[:, r] * 5 + r) * 10000 + red[:, r], (red[:, r] * 5 + r) * 10000 + blue[:, r]]
        w += [y, 1 - y]
    out["lane matchup"] = (np.concatenate(k), np.concatenate(w), np.tile(np.arange(len(y)), 10))
    k = [blue[:, 3] * 10000 + blue[:, 4], red[:, 3] * 10000 + red[:, 4]]
    out["bot-support duo"] = (np.concatenate(k), np.concatenate([y, 1 - y]), np.tile(np.arange(len(y)), 2))
    return out


BANDS = ((20, 50), (50, 150), (150, 500), (500, 2000), (2000, 10**9))


def bands(keys, wins, game, half):
    """Per band of cell games n: cells, median n, tau (method of moments within the band)
    and its reliability at the median n, and split-half Spearman-Brown 2r / (1 + r)"""
    d = pd.DataFrame({"k": keys, "w": wins, "h": half[game]})
    s = d.groupby("k")["w"].agg(["sum", "count"])
    m = s["sum"].sum() / s["count"].sum()
    hs = d.groupby(["k", "h"])["w"].agg(["sum", "count"]).unstack("h").reindex(s.index)
    rows = []
    for lo, hi in BANDS:
        sel = (s["count"] >= lo) & (s["count"] < hi)
        if sel.sum() < 30:
            continue
        c = s[sel]
        p = c["sum"] / c["count"]
        t2 = np.average((p - m) ** 2 - m * (1 - m) / c["count"], weights=c["count"])
        n = c["count"].median()
        rel = n * t2 / (n * t2 + m * (1 - m)) if t2 > 0 else 0.0
        h = hs[sel].dropna()
        p0 = h["sum"][0] / h["count"][0]
        p1 = h["sum"][1] / h["count"][1]
        r = np.corrcoef(p0, p1)[0, 1]
        rows.append((f"{lo}-{hi if hi < 10**9 else ''}", int(sel.sum()), n, np.sqrt(max(t2, 0)) * 100, rel, 2 * r / (1 + r)))
    return rows


def main():
    C, y, patch, half = load(sys.argv[1])
    print(f"{len(y)} games")
    scopes = [("all games", np.ones(len(y), bool))] + [
        (f"patch {p}", patch == p) for p in sorted(set(patch)) if (patch == p).sum() > 50000
    ]
    print("| table | scope | cell games | cells | median n | tau (pp) | reliability, formula | split-half |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for name, sel in scopes:
        idx = np.flatnonzero(sel)
        for t, (keys, wins, game) in tables(C[sel], y[sel]).items():
            for band, cells, n, tau, rel, sb in bands(keys, wins, game, half[idx]):
                print(f"| {t} | {name} | {band} | {cells} | {n:.0f} | {tau:.2f} | {rel:.2f} | {sb:.2f} |")


if __name__ == "__main__":
    main()
