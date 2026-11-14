"""Calibration of Your games' win chance by minute on games after the fit (docs/model.md
"Win chance by minute on later patches").

Reads `meiolol-lab state-calib` TSVs (match, platform, patch, duration_s, minute, p_richc,
p_wc, blue_win). Per stratum and minute block: calibration in the large (mean chance -
blue's win rate, points), slope (logistic of the result on the chance's logit), ECE over
10 equal-mass bins, each with a 95% range from DRAWS whole-game bootstrap draws; log loss
and AUC against winchance as context. The reading per stratum over the blocks to 29 min:
holds (every slope range overlaps 0.9-1.1, |in the large| < 1 point, ECE <= 0.015), off
(a slope range outside 0.9-1.1 or |in the large| > 2 points), else between.

Bootstrap draws reuse the full sample's ECE bin edges and score the slope on a grid of
600 logit cells (the point estimate is exact; the grid's own is printed beside it).

--base NAME=TSV: another model file's chances for NAME's games (state-calib --model on
the same games): each cell also gets the base's in the large and slope, and the paired
log loss difference per game-minute (NAME's minus the base's) with its range, also over
every minute 0-40 (block 0-40; not part of the reading).

TSVs with rank_known and rank_mean (state-calib --ranks) add strata by rank at game
start: games with RANK_SEATS+ seats known, by those seats' mean rank.

usage: calib.py OUT.tsv NAME=TSV[,TSV...] ... [--base NAME=TSV[,TSV...]]... [--draws 1000]
  strata per NAME: every patch in it, and EUW1 alone; games under 15:00 over all files
"""

import argparse

import numpy as np
import pandas as pd

BLOCKS = [(0, 0), (1, 4), (5, 9), (10, 14), (15, 19), (20, 24), (25, 29), (30, 40), (0, 40)]
RANK_SEATS = 8
# Mean packed rank (0 Challenger I, 12 Diamond I, 16 Emerald I, 20 Platinum I) below the bound
BRACKETS = [("Master+", 12), ("Diamond", 16), ("Emerald", 20), ("Platinum", 24)]
GRID = 600
SPAN = 7.5
MIN_GAMES = 500


def newton(x, pos, n, iters=8):
    """Intercept and slope of a logistic fit: pos wins of n at logit x; nan when every
    x is the same"""
    if np.ptp(x[n > 0]) < 1e-9:
        return np.nan, np.nan
    a, b = 0.0, 1.0
    for _ in range(iters):
        mu = 1 / (1 + np.exp(-(a + b * x)))
        r = pos - n * mu
        v = n * mu * (1 - mu)
        h = np.array([[v.sum(), (v * x).sum()], [(v * x).sum(), (v * x * x).sum()]])
        step = np.linalg.solve(h, np.array([r.sum(), (r * x).sum()]))
        a, b = a + step[0], b + step[1]
    return a, b


def auc(p, y):
    k = np.round(p * 1e5).astype(np.int64)
    pos = np.bincount(k, y, 100001)
    neg = np.bincount(k, 1 - y, 100001)
    below = np.cumsum(neg) - neg
    return float((pos * (below + neg / 2)).sum() / (pos.sum() * neg.sum()))


def logloss(p, y):
    p = np.clip(p, 1e-5, 1 - 1e-5)
    return float(-(y * np.log(p) + (1 - y) * np.log(1 - p)).mean())


