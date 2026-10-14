"""Shared pieces for the draftpath scripts (how drafts win): nn-export and state-export
loaders, the lab's blocks, draft designs, ridge and logistic fits with L2 picked on
inner val, paired per-game comparisons.

Blocks as netcheck (src/lab/winnet.zig runBlock): fold k fits on played games of splits
below k and scores split k; dev fits on splits 0-5 and scores dev-val (6). Val = newest
10% of fit by start. One row per game, so per-game pairs are already clustered by game.
"""

import json
import os
from dataclasses import dataclass

import numpy as np
import scipy.optimize
import scipy.sparse as sp

BLOCKS = ["1", "2", "3", "4", "5", "dev"]
FOLDS = BLOCKS[:5]
VAL_SHARE = 0.1
PLAYED = 1
TIMELINE15 = 2
ROLES = ["top", "jungle", "middle", "bottom", "utility"]
L2_GRID = [1, 3, 10, 30, 100, 300, 1000, 3000, 10000]


@dataclass
class Nn:
    meta: dict
    champ: np.ndarray  # [n, 10] dense champion index, slot = side * 5 + role
    platform: np.ndarray
    start: np.ndarray
    duration: np.ndarray  # seconds
    y: np.ndarray  # blue won, float64
    split: np.ndarray
    flags: np.ndarray
    aux: np.ndarray  # [n, 10, k] float32
    match_id: list

    @property
    def n(self):
        return len(self.y)

    def aux_col(self, name):
        return self.aux[:, :, self.meta["aux"].index(name)]

    def champ_name(self, dense):
        return str(self.meta["champions"][dense])


def load_nn(snap):
    d = os.path.join(os.path.expanduser(snap), "nn")
    with open(os.path.join(d, "meta.json")) as f:
        meta = json.load(f)
    n, k = meta["n"], meta["k"]

    def col(name, dtype, shape=(n,)):
        a = np.fromfile(os.path.join(d, name), dtype=dtype)
        assert a.size == int(np.prod(shape)), (name, a.size, shape)
        return a.reshape(shape)

    with open(os.path.join(d, "match_id.txt")) as f:
        mids = f.read().split("\n")[:n]
    assert len(mids) == n
    return Nn(
        meta=meta,
        champ=col("champ.u8", np.uint8, (n, 10)),
        platform=col("platform.u8", np.uint8),
        start=col("start.i64", "<i8"),
        duration=col("duration.u16", "<u2").astype(np.float64),
        y=col("blue_win.u8", np.uint8).astype(np.float64),
        split=col("split.u8", np.uint8),
        flags=col("flags.u8", np.uint8),
        aux=col("aux.f32", "<f4", (n, 10, k)),
        match_id=mids,
    )


@dataclass
class State:
    """SNAP/state (meiolol-lab state-export, meiolol-41 [701543]): game.f32 [n][G],
    minute.f32 [M][n][C] (minute-major, NaN rows when not going)"""

    meta: dict
    game: np.ndarray
    minute: np.ndarray  # memmap

    def g(self, name):
        return self.game[:, self.meta["game_columns"].index(name)]

    def m(self, minute, name):
        mi = self.meta["minutes"].index(minute)
        return np.asarray(self.minute[mi, :, self.meta["minute_columns"].index(name)])

    def block(self, minute):
        return np.asarray(self.minute[self.meta["minutes"].index(minute)])


def load_state(snap, nn):
    d = os.path.join(os.path.expanduser(snap), "state")
    with open(os.path.join(d, "meta.json")) as f:
        meta = json.load(f)
    n = meta.get("n_games", meta.get("n"))
    assert n == nn.n, (n, nn.n)
    with open(os.path.join(d, "match_id.txt")) as f:
        assert f.read().split("\n")[:n] == nn.match_id, "state-export order differs from nn-export"
    G, C, M = len(meta["game_columns"]), len(meta["minute_columns"]), len(meta["minutes"])
    game = np.fromfile(os.path.join(d, "game.f32"), "<f4").reshape(n, G)
    minute = np.memmap(os.path.join(d, "minute.f32"), "<f4", "r", shape=(M, n, C))
    return State(meta, game, minute)


@dataclass
class Sets:
    block: str
    fit: np.ndarray
    inner: np.ndarray
    val: np.ndarray
    scored: np.ndarray


