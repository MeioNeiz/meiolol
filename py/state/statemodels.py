"""Live state models: P(blue wins | draft, state at minute t), per protocol block.

Blocks as netcheck (nnsets.sets): dev (fit splits 0-5, score dev-val) and folds 1-5
(fit older splits, score the fold), games with a 10-player timeline only. Rows: every
game-minute 1..40 while going (state-export). Models, each fitted on the block's fit
games only:
- wc: winchance.zig's state (objectives lead + held), weights linear in minute between
  knots every 5 minutes (the shipped model's form), refitted here
- wcd: wc + the draft logit (win-ratings, cross-fitted on fit games)
- rich: every feature (statecommon.features), same smooth logistic form
- gbdt: LightGBM on every feature + minute, rounds by early stopping on the fit's
  newest 10%, refitted on all fit games
- richc: rich + a champion-role effect by minute beyond the state (ridge, picked on
  the fit's newest 10%): the explainable form of what champions are worth given the state
- gbdt_r: the same boosted from rich's logit (init score): what trees add beyond the
  smooth logistic; the offset is cross-fitted on fit games (3 parts by game)
Writes OUT/preds.npz (block, game, minute, y, one column per model) and OUT/report.md.

usage: statemodels.py SNAP [--out DIR] [--blocks dev,1,2,3,4,5] [--models wc,wcd,rich,gbdt]
"""

import argparse
import os
import time

import numpy as np
import torch

import nnsets
import statecommon as sc

MINUTES = list(range(1, 41))
# Fit rows every Nth minute (memory on the shared gpu-box); scored rows every minute
FIT_EVERY = [2]
REPORT_MINUTES = [1, 5, 10, 15, 20, 25, 30, 35, 40]


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


class Smooth:
    """Logistic regression with each weight (and the intercept) linear in minute between
    knots; inputs standardised on fit rows; L2 on standardised weights"""

    def __init__(self, l2=1e-5, knots=sc.KNOTS):
        self.l2, self.knots = l2, knots

    def fit(self, X, minute, y, max_iter=300):
        X = X.astype(np.float32)
        self.mu = X.mean(0)
        self.sd = X.std(0) + 1e-6
        Xt = torch.from_numpy((X - self.mu) / self.sd)
        H = torch.from_numpy(sc.hat(minute, self.knots))
        yt = torch.from_numpy(y.astype(np.float32))
        F, K = X.shape[1], len(self.knots)
        W = torch.zeros(F, K, requires_grad=True)
        b = torch.zeros(K, requires_grad=True)
        opt = torch.optim.LBFGS([W, b], lr=1, max_iter=max_iter, history_size=20, line_search_fn="strong_wolfe", tolerance_grad=1e-7, tolerance_change=1e-10)

        def closure():
            opt.zero_grad()
            z = ((Xt @ W) * H).sum(1) + H @ b
            loss = torch.nn.functional.binary_cross_entropy_with_logits(z, yt) + self.l2 * (W**2).sum()
            loss.backward()
            return loss

        opt.step(closure)
        self.W, self.b = W.detach().numpy(), b.detach().numpy()
        return self

    def logit(self, X, minute):
        H = sc.hat(minute, self.knots)
        Xs = (X.astype(np.float32) - self.mu) / self.sd
        return ((Xs @ self.W) * H).sum(1) + H @ self.b

    def predict(self, X, minute):
        return 1 / (1 + np.exp(-self.logit(X, minute)))