def cell(d, draws, rng):
    """One stratum x block. d: rows with game (0..), p_richc, p_wc, blue_win, and p_base
    when a base was given"""
    game = d["g"].to_numpy()
    games = int(game.max()) + 1
    y = d["blue_win"].to_numpy(float)
    p = np.clip(d["p_richc"].to_numpy(float), 1e-5, 1 - 1e-5)
    x = np.log(p / (1 - p))
    fine = np.clip(((x + SPAN) / (2 * SPAN) * GRID).astype(np.int64), 0, GRID - 1)
    count = np.bincount(fine, minlength=GRID)
    centre = np.bincount(fine, x, GRID) / np.maximum(count, 1)
    edges = np.quantile(p, np.linspace(0, 1, 11)[1:-1])
    tenth = np.searchsorted(edges, p, side="right")
    paired = "p_base" in d and bool(d["p_base"].notna().all())
    if paired:
        pb = np.clip(d["p_base"].to_numpy(float), 1e-5, 1 - 1e-5)
        xb = np.log(pb / (1 - pb))
        fine_b = np.clip(((xb + SPAN) / (2 * SPAN) * GRID).astype(np.int64), 0, GRID - 1)
        centre_b = np.bincount(fine_b, xb, GRID) / np.maximum(np.bincount(fine_b, minlength=GRID), 1)
        dll = -(y * np.log(p / pb) + (1 - y) * np.log((1 - p) / (1 - pb)))

    def stats(w):
        n = np.bincount(tenth, w, 10)
        sp = np.bincount(tenth, w * p, 10)
        sy = np.bincount(tenth, w * y, 10)
        _, slope = newton(centre, np.bincount(fine, w * y, GRID), np.bincount(fine, w, GRID))
        out = [100 * (sp.sum() - sy.sum()) / n.sum(), slope, np.abs(sp - sy).sum() / n.sum()]
        if paired:
            _, slope_b = newton(centre_b, np.bincount(fine_b, w * y, GRID), np.bincount(fine_b, w, GRID))
            out += [(w * dll).sum() / w.sum(), 100 * (w * (pb - y)).sum() / w.sum(), slope_b, abs(slope - 1) - abs(slope_b - 1)]
        return out

    point = stats(np.ones(len(y)))
    large, grid_slope, ece = point[:3]
    _, slope = newton(x, y, np.ones(len(y)))
    boot = np.empty((draws, len(point)))
    for i in range(draws):
        boot[i] = stats(rng.multinomial(games, np.full(games, 1 / games))[game].astype(float))
    lo, hi = np.percentile(boot, [2.5, 97.5], axis=0)
    base = {}
    if paired:
        base = {
            "dll": point[3],
            "dll_lo": lo[3],
            "dll_hi": hi[3],
            "large_base": point[4],
            "large_base_lo": lo[4],
            "large_base_hi": hi[4],
            "slope_base": newton(xb, y, np.ones(len(y)))[1],
            "slope_base_lo": lo[5],
            "slope_base_hi": hi[5],
            # |slope - 1| minus the base's: below 0 = nearer 1
            "slope_gap": point[6],
            "slope_gap_lo": lo[6],
            "slope_gap_hi": hi[6],
        }
    has_wc = d["p_wc"].notna().to_numpy()
    wc = d["p_wc"].to_numpy(float)[has_wc]
    return {
        "games": int(d["g"].nunique()),
        "rows": len(y),
        "blue_win": y.mean(),
        "large": large,
        "large_lo": lo[0],
        "large_hi": hi[0],
        "slope": slope,
        "slope_grid": grid_slope,
        "slope_lo": lo[1],
        "slope_hi": hi[1],
        "ece": ece,
        "ece_lo": lo[2],
        "ece_hi": hi[2],
        "ll": logloss(p, y),
        "ll_wc_rows": logloss(p[has_wc], y[has_wc]) if has_wc.any() else np.nan,
        "ll_wc": logloss(wc, y[has_wc]) if has_wc.any() else np.nan,
        "auc": auc(p, y),
        "auc_wc": auc(wc, y[has_wc]) if has_wc.any() else np.nan,
    } | base


