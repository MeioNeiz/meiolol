"""Q2, what a draft decides: the game's shape predicted from the draft alone.

Targets per game: gold lead at 14 by role and team (nn-export aux gold14, blue minus
red), first blood/tower/dragon/grubs/herald/baron/inhibitor taken by blue, minute of
each first (either team), length and kills per minute; win beside them. From
SNAP/state game.f32 when present, else SNAP/events.tsv. Draft-only models: platform +
champion-role, signed (blue minus red) for side targets, summed for game-level ones;
ridge or logistic, L2 on inner val per block. Held-out per block: R2 or log loss vs the
fit mean / base rate, paired per game, pooled over the 5 folds and dev-val apart.
Effects: the dev block's fit (splits 0-5) with bootstrap sd over games.

usage: shape.py SNAP [--boot 40] [--out .]
"""

import argparse
import os
import time

import numpy as np
import pandas as pd

import dp

ELEMENTAL = {"FIRE_DRAGON", "WATER_DRAGON", "EARTH_DRAGON", "AIR_DRAGON", "HEXTECH_DRAGON", "CHEMTECH_DRAGON"}
FIRSTS = ["blood", "tower", "dragon", "grubs", "herald", "baron", "inhib"]


def firsts_from_events(snap, nn):
    """{first_X_team, first_X_min}, kills, kills_15 per game in nn order"""
    ev = pd.read_csv(
        os.path.join(os.path.expanduser(snap), "events.tsv"),
        sep="\t",
        usecols=["match_id", "t_ms", "type", "subtype", "team", "first_blood"],
        dtype={"match_id": str, "t_ms": np.int64, "type": str, "subtype": str, "team": np.int32, "first_blood": np.int8},
    )
    idx = pd.Series(np.arange(nn.n), index=nn.match_id)
    ev["g"] = idx.reindex(ev["match_id"]).to_numpy()
    ev = ev[np.isfinite(ev["g"])]
    ev["g"] = ev["g"].astype(np.int64)
    ev = ev[ev["team"].isin([100, 200])].sort_values(["g", "t_ms"])
    kind = np.full(len(ev), "", object)
    t, s = ev["type"].to_numpy(), ev["subtype"].to_numpy()
    kind[(t == "kill") & (ev["first_blood"].to_numpy() == 1)] = "blood"
    kind[t == "tower"] = "tower"
    kind[(t == "monster") & np.isin(s, list(ELEMENTAL))] = "dragon"
    kind[(t == "monster") & (s == "HORDE")] = "grubs"
    kind[(t == "monster") & (s == "RIFTHERALD")] = "herald"
    kind[(t == "monster") & (s == "BARON_NASHOR")] = "baron"
    kind[t == "inhibitor"] = "inhib"
    ev["kind"] = kind
    out = {}
    for k in FIRSTS:
        e = ev[ev["kind"] == k].drop_duplicates("g")
        team = np.zeros(nn.n)
        mins = np.full(nn.n, np.nan)
        team[e["g"].to_numpy()] = np.where(e["team"].to_numpy() == 100, 1.0, -1.0)
        mins[e["g"].to_numpy()] = e["t_ms"].to_numpy() / 60000
        out[f"first_{k}_team"], out[f"first_{k}_min"] = team, mins
    kills = ev[ev["type"] == "kill"]
    out["kills"] = np.bincount(kills["g"], minlength=nn.n).astype(np.float64)
    out["kills_15"] = np.bincount(kills["g"][kills["t_ms"] < 900_000], minlength=nn.n).astype(np.float64)
    out["has_events"] = np.bincount(ev["g"], minlength=nn.n) > 0
    return out