class SmoothChamp(Smooth):
    """Smooth plus a champion-role effect by minute (hat basis over the same knots),
    blue's ten minus red's: what each champion is worth beyond the state, minute by
    minute; ridge on those effects, chosen on the fit's newest games"""

    def __init__(self, l2_champ=1e-4, **kw):
        super().__init__(**kw)
        self.l2_champ = l2_champ

    def _z(self, Xt, H, ids, W, b, E):
        sign = torch.tensor([1.0] * 5 + [-1.0] * 5)
        c = sum(sign[s] * (E[ids[:, s]] * H).sum(1) for s in range(10))
        return ((Xt @ W) * H).sum(1) + H @ b + c

    def fit(self, X, minute, y, ids, n_ids, max_iter=300):
        X = X.astype(np.float32)
        self.mu = X.mean(0)
        self.sd = X.std(0) + 1e-6
        Xt = torch.from_numpy((X - self.mu) / self.sd)
        H = torch.from_numpy(sc.hat(minute, self.knots))
        it = torch.from_numpy(ids.astype(np.int64))
        yt = torch.from_numpy(y.astype(np.float32))
        F, K = X.shape[1], len(self.knots)
        W = torch.zeros(F, K, requires_grad=True)
        b = torch.zeros(K, requires_grad=True)
        E = torch.zeros(n_ids, K, requires_grad=True)
        opt = torch.optim.LBFGS([W, b, E], lr=1, max_iter=max_iter, history_size=20, line_search_fn="strong_wolfe", tolerance_grad=1e-7, tolerance_change=1e-10)

        def closure():
            opt.zero_grad()
            z = self._z(Xt, H, it, W, b, E)
            loss = torch.nn.functional.binary_cross_entropy_with_logits(z, yt) + self.l2 * (W**2).sum() + self.l2_champ * (E**2).sum()
            loss.backward()
            return loss

        opt.step(closure)
        self.W, self.b, self.E = W.detach().numpy(), b.detach().numpy(), E.detach().numpy()
        return self

    def logit(self, X, minute, ids):
        H = sc.hat(minute, self.knots)
        z = super().logit(X, minute)
        for s in range(10):
            z = z + (1 if s < 5 else -1) * (self.E[ids[:, s]] * H).sum(1)
        return z

    def predict(self, X, minute, ids):
        return 1 / (1 + np.exp(-self.logit(X, minute, ids)))


CHAMP_L2 = [1e-5, 3e-5, 1e-4, 3e-4]


def fit_richc(Xf, mf, yf, ids_f, n_ids, is_val):
    """l2 on the champion effects picked on the fit's newest 10%, then refit on all"""
    losses = {}
    for l2 in CHAMP_L2:
        m = SmoothChamp(l2_champ=l2).fit(Xf[~is_val], mf[~is_val], yf[~is_val], ids_f[~is_val], n_ids)
        losses[l2] = sc.ll(yf[is_val], m.predict(Xf[is_val], mf[is_val], ids_f[is_val])).mean()
    best = min(losses, key=losses.get)
    log("  richc l2 on val: " + ", ".join(f"{k}: {v:.5f}" for k, v in losses.items()))
    return SmoothChamp(l2_champ=best).fit(Xf, mf, yf, ids_f, n_ids), best


GBDT_PARAMS = dict(
    objective="binary",
    learning_rate=0.1,
    num_leaves=31,
    max_bin=63,
    min_data_in_leaf=1000,
    feature_fraction=0.8,
    bagging_fraction=0.8,
    bagging_freq=1,
    lambda_l2=10.0,
    verbose=-1,
)


def fit_gbdt(X, minute, y, val_mask, init=None, seed=0):
    import lightgbm as lgb

    params = dict(GBDT_PARAMS, seed=seed, num_threads=int(os.environ.get("OMP_NUM_THREADS", "0") or 0))
    Xm = np.column_stack([X, minute.astype(np.float32)])
    sub = (lambda a, m: None) if init is None else (lambda a, m: a[m])
    tr = lgb.Dataset(Xm[~val_mask], y[~val_mask], init_score=sub(init, ~val_mask))
    va = lgb.Dataset(Xm[val_mask], y[val_mask], init_score=sub(init, val_mask), reference=tr)
    m = lgb.train(params, tr, 1500, valid_sets=[va], callbacks=[lgb.early_stopping(50, verbose=False)])
    best = m.best_iteration
    full = lgb.train(params, lgb.Dataset(Xm, y, init_score=init), int(best * 1.1) + 1)
    return full, best


def gbdt_predict(model, X, minute, init=None):
    raw = model.predict(np.column_stack([X, minute.astype(np.float32)]), raw_score=True)
    if init is not None:
        raw = raw + init
    return 1 / (1 + np.exp(-raw))


def crossfit_rich(X, minute, y, games, k=3, seed=0):
    """Rich logit for fit rows from fits without the row's game"""
    u, inv = np.unique(games, return_inverse=True)
    part = np.random.default_rng(seed).integers(0, k, len(u))[inv]
    out = np.zeros(len(y))
    for j in range(k):
        m = Smooth().fit(X[part != j], minute[part != j], y[part != j])
        out[part == j] = m.logit(X[part == j], minute[part == j])
    return out