def reading(rows):
    """The declared rule over a stratum's blocks to 29 min"""
    early = [r for r in rows if r["to"] <= 29]
    if any(r["slope_hi"] < 0.9 or r["slope_lo"] > 1.1 or abs(r["large"]) > 2 for r in early):
        return "off"
    if all(abs(r["large"]) < 1 and r["ece"] <= 0.015 for r in early):
        return "holds"
    return "between"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("sets", nargs="+")
    ap.add_argument("--draws", type=int, default=1000)
    ap.add_argument("--base", action="append", default=[])
    a = ap.parse_args()
    rng = np.random.default_rng(20261113)

    def read(paths):
        d = pd.concat([pd.read_csv(p, sep="\t", dtype={"patch": str}) for p in paths.split(",")])
        return d.drop_duplicates(["match", "minute"])

    bases = dict(b.split("=") for b in a.base)
    strata = []
    frames = []
    for s in a.sets:
        name, paths = s.split("=")
        d = read(paths)
        if name in bases:
            b = read(bases[name])[["match", "minute", "p_richc"]].rename(columns={"p_richc": "p_base"})
            both = d.merge(b, on=["match", "minute"])
            assert len(both) == len(d) == len(b), (name, len(d), len(b), len(both))
            d = both
        frames.append(d)
        for patch, dp in d.groupby("patch"):
            strata.append((f"{name} {patch}", dp))
            strata.append((f"{name} {patch} EUW1", dp[dp["platform"] == "EUW1"]))
            if "rank_mean" in dp:
                known = dp[dp["rank_known"] >= RANK_SEATS]
                lo = -1.0
                for bracket, hi in BRACKETS:
                    strata.append((f"{name} {patch} {bracket}", known[(known["rank_mean"] >= lo) & (known["rank_mean"] < hi)]))
                    lo = hi
    every = pd.concat(frames).drop_duplicates(["match", "minute"])
    strata.append(("under 15:00", every[every["duration_s"] < 900]))

    out = []
    for name, d in strata:
        d = d.assign(g=pd.factorize(d["match"])[0])
        games = d["g"].nunique()
        if games < MIN_GAMES:
            print(f"{name}: {games} games, under {MIN_GAMES}: skipped")
            continue
        rows = []
        for lo, hi in BLOCKS:
            b = d[(d["minute"] >= lo) & (d["minute"] <= hi)]
            if b["g"].nunique() < MIN_GAMES:
                continue
            rows.append({"stratum": name, "from": lo, "to": hi} | cell(b, a.draws, rng))
        if not rows:
            continue
        read = reading(rows)
        print(f"\n{name}: {games} games: {read}")
        for r in rows:
            r["reading"] = read
            print(
                f"  {r['from']:>2}-{r['to']:<2} games {r['games']:>6}"
                f"  large {r['large']:+.2f} [{r['large_lo']:+.2f}, {r['large_hi']:+.2f}]"
                f"  slope {r['slope']:.3f} [{r['slope_lo']:.3f}, {r['slope_hi']:.3f}]"
                f" (grid {r['slope_grid']:.3f})"
                f"  ece {r['ece']:.4f} [{r['ece_lo']:.4f}, {r['ece_hi']:.4f}]"
                f"  ll {r['ll']:.4f} wc {r['ll_wc']:.4f}  auc {r['auc']:.4f} wc {r['auc_wc']:.4f}"
            )
            if "dll" in r:
                print(
                    f"        vs base: ll {r['dll']:+.5f} [{r['dll_lo']:+.5f}, {r['dll_hi']:+.5f}]"
                    f"  base large {r['large_base']:+.2f} [{r['large_base_lo']:+.2f}, {r['large_base_hi']:+.2f}]"
                    f"  base slope {r['slope_base']:.3f} [{r['slope_base_lo']:.3f}, {r['slope_base_hi']:.3f}]"
                    f"  |slope-1| gap {r['slope_gap']:+.3f} [{r['slope_gap_lo']:+.3f}, {r['slope_gap_hi']:+.3f}]"
                )
        out += rows
    pd.DataFrame(out).to_csv(a.out, sep="\t", index=False, float_format="%.5f")


if __name__ == "__main__":
    main()
