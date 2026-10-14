"""Torch's resid offsets vs Zig's (from a set-net --dump run) per game: correlation,
scale (slope of torch on Zig, sd ratio) and log loss per part. A training/scored scale
mismatch on one side would explain resid nets disagreeing on otherwise equal inputs.

usage: offcmp.py SNAP --dump SETDUMPDIR [--blocks dev,2,3] [--offset-seed 1]
"""

import argparse
from types import SimpleNamespace

import numpy as np

import nnsets
import xnets


def loss(y, z):
    p = np.clip(1 / (1 + np.exp(-z)), 1e-6, 1 - 1e-6)
    return float(-(y * np.log(p) + (1 - y) * np.log(1 - p)).mean())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--dump", required=True)
    ap.add_argument("--blocks", default="dev,2,3")
    ap.add_argument("--offset-seed", type=int, default=1)
    a = ap.parse_args()
    data = nnsets.load(a.snap)
    o = SimpleNamespace(cross_part="random", offset_seed=a.offset_seed)
    for b in a.blocks.split(","):
        s = nnsets.sets(data, b)
        mine = xnets.offsets_for(data, s, a.offset_seed, print, o)
        zig = xnets.dumped_offsets(data, s, a.dump, b)
        for part, games in (("inner", s.inner), ("val", s.val), ("fit", s.fit), ("scored", s.scored)):
            t, z, y = mine[part], zig[part], data.y[games]
            slope = np.cov(t, z)[0, 1] / z.var()
            print(f"RESULT block {b} {part}: corr {np.corrcoef(t, z)[0, 1]:.4f}, slope torch on zig {slope:.3f}, sd torch {t.std():.4f} zig {z.std():.4f}, loss torch {loss(y, t):.5f} zig {loss(y, z):.5f}", flush=True)


if __name__ == "__main__":
    main()