def sets(nn, block, need=PLAYED):
    ok = (nn.flags & need) == need
    s = nn.split.astype(np.int32)
    if block == "dev":
        fit, scored = ok & (s <= 5), ok & (s == 6)
    else:
        k = int(block)
        fit, scored = ok & (s < k), ok & (s == k)
    fit = np.flatnonzero(fit)
    cut = np.sort(nn.start[fit])[int(len(fit) * (1 - VAL_SHARE))]
    return Sets(block, fit, fit[nn.start[fit] < cut], fit[nn.start[fit] >= cut], np.flatnonzero(scored))


# Draft designs. Columns: platform one-hot (n_plat), then champion-role (n_champ * 5).


def n_cols(nn):
    return len(nn.meta["platforms"]) + len(nn.meta["champions"]) * 5


def design(nn, games, kind="signed", drop_role=None, only_role=None):
    """signed: blue champion-roles +1, red -1, platform +1 (blue-minus-red targets);
    sum: both teams +1 (game-level targets). drop_role / only_role: leave out or keep
    one role's champions"""
    n_plat = len(nn.meta["platforms"])
    m = len(games)
    rows, cols, vals = [np.arange(m)], [nn.platform[games].astype(np.int64)], [np.ones(m)]
    for slot in range(10):
        role = slot % 5
        if drop_role is not None and role == drop_role:
            continue
        if only_role is not None and role != only_role:
            continue
        sign = 1.0 if (kind == "sum" or slot < 5) else -1.0
        rows.append(np.arange(m))
        cols.append(n_plat + nn.champ[games, slot].astype(np.int64) * 5 + role)
        vals.append(np.full(m, sign))
    return sp.csr_matrix(
        (np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))), shape=(m, n_cols(nn))
    )


def penalty(nn, l2):
    """L2 per column: platform lightly, champion-roles l2"""
    p = np.full(n_cols(nn), float(l2))
    p[: len(nn.meta["platforms"])] = 1e-3
    return p


# Fits. Ridge: exact normal equations (columns ~900). Logistic: L-BFGS, mean loss +
# 0.5 * sum(pen * w^2) / n_fit, intercept free.


def ridge(X, y, pen, w=None):
    """Returns (b0, w); X sparse, pen per column"""
    w8 = np.ones(len(y)) if w is None else w
    mu = np.average(y, weights=w8)
    xm = np.asarray(X.T @ w8).ravel() / w8.sum()
    Xw = X.multiply(w8[:, None]).tocsr()
    A = (X.T @ Xw).toarray() - np.outer(xm, xm) * w8.sum() + np.diag(pen)
    b = X.T @ (w8 * (y - mu))
    coef = np.linalg.solve(A, np.asarray(b).ravel())
    return mu - xm @ coef, coef


def logistic(X, y, pen, offset=None, w0=None):
    n, d = X.shape
    off = np.zeros(n) if offset is None else offset

    def f(theta):
        b0, w = theta[0], theta[1:]
        z = b0 + X @ w + off
        p = 1 / (1 + np.exp(-z))
        loss = np.mean(np.logaddexp(0, z) - y * z) + 0.5 * np.sum(pen * w * w) / n
        r = (p - y) / n
        g = np.concatenate([[r.sum()], X.T @ r + pen * w / n])
        return loss, g

    x0 = np.zeros(d + 1) if w0 is None else w0
    res = scipy.optimize.minimize(f, x0, jac=True, method="L-BFGS-B", options={"maxiter": 500})
    return res.x[0], res.x[1:]


def logloss(y, z):
    return np.logaddexp(0, z) - y * z


def pick_l2(fit_fn, score_fn, sets_):
    """L2 from L2_GRID on inner -> val; returns (best l2, val scores)"""
    scores = {}
    for l2 in L2_GRID:
        m = fit_fn(sets_.inner, l2)
        scores[l2] = float(np.mean(score_fn(m, sets_.val)))
    return min(scores, key=lambda k: scores[k]), scores


# Paired comparisons, one row per game


def paired(d):
    """mean, 95% half-width of a per-game difference"""
    d = np.asarray(d, np.float64)
    d = d[np.isfinite(d)]
    if len(d) < 2:
        return float("nan"), float("nan"), len(d)
    return float(d.mean()), float(1.96 * d.std(ddof=1) / np.sqrt(len(d))), len(d)


def fmt(m, h, digits=5):
    return f"{m:+.{digits}f} ± {h:.{digits}f}"
