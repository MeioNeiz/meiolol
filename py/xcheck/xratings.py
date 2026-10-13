"""win-ratings cross-check (src/lab/cand/win-ratings): same rows as netcheck's candidate.

Per block, three fits of blue-side intercept per platform + champion-role ratings:
- zigproc: torch, Zig's procedure (Adam lr 3e-3, batch 2048, L2 added to the gradient
  except intercepts, l2 grid picked on the newest 10% with patience 5, refit on all fit
  games for best + best // 10 epochs)
- exact: the L2 optimum (float64 L-BFGS), l2 picked on the same val from the same grid
- exact_zl2: the optimum at the l2 zigproc picked; sklearn at that l2 as a check of the
  optimiser
Compares each with the Zig candidate's per-game preds (netcheck preds.tsv `cand`).

usage: xratings.py SNAP --ref PREDS.tsv [--out DIR] [--seed N]
"""

import argparse
import os
import time

import numpy as np
import scipy.optimize
import scipy.sparse
import torch

import nnsets

L2_GRID = [3e-4, 1e-3, 3e-3, 1e-2]
FINE_GRID = [1e-5, 3e-5, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2]
LR = 3e-3
BATCH = 2048
MAX_EPOCHS = 60
PATIENCE = 5
N_PLATFORM = 256


def design(data, games, table):
    """Blue ids, red ids, platform, y as arrays"""
    i = nnsets.ids(data, games, table)
    return i[:, :5], i[:, 5:], data.platform[games].astype(np.int64), data.y[games].astype(np.float64)


def logits_np(params, blue, red, plat, n_ids):
    c, b = params[:N_PLATFORM], params[N_PLATFORM:]
    return c[plat] + b[blue].sum(1) - b[red].sum(1)


def logloss(y, z):
    p = np.clip(1 / (1 + np.exp(-z)), 1e-6, 1 - 1e-6)
    return -(y * np.log(p) + (1 - y) * np.log(1 - p))


def zig_train(n_ids, train, val, l2, epochs_cap, seed):
    """Zig's train(): returns (params float64, best_epoch, best_val_loss)"""
    g = torch.Generator().manual_seed(seed)
    blue, red, plat, y = (torch.from_numpy(a) for a in train)
    y = y.float()
    c = torch.zeros(N_PLATFORM, requires_grad=True)
    b = torch.zeros(n_ids, requires_grad=True)
    opt = torch.optim.Adam([c, b], lr=LR, betas=(0.9, 0.999), eps=1e-8)
    best, best_loss, best_epoch = None, float("inf"), 0
    n = len(y)
    for epoch in range(epochs_cap):
        order = torch.randperm(n, generator=g)
        for at in range(0, n, BATCH):
            idx = order[at : at + BATCH]
            z = c[plat[idx]] + b[blue[idx]].sum(1) - b[red[idx]].sum(1)
            loss = torch.nn.functional.binary_cross_entropy_with_logits(z, y[idx])
            opt.zero_grad()
            loss.backward()
            # Zig adds l2 * x to the averaged gradient, ratings only
            with torch.no_grad():
                b.grad += l2 * b
            opt.step()
        if val is None:
            best_epoch = epoch + 1
            continue
        p = np.concatenate([c.detach().double().numpy(), b.detach().double().numpy()])
        vl = logloss(val[3], logits_np(p, *val[:3], n_ids)).mean()
        if vl < best_loss - 1e-7:
            best_loss, best_epoch, best = vl, epoch + 1, p
        elif epoch + 1 - best_epoch >= PATIENCE:
            break
    if val is None:
        best = np.concatenate([c.detach().double().numpy(), b.detach().double().numpy()])
    return best, best_epoch, best_loss


def exact_fit(n_ids, train, l2, x0=None):
    """argmin mean log loss + l2 / 2 * |ratings|^2 (intercepts unpenalised), float64"""
    blue, red, plat, y = train
    n = len(y)
    rows = np.repeat(np.arange(n), 11)
    cols = np.concatenate([plat[:, None], N_PLATFORM + blue, N_PLATFORM + red], 1).ravel()
    vals = np.tile(np.r_[1.0, np.ones(5), -np.ones(5)], n)
    X = scipy.sparse.csr_matrix((vals, (rows, cols)), shape=(n, N_PLATFORM + n_ids))
    mask = np.r_[np.zeros(N_PLATFORM), np.ones(n_ids)]

    def f(w):
        z = X @ w
        loss = np.logaddexp(0, z) - y * z
        r = 1 / (1 + np.exp(-z)) - y
        grad = X.T @ r / n + l2 * mask * w
        return loss.mean() + 0.5 * l2 * np.sum(mask * w * w), grad

    w0 = np.zeros(N_PLATFORM + n_ids) if x0 is None else x0
    res = scipy.optimize.minimize(f, w0, jac=True, method="L-BFGS-B", options={"maxiter": 5000, "gtol": 1e-10, "ftol": 1e-14})
    return res.x, res


