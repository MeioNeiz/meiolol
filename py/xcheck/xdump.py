"""Set net (src/lab/setnet.zig) and player net (src/lab/playernet.zig) in torch, trained
on the inputs the Zig commands dump (`netcheck --net set --dump 1`, `playernet --dump
1`): same games, features, offsets and ids, so only the net and its training differ.
Writes a netcheck-format preds.tsv (cand = the dumped offset) for compare.py.

set: slot x = z(12) ++ role one-hot(5); u = ReLU(W1 x + b1) (phi); team t = mean of its
  5 u; f = w . dropout(ReLU(V in + c)) (rho), in = t_own (--cross 0) or [t_own; t_other];
  logit = (f(b, r) - f(r, b)) / 2 + c[platform] + a * off
player: slot x = (E[id] + R[role]) ++ features(21); value = w . dropout(ReLU(W x + b));
  logit = sum blue - sum red + c[platform] + a * off
Both: output weights 0 (start as the offset), AdamW with decay on weights and
embeddings only, global norm clip 1, early stopping on val 4x an epoch with step 0 (the
offset alone) eligible, patience 5; refit on fit for round(epochs * 1.1 * steps per
epoch) steps, 0 if step 0 won.

usage: xdump.py --kind set|player --dump DIR --ref PREDS.tsv [--seeds ..] [--out DIR]
"""

import argparse
import math
import os
import time

import numpy as np
import torch

import nnsets

N_PLATFORM = 16
BLOCK_FILE = {"dev": "dev", "1": "f1", "2": "f2", "3": "f3", "4": "f4", "5": "f5"}
DEFAULTS = {
    "set": dict(phi=16, rho=16, dropout=0.2, wd=0.1, lr=1e-3, batch=512, cross=0),
    "player": dict(emb=8, hidden=32, dropout=0.1, wd=0.1, lr=1e-3, batch=512),
}


def load_set(d, block, part):
    stem = os.path.join(d, f"set-{BLOCK_FILE[block]}-{part}")
    with open(stem + ".tsv") as f:
        f.readline()
        rows = [l.rstrip("\n").split("\t") for l in f if l.strip()]
    z = np.fromfile(stem + ".f32", "<f4").reshape(len(rows), 10, 12)
    role = np.tile(np.eye(5, dtype=np.float32), (2, 1))
    x = np.concatenate([z, np.broadcast_to(role, (len(rows), 10, 5))], 2)
    return dict(
        match_id=[r[0] for r in rows],
        x=x,
        ids=np.zeros((len(rows), 10), np.int64),
        plat=np.array([int(r[1]) for r in rows]),
        y=np.array([float(r[2]) for r in rows], np.float32),
        off=np.array([float(r[3]) for r in rows], np.float32),
        n_ids=1,
    )


def load_player(d, block, part):
    stem = os.path.join(d, f"net-{BLOCK_FILE[block]}-{part}")
    with open(stem + ".txt") as f:
        head = f.readline().split()
        mids = [l.strip() for l in f if l.strip()]
    rec = np.fromfile(stem + ".bin", "<u4").reshape(-1, 223)
    fl = rec.view("<f4")
    assert len(mids) == len(rec)
    return dict(
        match_id=mids,
        ids=rec[:, :10].astype(np.int64),
        x=fl[:, 10:220].reshape(-1, 10, 21).copy(),
        plat=fl[:, 220].astype(np.int64),
        y=fl[:, 221].copy(),
        off=fl[:, 222].copy(),
        n_ids=int(head[head.index("n_ids") + 1]),
    )


class SetNet(torch.nn.Module):
    def __init__(self, o, n_ids):
        super().__init__()
        self.W1 = uniform_linear(17, o.phi)
        self.V = uniform_linear(o.phi * (2 if o.cross else 1), o.rho)
        self.w = torch.nn.Parameter(torch.zeros(o.rho))
        self.c = torch.nn.Parameter(torch.zeros(N_PLATFORM))
        self.a = torch.nn.Parameter(torch.ones(()))
        self.cross = o.cross
        self.drop = o.dropout

    def f(self, own, other):
        h = torch.relu(self.V(torch.cat([own, other], 1) if self.cross else own))
        if self.training and self.drop > 0:
            h = torch.nn.functional.dropout(h, self.drop)
        return h @ self.w

    def forward(self, ids, x, plat, off):
        u = torch.relu(self.W1(x))
        tb, tr = u[:, :5].mean(1), u[:, 5:].mean(1)
        return (self.f(tb, tr) - self.f(tr, tb)) / 2 + self.c[plat] + self.a * off

    def groups(self, wd):
        return [dict(params=[self.W1.bias, self.V.bias, self.c, self.a], weight_decay=0.0), dict(params=[self.W1.weight, self.V.weight, self.w], weight_decay=wd)]


