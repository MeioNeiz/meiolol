"""Paired comparisons of live state models across runs: joins preds files (statemodels'
preds.npz, statenet's preds-net.npz) on (block, game, minute) and reports each model
minus a reference, log loss per game-minute, ± 95% clustered by game, folds pooled and
dev-val, by minute and over all minutes, with k of 5 folds.

usage: statecompare.py --ref RUN:MODEL [--out DIR] RUN:FILE:MODEL[=LABEL]...
  RUN is a run dir (relative to ~/ml/runs), FILE its out/ file, e.g.
  statecompare.py --ref A:preds.npz:rich A:preds.npz:richc B:preds-net.npz:neta
"""

import argparse
import os

import numpy as np

import statecommon as sc

MINUTES = [1, 5, 10, 15, 20, 25, 30, 35]
FOLDS = ["1", "2", "3", "4", "5"]


def load(path):
    z = np.load(path)
    nb = 1 + max(int(k.rsplit(".", 1)[1]) for k in z.files)
    return [{k.rsplit(".", 1)[0]: z[k] for k in z.files if k.endswith(f".{i}")} for i in range(nb)]


def keyed(blocks, model):
    out = {}
    for r in blocks:
        b = str(r["block"][0])
        k = r["game"].astype(np.int64) * 64 + r["minute"].astype(np.int64)
        out[b] = (k, r["y"], r[model])
    return out


def spec(s, runs_dir):
    run, file, model = s.split(":")
    label = model
    if "=" in model:
        model, label = model.split("=")
    return keyed(load(os.path.join(runs_dir, run, "out", file)), model), label


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True)
    ap.add_argument("--out", default="out")
    ap.add_argument("--runs", default="~/ml/runs")
    ap.add_argument("models", nargs="+")
    a = ap.parse_args()
    runs = os.path.expanduser(a.runs)
    ref, ref_label = spec(a.ref, runs)
    lines = [f"# vs {ref_label}: log loss per game-minute, model minus reference, ± 95% by game", ""]
    for s in a.models:
        m, label = spec(s, runs)
        for name, blocks in (("folds", FOLDS), ("dev-val", ["dev"])):
            ks, ys, ps, rs = [], [], [], []
            per_fold = []
            for b in blocks:
                if b not in m or b not in ref:
                    continue
                kr, yr, pr = ref[b]
                km, ym, pm = m[b]
                common, ir, im = np.intersect1d(kr, km, return_indices=True)
                assert np.array_equal(yr[ir], ym[im]), f"labels differ in block {b}"
                ks.append(common)
                ys.append(yr[ir])
                rs.append(pr[ir])
                ps.append(pm[im])
                per_fold.append(sc.paired(yr[ir], pm[im], pr[ir], common // 64)[0])
            if not ks:
                continue
            k, y, p, r = (np.concatenate(x) for x in (ks, ys, ps, rs))
            g, mn = k // 64, k % 64
            d, ci, n = sc.paired(y, p, r, g)
            cells = []
            for minute in MINUTES:
                sel = mn == minute
                if sel.sum() > 100:
                    dm, cim, _ = sc.paired(y[sel], p[sel], r[sel], g[sel])
                    cells.append(f"{minute}: {dm:+.4f} ± {cim:.4f}")
            better = f", better in {sum(x < 0 for x in per_fold)} of {len(per_fold)}" if len(per_fold) > 1 else ""
            lines.append(f"- {label}, {name} ({n} games, {len(y)} rows): {d:+.5f} ± {ci:.5f}{better}")
            lines.append("  by minute " + "; ".join(cells))
    text = "\n".join(lines) + "\n"
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "compare.md"), "w") as f:
        f.write(text)
    print(text, flush=True)


if __name__ == "__main__":
    main()
