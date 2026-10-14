"""Duplicate games in SNAP/nn: same match id, same (start, platform), same draft"""
import sys
from collections import Counter

import numpy as np

import nnsets

d = nnsets.load(sys.argv[1])
played = (d.flags & 1) != 0
print("games", d.n, "played", int(played.sum()))
if d.match_id is not None:
    c = Counter(d.match_id)
    print("RESULT duplicate match ids:", sum(v - 1 for v in c.values() if v > 1))
key = d.start.astype(np.int64) * 64 + d.platform
u, cnt = np.unique(key, return_counts=True)
print("RESULT games sharing (start, platform) with another:", int(cnt[cnt > 1].sum()), "in", int((cnt > 1).sum()), "groups")
draft = np.concatenate([d.champ.astype(np.int64), d.platform[:, None].astype(np.int64)], 1)
_, inv, dc = np.unique(draft, axis=0, return_inverse=True, return_counts=True)
print("RESULT games sharing (10 champions, platform) with another:", int(dc[dc > 1].sum()), "in", int((dc > 1).sum()), "groups")
same = dc[inv.ravel()] > 1
idx = np.flatnonzero(same)
order = idx[np.argsort(inv.ravel()[idx], kind="stable")]
adj = 0
for a, b in zip(order[:-1], order[1:]):
    if inv.ravel()[a] == inv.ravel()[b] and abs(int(a) - int(b)) <= 3:
        adj += 1
print("RESULT same-draft pairs within 3 indices:", adj)
for a, b in list(zip(order[:-1], order[1:]))[:400]:
    if inv.ravel()[a] == inv.ravel()[b]:
        print("  example", a, b, d.match_id[a] if d.match_id else "", d.match_id[b] if d.match_id else "", d.start[a], d.start[b], d.y[a], d.y[b], d.split[a], d.split[b])
        break
