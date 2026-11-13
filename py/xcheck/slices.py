"""Paired model differences per slice, from one `effects --a10 1` run (A10 (a), D1).

    slices.py RUN_DIR BASE=MODEL ... [--picks BASE=MODEL ...]

Each BASE=MODEL pairs games-MODEL.tsv against games-BASE.tsv per game: milli-nats a game
(MODEL minus BASE, negative better) +- 1.96 se over games, for dev-val and the folds
pooled, overall and per slice from games-meta.tsv: rank bracket (median rank_start of
6+ known seats), EUW1, and the fewest fit games among the ten champion-roles (rare
under 100, thin 100-999, common 1000+), and by seats with a pre-game mastery fetch when
the meta has known_seats; each block's overall under the table. --picks: the pick metric from picks-*.tsv
(dev-val sample): AUC of the real pick's percentile, winners against losers, the top-10%
win rate, and MODEL minus BASE in AUC with a game bootstrap interval. Markdown out.
"""

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd


def games(run, model):
    g = pd.read_csv(run / f"games-{model}.tsv", sep="\t")
    g = g[g["outcome"] == "win"]
    p = g["pred"].clip(1e-6, 1 - 1e-6)
    g["loss"] = -(g["y"] * np.log(p) + (1 - g["y"]) * np.log(1 - p))
    return g.set_index(["block", "match_id"])["loss"]


def slices(meta):
    m = meta.copy()
    m["euw1"] = m["match_id"].str.startswith("EUW1_")
    n = m["min_fit_games"]
    m["pop"] = np.where(n < 100, "rare", np.where(n < 1000, "thin", "common"))
    out = {"all": np.ones(len(m), bool)}
    for b in ["iron-silver", "gold-emerald", "diamond+", "unknown"]:
        out[b] = (m["bracket"] == b).to_numpy()
    out["EUW1"] = m["euw1"].to_numpy()
    for p in ["rare", "thin", "common"]:
        out[p] = (m["pop"] == p).to_numpy()
    if "known_seats" in m:
        k = m["known_seats"].to_numpy()
        out["no seat's mastery known"] = k == 0
        out["1+ seats known"] = k > 0
        out["all ten known"] = k == 10
    return out


def cell(d):
    if len(d) < 2:
        return "", len(d)
    se = d.std(ddof=1) / math.sqrt(len(d))
    return f"{1000 * d.mean():+.2f} ± {1000 * 1.96 * se:.2f}", len(d)


def auc(pct, won):
    r = pd.Series(pct).rank().to_numpy()
    nw = won.sum()
    nl = len(won) - nw
    return (r[won].sum() - nw * (nw + 1) / 2) / (nw * nl)


def picks(run, base, model, reps=200):
    a = pd.read_csv(run / f"picks-{base}.tsv", sep="\t")
    b = pd.read_csv(run / f"picks-{model}.tsv", sep="\t")
    k = ["match_id", "side", "role"]
    x = a.merge(b, on=k + ["won"], suffixes=("_a", "_b")).dropna()
    won = x["won"].to_numpy() == 1
    res = {}
    for s in ["a", "b"]:
        q = x[f"pct_{s}"].to_numpy()
        top = q >= 0.9
        res[s] = (auc(q, won), won[top].mean(), top.sum())
    ids = x["match_id"].to_numpy()
    uniq, inv = np.unique(ids, return_inverse=True)
    rng = np.random.default_rng(0xa10)
    diffs = []
    qa, qb = x["pct_a"].to_numpy(), x["pct_b"].to_numpy()
    for _ in range(reps):
        w = rng.poisson(1, len(uniq))[inv]
        sel = np.repeat(np.arange(len(x)), w)
        diffs.append(auc(qb[sel], won[sel]) - auc(qa[sel], won[sel]))
    lo, hi = np.percentile(diffs, [2.5, 97.5])
    return len(x), res, res["b"][0] - res["a"][0], lo, hi


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run", type=Path)
    ap.add_argument("pairs", nargs="+")
    ap.add_argument("--picks", nargs="*", default=[])
    o = ap.parse_args()
    meta = pd.read_csv(o.run / "games-meta.tsv", sep="\t").set_index(["block", "match_id"])
    for spec in o.pairs:
        base, model = spec.split("=")
        a, b = games(o.run, base), games(o.run, model)
        d = (b - a).reindex(meta.index)
        print(f"\n### {model} minus {base}, milli-nats a game\n")
        print("| slice | dev-val | games | folds pooled | games |")
        print("| --- | --: | --: | --: | --: |")
        dev = (meta.index.get_level_values(0) == "dev")
        m = meta.reset_index()
        for name, mask in slices(m).items():
            dv, nd = cell(d[mask & dev].dropna())
            fo, nf = cell(d[mask & ~dev].dropna())
            print(f"| {name} | {dv} | {nd:,} | {fo} | {nf:,} |")
        blocks = meta.index.get_level_values(0)
        per = [f"{b} {cell(d[blocks == b].dropna())[0]}" for b in sorted(set(blocks))]
        print("\nPer block: " + ", ".join(per))
    for spec in o.picks:
        base, model = spec.split("=")
        n, res, dd, lo, hi = picks(o.run, base, model)
        print(f"\n### Pick metric, {model} vs {base} (dev-val sample, {n:,} picks)\n")
        print("| model | AUC | top-10% win rate | top-10% picks |")
        print("| --- | --: | --: | --: |")
        for s, label in [("a", base), ("b", model)]:
            print(f"| {label} | {res[s][0]:.4f} | {100 * res[s][1]:.1f}% | {res[s][2]:,} |")
        print(f"\nAUC {model} minus {base}: {dd:+.4f} (95% {lo:+.4f} to {hi:+.4f})")


if __name__ == "__main__":
    main()
