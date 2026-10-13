"""Creative checks on the live state model, each as rich + extra terms vs rich, paired.

- momentum: change over the last 3 and 5 minutes in the team gold, XP, kill, tower and
  dragon leads, beyond the current state
- lead x draft: does a lead convert differently for the stronger draft (gold and XP lead
  times the draft logit)
- late comp: each champion-role's late-game lean (shrunk mean of the win residual beyond
  the wcd state at minutes 24-30 minus at 8-12, from fit games, cross-fitted in two
  halves there), team sum blue minus red, alone and times the gold lead: does a lead
  decay faster against a late-game comp (comebacks), or hold for one (throws)
Blocks as statemodels.py; rows minutes 6..40 while going (momentum needs minute - 5).

usage: statechecks.py SNAP [--out DIR] [--blocks dev,1,2,3,4,5]
"""

import argparse
import os

import numpy as np

import nnsets
import statecommon as sc
from statemodels import Smooth, log

MINUTES = list(range(6, 41))
REPORT = [10, 15, 20, 25, 30, 35]
SHRINK = 200


def team_leads(state, games, minute):
    S = state.block(minute, games)
    c = state.cols

    def side(f):
        return sum(S[:, c[f"s{s}_{f}"]] for s in range(5)) - sum(S[:, c[f"s{5 + s}_{f}"]] for s in range(5))

    return np.stack([side("gold") / 1000, side("xp") / 1000, S[:, c["b_kills"]] - S[:, c["r_kills"]], S[:, c["obj_towers"]], S[:, c["obj_dragons"]]], 1)


def rows_with_momentum(state, games, logit):
    Xs, Ms, gs, ms = [], [], [], []
    names = None
    for m in MINUTES:
        S = state.block(m, games)
        going = ~np.isnan(S[:, 0])
        g = games[going]
        X, names = sc.features(state, S[going], logit[g].astype(np.float32), m)
        now = team_leads(state, g, m)
        mom = np.concatenate([now - team_leads(state, g, m - 3), now - team_leads(state, g, m - 5)], 1)
        Xs.append(X)
        Ms.append(mom.astype(np.float32))
        gs.append(g)
        ms.append(np.full(len(g), m, np.int16))
    return np.concatenate(Xs), names, np.concatenate(Ms), np.concatenate(gs), np.concatenate(ms)


def late_lean(data, games, minute, resid, n_champ):
    """Per (champion, role): shrunk mean of blue-signed residual at minutes 24-30 minus
    8-12, from these rows"""
    out = np.zeros((n_champ, 5))
    for lo, hi, sign in ((24, 30, 1), (8, 12, -1)):
        sel = (minute >= lo) & (minute <= hi)
        s = np.zeros((n_champ, 5))
        n = np.zeros((n_champ, 5))
        for slot in range(10):
            ch = data.champ[games[sel], slot]
            r = resid[sel] * (1 if slot < 5 else -1)
            np.add.at(s[:, slot % 5], ch, r)
            np.add.at(n[:, slot % 5], ch, 1)
        out += sign * s / (n + SHRINK)
    return out


def team_index(data, games, lean):
    ch = data.champ[games].astype(np.int64)
    roles = np.tile(np.arange(5), 2)
    v = lean[ch, roles]
    return v[:, :5].sum(1) - v[:, 5:].sum(1)