def run_block(state, data, block, models, out):
    sets = nnsets.sets(data, block)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    log(f"block {block}: fit {len(sets.fit)} games, scored {len(sets.scored)}; with timeline {has_tl[sets.fit].sum()} / {has_tl[sets.scored].sum()}")
    logit, l2, vl = sc.draft_logits(data, sets)
    log(f"  draft ratings l2 {l2} (val {', '.join(f'{k}: {v:.5f}' for k, v in vl.items())})")
    fit_g = sets.fit[has_tl[sets.fit]]
    sc_g = sets.scored[has_tl[sets.scored]]
    val_cut = nnsets.val_cut(data.start[sets.fit])
    Xf, names, gf, mf = sc.rows_for(state, fit_g, MINUTES[:: FIT_EVERY[0]], logit)
    Xs, _, gs, ms = sc.rows_for(state, sc_g, MINUTES, logit)
    yf, ys = data.y[gf], data.y[gs]
    log(f"  rows: fit {len(yf)}, scored {len(ys)}, {len(names)} features")
    idx = {n: i for i, n in enumerate(names)}
    cols = {
        "wc": [idx[f"obj_{f}"] for f in sc.WC],
        "wcd": [idx[f"obj_{f}"] for f in sc.WC] + [idx["draft"]],
        "rich": list(range(len(names))),
    }
    res = {"block": np.full(len(ys), block), "game": gs, "minute": ms, "y": ys}
    for name in models:
        t0 = time.time()
        if name in cols:
            c = cols[name]
            m = Smooth().fit(Xf[:, c], mf, yf)
            res[name] = m.predict(Xs[:, c], ms)
            if name == "wcd":
                fade = m.W[-1] / m.sd[-1]
                log("  draft weight a(t) by knot " + ", ".join(f"{k}: {w:.2f}" for k, w in zip(sc.KNOTS, fade)))
                res["fade"] = np.tile(fade, (len(ys), 1))
            if name == "rich":
                np.save(os.path.join(out, f"rich-W-{block}.npy"), m.W)
                rich_scored = m.logit(Xs, ms)
        elif name == "gbdt":
            model, best = fit_gbdt(Xf, mf, yf, data.start[gf] >= val_cut)
            res[name] = gbdt_predict(model, Xs, ms)
            model.save_model(os.path.join(out, f"gbdt-{block}.txt"))
            log(f"  gbdt best round {best}")
        elif name == "richc":
            table, n_ids = nnsets.rating_vocab(data, sets.fit)
            m, l2c = fit_richc(Xf, mf, yf, nnsets.ids(data, gf, table), n_ids, data.start[gf] >= val_cut)
            res[name] = m.predict(Xs, ms, nnsets.ids(data, gs, table))
            np.save(os.path.join(out, f"richc-E-{block}.npy"), m.E)
            log(f"  richc l2 {l2c}; champion effect sd by knot " + ", ".join(f"{v:.3f}" for v in m.E[1:].std(0)))
        elif name == "gbdt_r":
            off = crossfit_rich(Xf, mf, yf, gf)
            model, best = fit_gbdt(Xf, mf, yf, data.start[gf] >= val_cut, init=off)
            res[name] = gbdt_predict(model, Xs, ms, init=rich_scored)
            log(f"  gbdt_r best round {best}")
        log(f"  {name}: {time.time() - t0:.0f} s, scored log loss {sc.ll(ys, res[name]).mean():.5f}")
    with open(os.path.join(out, "features.txt"), "w") as f:
        f.write("\n".join(names) + "\n")
    return res


def ece(y, p, bins=10):
    """Expected calibration error, equal-mass bins"""
    o = np.argsort(p)
    return sum(abs(y[b].mean() - p[b].mean()) * len(b) for b in np.array_split(o, bins)) / len(y)


def auc(y, p):
    r = np.argsort(np.argsort(p)) + 1
    n1 = y.sum()
    return (r[y == 1].sum() - n1 * (n1 + 1) / 2) / (n1 * (len(y) - n1))


