"""Live state model data: SNAP/state (meiolol-lab state-export) joined to SNAP/nn.

Features are blue minus red unless named otherwise; GROUPS maps each to the group the
importance tables drop or permute together. The draft logit is win-ratings refitted per
block, cross-fitted on fit games (a fit game's logit comes from a fit without it).
"""

import json
import os

import numpy as np
import scipy.optimize
import scipy.sparse

import nnsets

ROLES = ["top", "jungle", "middle", "bottom", "utility"]
LANES = ["top", "mid", "bot"]
TIERS = ["outer", "inner", "base"]
ELEMENTS = ["infernal", "ocean", "mountain", "cloud", "hextech", "chemtech"]
# winchance.zig's state: objectives.lead ++ objectives.held
WC = ["gold", "gold_curve", "xp", "towers", "inhibs_down", "dragons", "soul_point", "soul", "elder", "grubs", "herald", "baron"]


class State:
    def __init__(self, snap):
        d = os.path.join(os.path.expanduser(snap), "state")
        with open(os.path.join(d, "meta.json")) as f:
            self.meta = json.load(f)
        self.n = self.meta["n"]
        self.c = self.meta["c"]
        self.minutes = self.meta["minutes"]
        self.cols = {name: i for i, name in enumerate(self.meta["minute_columns"])}
        self.gcols = {name: i for i, name in enumerate(self.meta["game_columns"])}
        assert len(self.cols) == self.c
        self.minute = np.memmap(os.path.join(d, "minute.f32"), dtype="<f4", mode="r", shape=(len(self.minutes), self.n, self.c))
        self.game = np.fromfile(os.path.join(d, "game.f32"), dtype="<f4").reshape(self.n, -1)
        with open(os.path.join(d, "match_id.txt")) as f:
            self.match_id = f.read().split("\n")[: self.n]

    def block(self, minute, games):
        """[len(games), c] rows at `minute` (NaN rows: not going)"""
        return np.asarray(self.minute[self.minutes.index(minute)][games])


def check_join(state, data):
    assert state.n == data.n, (state.n, data.n)
    if data.match_id is not None:
        assert state.match_id == data.match_id[: state.n], "state and nn game order differ"


def features(state, S, draft_logit, minute):
    """Feature matrix [rows, F] and names from state rows S (all going)"""
    c = state.cols

    def g(name):
        return S[:, c[name]]

    def seat(s, f):
        return S[:, c[f"s{s}_{f}"]]

    def side(f):
        return sum(seat(s, f) for s in range(5)) - sum(seat(5 + s, f) for s in range(5))

    def team(f):
        return g(f"b_{f}") - g(f"r_{f}")

    out = {}
    out["draft"] = draft_logit
    for f in WC:
        out[f"obj_{f}"] = g(f"obj_{f}")
    for r, role in enumerate(ROLES):
        out[f"gold_{role}"] = (seat(r, "gold") - seat(5 + r, "gold")) / 1000
        out[f"xp_{role}"] = (seat(r, "xp") - seat(5 + r, "xp")) / 1000
        out[f"level_{role}"] = seat(r, "level") - seat(5 + r, "level")
        out[f"cs_{role}"] = (seat(r, "cs") - seat(5 + r, "cs")) / 10
        out[f"dead_{role}"] = (seat(r, "respawn_s") - seat(5 + r, "respawn_s")) / 10
        out[f"items_{role}"] = seat(r, "legendaries") - seat(5 + r, "legendaries")
        out[f"unspent_{role}"] = (seat(r, "unspent") - seat(5 + r, "unspent")) / 1000
        out[f"deaths_{role}"] = seat(r, "deaths") - seat(5 + r, "deaths")
    out["dead_count"] = sum((seat(s, "respawn_s") > 0).astype(np.float32) for s in range(5)) - sum(
        (seat(5 + s, "respawn_s") > 0).astype(np.float32) for s in range(5)
    )
    out["kills"] = team("kills")
    out["dmg_champ"] = side("dmg_champ") / 1000
    out["gold_total"] = (sum(seat(s, "gold") for s in range(10))) / 10000
    for lane in LANES:
        for tier in TIERS:
            out[f"tower_{lane}_{tier}"] = team(f"tower_{lane}_{tier}")
    out["tower_nexus"] = team("tower_nexus")
    out["plates"] = team("plates")
    out["inhib_s"] = sum(team(f"inhib_{lane}_s") for lane in LANES) / 100
    out["inhibs_ever"] = team("inhibs")
    for el in ELEMENTS:
        out[f"drag_{el}"] = team(el)
    blue_soul, red_soul = g("b_soul"), g("r_soul")
    for i, el in enumerate(ELEMENTS):
        out[f"soul_{el}"] = (blue_soul == i + 1).astype(np.float32) - (red_soul == i + 1).astype(np.float32)
    out["elder_s"] = team("elder_s") / 100
    out["baron_s"] = team("baron_s") / 100
    out["barons"] = team("barons")
    out["elders"] = team("elders")
    out["grubs_n"] = team("grubs")
    out["heralds_n"] = team("heralds")
    out["wards"] = side("wards") / 10
    out["ctrl_wards"] = side("ctrl_wards")
    out["wards_killed"] = side("wards_killed") / 10
    names = list(out)
    X = np.stack([np.asarray(out[k], np.float32) for k in names], 1)
    return X, names


