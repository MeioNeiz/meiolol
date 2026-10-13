"""What matters in the live state, by minute (meiolol-research's design, correlated-importance).

Per bucket minute (5, 10, 15, 20, 25, 30) one row per game going then, dev-visible games
with a timeline (splits 0-6: no selection or test games), 5-fold cross-fitting by game.
Value of a set of groups = log-loss skill (base rate's log loss minus the model's) of a
logistic regression on those groups' features, out of fold. Per group:
- unique: full minus the refit without the group (what only it carries)
- alone: the group by itself
- Shapley: exact over all 2^8 subsets of the eight groups
The gap between unique and alone is signal the group shares with others; no method
assigns it without a convention (Shapley is one). Intervals: per-game contributions
(Shapley is linear in the per-game skill), 95%, clustered by game by construction.
LightGBM unique and alone beside it as a check of the learner. "win pp" is the spread
(sd over games) of the group's part of the full model's logit, times 25 (pp per unit
logit at even odds): how far the group typically moves the win chance there.
Gold equivalents: a logistic with the team gold lead in thousands in place of the per-role
gold, value of one more of X = weight(X) / weight(gold) * 1000.
Writes OUT/imp.md, OUT/imp.tsv.

usage: stateimp.py SNAP [--out DIR] [--buckets 5,10,15,20,25,30] [--no-gbdt]
"""

import argparse
import itertools
import math
import os
import time

import numpy as np
from joblib import Parallel, delayed
from sklearn.linear_model import LogisticRegression

import nnsets
import statecommon as sc

GROUPS = ["draft", "economy", "xp", "fights", "structures", "dragons", "neutral", "vision"]
SUBGROUPS = {
    # labelled unique shares only (drop and refit), never Shapley
    "dead now": lambda n: n.startswith("dead_"),
    "kills and deaths": lambda n: n.startswith("deaths_") or n == "kills",
    "items completed": lambda n: n.startswith("items_"),
    "unspent gold": lambda n: n.startswith("unspent_"),
    "gold by role": lambda n: n.startswith("gold_") and n != "gold_total",
    "CS": lambda n: n.startswith("cs_"),
    "towers by lane and tier": lambda n: n.startswith("tower_"),
    "dragon elements and soul type": lambda n: n.startswith(("drag_", "soul_")),
    "buff time left": lambda n: n in ("elder_s", "baron_s"),
}
K = 5
FEATURES_SEEN = []


def group8(name):
    if name == "draft":
        return "draft"
    if name.startswith(("gold_", "cs_", "unspent_", "items_")) or name in ("obj_gold", "obj_gold_curve"):
        return "economy"
    if name.startswith(("xp_", "level_")) or name == "obj_xp":
        return "xp"
    if name.startswith(("dead_", "deaths_")) or name in ("kills", "dmg_champ"):
        return "fights"
    if name.startswith("tower_") or name in ("obj_towers", "plates", "inhib_s", "inhibs_ever", "obj_inhibs_down"):
        return "structures"
    if name.startswith(("drag_", "soul_")) or name in ("obj_dragons", "obj_soul_point", "obj_soul"):
        return "dragons"
    if name in ("elder_s", "baron_s", "barons", "elders", "obj_elder", "obj_baron", "grubs_n", "heralds_n", "obj_grubs", "obj_herald"):
        return "neutral"
    if name in ("wards", "ctrl_wards", "wards_killed"):
        return "vision"
    raise KeyError(name)


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def ll(y, z):
    return np.logaddexp(0, z) - y * z


def fit_logit(X, y):
    if X.shape[1] == 0:
        p = y.mean()
        return lambda Z: np.full(len(Z), math.log(p / (1 - p)))
    mu, sd = X.mean(0), X.std(0) + 1e-6
    m = LogisticRegression(C=100.0, max_iter=1000, tol=1e-6).fit((X - mu) / sd, y)
    return lambda Z: m.decision_function((Z - mu) / sd)


def oof(X, y, part, cols):
    """Out-of-fold logits of a logistic on `cols`"""
    z = np.zeros(len(y))
    for j in range(K):
        f = fit_logit(X[part != j][:, cols], y[part != j])
        z[part == j] = f(X[part == j][:, cols])
    return z


def oof_gbdt(X, y, part, cols, threads):
    import lightgbm as lgb

    params = dict(objective="binary", learning_rate=0.05, num_leaves=31, min_data_in_leaf=200, feature_fraction=0.8,
                  bagging_fraction=0.8, bagging_freq=1, lambda_l2=10.0, verbose=-1, num_threads=threads, seed=0)
    z = np.zeros(len(y))
    if not cols:
        return oof(X, y, part, cols)
    for j in range(K):
        tr = part != j
        m = lgb.train(params, lgb.Dataset(X[tr][:, cols], y[tr]), 400)
        z[part == j] = m.predict(X[part == j][:, cols], raw_score=True)
    return z