def report(all_res, models, out):
    lines = ["# Live state models vs winchance's form (wc), log loss per game-minute, model minus wc", ""]
    for label, blocks in (("folds", ["1", "2", "3", "4", "5"]), ("dev-val", ["dev"])):
        rs = [r for r in all_res if r["block"][0] in blocks]
        if not rs:
            continue
        cat = {k: np.concatenate([r[k] for r in rs]) for k in rs[0] if k != "fade"}
        if "fade" in rs[0]:
            cat["fade"] = True
        lines += [f"## {label}", "", "| minute | games | wc log loss | " + " | ".join(m for m in models if m != "wc") + " |", "|" + " --- |" * (2 + len(models))]
        for mn in REPORT_MINUTES + ["all"]:
            sel = np.ones(len(cat["y"]), bool) if mn == "all" else cat["minute"] == mn
            if not sel.any():
                continue
            y, g = cat["y"][sel], cat["game"][sel]
            cells = []
            for m in models:
                if m == "wc":
                    continue
                d, ci, n = sc.paired(y, cat[m][sel], cat["wc"][sel], g)
                cells.append(f"{d:+.5f} ± {ci:.5f}")
            lines.append(f"| {mn} | {len(np.unique(g))} | {sc.ll(y, cat['wc'][sel]).mean():.5f} | " + " | ".join(cells) + " |")
        lines += ["", "Calibration and ranking per minute (ECE equal-mass, 10 bins; AUC):", "",
                  "| minute | " + " | ".join(f"{m} ECE | {m} AUC" for m in models) + " |", "|" + " --- |" * (1 + 2 * len(models))]
        for mn in REPORT_MINUTES:
            sel = cat["minute"] == mn
            if sel.sum() < 100:
                continue
            lines.append(f"| {mn} | " + " | ".join(f"{ece(cat['y'][sel], cat[m][sel]):.4f} | {auc(cat['y'][sel], cat[m][sel]):.3f}" for m in models) + " |")
        if "fade" in cat:
            lines.append("")
            lines.append("Draft logit weight a(t) in wcd (1 = the draft's own odds), mean over blocks, by knot: " + ", ".join(
                f"{k}: {w:.2f}" for k, w in zip(sc.KNOTS, np.mean([r["fade"][0] for r in rs], 0))))
        if len(blocks) > 1:
            lines.append("")
            lines.append("Better in k of 5 folds (all minutes): " + ", ".join(
                f"{m} {sum(sc.paired(r['y'], r[m], r['wc'], r['game'])[0] < 0 for r in rs)}" for m in models if m != "wc"))
        lines.append("")
    text = "\n".join(lines)
    with open(os.path.join(out, "report.md"), "w") as f:
        f.write(text)
    print(text, flush=True)


def coverage(state, data, out):
    """Share of going rows where each feature is nonzero, minutes 5..30"""
    has_tl = np.flatnonzero(state.game[:, state.gcols["has_timeline"]] == 1)
    logit = np.zeros(data.n)
    lines = ["# Coverage: share of going game-minutes with a nonzero value", "", "| feature | 5 | 10 | 15 | 20 | 25 | 30 |", "| --- |" + " --- |" * 6]
    per = {}
    for m in [5, 10, 15, 20, 25, 30]:
        X, names, _, _ = sc.rows_for(state, has_tl, [m], logit)
        per[m] = (X != 0).mean(0), names
    for i, n in enumerate(per[5][1]):
        lines.append(f"| {n} | " + " | ".join(f"{per[m][0][i]:.3f}" for m in per) + " |")
    with open(os.path.join(out, "coverage.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--blocks", default="dev,1,2,3,4,5")
    ap.add_argument("--models", default="wc,wcd,rich,gbdt,gbdt_r")
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--fit-every", type=int, default=2)
    ap.add_argument("--report-from", help="preds.npz of an earlier run: report only")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    FIT_EVERY[0] = a.fit_every
    models = a.models.split(",")
    if a.report_from:
        z = np.load(a.report_from)
        n_blocks = 1 + max(int(k.rsplit(".", 1)[1]) for k in z.files)
        all_res = [{k.rsplit(".", 1)[0]: z[k] for k in z.files if k.endswith(f".{i}")} for i in range(n_blocks)]
        report(all_res, [m for m in models if m in all_res[0]], a.out)
        return
    torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", "8") or 8))
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    if a.coverage:
        coverage(state, data, a.out)
    all_res = []
    for b in filter(None, a.blocks.split(",")):
        all_res.append(run_block(state, data, b, models, a.out))
        np.savez_compressed(os.path.join(a.out, "preds.npz"), **{f"{k}.{i}": v for i, r in enumerate(all_res) for k, v in r.items()})
        report(all_res, models, a.out)


if __name__ == "__main__":
    main()
