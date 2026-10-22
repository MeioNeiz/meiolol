"""Ensemble selection over per-game prediction files (lab-frontier A2).

Members are columns of preds.tsv files (netcheck, champcomp: fold, match_id, y, ...),
joined on match_id. Weights are fitted forward: block b (folds 2-5, dev-val) is scored
with weights fitted on the blocks before it only. A member may name a sealed file: its
weights are fitted on the dev-seed preds and scored with the sealed ones, so seed luck
picked in selection is not scored.

Methods, all in logit space:
- best: the single member with the lowest loss on the fit blocks
- greedy: Caruana selection with replacement, sorted start (best 3), 20 bags of half
  the members, 40 steps each, weights averaged over bags
- stack: logistic regression on member logits (L2 1e-4 per game), with an intercept

Usage: ensel.py SPEC.tsv [REF [OUT]]   SPEC lines: name<TAB>file<TAB>column[<TAB>sealed file]
Paths are relative to SPEC's directory or absolute. Prints per-block and pooled paired
log loss vs REF (a member name; default the first), milli-nats, 95% paired interval.
OUT: preds.tsv of the three methods (fold, match_id, y, best, greedy, stack; block 1 has
none, so it is left out)
"""

import os
import sys

import numpy as np
import pandas as pd

BLOCKS = ["1", "2", "3", "4", "5", "dev"]
EPS = 1e-6


def logit(p):
    p = np.clip(p, EPS, 1 - EPS)
    return np.log(p / (1 - p))


def loss(z, y):
    # per-game log loss of logits z
    return np.logaddexp(0, z) - y * z


def load(spec_path):
    base = os.path.dirname(os.path.abspath(spec_path))
    spec = [l.rstrip("\n").split("\t") for l in open(spec_path) if l.strip() and not l.startswith("#")]
    frames = {}

    def read(path):
        path = path if os.path.isabs(path) else os.path.join(base, path)
        if path not in frames:
            frames[path] = pd.read_csv(path, sep="\t", dtype={"fold": str}).set_index("match_id")
        return frames[path]

    names, dev, sealed = [], {}, {}
    ref = None
    for row in spec:
        name, path, col = row[0], row[1], row[2]
        d = read(path)
        if ref is None:
            ref = d[["fold", "y"]]
        names.append(name)
        dev[name] = d[col]
        sealed[name] = read(row[3])[col] if len(row) > 3 and row[3] else d[col]
    games = ref.index
    for n in names:
        for s in (dev[n], sealed[n]):
            missing = games.difference(s.index)
            if len(missing):
                sys.exit(f"{n}: {len(missing)} games missing")
    y = ref["y"].to_numpy(float)
    fold = ref["fold"].to_numpy(str)
    Zd = np.column_stack([logit(dev[n].reindex(games).to_numpy(float)) for n in names])
    Zs = np.column_stack([logit(sealed[n].reindex(games).to_numpy(float)) for n in names])
    return names, y, fold, Zd, Zs, games


def greedy(Z, y, rng, bags=20, steps=40, start=3):
    m = Z.shape[1]
    single = loss(Z, y[:, None]).mean(0)
    w_all = np.zeros(m)
    for _ in range(bags):
        pool = np.flatnonzero(rng.random(m) < 0.5)
        if len(pool) == 0:
            pool = np.array([rng.integers(m)])
        order = pool[np.argsort(single[pool])]
        counts = np.zeros(m)
        counts[order[:start]] += 1
        s = Z[:, order[:start]].sum(1)
        k = min(start, len(order))
        for _ in range(steps):
            cand = (s[:, None] + Z[:, pool]) / (k + 1)
            j = pool[np.argmin(loss(cand, y[:, None]).mean(0))]
            s = s + Z[:, j]
            counts[j] += 1
            k += 1
        w_all += counts / counts.sum()
    return w_all / bags


def stack(Z, y, l2=1e-4, iters=50):
    X = np.column_stack([np.ones(len(y)), Z])
    w = np.zeros(X.shape[1])
    w[1:] = 1.0 / Z.shape[1]
    n = len(y)
    for _ in range(iters):
        z = X @ w
        p = 1 / (1 + np.exp(-z))
        g = X.T @ (p - y) / n + l2 * np.r_[0, w[1:]]
        H = (X * (p * (1 - p))[:, None]).T @ X / n + l2 * np.diag(np.r_[0, np.ones(Z.shape[1])])
        step = np.linalg.solve(H, g)
        w -= step
        if np.abs(step).max() < 1e-9:
            break
    return w


def main():
    spec = sys.argv[1]
    names, y, fold, Zd, Zs, games = load(spec)
    ref = names.index(sys.argv[2]) if len(sys.argv) > 2 else 0
    rng = np.random.default_rng(1)
    out = {k: np.full(len(y), np.nan) for k in ["best", "greedy", "stack"]}
    weights = {}
    for i, b in enumerate(BLOCKS[1:], 1):
        fit = np.isin(fold, BLOCKS[:i])
        sc = fold == b
        Zf, yf = Zd[fit], y[fit]
        best = int(np.argmin(loss(Zf, yf[:, None]).mean(0)))
        out["best"][sc] = Zs[sc, best]
        w = greedy(Zf, yf, rng)
        out["greedy"][sc] = Zs[sc] @ w
        ws = stack(Zf, yf)
        out["stack"][sc] = ws[0] + Zs[sc] @ ws[1:]
        weights[b] = (names[best], w, ws)

    scored = fold != "1"
    if len(sys.argv) > 3:
        cols = {k: 1 / (1 + np.exp(-v[scored])) for k, v in out.items()}
        pd.DataFrame({"fold": fold[scored], "match_id": games[scored], "y": y[scored].astype(int), **cols}).to_csv(
            sys.argv[3], sep="\t", index=False, float_format="%.6f"
        )
    base = loss(Zs[:, ref], y)

    def row(label, z):
        d = (loss(z, y) - base) * 1000
        cells = []
        for b in BLOCKS[1:]:
            m = fold == b
            cells.append(f"{d[m].mean():+.2f}")
        dd = d[scored]
        half = 1.96 * dd.std(ddof=1) / np.sqrt(len(dd))
        acc = ((z[scored] > 0) == (y[scored] > 0.5)).mean() * 100
        print(f"| {label} | {dd.mean():+.2f} ± {half:.2f} | {' | '.join(cells)} | {loss(z[scored], y[scored]).mean():.5f} | {acc:.1f}% |")

    print(f"vs {names[ref]} (sealed where given), milli-nats a game, scored blocks 2-5 + dev-val, n {scored.sum()}")
    print(f"| model | pooled | {' | '.join(BLOCKS[1:])} | loss | acc |")
    print("| --- | --- |" + " --- |" * (len(BLOCKS) + 1))
    for j, n in enumerate(names):
        row(n, Zs[:, j])
    for k in out:
        row(f"**{k}**", out[k])
    print()
    for b, (best, w, ws) in weights.items():
        g = ", ".join(f"{names[j]} {w[j]:.2f}" for j in np.argsort(-w) if w[j] > 0.005)
        s = ", ".join(f"{names[j]} {ws[j + 1]:+.2f}" for j in range(len(names)))
        print(f"{b}: best {best}; greedy {g}; stack b {ws[0]:+.3f} {s}")


if __name__ == "__main__":
    main()