def shapley_weights(n):
    return {s: math.factorial(s) * math.factorial(n - s - 1) / math.factorial(n) for s in range(n)}


def ci(v):
    return 1.96 * v.std(ddof=1) / math.sqrt(len(v))


def bucket(state, data, games, minute, threads, use_gbdt, logit):
    S = state.block(minute, games)
    going = ~np.isnan(S[:, 0])
    g = games[going]
    X, names = sc.features(state, S[going], logit[g].astype(np.float32), minute)
    y = data.y[g].astype(np.float64)
    part = (np.random.default_rng(minute).permutation(len(g)) % K)
    gcols = {G: [i for i, n in enumerate(names) if group8(n) == G] for G in GROUPS}
    log(f"minute {minute}: {len(g)} games, {len(names)} features")

    subsets = list(itertools.product([0, 1], repeat=len(GROUPS)))
    def cols_of(mask):
        return sorted(c for G, on in zip(GROUPS, mask) if on for c in gcols[G])

    zs = Parallel(n_jobs=threads)(delayed(oof)(X, y, part, cols_of(m)) for m in subsets)
    loss = {m: ll(y, z) for m, z in zip(subsets, zs)}
    base = loss[tuple([0] * len(GROUPS))]
    full_mask = tuple([1] * len(GROUPS))
    skill = {m: base - l for m, l in loss.items()}  # per game
    w = shapley_weights(len(GROUPS))
    out = {"minute": minute, "games": len(g), "base": base.mean(), "full": skill[full_mask], "groups": {}}
    full_z = zs[subsets.index(full_mask)]
    # Full-model logit parts per group, from one fit on all rows (for the win pp spread)
    mu, sd = X.mean(0), X.std(0) + 1e-6
    lr = LogisticRegression(C=100.0, max_iter=1000, tol=1e-6).fit((X - mu) / sd, y)
    coef = lr.coef_[0]
    for i, G in enumerate(GROUPS):
        phi = np.zeros(len(g))
        for m in subsets:
            if m[i]:
                continue
            with_i = m[:i] + (1,) + m[i + 1:]
            phi += w[sum(m)] * (skill[with_i] - skill[m])
        without = full_mask[:i] + (0,) + full_mask[i + 1:]
        alone = tuple(int(j == i) for j in range(len(GROUPS)))
        part_logit = ((X[:, gcols[G]] - mu[gcols[G]]) / sd[gcols[G]]) @ coef[gcols[G]]
        out["groups"][G] = {
            "unique": skill[full_mask] - skill[without],
            "alone": skill[alone],
            "shapley": phi,
            "win_pp": 25 * part_logit.std(),
        }
    out["sub"] = {}
    for label, pred in SUBGROUPS.items():
        drop = [i for i, n in enumerate(names) if pred(n)]
        keep = [c for c in range(len(names)) if c not in drop]
        z = oof(X, y, part, keep)
        out["sub"][label] = ll(y, z) - loss[full_mask]
    if use_gbdt:
        allc = list(range(len(names)))
        zf = oof_gbdt(X, y, part, allc, threads)
        out["gbdt_full"] = base - ll(y, zf)
        out["gbdt"] = {}
        for G in GROUPS:
            zw = oof_gbdt(X, y, part, [c for c in allc if c not in gcols[G]], threads)
            za = oof_gbdt(X, y, part, gcols[G], threads)
            out["gbdt"][G] = {"unique": ll(y, zw) - ll(y, zf), "alone": base - ll(y, za)}
    out["gold_eq"] = gold_equivalents(X, names, y)
    return out


EQUIV = [
    ("1000 XP lead", lambda n: n == "obj_xp", 1.0),
    ("elemental dragon", lambda n: n.startswith("drag_"), None),
    ("soul point", lambda n: n == "obj_soul_point", 1.0),
    ("soul", lambda n: n.startswith("soul_"), None),
    ("elder, per 100 s left", lambda n: n == "elder_s", 1.0),
    ("baron, per 100 s left", lambda n: n == "baron_s", 1.0),
    ("baron taken", lambda n: n == "barons", 1.0),
    ("outer tower", lambda n: n.startswith("tower_") and n.endswith("_outer"), None),
    ("inner tower", lambda n: n.startswith("tower_") and n.endswith("_inner"), None),
    ("base tower", lambda n: n.startswith("tower_") and n.endswith("_base"), None),
    ("inhibitor, per 100 s down", lambda n: n == "inhib_s", 1.0),
    ("grub", lambda n: n == "grubs_n", 1.0),
    ("herald", lambda n: n == "heralds_n", 1.0),
    ("one more player dead, now", lambda n: n == "dead_count", 1.0),
    ("one more kill", lambda n: n == "kills", 1.0),
    ("one more item completed (any role)", lambda n: n.startswith("items_"), None),
    ("draft logit +0.1", lambda n: n == "draft", 0.1),
]


