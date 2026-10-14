"""Q1 and Q2 by comp archetype (meiolol-c1's teams.tsv: k-means on cross-fitted team
profiles, 0-5), on the 5 folds' scored games (dev-val apart).

Q1: info.py's per-game log loss gains (info-raw.npy) among games where a team has
archetype a: draft vs base at 0, draft given state by minute.
Q2 (team view, model-free with game-clustered intervals): gold lead at 10/15/20, first
dragon/herald/tower/grubs, length, win; win by length band (<25, 25-32, 32+ min) beside
the draft-only model's chance for that team (D in info-raw): observed minus expected
says when an archetype wins beyond its champions.
Also by damage mix (magic_share, meiolol-94's cuts: under 0.2, 0.2-0.6, 0.6+), the comp
variable whose win effect held in the comps sealed check; archetypes did not, so their
rows are description only.

usage: archsplit.py SNAP --info info-raw.npy --teams teams.tsv [--names a,b,...] [--out .]
"""

import argparse
import os

import numpy as np
import pandas as pd

import dp

# labels for 2055Z's k-means (c1); each export's centres differ, so pass --names for others
NAMES_2055Z = "range/siege,tank/engage,AD dive,late scaling,early dive/roam,enchanter/peel"


def p_blue(loss, y):
    p = np.exp(-loss)
    return np.where(y == 1, p, 1 - p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--info", required=True)
    ap.add_argument("--teams", required=True)
    ap.add_argument("--names", default=NAMES_2055Z, help="archetype labels 0-5, from the run's archetypes.tsv")
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    global NAMES
    NAMES = dict(enumerate(a.names.split(",")))
    nn = dp.load_nn(a.snap)
    st = dp.load_state(a.snap, nn)
    by = np.load(os.path.expanduser(a.info), allow_pickle=True).item()
    tm = pd.read_csv(os.path.expanduser(a.teams), sep="\t", dtype={"match_id": str, "block": str})
    idx = pd.Series(np.arange(nn.n), index=nn.match_id)
    tm["g"] = idx.reindex(tm["match_id"]).to_numpy()
    gi, side = tm["g"].to_numpy().astype(int), tm["side"].to_numpy()
    arch = np.full((nn.n, 2), -1)
    arch[gi, side] = tm["archetype"].to_numpy()
    mix = np.full((nn.n, 2), -1)
    mix[gi, side] = np.digitize(tm["magic_share"].to_numpy(), [0.2, 0.6])
    # (id, label, team label array, value)
    groups = [(f"a{ar}", NAMES[ar], arch, ar) for ar in range(6)]
    groups += [(f"mix{v}", lab, mix, v) for v, lab in enumerate(["magic <20%", "magic 20-60%", "magic 60%+"])]
    f = open(os.path.join(a.out, "archsplit.tsv"), "w")
    f.write("part\tgroup\tname\tblocks\tquantity\tvalue\tci\tn\n")

    def w(part, gid, label, blocks, q, v, h, n):
        f.write(f"{part}\t{gid}\t{label}\t{blocks}\t{q}\t{v:.6f}\t{h:.6f}\t{n}\n")

    for name, blocks in (("folds", dp.FOLDS), ("dev", ["dev"])):
        # Q1
        for t in sorted(by[blocks[0]]["minutes"]):
            g = np.concatenate([by[b]["minutes"][t]["games"] for b in blocks])
            r = {k: np.concatenate([by[b]["minutes"][t][k] for b in blocks]) for k in ("base", "D", "S", "DS") if k in by[blocks[0]]["minutes"][t]}
            for gid, label, lab, v in groups:
                sel = (lab[g] == v).any(1)
                if t == 0:
                    m, h, n = dp.paired((r["D"] - r["base"])[sel])
                    w("info", gid, label, name, "draft vs base, min 0", m, h, n)
                else:
                    m, h, n = dp.paired((r["DS"] - r["S"])[sel])
                    w("info", gid, label, name, f"draft given state, min {t}", m, h, n)
                    if name == "folds" and t in (15, 25):
                        print(f"{name} {label:<16} min {t}: draft given state {dp.fmt(m, h)} n {n}")
        # Q2, team view: one row per team of archetype a in scored games
        g0 = np.concatenate([by[b]["minutes"][0]["games"] for b in blocks])
        d0 = np.concatenate([by[b]["minutes"][0]["D"] for b in blocks])
        pb = p_blue(d0, nn.y[g0])
        mins = nn.duration[g0] / 60
        for gid, label, lab, v in groups:
            rows = []
            for side in (0, 1):
                sel = lab[g0, side] == v
                sg = 1.0 if side == 0 else -1.0
                gg = g0[sel]
                win = nn.y[gg] if side == 0 else 1 - nn.y[gg]
                exp = pb[sel] if side == 0 else 1 - pb[sel]
                rec = {"win": win, "expected": exp, "length": mins[sel]}
                for t in (10, 15, 20):
                    lead = sum(st.g(f"lead_{r}_{t}")[gg].astype(np.float64) for r in dp.ROLES)
                    rec[f"lead{t}"] = sg * lead
                for x in ("dragon", "herald", "tower", "grubs"):
                    tt = st.g(f"first_{x}_team")[gg]
                    rec[f"first_{x}"] = np.where(tt == 0, np.nan, (sg * tt > 0).astype(float))
                rows.append(rec)
            rec = {k: np.concatenate([r_[k] for r_ in rows]) for k in rows[0]}
            for k in ("lead10", "lead15", "lead20", "first_dragon", "first_herald", "first_tower", "first_grubs", "length", "win"):
                m, h, n = dp.paired(rec[k])
                w("shape", gid, label, name, k, m, h, n)
            m, h, n = dp.paired(rec["win"] - rec["expected"])
            w("shape", gid, label, name, "win minus draft-only expected", m, h, n)
            line = [f"{name} {label:<16} lead15 {np.nanmean(rec['lead15']):+.0f}, length {np.mean(rec['length']):.1f}, win-exp {100 * m:+.2f}±{100 * h:.2f}"]
            for lo, hi in ((0, 25), (25, 32), (32, 99)):
                sel = (rec["length"] >= lo) & (rec["length"] < hi)
                m, h, n = dp.paired((rec["win"] - rec["expected"])[sel])
                w("shape", gid, label, name, f"win minus expected, {lo}-{hi} min", m, h, n)
                line.append(f"{lo}-{hi}: {100 * m:+.1f}±{100 * h:.1f}")
            print(" | ".join(line))
    f.close()


if __name__ == "__main__":
    main()
