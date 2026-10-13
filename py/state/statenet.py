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
fit's newest 10% of games; mean of seeds reported, seeds kept. Writes OUT/preds-net.npz.

usage: statenet.py SNAP [--out DIR] [--blocks dev,1,2,3,4,5] [--seeds 3] [--dim 8]
"""

import argparse
import os
import time

import numpy as np
import torch

import nnsets
import statecommon as sc

MINUTES = list(range(1, 41))


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


class Net(torch.nn.Module):
    def __init__(self, n_feat, n_ids, dim, hidden=128, use_champs=True):
        super().__init__()
        self.use_champs = use_champs
        self.emb = torch.nn.Embedding(n_ids, dim) if use_champs else None
        if use_champs:
            torch.nn.init.normal_(self.emb.weight, std=0.05)
        n_in = n_feat + len(sc.KNOTS) + (10 * dim if use_champs else 0)
        self.g = torch.nn.Sequential(
            torch.nn.Linear(n_in, hidden), torch.nn.GELU(), torch.nn.Dropout(0.1),
            torch.nn.Linear(hidden, hidden), torch.nn.GELU(), torch.nn.Dropout(0.1),
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


def train(net, tensors, tr, va, seed, epochs=30, batch=4096, patience=3, lr=1e-3):
    x, flip, H, ids, y = tensors
    opt = torch.optim.AdamW(net.parameters(), lr=lr, weight_decay=1e-4)
    g = torch.Generator(device="cpu").manual_seed(seed)
    best, best_loss, bad = None, float("inf"), 0
    lossf = torch.nn.functional.binary_cross_entropy_with_logits
    for ep in range(epochs):
        net.train()
        perm = tr[torch.randperm(len(tr), generator=g).to(tr.device)]
        for i in range(0, len(perm), batch):
            b = perm[i : i + batch]
            opt.zero_grad()
            lossf(net(x[b], flip, H[b], ids[b]), y[b]).backward()
            opt.step()
        net.eval()
        with torch.no_grad():
            vl = sum(lossf(net(x[b], flip, H[b], ids[b]), y[b], reduction="sum").item() for b in va.split(65536)) / len(va)
        if vl < best_loss - 1e-6:
            best_loss, bad = vl, 0
            best = {k: v.detach().clone() for k, v in net.state_dict().items()}
        else:
            bad += 1
            if bad >= patience:
                break
    net.load_state_dict(best)
    return best_loss, ep


def run_block(state, data, block, seeds, dim, dev):
    sets = nnsets.sets(data, block)
    has_tl = state.game[:, state.gcols["has_timeline"]] == 1
    logit, l2, _ = sc.draft_logits(data, sets)
    fit_g, sc_g = sets.fit[has_tl[sets.fit]], sets.scored[has_tl[sets.scored]]
    Xf, names, gf, mf = sc.rows_for(state, fit_g, MINUTES, logit)
    Xs, _, gs, ms = sc.rows_for(state, sc_g, MINUTES, logit)
    mu, sd = Xf.mean(0), Xf.std(0) + 1e-6
    flip = torch.tensor([1.0 if n == "gold_total" else -1.0 for n in names], device=dev)
    # Symmetric features keep their mean; antisymmetric ones are scaled only, so flip
    # stays a sign change after standardising
    mu = np.where(flip.cpu().numpy() > 0, mu, 0)
    table, n_ids = nnsets.rating_vocab(data, sets.fit)

    def tens(X, g, m):
        return (
            torch.from_numpy(((X - mu) / sd).astype(np.float32)).to(dev),
            flip,
            torch.from_numpy(sc.hat(m, sc.KNOTS)).to(dev),
            torch.from_numpy(nnsets.ids(data, g, table)).to(dev),
            torch.from_numpy(data.y[g].astype(np.float32)).to(dev),
        )

    tf, ts = tens(Xf, gf, mf), tens(Xs, gs, ms)
    val_cut = nnsets.val_cut(data.start[sets.fit])
    is_val = torch.from_numpy(data.start[gf] >= val_cut).to(dev)
    tr, va = torch.nonzero(~is_val).squeeze(1), torch.nonzero(is_val).squeeze(1)
    log(f"block {block}: fit rows {len(gf)} (val {len(va)}), scored {len(gs)}, ids {n_ids}")
    res = {"block": np.full(len(gs), block), "game": gs, "minute": ms, "y": data.y[gs]}
    for kind in ("nets", "netd"):
        for s in seeds:
            torch.manual_seed(1000 * s + 7)
            net = Net(len(names), n_ids, dim, use_champs=kind == "netd").to(dev)
            vl, ep = train(net, tf, tr, va, s)
            net.eval()
            with torch.no_grad():
                z = torch.cat([net(ts[0][b], flip, ts[2][b], ts[3][b]) for b in torch.arange(len(gs), device=dev).split(65536)])
            p = torch.sigmoid(z).cpu().numpy()
            res[f"{kind}_s{s}"] = p
            log(f"  {kind} seed {s}: val {vl:.5f} after {ep + 1} epochs, scored {sc.ll(res['y'], p).mean():.5f}")
        res[kind] = np.mean([res[f"{kind}_s{s}"] for s in seeds], 0)
    d, ci, n = sc.paired(res["y"], res["netd"], res["nets"], gs)
    log(f"  netd - nets: {d:+.5f} ± {ci:.5f} ({n} games)")
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--out", default="out")
    ap.add_argument("--blocks", default="dev,1,2,3,4,5")
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--dim", type=int, default=8)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    data = nnsets.load(a.snap)
    state = sc.State(a.snap)
    sc.check_join(state, data)
    seeds = list(range(1, a.seeds + 1))
    all_res = []
    for b in a.blocks.split(","):
        all_res.append(run_block(state, data, b, seeds, a.dim, dev))
        np.savez_compressed(os.path.join(a.out, "preds-net.npz"), **{f"{k}.{i}": v for i, r in enumerate(all_res) for k, v in r.items()})


if __name__ == "__main__":
    main()