def sklearn_fit(n_ids, train, l2):
    """The same optimum via sklearn: C = 1 / (l2 N); intercept columns scaled by 1000 so
    their penalty is ~1e-6 of the ratings'"""
    from sklearn.linear_model import LogisticRegression

    blue, red, plat, y = train
    n = len(y)
    s = 1000.0
    rows = np.repeat(np.arange(n), 11)
    cols = np.concatenate([plat[:, None], N_PLATFORM + blue, N_PLATFORM + red], 1).ravel()
    vals = np.tile(np.r_[s, np.ones(5), -np.ones(5)], n)
    X = scipy.sparse.csr_matrix((vals, (rows, cols)), shape=(n, N_PLATFORM + n_ids))
    m = LogisticRegression(C=1 / (l2 * n), fit_intercept=False, solver="lbfgs", max_iter=10000, tol=1e-10)
    m.fit(X, y)
    w = m.coef_[0].copy()
    w[:N_PLATFORM] *= s
    return w


def run_block(data, block, seed, log):
    s = nnsets.sets(data, block)
    table, n_ids = nnsets.rating_vocab(data, s.fit)
    inner, val, fit, scored = (design(data, g, table) for g in (s.inner, s.val, s.fit, s.scored))
    out = {}

    t0 = time.time()
    best = None
    for l2 in L2_GRID:
        _, ep, vl = zig_train(n_ids, inner, val, l2, MAX_EPOCHS, seed)
        log(f"  zigproc l2 {l2:g}: epochs {ep} val {vl:.5f}")
        if best is None or vl < best[2]:
            best = (l2, ep, vl)
    zl2, zep, zvl = best
    p, _, _ = zig_train(n_ids, fit, None, zl2, max(1, zep + zep // 10), seed)
    out["zigproc"] = logits_np(p, *scored[:3], n_ids)
    log(f"block {block}: zigproc l2 {zl2:g} epochs {zep} val {zvl:.5f} ({time.time() - t0:.0f} s)")

    t0 = time.time()
    vals = {}
    w = None
    for l2 in sorted(FINE_GRID, reverse=True):
        w, _ = exact_fit(n_ids, inner, l2, w)
        vals[l2] = logloss(val[3], logits_np(w, *val[:3], n_ids)).mean()
    el2 = min((l2 for l2 in vals if l2 in L2_GRID), key=vals.get)
    fl2 = min(vals, key=vals.get)
    log("  exact val by l2: " + ", ".join(f"{l2:g} {v:.5f}" for l2, v in sorted(vals.items())))
    for name, l2 in (("exact", el2), ("exact_fine", fl2), ("exact_zl2", zl2)):
        w, res = exact_fit(n_ids, fit, l2)
        out[name] = logits_np(w, *scored[:3], n_ids)
        log(f"  {name}: l2 {l2:g}, converged {res.success}, |grad| {np.abs(res.jac).max():.1e}")
    wsk = sklearn_fit(n_ids, fit, zl2)
    out["sklearn_zl2"] = logits_np(wsk, *scored[:3], n_ids)
    log(f"  exact vs sklearn at l2 {zl2:g}: max |dlogit| {np.abs(out['exact_zl2'] - out['sklearn_zl2']).max():.1e} ({time.time() - t0:.0f} s)")
    return s, scored[3], out, {"zigproc_l2": zl2, "zigproc_epochs": zep, "exact_l2": el2, "fine_l2": fl2}


def paired(y, p_ref, p_new):
    """mean and se of per-game log loss difference new - ref (one row per game)"""
    d = logloss(y, p_new) - logloss(y, p_ref)
    return d.mean(), d.std(ddof=1) / np.sqrt(len(d))


def zigproc_logits(data, block, seed):
    s = nnsets.sets(data, block)
    table, n_ids = nnsets.rating_vocab(data, s.fit)
    inner, val, fit, scored = (design(data, g, table) for g in (s.inner, s.val, s.fit, s.scored))
    best = None
    for l2 in L2_GRID:
        _, ep, vl = zig_train(n_ids, inner, val, l2, MAX_EPOCHS, seed)
        if best is None or vl < best[2]:
            best = (l2, ep, vl)
    p, _, _ = zig_train(n_ids, fit, None, best[0], max(1, best[1] + best[1] // 10), seed)
    return logits_np(p, *scored[:3], n_ids), scored[3], best


def spread(data, ref, a, log):
    """Ratings' own seed noise: Zig's procedure per shuffle seed; per block the sd of
    log loss over seeds, and each seed's paired difference to Zig's seed-1 fit"""
    seeds = [int(x) for x in a.spread.split(",")]
    pooled = {s: [] for s in seeds}
    ys, zigs = [], []
    with open(os.path.join(a.out, "spread.tsv"), "w") as pf:
        pf.write("block\tmatch_id\ty\tzig\t" + "\t".join(f"seed{s}" for s in seeds) + "\n")
        for b in a.blocks.split(","):
            zig = np.log(np.clip(ref[b]["cand"], 1e-6, 1 - 1e-6) / np.clip(1 - ref[b]["cand"], 1e-6, 1))
            outs = {}
            for sd in seeds:
                z, y, best = zigproc_logits(data, b, sd)
                outs[sd] = z
                log(f"block {b} seed {sd}: l2 {best[0]:g} epochs {best[1]} val {best[2]:.5f} scored {logloss(y, z).mean():.5f}")
            ls = np.array([logloss(y, outs[sd]).mean() for sd in seeds])
            ens = np.log(np.mean([1 / (1 + np.exp(-outs[sd])) for sd in seeds], 0))
            ens = ens - np.log1p(-np.exp(ens))
            dz = np.mean([np.abs(outs[sd] - outs[seeds[0]]).mean() for sd in seeds[1:]])
            log(f"RESULT block {b}: zig {logloss(y, zig).mean():.5f}, seeds mean {ls.mean():.5f} sd {ls.std(ddof=1):.5f} (min {ls.min():.5f} max {ls.max():.5f}), seed ensemble {logloss(y, ens).mean():.5f}; mean |dlogit| between seeds {dz:.4f}")
            for i in range(len(y)):
                pf.write(f"{b}\t{ref[b]['match_id'][i]}\t{y[i]:.0f}\t{zig[i]:.6f}\t" + "\t".join(f"{outs[sd][i]:.6f}" for sd in seeds) + "\n")
            if b != "dev":
                ys.append(y)
                zigs.append(zig)
                for sd in seeds:
                    pooled[sd].append(outs[sd])
    if ys:
        y = np.concatenate(ys)
        ls = np.array([logloss(y, np.concatenate(pooled[sd])).mean() for sd in seeds])
        log(f"RESULT folds pooled: zig {logloss(y, np.concatenate(zigs)).mean():.5f}, seeds mean {ls.mean():.5f} sd {ls.std(ddof=1):.5f} (min {ls.min():.5f} max {ls.max():.5f})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--ref", required=True)
    ap.add_argument("--out", default="out")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--blocks", default=",".join(nnsets.BLOCKS))
    ap.add_argument("--spread", help="seeds, e.g. 1,2,3,4,5: Zig's procedure only, per seed")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", "4")))
    logf = open(os.path.join(a.out, "xratings.log"), "w")

    def log(msg):
        print(msg, flush=True)
        logf.write(msg + "\n")
        logf.flush()

    data = nnsets.load(a.snap)
    ref = nnsets.read_preds(a.ref)
    ok, lines = nnsets.check_against(data, ref)
    for line in lines:
        log(line)
    if not ok:
        log("reader does not reproduce the reference's scored games: stop")
        raise SystemExit(1)

    if a.spread:
        return spread(data, ref, a, log)
    names = ["zigproc", "exact", "exact_fine", "exact_zl2", "sklearn_zl2"]
    pooled = {k: [] for k in ["y", "zig"] + names}
    with open(os.path.join(a.out, "preds.tsv"), "w") as pf:
        pf.write("block\tmatch_id\ty\tzig\t" + "\t".join(names) + "\n")
        for b in a.blocks.split(","):
            s, y, out, info = run_block(data, b, a.seed, log)
            zig = np.log(np.clip(ref[b]["cand"], 1e-6, 1 - 1e-6) / np.clip(1 - ref[b]["cand"], 1e-6, 1))
            for k in names:
                d, se = paired(y, zig, out[k])
                dz = np.abs(out[k] - zig)
                log(f"  {k} - zig: {d:+.5f} ± {1.96 * se:.5f} nats/game; |dlogit| mean {dz.mean():.4f} max {dz.max():.4f}; corr {np.corrcoef(out[k], zig)[0, 1]:.5f}")
            mids = ref[b]["match_id"]
            for i in range(len(y)):
                pf.write(f"{b}\t{mids[i]}\t{y[i]:.0f}\t{zig[i]:.6f}\t" + "\t".join(f"{out[k][i]:.6f}" for k in names) + "\n")
            if b != "dev":
                pooled["y"].append(y)
                pooled["zig"].append(zig)
                for k in names:
                    pooled[k].append(out[k])
    if pooled["y"]:
        y = np.concatenate(pooled["y"])
        zig = np.concatenate(pooled["zig"])
        log(f"folds pooled ({len(y)} games): zig log loss {logloss(y, zig).mean():.5f}")
        for k in names:
            p = np.concatenate(pooled[k])
            d, se = paired(y, zig, p)
            per = [paired(yy, zz, pp)[0] for yy, zz, pp in zip(pooled["y"], pooled["zig"], pooled[k])]
            log(f"  {k}: {logloss(y, p).mean():.5f}, - zig {d:+.5f} ± {1.96 * se:.5f}, better in {sum(x < 0 for x in per)} of {len(per)} folds")


if __name__ == "__main__":
    main()