def group_of(name):
    """Importance group of a feature"""
    if name == "draft":
        return "draft"
    if name.startswith(("gold_", "cs_", "unspent_")) or name in ("obj_gold", "obj_gold_curve", "gold_total"):
        return "gold"
    if name.startswith(("xp_", "level_")) or name == "obj_xp":
        return "xp"
    if name.startswith("dead_"):
        return "dead"
    if name.startswith(("deaths_",)) or name in ("kills", "dmg_champ"):
        return "kills"
    if name.startswith(("tower_",)) or name in ("obj_towers", "plates"):
        return "towers"
    if name in ("inhib_s", "inhibs_ever", "obj_inhibs_down"):
        return "inhibs"
    if name.startswith(("drag_", "soul_")) or name in ("obj_dragons", "obj_soul_point", "obj_soul"):
        return "dragons"
    if name in ("elder_s", "baron_s", "barons", "elders", "obj_elder", "obj_baron"):
        return "baron_elder"
    if name in ("grubs_n", "heralds_n", "obj_grubs", "obj_herald"):
        return "grubs_herald"
    if name.startswith("items_"):
        return "items"
    if name in ("wards", "ctrl_wards", "wards_killed"):
        return "vision"
    raise KeyError(name)


# ---- draft logit: win-ratings refitted per block --------------------------------------

def _ratings_design(data, games, table, n_ids):
    ids = nnsets.ids(data, games, table)
    n = len(games)
    rows = np.repeat(np.arange(n), 10)
    sign = np.tile(np.r_[np.ones(5), -np.ones(5)], n)
    X = scipy.sparse.csr_matrix((sign, (rows, ids.ravel())), shape=(n, n_ids))
    P = scipy.sparse.csr_matrix((np.ones(n), (np.arange(n), data.platform[games].astype(np.int64))), shape=(n, 256))
    return scipy.sparse.hstack([P, X]).tocsr()


def _fit_ratings(X, y, l2):
    n = X.shape[0]

    def f(w):
        z = X @ w
        p = 1 / (1 + np.exp(-z))
        loss = np.mean(np.logaddexp(0, z) - y * z) + l2 * np.sum(w[256:] ** 2)
        grad = X.T @ (p - y) / n
        grad[256:] += 2 * l2 * w[256:]
        return loss, grad

    w0 = np.zeros(X.shape[1])
    return scipy.optimize.minimize(f, w0, jac=True, method="L-BFGS-B", options={"maxiter": 500}).x


def _logloss(y, z):
    return np.mean(np.logaddexp(0, z) - y * z)


def draft_logits(data, sets, l2_grid=(1e-3, 3e-3, 1e-2), k=5, seed=0):
    """Ratings logit for every fit game (cross-fitted in k parts) and scored game, and
    the l2 picked on the fit's newest 10%"""
    fit, scored = sets.fit, sets.scored
    table, n_ids = nnsets.rating_vocab(data, fit)
    y = data.y.astype(np.float64)
    Xi, Xv = _ratings_design(data, sets.inner, table, n_ids), _ratings_design(data, sets.val, table, n_ids)
    val_loss = {l2: _logloss(y[sets.val], Xv @ _fit_ratings(Xi, y[sets.inner], l2)) for l2 in l2_grid}
    l2 = min(val_loss, key=val_loss.get)
    logit = np.full(data.n, np.nan)
    Xf = _ratings_design(data, fit, table, n_ids)
    part = np.random.default_rng(seed).integers(0, k, len(fit))
    for j in range(k):
        tr, te = part != j, part == j
        logit[fit[te]] = Xf[te] @ _fit_ratings(Xf[tr], y[fit[tr]], l2)
    logit[scored] = _ratings_design(data, scored, table, n_ids) @ _fit_ratings(Xf, y[fit], l2)
    return logit, l2, val_loss


# ---- rows ------------------------------------------------------------------------------

def rows_for(state, games, minutes, draft_logit):
    """Stacked rows of `games` going at each of `minutes`: X, names, y-index game, minute"""
    Xs, gi, mi = [], [], []
    names = None
    for m in minutes:
        S = state.block(m, games)
        going = ~np.isnan(S[:, 0])
        if not going.any():
            continue
        X, names = features(state, S[going], draft_logit[games[going]].astype(np.float32), m)
        Xs.append(X)
        gi.append(games[going])
        mi.append(np.full(going.sum(), m, np.int16))
    return np.concatenate(Xs), names, np.concatenate(gi), np.concatenate(mi)


def hat(minute, knots):
    """[rows, K] hat basis: weights linear in minute between knots (winchance.zig)"""
    m = np.clip(np.asarray(minute, np.float64), knots[0], knots[-1])
    H = np.zeros((len(m), len(knots)), np.float32)
    for k in range(len(knots)):
        if k > 0:
            lo, hi = knots[k - 1], knots[k]
            sel = (m >= lo) & (m <= hi)
            H[sel, k] = ((m[sel] - lo) / (hi - lo)).astype(np.float32)
        if k + 1 < len(knots):
            lo, hi = knots[k], knots[k + 1]
            sel = (m >= lo) & (m < hi)
            H[sel, k] = ((hi - m[sel]) / (hi - lo)).astype(np.float32)
    H[m == knots[-1], -1] = 1
    return H


KNOTS = [1, 5, 10, 15, 20, 25, 30, 35, 40]


# ---- paired comparisons ----------------------------------------------------------------

def ll(y, p):
    p = np.clip(p, 1e-7, 1 - 1e-7)
    return -(y * np.log(p) + (1 - y) * np.log(1 - p))


def paired(y, pa, pb, games):
    """Mean log loss a minus b per row, 95% half-width clustered by game"""
    d = ll(y, pa) - ll(y, pb)
    u, inv = np.unique(games, return_inverse=True)
    sums = np.bincount(inv, d)
    cnt = np.bincount(inv)
    mean = sums.sum() / cnt.sum()
    resid = sums - mean * cnt
    se = np.sqrt(np.sum(resid**2)) / cnt.sum() * np.sqrt(len(u) / max(len(u) - 1, 1))
    return mean, 1.96 * se, len(u)
