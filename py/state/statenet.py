"""GPU nets for the live state: does the draft change what a state is worth?

Same blocks, rows and features as statemodels.py (draft logit among the features). Each
net is antisymmetric: z = g(x, B, R) - g(flip x, R, B) + c(minute), flip negating every
blue-minus-red feature (all but gold_total), so swapping sides swaps the prediction
apart from the blue-side intercept c (hat basis over minute).
- nets: g = MLP(x, minute) only; the draft enters as its logit, so the state's value
  may depend on how strong the draft is but not on which champions
- netd: g also sees champion-role embeddings of both teams (concatenated by role): the
  state's value may depend on the champions themselves
netd minus nets is what champion-specific draft x state terms add. Early stopping on the
fit's newest 10% of games; mean of seeds reported, seeds kept. Writes OUT/preds-net.npz
and, for lab-sweep (netcheck's contract), OUT/folds.tsv for the first of --kind (others
OUT/folds-KIND.tsv): reference = the rich smooth logistic (statemodels.py) on the same
rows, gain = reference minus net log loss per game-minute (positive better), se
clustered by game.

usage: statenet.py SNAP [--out DIR] [--blocks dev,1,2,3,4,5] [--seeds 3] [--kind netd,nets]
       [--dim 8] [--hidden 128] [--dropout 0.1] [--lr 1e-3] [--wd 1e-4] [--patience 3]
       [--epochs 30] [--batch 4096] [--control permute]
--control permute: training rows get another fit game's champions (whole drafts
permuted across fit games; scored rows real), so any netd gain must vanish
"""

import argparse
import os
import time

import numpy as np
import torch

import nnsets
import statecommon as sc
from statemodels import Smooth

MINUTES = list(range(1, 41))


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


class Net(torch.nn.Module):
    def __init__(self, n_feat, n_ids, dim, hidden=128, dropout=0.1, use_champs=True):
        super().__init__()
        self.use_champs = use_champs
        self.emb = torch.nn.Embedding(n_ids, dim) if use_champs else None
        if use_champs:
            torch.nn.init.normal_(self.emb.weight, std=0.05)
        n_in = n_feat + len(sc.KNOTS) + (10 * dim if use_champs else 0)
        self.g = torch.nn.Sequential(
            torch.nn.Linear(n_in, hidden), torch.nn.GELU(), torch.nn.Dropout(dropout),
            torch.nn.Linear(hidden, hidden), torch.nn.GELU(), torch.nn.Dropout(dropout),
            torch.nn.Linear(hidden, 1),
        )
        self.c = torch.nn.Parameter(torch.zeros(len(sc.KNOTS)))

    def half(self, x, H, blue, red):
        parts = [x, H]
        if self.use_champs:
            parts += [self.emb(blue).flatten(1), self.emb(red).flatten(1)]
        return self.g(torch.cat(parts, 1)).squeeze(1)

    def forward(self, x, flip, H, ids):
        blue, red = ids[:, :5], ids[:, 5:]
        return self.half(x, H, blue, red) - self.half(x * flip, H, red, blue) + H @ self.c


def batches(tensors, idx, dev):
    """The rows idx of CPU tensors (x, H, ids, y), on the device"""
    return [t[idx].to(dev, non_blocking=True) for t in tensors]


def train(net, tensors, flip, tr, va, seed, hp, dev):
    epochs, batch, patience, lr = hp.epochs, hp.batch, hp.patience, hp.lr
    opt = torch.optim.AdamW(net.parameters(), lr=lr, weight_decay=hp.wd)
    g = torch.Generator(device="cpu").manual_seed(seed)
    best, best_loss, bad = None, float("inf"), 0
    lossf = torch.nn.functional.binary_cross_entropy_with_logits
    for ep in range(epochs):
        net.train()
        perm = tr[torch.randperm(len(tr), generator=g)]
        for i in range(0, len(perm), batch):
            x, H, ids, y = batches(tensors, perm[i : i + batch], dev)
            opt.zero_grad()
            lossf(net(x, flip, H, ids), y).backward()
            opt.step()
        net.eval()
        vl = 0.0
        with torch.no_grad():
            for b in va.split(65536):
                x, H, ids, y = batches(tensors, b, dev)
                vl += lossf(net(x, flip, H, ids), y, reduction="sum").item()
        vl /= len(va)
        if vl < best_loss - 1e-6:
            best_loss, bad = vl, 0
            best = {k: v.detach().clone() for k, v in net.state_dict().items()}
        else:
            bad += 1
            if bad >= patience:
                break
    net.load_state_dict(best)
    return best_loss, ep


def auc(y, p):
    r = np.argsort(np.argsort(p)) + 1
    n1 = y.sum()
    return (r[y == 1].sum() - n1 * (n1 + 1) / 2) / (n1 * (len(y) - n1))


def gain(y, ref, p, games):
    """reference minus net log loss per row, se clustered by game"""
    d, ci, _ = sc.paired(y, ref, p, games)
    return d, ci / 1.96


