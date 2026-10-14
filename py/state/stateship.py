"""Shipped in-game win chance: richc (statemodels.py) fitted on every played game with a
timeline, test included, written as the model file Your games reads (src/statemodel.zig,
format in docs/model.md "In-game model file").

Same procedure as a statemodels.py block with every played game as the fit: win-ratings
L2 and richc's ridge picked on the newest 10%, the draft logit cross-fitted in 5 parts
for the fit rows, fit rows every other minute. The shipped draft logit is the full fit's
(platform intercept + blue's ratings - red's). Also writes the check file: blue's
chance per minute from the exported numbers for CHECK random games, which
`meiolol-lab state-export SNAP --check MODEL CHECK` must reproduce from the timelines.

usage: stateship.py SNAP [--out DIR] [--check N] [--run NAME]
"""

import argparse
import os
import struct

import numpy as np

import nnsets
import statecommon as sc
from statemodels import MINUTES, fit_richc, log

MAGIC = b"meiolol-state\0\0\0"
VERSION = 1
NAME_LEN = 24
PLATFORM_LEN = 8
ROLES = sc.ROLES


def fit_ratings(data, fit):
    """L2 on the newest 10% of fit; cross-fitted logits for fit games; the full weights"""
    cut = nnsets.val_cut(data.start[fit])
    inner, val = fit[data.start[fit] < cut], fit[data.start[fit] >= cut]
    sets = nnsets.Sets("ship", fit, inner, val, np.array([], np.int64))
    logit, l2, vl = sc.draft_logits(data, sets)
    table, n_ids = nnsets.rating_vocab(data, fit)
    w = sc._fit_ratings(sc._ratings_design(data, fit, table, n_ids), data.y[fit].astype(np.float64), l2)
    return logit, l2, vl, table, w


def full_logit(data, games, table, w):
    return sc._ratings_design(data, games, table, len(w) - 256) @ w


def write_model(path, meta, names, model, w, table, data, fit):
    K = len(sc.KNOTS)
    platforms = data.meta["platforms"]
    counts = np.bincount(data.platform[fit], minlength=len(platforms))
    default = float(np.sum(w[: len(platforms)] * counts) / counts.sum())
    champs = data.meta["champions"]
    terms = []
    for ci, champion in enumerate(champs):
        for r in range(5):
            i = table[ci, r]
            if i > 0:
                terms.append((int(champion), r, float(w[256 + i]), model.E[i]))
    b = bytearray()
    b += MAGIC
    b += struct.pack("<7I", VERSION, len(names), K, len(platforms), len(terms), meta["games"], 0)
    b += struct.pack("<q", meta["newest"])
    b += meta["snapshot"].encode()[:63].ljust(64, b"\0")
    b += meta["run"].encode()[:63].ljust(64, b"\0")
    b += np.asarray(sc.KNOTS, "<f4").tobytes()
    for n in names:
        assert len(n) < NAME_LEN, n
        b += n.encode().ljust(NAME_LEN, b"\0")
    b += np.asarray(model.mu, "<f4").tobytes()
    b += np.asarray(model.sd, "<f4").tobytes()
    b += np.asarray(model.W, "<f4").tobytes()
    b += np.asarray(model.b, "<f4").tobytes()
    b += struct.pack("<f", default)
    for p, name in enumerate(platforms):
        b += name.encode().ljust(PLATFORM_LEN, b"\0") + struct.pack("<f", float(w[p]))
    for champion, role, rating, effect in terms:
        b += struct.pack("<IIf", champion, role, rating) + np.asarray(effect, "<f4").tobytes()
    with open(path, "wb") as f:
        f.write(bytes(b))
    return len(terms), default


def read_model(path):
    """The file back, for the check: dict of arrays (numpy reference for statemodel.zig)"""
    raw = open(path, "rb").read()
    assert raw[:16] == MAGIC
    version, F, K, P, C, games, _ = struct.unpack_from("<7I", raw, 16)
    assert version == VERSION
    o = 16 + 28 + 8 + 128

    def f32(n):
        nonlocal o
        a = np.frombuffer(raw, "<f4", n, o)
        o += 4 * n
        return a

    knots = f32(K)
    names = [raw[o + i * NAME_LEN : o + (i + 1) * NAME_LEN].rstrip(b"\0").decode() for i in range(F)]
    o += F * NAME_LEN
    mu, sd, W, b = f32(F), f32(F), f32(F * K).reshape(F, K), f32(K)
    default = f32(1)[0]
    plat = {}
    for _ in range(P):
        name = raw[o : o + PLATFORM_LEN].rstrip(b"\0").decode()
        o += PLATFORM_LEN
        plat[name] = f32(1)[0]
    terms = {}
    for _ in range(C):
        champion, role = struct.unpack_from("<II", raw, o)
        o += 8
        rating = f32(1)[0]
        terms[(champion, role)] = (rating, f32(K))
    assert o == len(raw), (o, len(raw))
    return dict(knots=knots, names=names, mu=mu, sd=sd, W=W, b=b, default=default, plat=plat, terms=terms)