def gold_equivalents(X, names, y):
    """Team gold lead model: per-role gold, CS and unspent replaced by the team gold lead"""
    keep = [i for i, n in enumerate(names) if not n.startswith(("gold_", "cs_", "unspent_")) and n not in ("obj_gold_curve",)]
    kn = [names[i] for i in keep]
    Xk = X[:, keep]
    m = LogisticRegression(C=100.0, max_iter=2000, tol=1e-7).fit(Xk, y)
    coef = dict(zip(kn, m.coef_[0]))
    wg = coef["obj_gold"]
    out = {"gold_logodds_per_1000": wg}
    for label, pred, scale in EQUIV:
        fs = [n for n in kn if pred(n)]
        if not fs:
            continue
        # mean weight over the matching features (elements, lanes, roles)
        wv = np.mean([coef[f] for f in fs]) * (scale or 1.0)
        out[label] = 1000 * wv / wg
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--buckets", default="5,10,15,20,25,30")
    ap.add_argument("--no-gbdt", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    threads = int(os.environ.get("OMP_NUM_THREADS", "8") or 8)
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    played = (data.flags & nnsets.PLAYED) != 0
    games = np.flatnonzero(played & has_tl & (data.split <= 6))
    # Draft logit cross-fitted over the same games (a game's from fits without its part)
    fake = nnsets.Sets("imp", games, games[data.start[games] < nnsets.val_cut(data.start[games])],
                       games[data.start[games] >= nnsets.val_cut(data.start[games])], np.array([], np.int64))
    logit, l2, _ = sc.draft_logits(data, fake)
    log(f"{len(games)} games; draft l2 {l2}")
    global FEATURES_SEEN
    FEATURES_SEEN = sc.features(state, state.block(10, games[:10]), logit[games[:10]].astype(np.float32), 10)[1]

    rows, md = [], ["# What matters in the live state, by minute", "",
                    "Log-loss skill in milli-nats per game (base rate minus model, out of fold), ± 95%. "
                    "share = Shapley / full skill.", "",
                    "Groups (fixed; compare runs only with the same list): " + "; ".join(
                        f"{G}: " + ", ".join(n for n in FEATURES_SEEN if group8(n) == G) for G in GROUPS), ""]
    for minute in map(int, a.buckets.split(",")):
        r = bucket(state, data, games, minute, threads, not a.no_gbdt, logit)
        full = r["full"].mean()
        md += [f"## {minute}:00, {r['games']} games, full skill {1000 * full:.1f} ± {1000 * ci(r['full']):.1f} (base log loss {r['base']:.4f})", "",
               "| group | unique | alone | Shapley | share | win pp (sd) | gbdt unique | gbdt alone |", "| --- |" + " --- |" * 7]
        for G in GROUPS:
            x = r["groups"][G]
            gb = r.get("gbdt", {}).get(G)
            gcells = [f"{1000 * gb[k].mean():.2f} ± {1000 * ci(gb[k]):.2f}" for k in ("unique", "alone")] if gb else ["", ""]
            md.append(f"| {G} | " + " | ".join(f"{1000 * x[k].mean():.2f} ± {1000 * ci(x[k]):.2f}" for k in ("unique", "alone", "shapley"))
                      + f" | {100 * x['shapley'].mean() / full:.0f}% | {x['win_pp']:.1f} | " + " | ".join(gcells) + " |")
            for k in ("unique", "alone", "shapley"):
                rows.append((minute, G, k, 1000 * x[k].mean(), 1000 * ci(x[k])))
        if "gbdt_full" in r:
            md.append(f"\nLightGBM full skill {1000 * r['gbdt_full'].mean():.1f} ± {1000 * ci(r['gbdt_full']):.1f}")
        md += ["", "Unique shares within groups (drop and refit, logistic):", ""]
        for label, v in r["sub"].items():
            md.append(f"- {label}: {1000 * v.mean():.2f} ± {1000 * ci(v):.2f}")
            rows.append((minute, label, "unique", 1000 * v.mean(), 1000 * ci(v)))
        ge = r["gold_eq"]
        md += ["", f"Gold equivalents (team gold lead model; 1000 gold = {ge['gold_logodds_per_1000']:.3f} log-odds):", ""]
        md += [f"- {k}: {v:.0f} gold" for k, v in ge.items() if k != "gold_logodds_per_1000"]
        md.append("")
        with open(os.path.join(a.out, "imp.md"), "w") as f:
            f.write("\n".join(md) + "\n")
        with open(os.path.join(a.out, "imp.tsv"), "w") as f:
            f.write("minute\tgroup\tkind\tmnats\tci\n" + "".join(f"{m}\t{G}\t{k}\t{v:.4f}\t{c:.4f}\n" for m, G, k, v, c in rows))
        print("\n".join(md[-40:]), flush=True)


if __name__ == "__main__":
    main()
