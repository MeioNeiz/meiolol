"""Reads SNAP/nn (meiolol-lab nn-export) and rebuilds netcheck's sets per block.

Mirrors src/lab/winnet.zig runBlock: fit = played dev-visible games before the block,
val = newest 10% of fit by start (inner the rest), scored = dev-val (dev) or the fold's
played games. Ids as winnet's Vocab (champion-roles with min_games fit games, else the
role's 0-4) and win-ratings' (every fit champion-role, 0 unseen).
"""

import json
import os
from dataclasses import dataclass

import numpy as np

BLOCKS = ["dev", "1", "2", "3", "4", "5"]
VAL_SHARE = 0.1
PLAYED = 1


@dataclass
class Data:
    meta: dict
    champ: np.ndarray  # [n, 10] dense champion index, slot = side * 5 + role
    platform: np.ndarray
    start: np.ndarray
    y: np.ndarray  # blue won, float32
    split: np.ndarray
    flags: np.ndarray
    match_id: list | None

    @property
    def n(self):
        return len(self.y)

    def eu(self):
        return self.meta["platforms"].index("EUW1")


def load(snap):
    d = os.path.join(os.path.expanduser(snap), "nn")
    with open(os.path.join(d, "meta.json")) as f:
        meta = json.load(f)
    n = meta["n"]

    def col(name, dtype, shape=(n,)):
        a = np.fromfile(os.path.join(d, name), dtype=dtype)
        assert a.size == int(np.prod(shape)), (name, a.size, shape)
        return a.reshape(shape)

    mid_path = os.path.join(d, "match_id.txt")
    mids = None
    if os.path.exists(mid_path):
        with open(mid_path) as f:
            mids = f.read().split("\n")[:n]
        assert len(mids) == n
    return Data(
        meta=meta,
        champ=col("champ.u8", np.uint8, (n, 10)),
        platform=col("platform.u8", np.uint8),
        start=col("start.i64", "<i8"),
        y=col("blue_win.u8", np.uint8).astype(np.float32),
        split=col("split.u8", np.uint8),
        flags=col("flags.u8", np.uint8),
        match_id=mids,
    )


@dataclass
class Sets:
    block: str
    fit: np.ndarray  # game indices, ascending (rows.Data order)
    inner: np.ndarray
    val: np.ndarray
    scored: np.ndarray


def val_cut(starts):
    s = np.sort(starts)
    return s[int(len(s) * (1 - VAL_SHARE))]


def sets(data, block):
    played = (data.flags & PLAYED) != 0
    sp = data.split.astype(np.int32)
    if block == "dev":
        fit = played & (sp <= 5)
        scored = played & (sp == 6)
    else:
        k = int(block)
        fit = played & (sp < k)
        scored = played & (sp == k)
    fit = np.flatnonzero(fit)
    cut = val_cut(data.start[fit])
    inner = fit[data.start[fit] < cut]
    val = fit[data.start[fit] >= cut]
    return Sets(block, fit, inner, val, np.flatnonzero(scored))


def vocab(data, fit, min_games):
    """winnet's Vocab: [n_champ, 5] -> dense id; champion-roles under min_games get
    their role's id (0-4). Sorted by (champion, role) as Zig's sorted keys"""
    n_champ = len(data.meta["champions"])
    counts = np.zeros((n_champ, 5), np.int64)
    for slot in range(10):
        np.add.at(counts[:, slot % 5], data.champ[fit, slot], 1)
    table = np.tile(np.arange(5), (n_champ, 1))
    keep = counts >= min_games
    # meta champions ascend by id, so (dense champion, role) order = Zig's key order
    table[keep] = 5 + np.arange(keep.sum())
    return table, 5 + int(keep.sum())


def ids(data, games, table):
    """[len(games), 10] dense ids by slot"""
    c = data.champ[games].astype(np.int64)
    return table[c, np.tile(np.arange(5), 2)]


def rating_vocab(data, fit):
    """win-ratings' ids: every fit champion-role its own (1..), 0 unseen"""
    n_champ = len(data.meta["champions"])
    seen = np.zeros((n_champ, 5), bool)
    for slot in range(10):
        seen[data.champ[fit, slot], slot % 5] = True
    table = np.zeros((n_champ, 5), np.int64)
    table[seen] = 1 + np.arange(seen.sum())
    return table, 1 + int(seen.sum())


def read_preds(path):
    """netcheck preds.tsv: {block: dict(match_id, y, cand, seeds [k, n], ens)}"""
    out = {}
    with open(path) as f:
        head = f.readline().rstrip("\n").split("\t")
        seed_cols = [i for i, h in enumerate(head) if h.startswith("seed")]
        # playernet appends coverage columns after ens
        ens_col = head.index("ens")
        rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    for b in BLOCKS:
        rs = [r for r in rows if r[0] == b]
        if not rs:
            continue
        out[b] = {
            "match_id": [r[1] for r in rs],
            "y": np.array([float(r[3]) for r in rs], np.float32),
            "cand": np.array([float(r[4]) for r in rs]),
            "seeds": np.array([[float(r[i]) for r in rs] for i in seed_cols]),
            "seed_names": [head[i] for i in seed_cols],
            "ens": np.array([float(r[ens_col]) for r in rs]),
        }
    return out


def check_against(data, ref):
    """Scored games per block must equal the reference preds.tsv's, in order, with
    the same labels; returns lines to print"""
    lines = []
    ok = True
    for b, r in ref.items():
        s = sets(data, b).scored
        same_n = len(s) == len(r["y"])
        same_y = same_n and np.array_equal(data.y[s], r["y"])
        same_id = None
        if data.match_id is not None and same_n:
            same_id = [data.match_id[i] for i in s] == r["match_id"]
        good = same_n and same_y and same_id is not False
        ok &= good
        lines.append(f"block {b}: scored {len(s)} vs ref {len(r['y'])}, labels {'same' if same_y else 'DIFFER'}, match ids {same_id}")
    return ok, lines


def summary(data):
    lines = []
    for b in BLOCKS:
        s = sets(data, b)
        lines.append(f"block {b}: fit {len(s.fit)} games (inner {len(s.inner)}, val {len(s.val)}, ids {vocab(data, s.fit, 10)[1]}), scored {len(s.scored)}")
    return lines


if __name__ == "__main__":
    import sys

    data = load(sys.argv[1])
    print("\n".join(summary(data)))
    for p in sys.argv[2:]:
        ok, lines = check_against(data, read_preds(p))
        print(p, "OK" if ok else "MISMATCH")
        print("\n".join(lines))