def score_file(m, X_no_draft, minute, champions, platform):
    """Blue's chance from the file alone (champions [rows, 10] Riot ids by seat)"""
    K = len(m["knots"])
    zero = (0.0, np.zeros(K, np.float32))
    draft = np.array([m["plat"].get(p, m["default"]) for p in platform], np.float64)
    effect = np.zeros((len(minute), K))
    for s in range(10):
        sign = 1 if s < 5 else -1
        for i in range(len(minute)):
            rating, e = m["terms"].get((int(champions[i, s]), s % 5), zero)
            draft[i] += sign * rating
            effect[i] += sign * e
    X = X_no_draft.astype(np.float64).copy()
    X[:, 0] = draft
    H = sc.hat(minute, list(m["knots"]))
    Xs = (X - m["mu"]) / m["sd"]
    z = ((Xs @ m["W"]) * H).sum(1) + H @ m["b"] + (effect * H).sum(1)
    return 1 / (1 + np.exp(-z))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--check", type=int, default=500)
    ap.add_argument("--run", default=os.path.basename(os.getcwd()))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    played = (data.flags & nnsets.PLAYED) != 0
    fit = np.flatnonzero(played)
    log(f"fit: {len(fit)} played games (every split, test included), {has_tl[fit].sum()} with a timeline")
    logit, l2, vl, table, w = fit_ratings(data, fit)
    log(f"ratings l2 {l2} (newest 10%: {', '.join(f'{k}: {v:.5f}' for k, v in vl.items())})")
    fit_g = fit[has_tl[fit]]
    Xf, names, gf, mf = sc.rows_for(state, fit_g, MINUTES[::2], logit)
    yf = data.y[gf]
    is_val = data.start[gf] >= nnsets.val_cut(data.start[fit])
    log(f"rows {len(yf)}, {len(names)} features")
    model, l2c = fit_richc(Xf, mf, yf, nnsets.ids(data, gf, table), int(table.max()) + 1, is_val)
    log(f"richc l2 {l2c}; champion effect sd by knot " + ", ".join(f"{v:.3f}" for v in model.E[1:].std(0)))
    del Xf

    path = os.path.join(a.out, "state-model.bin")
    snap = os.path.basename(os.path.normpath(os.path.expanduser(a.snap)))
    meta = dict(games=len(fit_g), newest=int(data.start[fit_g].max()), snapshot=snap, run=a.run)
    n_terms, default = write_model(path, meta, names, model, w, table, data, fit)
    log(f"wrote {path}: {os.path.getsize(path)} bytes, {n_terms} champion-role terms, default intercept {default:.5f}")

    # Check games: the exported numbers through the model's own predict and the file
    rng = np.random.default_rng(7)
    games = np.sort(rng.choice(fit_g, a.check, replace=False))
    full = full_logit(data, games, table, w)
    full_all = np.full(data.n, np.nan)
    full_all[games] = full
    X, _, g, m = sc.rows_for(state, games, MINUTES, full_all)
    p_model = model.predict(X, m, nnsets.ids(data, g, table))
    champions = np.asarray(data.meta["champions"])[data.champ[g]]
    platform = [data.meta["platforms"][p] for p in data.platform[g]]
    p_file = score_file(read_model(path), X, m, champions, platform)
    diff = np.abs(p_model - p_file).max()
    log(f"check: {len(games)} games, {len(g)} game-minutes, file vs model max |diff| {diff:.2e}")
    assert diff < 1e-5, diff
    with open(os.path.join(a.out, "state-check.tsv"), "w") as f:
        f.write("match_id\tminute\tp\n")
        for gi, mi, p in zip(g, m, p_file):
            f.write(f"{data.match_id[gi]}\t{mi}\t{p:.9f}\n")
    with open(os.path.join(a.out, "report.md"), "w") as f:
        f.write(f"# stateship\n\nsnapshot {snap}; {len(fit)} played games, {len(fit_g)} with a timeline "
                f"fitted; newest game start {meta['newest']}\nratings l2 {l2}; richc l2 {l2c}\n"
                f"champion effect sd by knot: {', '.join(f'{v:.3f}' for v in model.E[1:].std(0))}\n"
                f"{n_terms} champion-role terms; check {len(games)} games, {len(g)} game-minutes, "
                f"file vs model max |diff| {diff:.2e}\n")


if __name__ == "__main__":
    main()