def targets(snap, nn):
    """name -> (values [n] with NaN where undefined, kind 'signed'|'sum', 'ridge'|'logit',
    unit, need flag)"""
    g14 = nn.aux_col("gold14").astype(np.float64)
    tl = (nn.flags & dp.TIMELINE15) != 0
    t = {}
    for r, role in enumerate(dp.ROLES):
        v = g14[:, r] - g14[:, 5 + r]
        t[f"lead14_{role}"] = (np.where(tl, v, np.nan), "signed", "ridge", "gold", dp.TIMELINE15)
    t["lead14_team"] = (np.where(tl, g14[:, :5].sum(1) - g14[:, 5:].sum(1), np.nan), "signed", "ridge", "gold", dp.TIMELINE15)
    f = firsts_from_events(snap, nn)
    has = f["has_events"]
    for k in FIRSTS:
        team = f[f"first_{k}_team"]
        t[f"first_{k}_blue"] = (np.where(has & (team != 0), (team > 0).astype(float), np.nan), "signed", "logit", "pp", dp.PLAYED)
        t[f"first_{k}_min"] = (np.where(has, f[f"first_{k}_min"], np.nan), "sum", "ridge", "min", dp.PLAYED)
    sdir = os.path.join(os.path.expanduser(snap), "state")
    if os.path.exists(os.path.join(sdir, "meta.json")):
        st = dp.load_state(snap, nn)
        for m in (10, 15, 20):
            team = np.zeros(nn.n)
            for role in dp.ROLES:
                v = st.g(f"lead_{role}_{m}").astype(np.float64)
                team = team + v
                t[f"lead{m}_{role}"] = (v, "signed", "ridge", "gold", dp.PLAYED)
            t[f"lead{m}_team"] = (team, "signed", "ridge", "gold", dp.PLAYED)
    mins = nn.duration / 60
    t["length_min"] = (mins, "sum", "ridge", "min", dp.PLAYED)
    t["kills_per_min"] = (np.where(has, f["kills"] / mins, np.nan), "sum", "ridge", "kills/min", dp.PLAYED)
    t["kills_15"] = (np.where(has & (nn.duration >= 900), f["kills_15"], np.nan), "sum", "ridge", "kills", dp.PLAYED)
    t["win"] = (nn.y.copy(), "signed", "logit", "pp", dp.PLAYED)
    return t


class Model:
    def __init__(self, nn, kind, link):
        self.nn, self.kind, self.link = nn, kind, link

    def fit(self, games, y, l2):
        X = dp.design(self.nn, games, self.kind)
        pen = dp.penalty(self.nn, l2)
        if self.link == "ridge":
            return dp.ridge(X, y, pen)
        return dp.logistic(X, y, pen)

    def predict(self, m, games):
        return m[0] + dp.design(self.nn, games, self.kind) @ m[1]

    def loss(self, m, games, y):
        z = self.predict(m, games)
        return (y - z) ** 2 if self.link == "ridge" else dp.logloss(y, z)

    def base_loss(self, fit_y, y):
        mu = fit_y.mean()
        if self.link == "ridge":
            return (y - mu) ** 2
        return dp.logloss(y, np.log(mu / (1 - mu)))


def run_target(nn, name, spec, boot, rng):
    vals, kind, link, unit, need = spec
    model = Model(nn, kind, link)
    rows, per_block = [], {}
    for b in dp.BLOCKS:
        s = dp.sets(nn, b, need)
        keep = lambda g: g[np.isfinite(vals[g])]
        fit, inner, val, scored = keep(s.fit), keep(s.inner), keep(s.val), keep(s.scored)
        scores = {}
        for l2 in dp.L2_GRID:
            m = model.fit(inner, vals[inner], l2)
            scores[l2] = float(np.mean(model.loss(m, val, vals[val])))
        l2 = min(scores, key=lambda k: scores[k])
        m = model.fit(fit, vals[fit], l2)
        d = model.loss(m, scored, vals[scored]) - model.base_loss(vals[fit], vals[scored])
        base = model.base_loss(vals[fit], vals[scored])
        per_block[b] = (d, base, l2, m, fit)
        mean, half, n = dp.paired(d)
        rows.append((b, mean, half, n, float(base.mean()), l2))
    folds_d = np.concatenate([per_block[b][0] for b in dp.FOLDS])
    folds_base = np.concatenate([per_block[b][1] for b in dp.FOLDS])
    better = sum(per_block[b][0].mean() < 0 for b in dp.FOLDS)
    edge = [b for b in dp.BLOCKS if per_block[b][2] in (dp.L2_GRID[0], dp.L2_GRID[-1])]

    # Effects: dev block's fit, bootstrap over its games at the picked l2
    d_dev, _, l2, m, fit = per_block["dev"]
    n_plat = len(nn.meta["platforms"])
    coef = m[1][n_plat:]
    bs = []
    for _ in range(boot):
        gb = rng.choice(fit, len(fit))
        bs.append(model.fit(gb, vals[gb], l2)[1][n_plat:])
    sd = np.std(bs, axis=0, ddof=1) if boot > 1 else np.full_like(coef, np.nan)
    return rows, folds_d, folds_base, better, edge, coef, sd