def run_block(state, data, block, seeds, hp, dev, folds):
    sets = nnsets.sets(data, block)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    logit, l2, _ = sc.draft_logits(data, sets)
    fit_g, sc_g = sets.fit[has_tl[sets.fit]], sets.scored[has_tl[sets.scored]]
    # Fit rows every other minute (RAM on the shared gpu-box), scored every minute
    Xf, names, gf, mf = sc.rows_for(state, fit_g, MINUTES[::2], logit)
    Xs, _, gs, ms = sc.rows_for(state, sc_g, MINUTES, logit)
    ys = data.y[gs]
    res = {"block": np.full(len(gs), block), "game": gs, "minute": ms, "y": ys}
    t0 = time.time()
    res["rich"] = Smooth().fit(Xf, mf, data.y[gf]).predict(Xs, ms)
    ref_ll, ref_auc = sc.ll(ys, res["rich"]).mean(), auc(ys, res["rich"])
    log(f"  rich (reference): {ref_ll:.5f}, {time.time() - t0:.0f} s")
    mu, sd = Xf.mean(0), Xf.std(0) + 1e-6
    flip = torch.tensor([1.0 if n == "gold_total" else -1.0 for n in names], device=dev)
    # Symmetric features keep their mean; antisymmetric ones are scaled only, so flip
    # stays a sign change after standardising
    mu = np.where(flip.cpu().numpy() > 0, mu, 0)
    table, n_ids = nnsets.rating_vocab(data, sets.fit)

    # Kept on the CPU (standardised in place, no copies); batches go to the card, so a
    # job fits any per-slot GPU memory cap
    def tens(X, g, m, id_games):
        X -= mu.astype(np.float32)
        X /= sd.astype(np.float32)
        return (
            torch.from_numpy(X),
            torch.from_numpy(sc.hat(m, sc.KNOTS)),
            torch.from_numpy(nnsets.ids(data, id_games, table)),
            torch.from_numpy(data.y[g].astype(np.float32)),
        )

    # Control: each fit game's whole draft (champion ids only; its draft logit, state and
    # result stay) from another fit game, so champion x state terms learnt from it are noise
    id_gf = gf
    if hp.control == "permute":
        u = np.unique(gf)
        swap = dict(zip(u, np.random.default_rng(99).permutation(u)))
        id_gf = np.array([swap[g] for g in gf])
    tf, ts = tens(Xf, gf, mf, id_gf), tens(Xs, gs, ms, gs)
    val_cut = nnsets.val_cut(data.start[sets.fit])
    is_val = torch.from_numpy(data.start[gf] >= val_cut)
    tr, va = torch.nonzero(~is_val).squeeze(1), torch.nonzero(is_val).squeeze(1)
    log(f"block {block}: fit rows {len(gf)} (val {len(va)}), scored {len(gs)}, ids {n_ids}")
    n_fit, n_sc = len(np.unique(gf)), len(np.unique(gs))
    for kind in hp.kind.split(","):
        vls, eps, secs = [], [], []
        for s in seeds:
            t0 = time.time()
            torch.manual_seed(1000 * s + 7)
            net = Net(len(names), n_ids, hp.dim, hp.hidden, hp.dropout, use_champs=kind == "netd").to(dev)
            vl, ep = train(net, tf, flip, tr, va, s, hp, dev)
            net.eval()
            with torch.no_grad():
                z = torch.cat([net(x, flip, H, ids) for x, H, ids, _ in (batches(ts, b, dev) for b in torch.arange(len(gs)).split(65536))])
            p = torch.sigmoid(z).cpu().numpy()
            res[f"{kind}_s{s}"] = p
            vls.append(vl), eps.append(ep + 1), secs.append(time.time() - t0)
            gm, gse = gain(ys, res["rich"], p, gs)
            folds[kind].write(f"{s}\t{block}\t{n_fit}\t{n_sc}\t{sc.ll(ys, p).mean():.6f}\t{ref_ll:.6f}\t{gm:.6f}\t{gse:.6f}\t{ep + 1}\t{secs[-1]:.1f}\t{vl:.6f}\t{auc(ys, p):.5f}\t{ref_auc:.5f}\n")
            log(f"  {kind} seed {s}: val {vl:.5f} after {ep + 1} epochs, scored {sc.ll(ys, p).mean():.5f}, vs rich {-gm:+.5f}")
        p = res[kind] = np.mean([res[f"{kind}_s{s}"] for s in seeds], 0)
        gm, gse = gain(ys, res["rich"], p, gs)
        folds[kind].write(f"ens\t{block}\t{n_fit}\t{n_sc}\t{sc.ll(ys, p).mean():.6f}\t{ref_ll:.6f}\t{gm:.6f}\t{gse:.6f}\t{np.mean(eps):.2f}\t{sum(secs):.1f}\t{np.mean(vls):.6f}\t{auc(ys, p):.5f}\t{ref_auc:.5f}\n")
        folds[kind].flush()
    if "netd" in res and "nets" in res:
        d, ci, n = sc.paired(ys, res["netd"], res["nets"], gs)
        log(f"  netd - nets: {d:+.5f} ± {ci:.5f} ({n} games)")
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--blocks", default="dev,1,2,3,4,5")
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--kind", default="netd,nets")
    ap.add_argument("--dim", type=int, default=8)
    ap.add_argument("--hidden", type=int, default=128)
    ap.add_argument("--dropout", type=float, default=0.1)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--wd", type=float, default=1e-4)
    ap.add_argument("--patience", type=int, default=3)
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--batch", type=int, default=4096)
    ap.add_argument("--control", choices=["none", "permute"], default="none")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    seeds = list(range(1, a.seeds + 1))
    head = "seed\tfold\tfit_games\tscored_games\tlogloss\tratings_logloss\tgain\tgain_se\tepochs\tseconds\tval_logloss\tauc\tratings_auc\n"
    kinds = a.kind.split(",")
    folds = {k: open(os.path.join(a.out, "folds.tsv" if i == 0 else f"folds-{k}.tsv"), "w") for i, k in enumerate(kinds)}
    for f in folds.values():
        f.write(head)
    all_res = []
    for b in a.blocks.split(","):
        all_res.append(run_block(state, data, b, seeds, a, dev, folds))
        np.savez_compressed(os.path.join(a.out, "preds-net.npz"), **{f"{k}.{i}": v for i, r in enumerate(all_res) for k, v in r.items()})


if __name__ == "__main__":
    main()