class PlayerNet(torch.nn.Module):
    def __init__(self, o, n_ids):
        super().__init__()
        self.E = torch.nn.Parameter(torch.empty(n_ids, o.emb).uniform_(-0.1, 0.1))
        self.R = torch.nn.Parameter(torch.empty(5, o.emb).uniform_(-0.1, 0.1))
        self.W = uniform_linear(o.emb + 21, o.hidden)
        self.w = torch.nn.Parameter(torch.zeros(o.hidden))
        self.c = torch.nn.Parameter(torch.zeros(N_PLATFORM))
        self.a = torch.nn.Parameter(torch.ones(()))
        self.drop = o.dropout
        self.sign = torch.tensor([1.0] * 5 + [-1.0] * 5)

    def forward(self, ids, x, plat, off):
        e = self.E[ids] + self.R[torch.arange(10, device=ids.device) % 5]
        h = torch.relu(self.W(torch.cat([e, x], 2)))
        if self.training and self.drop > 0:
            h = torch.nn.functional.dropout(h, self.drop)
        v = h @ self.w
        return (v * self.sign.to(v.device)).sum(1) + self.c[plat] + self.a * off

    def groups(self, wd):
        return [dict(params=[self.W.bias, self.c, self.a], weight_decay=0.0), dict(params=[self.E, self.R, self.W.weight, self.w], weight_decay=wd)]


def uniform_linear(fan_in, fan_out):
    lin = torch.nn.Linear(fan_in, fan_out)
    b = math.sqrt(6 / fan_in)
    torch.nn.init.uniform_(lin.weight, -b, b)
    torch.nn.init.zeros_(lin.bias)
    return lin


class Part:
    def __init__(self, raw, dev):
        self.match_id = raw["match_id"]
        self.n_ids = raw["n_ids"]
        self.ids = torch.from_numpy(raw["ids"]).to(dev)
        self.x = torch.from_numpy(np.ascontiguousarray(raw["x"], np.float32)).to(dev)
        self.plat = torch.from_numpy(raw["plat"].astype(np.int64)).to(dev)
        self.y = torch.from_numpy(raw["y"]).to(dev)
        self.off = torch.from_numpy(raw["off"]).to(dev)

    def __len__(self):
        return len(self.y)


def predict(net, g):
    net.eval()
    with torch.no_grad():
        p = torch.sigmoid(net(g.ids, g.x, g.plat, g.off))
    net.train()
    return p


def mean_loss(y, p):
    p = p.double().clamp(1e-6, 1 - 1e-6)
    return float(-(y * p.log() + (1 - y) * (1 - p).log()).mean())