def counts(nn, games):
    c = np.zeros(len(nn.meta["champions"]) * 5, np.int64)
    for slot in range(10):
        np.add.at(c, nn.champ[games, slot].astype(np.int64) * 5 + slot % 5, 1)
    return c


def scale(link, unit, coef):
    """coefficient -> plain unit: logit -> pp at 50% (x25); ridge as is"""
    return coef * 25 if link == "logit" else coef


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--boot", type=int, default=40)
    ap.add_argument("--out", default=".")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    t0 = time.time()
    nn = dp.load_nn(a.snap)
    print(f"nn-export: {nn.n} games, {time.time() - t0:.0f} s", flush=True)
    tg = targets(a.snap, nn)
    print(f"targets: {len(tg)}, {time.time() - t0:.0f} s", flush=True)
    rng = np.random.default_rng(1)
    dev_fit = dp.sets(nn, "dev").fit
    n_games = counts(nn, dev_fit)
    names = [n for n in tg if not a.only or n in a.only.split(",")]
    summary = open(os.path.join(a.out, "shape-summary.tsv"), "w")
    summary.write("target\tunit\tblock\tdiff\tci\tgames\tbase_loss\tr2_or_rel\tl2\tfolds_better\n")
    eff = {}
    for name in names:
        vals, kind, link, unit, need = tg[name]
        rows, fd, fb, better, edge, coef, sd = run_target(nn, name, tg[name], a.boot, rng)
        mean, half, n = dp.paired(fd)
        rel = -mean / fb.mean()
        print(f"{name} ({kind} {link}): folds {dp.fmt(mean, half)} over {n} games, {100 * rel:.2f}% of base loss, better in {better}/5" + (f", L2 at grid edge in {edge}" if edge else ""), flush=True)
        summary.write(f"{name}\t{unit}\tfolds\t{mean:.6f}\t{half:.6f}\t{n}\t{fb.mean():.6f}\t{rel:.5f}\t\t{better}\n")
        for b, m_, h_, n_, base, l2 in rows:
            summary.write(f"{name}\t{unit}\t{b}\t{m_:.6f}\t{h_:.6f}\t{n_}\t{base:.6f}\t{-m_ / base:.5f}\t{l2}\t\n")
            if b == "dev":
                print(f"  dev-val {dp.fmt(m_, h_)} over {n_}, {100 * -m_ / base:.2f}%, l2 {l2}", flush=True)
        eff[name] = (scale(link, unit, coef), scale(link, unit, sd))
        summary.flush()
    summary.close()

    # One effects table: champion-role x target, dev fit, with bootstrap sd
    n_champ = len(nn.meta["champions"])
    with open(os.path.join(a.out, "shape-effects.tsv"), "w") as f:
        f.write("champion\trole\tgames\t" + "\t".join(f"{n}\t{n}_sd" for n in eff) + "\n")
        for c in range(n_champ):
            for r, role in enumerate(dp.ROLES):
                j = c * 5 + r
                if n_games[j] == 0:
                    continue
                f.write(f"{nn.champ_name(c)}\t{role}\t{n_games[j]}")
                for n in eff:
                    f.write(f"\t{eff[n][0][j]:.4f}\t{eff[n][1][j]:.4f}")
                f.write("\n")
    print(f"done, {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()