def run_block(state, data, block):
    sets = nnsets.sets(data, block)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    logit, _, _ = sc.draft_logits(data, sets)
    fit_g, sc_g = sets.fit[has_tl[sets.fit]], sets.scored[has_tl[sets.scored]]
    Xf, names, Mf, gf, mf = rows_with_momentum(state, fit_g, logit)
    Xs, _, Ms, gs, ms = rows_with_momentum(state, sc_g, logit)
    yf, ys = data.y[gf], data.y[gs]
    idx = {n: i for i, n in enumerate(names)}
    wcd = [idx[f"obj_{f}"] for f in sc.WC] + [idx["draft"]]
    n_champ = len(data.meta["champions"])

    # late-game lean: cross-fitted in halves on fit games, all fit games for scored ones
    half = np.random.default_rng(5).integers(0, 2, data.n)
    idx_f = np.zeros(len(yf))
    for h in (0, 1):
        src, dst = half[gf] != h, half[gf] == h
        p = Smooth().fit(Xf[src][:, wcd], mf[src], yf[src]).predict(Xf[src][:, wcd], mf[src])
        lean = late_lean(data, gf[src], mf[src], yf[src] - p, n_champ)
        idx_f[dst] = team_index(data, gf[dst], lean)
    p = Smooth().fit(Xf[:, wcd], mf, yf).predict(Xf[:, wcd], mf)
    idx_s = team_index(data, gs, late_lean(data, gf, mf, yf - p, n_champ))

    gold, xp, draft = idx["obj_gold"], idx["obj_xp"], idx["draft"]
    extra = {
        "momentum": (Mf, Ms),
        "lead x draft": (np.stack([Xf[:, gold] * Xf[:, draft], Xf[:, xp] * Xf[:, draft]], 1), np.stack([Xs[:, gold] * Xs[:, draft], Xs[:, xp] * Xs[:, draft]], 1)),
        "late comp": (np.stack([idx_f, idx_f * Xf[:, gold]], 1), np.stack([idx_s, idx_s * Xs[:, gold]], 1)),
    }
    res = {"block": np.full(len(ys), block), "game": gs, "minute": ms, "y": ys}
    rich = Smooth().fit(Xf, mf, yf)
    res["rich"] = rich.predict(Xs, ms)
    for k, (ef, es) in extra.items():
        m = Smooth().fit(np.column_stack([Xf, ef]), mf, yf)
        res[k] = m.predict(np.column_stack([Xs, es]), ms)
        # the extra terms' weights at each knot, in sd units
        res[f"{k} W"] = m.W[Xf.shape[1]:]
        d, ci, n = sc.paired(ys, res[k], res["rich"], gs)
        log(f"block {block}: {k} vs rich {d:+.5f} ± {ci:.5f}")
    res["late sd"] = np.array([idx_s.std()])
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--blocks", default="dev,1,2,3,4,5")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    all_res = [run_block(state, data, b) for b in a.blocks.split(",")]
    checks = ["momentum", "lead x draft", "late comp"]
    lines = ["# Creative checks: rich + terms vs rich, log loss per game-minute, ± 95% by game", ""]
    for label, blocks in (("folds", ["1", "2", "3", "4", "5"]), ("dev-val", ["dev"])):
        rs = [r for r in all_res if r["block"][0] in blocks]
        if not rs:
            continue
        cat = {k: np.concatenate([r[k] for r in rs]) for k in ["game", "minute", "y", "rich"] + checks}
        lines += [f"## {label}", "", "| minute | " + " | ".join(checks) + " |", "| --- |" + " --- |" * len(checks)]
        for mn in REPORT + ["all"]:
            sel = np.ones(len(cat["y"]), bool) if mn == "all" else cat["minute"] == mn
            cells = []
            for k in checks:
                d, ci, _ = sc.paired(cat["y"][sel], cat[k][sel], cat["rich"][sel], cat["game"][sel])
                cells.append(f"{d:+.5f} ± {ci:.5f}")
            lines.append(f"| {mn} | " + " | ".join(cells) + " |")
        if len(blocks) > 1:
            lines.append("\nBetter in k of 5 folds: " + ", ".join(f"{k} {sum(sc.paired(r['y'], r[k], r['rich'], r['game'])[0] < 0 for r in rs)}" for k in checks))
        lines.append("")
    for r in all_res:
        lines.append(f"block {r['block'][0]} weights (sd units by knot {sc.KNOTS}):")
        for k in checks:
            lines.append(f"  {k}: " + "; ".join(" ".join(f"{w:+.3f}" for w in row) for row in r[f"{k} W"]))
        lines.append(f"  late comp index sd {r['late sd'][0]:.3f} (log-odds)")
    text = "\n".join(lines)
    with open(os.path.join(a.out, "checks.md"), "w") as f:
        f.write(text + "\n")
    print(text, flush=True)


if __name__ == "__main__":
    main()