def train(o, seed, n_ids, tr, val, max_steps, dev):
    torch.manual_seed(seed)
    gen = torch.Generator().manual_seed(seed)
    net = (SetNet if o.kind == "set" else PlayerNet)(o, n_ids).to(dev)
    opt = torch.optim.AdamW(net.groups(o.wd), lr=o.lr, betas=(0.9, 0.999), eps=1e-8)
    per = max(1, (len(tr) + o.batch - 1) // o.batch)
    every = max(1, per // o.evals)
    best, best_loss, best_step, since = None, math.inf, 0, 0
    if val is not None:
        best_loss = mean_loss(val.y, predict(net, val))
        best = {k: v.detach().clone() for k, v in net.state_dict().items()}
    step, at, order = 0, len(tr), None
    while step < max_steps:
        if at >= len(tr):
            order = torch.randperm(len(tr), generator=gen).to(dev)
            at = 0
        idx = order[at : at + o.batch]
        at += len(idx)
        z = net(tr.ids[idx], tr.x[idx], tr.plat[idx], tr.off[idx])
        loss = torch.nn.functional.binary_cross_entropy_with_logits(z, tr.y[idx])
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(net.parameters(), o.clip)
        opt.step()
        step += 1
        if val is None or (step % every != 0 and step != max_steps):
            continue
        vl = mean_loss(val.y, predict(net, val))
        if vl < best_loss - 1e-7:
            best_loss, best_step, since = vl, step, 0
            best = {k: v.detach().clone() for k, v in net.state_dict().items()}
        else:
            since += 1
            if since >= o.patience:
                break
    if val is not None:
        net.load_state_dict(best)
    return net, best_step, best_step / per, best_loss


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", required=True, choices=["set", "player"])
    ap.add_argument("--dump", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--seeds", default="1,2,3,4,5,6,7,8,9,10")
    ap.add_argument("--blocks", default=",".join(nnsets.BLOCKS))
    ap.add_argument("--out", default="out")
    ap.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    ap.add_argument("--evals", type=int, default=4)
    ap.add_argument("--patience", type=int, default=5)
    ap.add_argument("--max-epochs", type=int, default=60)
    ap.add_argument("--clip", type=float, default=1.0)
    for k in ["phi", "rho", "emb", "hidden", "batch", "cross"]:
        ap.add_argument("--" + k, type=int)
    for k in ["dropout", "wd", "lr"]:
        ap.add_argument("--" + k, type=float)
    o = ap.parse_args()
    for k, v in DEFAULTS[o.kind].items():
        if getattr(o, k, None) is None:
            setattr(o, k, v)
    seeds = [int(s) for s in o.seeds.split(",")]
    os.makedirs(o.out, exist_ok=True)
    torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", "4")))
    logf = open(os.path.join(o.out, "xdump.log"), "w")

    def log(msg):
        print(msg, flush=True)
        logf.write(msg + "\n")
        logf.flush()

    log(f"# xdump {o.kind}: " + " ".join(f"{k} {v}" for k, v in sorted(vars(o).items())))
    ref = nnsets.read_preds(o.ref)
    load = load_set if o.kind == "set" else load_player
    with open(os.path.join(o.out, "preds.tsv"), "w") as pf:
        pf.write("fold\tmatch_id\tplatform\ty\tcand\t" + "\t".join(f"seed{s}" for s in seeds) + "\tens\n")
        for b in o.blocks.split(","):
            parts = {p: Part(load(o.dump, b, p), o.device) for p in ("inner", "val", "fit", "scored")}
            sc = parts["scored"]
            r = ref[b]
            same = sc.match_id == r["match_id"] and np.array_equal(sc.y.cpu().numpy(), r["y"])
            cand = torch.sigmoid(sc.off).cpu().numpy()
            dcand = np.abs(cand - r["cand"]).max()
            log(f"block {b}: inner {len(parts['inner'])} val {len(parts['val'])} fit {len(parts['fit'])} scored {len(sc)}; games and labels as ref: {same}; max |offset - ref cand| {dcand:.1e}")
            if not same:
                raise SystemExit("dump and reference differ")
            per_inner = max(1, (len(parts["inner"]) + o.batch - 1) // o.batch)
            per_fit = max(1, (len(parts["fit"]) + o.batch - 1) // o.batch)
            preds = []
            for seed in seeds:
                t0 = time.time()
                _, steps, epochs, vl = train(o, seed, parts["inner"].n_ids, parts["inner"], parts["val"], o.max_epochs * per_inner, o.device)
                refit = 0 if steps == 0 else max(1, round(epochs * 1.1 * per_fit))
                net, _, _, _ = train(o, seed, parts["fit"].n_ids, parts["fit"], None, refit, o.device)
                p = predict(net, sc).cpu().numpy().astype(np.float64)
                preds.append(p)
                log(f"  seed {seed}: epochs {epochs:.2f} val {vl:.5f} refit steps {refit} scored {mean_loss(sc.y.cpu().double(), torch.from_numpy(p)):.5f} a {float(net.a):.3f} ({time.time() - t0:.1f} s)")
            ens = np.mean(preds, 0)
            for i in range(len(sc)):
                pf.write(f"{b}\t{sc.match_id[i]}\t-\t{r['y'][i]:.0f}\t{r['cand'][i]:.6f}\t" + "\t".join(f"{p[i]:.6f}" for p in preds) + f"\t{ens[i]:.6f}\n")
            pf.flush()


if __name__ == "__main__":
    main()
