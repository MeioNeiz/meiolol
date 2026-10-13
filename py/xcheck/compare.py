"""Pairs two netcheck-format preds.tsv (e.g. torch vs Zig) on the same games.

Agreement test: if both sides run the same procedure they differ only by seed noise,
so per block (and folds pooled) the mean single-seed log loss of A and B should differ
by no more than 2 x sqrt(sd_A^2 / k_A + sd_B^2 / k_B) (sd over seeds); the ensembles'
log loss likewise. Also the per-game paired difference of the ensembles (clustered by
game, one row a game) and the correlation of their logits.

usage: compare.py A.tsv B.tsv [--names torch,zig]
"""

import argparse

import numpy as np

import nnsets


def loss(y, p):
    p = np.clip(p, 1e-6, 1 - 1e-6)
    return -(y * np.log(p) + (1 - y) * np.log(1 - p))


def logit(p):
    p = np.clip(p, 1e-6, 1 - 1e-6)
    return np.log(p / (1 - p))


def side(r):
    single = np.array([loss(r["y"], s).mean() for s in r["seeds"]])
    return single, loss(r["y"], r["ens"]).mean()


def report(name, ra, rb, na, nb):
    assert ra["match_id"] == rb["match_id"], f"{name}: games differ"
    y = ra["y"]
    sa, ea = side(ra)
    sb, eb = side(rb)
    cand = loss(y, ra["cand"]).mean()
    cand_b = loss(y, rb["cand"]).mean()
    ka, kb = len(sa), len(sb)
    sda = sa.std(ddof=1) if ka > 1 else np.nan
    sdb = sb.std(ddof=1) if kb > 1 else np.nan
    tol = 2 * np.sqrt(sda**2 / ka + sdb**2 / kb)
    # Each side against its own candidate (resid: torch's ratings offsets vs Zig's)
    d_single = (sa.mean() - cand) - (sb.mean() - cand_b)
    d = loss(y, ra["ens"]) - loss(y, rb["ens"])
    corr = np.corrcoef(logit(ra["ens"]), logit(rb["ens"]))[0, 1]
    verdict = "agree" if abs(d_single) <= tol else "DISAGREE"
    print(f"{name}: {len(y)} games, cand {na} {cand:.5f} {nb} {cand_b:.5f}")
    print(f"  single seeds vs cand: {na} {sa.mean() - cand:+.5f} (sd {sda:.5f}, k {ka}), {nb} {sb.mean() - cand_b:+.5f} (sd {sdb:.5f}, k {kb})")
    print(f"  {na} - {nb}: single-seed gain vs own cand {d_single:+.5f}, tolerance ±{tol:.5f}: {verdict}")
    print(f"  ensembles vs cand: {na} {ea - cand:+.5f}, {nb} {eb - cand_b:+.5f}; ens {na} - {nb} {d.mean():+.5f} ± {1.96 * d.std(ddof=1) / np.sqrt(len(d)):.5f} (paired); logit corr {corr:.4f}")
    return verdict == "agree"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--names", default="A,B")
    o = ap.parse_args()
    na, nb = o.names.split(",")
    A, B = nnsets.read_preds(o.a), nnsets.read_preds(o.b)
    blocks = [b for b in nnsets.BLOCKS if b in A and b in B]
    ok = all([report(f"block {b}", A[b], B[b], na, nb) for b in blocks])
    folds = [b for b in blocks if b != "dev"]
    if len(folds) > 1:
        cat = lambda R: {
            "match_id": sum((R[b]["match_id"] for b in folds), []),
            "y": np.concatenate([R[b]["y"] for b in folds]),
            "cand": np.concatenate([R[b]["cand"] for b in folds]),
            "seeds": np.concatenate([R[b]["seeds"] for b in folds], 1),
            "ens": np.concatenate([R[b]["ens"] for b in folds]),
        }
        ok &= report("folds pooled", cat(A), cat(B), na, nb)
    print("ALL AGREE" if ok else "SOME DISAGREE")


if __name__ == "__main__":
    main()
