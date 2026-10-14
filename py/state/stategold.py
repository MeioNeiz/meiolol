"""Gold equivalents of the live state: what a dragon, a tower, a player dead now... is worth
in team gold lead at each minute, with the draft in the model.

Per bucket minute, one row per game going then (dev-visible games with a timeline), a
logistic regression on one column per thing (blue minus red), each counted once: team
gold lead (thousands) and its curve term, XP lead (thousands), elemental dragons, soul
point, soul, elder and baron buff active, barons taken, towers by tier (outer, inner,
base, nexus), inhibitors down now, grubs, heralds, players dead now, kills, completed
items, plates, control wards placed, the draft logit. Value of one more = weight /
gold weight x 1000 (at an even game, where the curve term has no slope). 95% intervals
from 100 Poisson bootstraps over games. Association: teams that take things differ in
ways the state misses (objectives.zig's caveat).

usage: stategold.py SNAP [--out DIR] [--buckets 5,10,15,20,25,30] [--boot 100]
"""

import argparse
import os

import numpy as np
from joblib import Parallel, delayed
from sklearn.linear_model import LogisticRegression

import nnsets
import statecommon as sc

TIERS = ["outer", "inner", "base"]
MIN_GAMES = 300


def design(state, S, logit):
    c = state.cols

    def g(n):
        return S[:, c[n]]

    def side(f):
        return sum(g(f"s{s}_{f}") for s in range(5)) - sum(g(f"s{5 + s}_{f}") for s in range(5))

    def team(f):
        return g(f"b_{f}") - g(f"r_{f}")

    cols = {
        "1000 gold lead": g("obj_gold"),
        "gold curve": g("obj_gold_curve"),
        "1000 XP lead": g("obj_xp"),
        "elemental dragon": g("obj_dragons"),
        "soul point": g("obj_soul_point"),
        "soul": g("obj_soul"),
        "elder buff active": g("obj_elder"),
        "baron buff active": g("obj_baron"),
        "baron taken": team("barons"),
        "nexus tower": team("tower_nexus"),
        "inhibitor down now": g("obj_inhibs_down"),
        "grub": g("obj_grubs"),
        "herald": g("obj_herald"),
        "player dead now": sum((g(f"s{s}_respawn_s") > 0).astype(np.float32) for s in range(5))
        - sum((g(f"s{5 + s}_respawn_s") > 0).astype(np.float32) for s in range(5)),
        "kill": team("kills"),
        "completed item": side("legendaries"),
        "plate": team("plates"),
        "control ward placed": side("ctrl_wards"),
        "draft logit +0.1": logit * 10,
    }
    for t in TIERS:
        cols[f"{t} tower"] = sum(team(f"tower_{lane}_{t}") for lane in sc.LANES)
    names = list(cols)
    return np.stack([np.asarray(cols[n], np.float64) for n in names], 1), names


def fit(X, y, w=None):
    """Raw-unit weights; fitted on standardised columns, which lbfgs needs to converge"""
    sd = X.std(0)
    m = LogisticRegression(C=1e4, max_iter=1000, tol=1e-7).fit(X / sd, y, sample_weight=w)
    return m.coef_[0] / sd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--buckets", default="5,10,15,20,25,30")
    ap.add_argument("--boot", type=int, default=100)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    threads = int(os.environ.get("OMP_NUM_THREADS", "8") or 8)
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    played = (data.flags & nnsets.PLAYED) != 0
    games = np.flatnonzero(played & has_tl & (data.split <= 6))
    cut = nnsets.val_cut(data.start[games])
    fake = nnsets.Sets("gold", games, games[data.start[games] < cut], games[data.start[games] >= cut], np.array([], np.int64))
    logit, _, _ = sc.draft_logits(data, fake)
    table = {}
    names = None
    for m in map(int, a.buckets.split(",")):
        S = state.block(m, games)
        going = ~np.isnan(S[:, 0])
        X, names = design(state, S[going], logit[games[going]])
        y = data.y[games[going]].astype(np.float64)
        # a column only where 300+ games differ on it (rare cells give wild ratios)
        keep = (X != 0).sum(0) >= MIN_GAMES
        w0 = np.zeros(X.shape[1])
        w0[keep] = fit(X[:, keep], y)
        rng = np.random.default_rng(m)
        seeds = rng.integers(0, 2**31, a.boot)

        def one(s):
            w = np.zeros(X.shape[1])
            w[keep] = fit(X[:, keep], y, np.random.default_rng(s).poisson(1.0, len(y)))
            return w

        W = np.array(Parallel(n_jobs=threads)(delayed(one)(s) for s in seeds))
        g = names.index("1000 gold lead")
        eq = 1000 * W / W[:, [g]]
        lo, hi = np.percentile(eq, [2.5, 97.5], 0)
        table[m] = (1000 * w0 / w0[g], lo, hi, keep, going.sum(), w0[g])
        print(f"minute {m}: {going.sum()} games, 1000 gold = {w0[g]:.3f} log-odds", flush=True)
    mins = list(table)
    lines = ["# Gold equivalents of the live state (team gold lead worth the same, at an even game)", "",
             "Logistic per minute on one column per thing, blue minus red, with the draft logit; ± 95% from game bootstraps. "
             "Association, not proof the thing caused the win.", "",
             "| thing | " + " | ".join(f"{m}:00" for m in mins) + " |", "| --- |" + " --- |" * len(mins)]
    lines.append("| games | " + " | ".join(f"{table[m][4]}" for m in mins) + " |")
    lines.append("| 1000 gold, log-odds | " + " | ".join(f"{table[m][5]:.3f}" for m in mins) + " |")
    for i, n in enumerate(names):
        if n in ("1000 gold lead", "gold curve"):
            continue
        cells = []
        for m in mins:
            v, lo, hi, keep, _, _ = table[m]
            cells.append(f"{v[i]:.0f} [{lo[i]:.0f}, {hi[i]:.0f}]" if keep[i] else "-")
        lines.append(f"| {n} | " + " | ".join(cells) + " |")
    text = "\n".join(lines) + "\n"
    with open(os.path.join(a.out, "gold.md"), "w") as f:
        f.write(text)
    print(text, flush=True)


if __name__ == "__main__":
    main()
