"""netcheck's small, resid and big nets in torch (src/lab/winnet.zig, draftnet.zig), same
rows, ids, init, optimiser, dropout, early stopping and refit; writes a preds.tsv in
netcheck's format so compare.py can pair it with a Zig run.

Antisymmetric: logit = (f(blue, red) - f(red, blue)) / 2 + c[platform] (+ a * offset).
Slot input E[id] + R[role]; f an MLP with ReLU and inverted dropout after every hidden
layer (independent masks per side order), no output bias. AdamW with decoupled decay
inside the lr (torch's AdamW is the same update); val = newest 10% of fit games,
checked `evals` times an epoch, patience in checks; refit on all fit games for
round(best_epochs * 1.1 * steps_per_epoch(fit)) steps.

resid: offsets from xratings' Zig-procedure ratings, cross-fitted over 5 fifths by a
hash of the game index (netcheck hashes start and platform with Wyhash: a different
but equivalent partition).

usage: xnets.py SNAP --net small|big|resid --ref PREDS.tsv [--seeds 1,...] [--out DIR]
       [--lr --wd --emb-wd --batch --evals --patience --dropout --emb --hidden --depth
        --clip --max-epochs --min-games --opt adamw|... --device cuda|cpu]
"""

import argparse
import math
import os
import time

import numpy as np
import torch

import nnsets

N_PLATFORM = 256

DEFAULTS = {
    "small": dict(emb=16, hidden=[64], dropout=0.2, wd=0.1, emb_wd=None, lr=1e-3, clip=1.0, batch=512, evals=4, patience=5, min_games=10),
    "big": dict(emb=32, hidden=[512, 256], dropout=0.1, wd=1e-4, emb_wd=None, lr=1e-3, clip=0.0, batch=1024, evals=1, patience=5, min_games=30),
}
DEFAULTS["resid"] = dict(DEFAULTS["small"])


class Net(torch.nn.Module):
    def __init__(self, kind, n_ids, emb, hidden, dropout, zero_out):
        super().__init__()
        self.E = torch.nn.Parameter(torch.empty(n_ids, emb).uniform_(-0.1, 0.1))
        # small: R uniform +-0.1 like E; draftnet (big): R starts at 0
        self.R = torch.nn.Parameter(torch.zeros(5, emb) if kind == "big" else torch.empty(5, emb).uniform_(-0.1, 0.1))
        self.c = torch.nn.Parameter(torch.zeros(N_PLATFORM))
        self.a = torch.nn.Parameter(torch.ones(()))
        layers = []
        fan = 10 * emb
        for h in hidden:
            lin = torch.nn.Linear(fan, h)
            bound = math.sqrt(6 / fan)
            torch.nn.init.uniform_(lin.weight, -bound, bound)
            torch.nn.init.zeros_(lin.bias)
            layers.append(lin)
            fan = h
        self.hidden = torch.nn.ModuleList(layers)
        self.out = torch.nn.Parameter(torch.empty(fan).uniform_(-math.sqrt(3 / fan), math.sqrt(3 / fan)) if not zero_out else torch.zeros(fan))
        self.keep = 1 - dropout
        self.role = torch.arange(10) % 5

    def f(self, x):
        for lin in self.hidden:
            x = torch.relu(lin(x))
            if self.training and self.keep < 1:
                x = torch.nn.functional.dropout(x, 1 - self.keep)
        return x @ self.out

    def forward(self, ids, plat, off):
        x = self.E[ids] + self.R[self.role.to(ids.device)]
        blue = x.reshape(len(ids), -1)
        red = torch.cat([x[:, 5:], x[:, :5]], 1).reshape(len(ids), -1)
        return (self.f(blue) - self.f(red)) / 2 + self.c[plat] + self.a * off

    def groups(self, wd, emb_wd):
        none = [self.c, self.a] + [l.bias for l in self.hidden]
        emb = [self.E, self.R]
        w = [l.weight for l in self.hidden] + [self.out]
        return [dict(params=none, weight_decay=0.0), dict(params=emb, weight_decay=emb_wd), dict(params=w, weight_decay=wd)]


def steps_per_epoch(n, batch):
    return max(1, (n + batch - 1) // batch)


class Games:
    def __init__(self, data, games, table, off, dev):
        self.ids = torch.from_numpy(nnsets.ids(data, games, table)).to(dev)
        self.plat = torch.from_numpy(data.platform[games].astype(np.int64)).to(dev)
        self.y = torch.from_numpy(data.y[games]).to(dev)
        self.off = torch.from_numpy(np.zeros(len(games), np.float32) if off is None else off.astype(np.float32)).to(dev)

    def __len__(self):
        return len(self.y)


def predict(net, g):
    net.eval()
    with torch.no_grad():
        out = torch.sigmoid(net(g.ids, g.plat, g.off))
    net.train()
    return out


def mean_loss(y, p):
    p = p.double().clamp(1e-6, 1 - 1e-6)
    return float(-(y * p.log() + (1 - y) * (1 - p).log()).mean())


def make_opt(net, o):
    groups = net.groups(o.wd, o.wd if o.emb_wd is None else o.emb_wd)
    if o.opt == "adamw":
        return torch.optim.AdamW(groups, lr=o.lr, betas=(0.9, 0.999), eps=1e-8)
    if o.opt == "sgdm":
        return torch.optim.SGD(groups, lr=o.lr, momentum=0.9, nesterov=True)
    raise ValueError(o.opt)


def train(o, seed, n_ids, tr, val, max_steps, dev):
    torch.manual_seed(seed)
    gen = torch.Generator(device="cpu").manual_seed(seed)
    net = Net(o.net, n_ids, o.emb, o.hidden, o.dropout, zero_out=o.net == "resid").to(dev)
    if o.fix_offset:
        net.a.requires_grad_(False)
    opt = make_opt(net, o)
    # --ema D: evaluate and predict with an exponential average of the weights
    ema = None
    if o.ema > 0:
        import copy

        ema = copy.deepcopy(net)
        for e in ema.parameters():
            e.requires_grad_(False)
    per = steps_per_epoch(len(tr), o.batch)
    every = max(1, per // max(o.evals, 1))
    best, best_loss, best_step, since = None, math.inf, 0, 0
    step = 0
    norms = []
    order, at = None, len(tr)
    while step < max_steps:
        if at >= len(tr):
            order = torch.randperm(len(tr), generator=gen).to(dev)
            at = 0
        idx = order[at : at + o.batch]
        at += len(idx)
        z = net(tr.ids[idx], tr.plat[idx], tr.off[idx])
        loss = torch.nn.functional.binary_cross_entropy_with_logits(z, tr.y[idx])
        opt.zero_grad(set_to_none=True)
        loss.backward()
        if o.clip > 0:
            norm = float(torch.nn.utils.clip_grad_norm_(net.parameters(), o.clip))
            norms.append(norm)
        opt.step()
        if ema is not None:
            with torch.no_grad():
                for e, x in zip(ema.parameters(), net.parameters()):
                    e.lerp_(x, 1 - o.ema)
        step += 1
        if val is None or (step % every != 0 and step != max_steps):
            continue
        vl = mean_loss(val.y, predict(ema if ema is not None else net, val))
        if vl < best_loss - 1e-7:
            best_loss, best_step, since = vl, step, 0
            best = {k: v.detach().clone() for k, v in (ema if ema is not None else net).state_dict().items()}
        else:
            since += 1
            if since >= o.patience:
                break
    if norms and o.trace:
        n = np.array(norms)
        print(f"    grad norm: median {np.median(n):.3f}, p90 {np.quantile(n, 0.9):.3f}, clipped {np.mean(n > o.clip):.1%} of {len(n)} steps; first 50 median {np.median(n[:50]):.3f}", flush=True)
    if val is None:
        best_step = step
        if ema is not None:
            net.load_state_dict(ema.state_dict())
    elif best is not None:
        net.load_state_dict(best)
    return net, best_step / per, best_loss


def offsets_for(data, s, seed, log, o):
    """resid offsets (logits) as winnet: cross-fitted on fit and inner games, the inner
    fit's for val, the all-fit one's for scored"""
    import xratings

    def fit_ratings(games, seed):
        table, n_ids = nnsets.rating_vocab(data, games)
        sub = nnsets.Sets("x", games, *split_val(data, games), np.array([], np.int64))
        tr_inner = xratings.design(data, sub.inner, table)
        tr_val = xratings.design(data, sub.val, table)
        bestl = None
        for l2 in xratings.L2_GRID:
            _, ep, vl = xratings.zig_train(n_ids, tr_inner, tr_val, l2, xratings.MAX_EPOCHS, seed)
            if bestl is None or vl < bestl[2]:
                bestl = (l2, ep, vl)
        p, _, _ = xratings.zig_train(n_ids, xratings.design(data, games, table), None, bestl[0], max(1, bestl[1] + bestl[1] // 10), seed)
        return lambda gs: xratings.logits_np(p, *xratings.design(data, gs, table)[:3], n_ids)

    def cross(games, seed):
        out = np.zeros(len(games))
        if o.cross_part == "random":
            fifth = np.random.default_rng(12344 + seed).integers(0, 5, data.n)[games]
        else:
            fifth = (games * 2654435761 % 2**32) % 5
        for f in range(5):
            m = fifth == f
            out[m] = fit_ratings(games[~m], seed)(games[m])
        return out

    # --offset-avg K: training offsets averaged over K partitions and ratings seeds; val
    # and scored stay one fit at `seed`, so the candidate matches K = 1
    t0 = time.time()
    seeds = range(seed, seed + o.offset_avg)
    off = {k: np.mean([cross(g, sd) for sd in seeds], 0) for k, g in (("fit", s.fit), ("inner", s.inner))}
    off["val"] = fit_ratings(s.inner, seed)(s.val)
    off["scored"] = fit_ratings(s.fit, seed)(s.scored)
    log(f"  offsets: {10 * o.offset_avg + 2} ratings fits in {time.time() - t0:.0f} s")
    return off


def dumped_offsets(data, s, d, block):
    """Zig's cross-fitted offsets from a `netcheck --net set --dump 1` run (same
    candidate, blocks and crossFold), joined on match id"""
    name = "dev" if block == "dev" else "f" + block
    out = {}
    for part, games in (("inner", s.inner), ("val", s.val), ("fit", s.fit), ("scored", s.scored)):
        with open(os.path.join(os.path.expanduser(d), f"set-{name}-{part}.tsv")) as f:
            f.readline()
            m = {r[0]: float(r[3]) for r in (l.rstrip("\n").split("\t") for l in f if l.strip())}
        assert len(m) == len(games), (part, len(m), len(games))
        out[part] = np.array([m[data.match_id[g]] for g in games])
    return out


def split_val(data, games):
    cut = nnsets.val_cut(data.start[games])
    return games[data.start[games] < cut], games[data.start[games] >= cut]


def run_block(data, block, o, dev, log):
    s = nnsets.sets(data, block)
    t_in, n_in = nnsets.vocab(data, s.inner, o.min_games)
    t_all, n_all = nnsets.vocab(data, s.fit, o.min_games)
    if o.net == "resid" and o.offsets_from:
        off = dumped_offsets(data, s, o.offsets_from, block)
    else:
        off = offsets_for(data, s, o.offset_seed, log, o) if o.net == "resid" else {}
    inner = Games(data, s.inner, t_in, off.get("inner"), dev)
    val = Games(data, s.val, t_in, off.get("val"), dev)
    fit = Games(data, s.fit, t_all, off.get("fit"), dev)
    scored = Games(data, s.scored, t_all, off.get("scored"), dev)
    log(f"block {block}: fit {len(fit)} (inner {len(inner)}, val {len(val)}, ids {n_all}), scored {len(scored)}")
    if off:
        alone = {k: mean_loss(g.y.cpu().double(), torch.sigmoid(g.off.cpu()).double()) for k, g in (("inner", inner), ("val", val), ("fit", fit), ("scored", scored))}
        log("  offset alone: " + ", ".join(f"{k} {v:.5f}" for k, v in alone.items()))
        if o.offsets_only:
            return s, np.zeros((0, len(s.scored))), [], None
    preds, info = [], []
    for seed in o.seeds:
        t0 = time.time()
        _, epochs, vl = train(o, seed, n_in, inner, val, o.max_epochs * steps_per_epoch(len(inner), o.batch), dev)
        steps = max(1, round(epochs * 1.1 * steps_per_epoch(len(fit), o.batch)))
        net, _, _ = train(o, seed, n_all, fit, None, steps, dev)
        p = predict(net, scored).cpu().numpy().astype(np.float64)
        preds.append(p)
        info.append((seed, epochs, vl, float(net.a)))
        log(f"  seed {seed}: epochs {epochs:.2f} val {vl:.5f} scored {mean_loss(scored.y.cpu().double(), torch.from_numpy(p)):.5f} a {float(net.a):.3f} ({time.time() - t0:.1f} s)")
    own = 1 / (1 + np.exp(-off["scored"])) if "scored" in off else None
    if own is not None:
        log(f"  own offset alone on scored: {mean_loss(scored.y.cpu().double(), torch.from_numpy(own)):.5f}")
    return s, np.array(preds), info, own


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap")
    ap.add_argument("--net", required=True, choices=["small", "big", "resid"])
    ap.add_argument("--ref", required=True, help="netcheck preds.tsv: its cand column is copied for pairing")
    ap.add_argument("--seeds", default="1,2,3,4,5,6,7,8,9,10")
    ap.add_argument("--blocks", default=",".join(nnsets.BLOCKS))
    ap.add_argument("--out", default="out")
    ap.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    ap.add_argument("--opt", default="adamw")
    ap.add_argument("--ema", type=float, default=0.0)
    ap.add_argument("--trace", action="store_true", help="log gradient norm stats per fit")
    ap.add_argument("--max-epochs", type=int, default=60)
    ap.add_argument("--fix-offset", action="store_true")
    ap.add_argument("--cross-part", default="random", choices=["stride", "random"], help="resid: how training games are split into fifths")
    ap.add_argument("--offset-seed", type=int, default=1, help="resid: seed of the offsets' ratings fits and partition")
    ap.add_argument("--offset-avg", type=int, default=1, help="resid: average the cross-fitted training offsets over this many partitions")
    ap.add_argument("--offsets-only", action="store_true", help="resid: log the offsets' losses and stop")
    ap.add_argument("--offsets-from", help="resid: Zig's offsets from a set-net --dump run dir")
    for k in ["emb", "batch", "evals", "patience", "min_games"]:
        ap.add_argument("--" + k.replace("_", "-"), type=int)
    for k in ["dropout", "wd", "emb_wd", "lr", "clip"]:
        ap.add_argument("--" + k.replace("_", "-"), type=float)
    ap.add_argument("--hidden", help="comma list of widths")
    o = ap.parse_args()
    for k, v in DEFAULTS[o.net].items():
        if getattr(o, k, None) is None:
            setattr(o, k, v)
    if isinstance(o.hidden, str):
        o.hidden = [int(x) for x in o.hidden.split(",")]
    o.seeds = [int(x) for x in o.seeds.split(",")]
    os.makedirs(o.out, exist_ok=True)
    torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", "4")))
    logf = open(os.path.join(o.out, "xnets.log"), "w")

    def log(msg):
        print(msg, flush=True)
        logf.write(msg + "\n")
        logf.flush()

    log(f"# xnets {o.net}: " + " ".join(f"{k} {getattr(o, k)}" for k in ["emb", "hidden", "dropout", "wd", "emb_wd", "lr", "clip", "batch", "evals", "patience", "min_games", "max_epochs", "opt", "ema", "fix_offset", "offset_seed", "offset_avg", "cross_part", "device"]))
    data = nnsets.load(o.snap)
    ref = nnsets.read_preds(o.ref)
    ok, lines = nnsets.check_against(data, ref)
    for line in lines:
        log(line)
    if not ok:
        log("reader does not reproduce the reference's scored games: stop")
        raise SystemExit(1)
    plats = data.meta["platforms"]
    with open(os.path.join(o.out, "preds.tsv"), "w") as pf, open(os.path.join(o.out, "folds.tsv"), "w") as ff:
        pf.write("fold\tmatch_id\tplatform\ty\tcand\t" + "\t".join(f"seed{s}" for s in o.seeds) + "\tens\n")
        ff.write("seed\tfold\tepochs\tval_logloss\toffset_weight\n")
        for b in o.blocks.split(","):
            s, preds, info, own = run_block(data, b, o, o.device, log)
            if o.offsets_only:
                continue
            ens = preds.mean(0)
            for seed, ep, vl, a in info:
                ff.write(f"{seed}\t{b}\t{ep:.2f}\t{vl:.6f}\t{a:.4f}\n")
            r = ref[b]
            # resid: its own ratings offset is its candidate (compare.py pairs each side with its own)
            cand = r["cand"] if own is None else own
            for i, gi in enumerate(s.scored):
                pf.write(f"{b}\t{r['match_id'][i]}\t{plats[data.platform[gi]]}\t{data.y[gi]:.0f}\t{cand[i]:.6f}\t" + "\t".join(f"{p[i]:.6f}" for p in preds) + f"\t{ens[i]:.6f}\n")
            pf.flush()
            ff.flush()


if __name__ == "__main__":
    main()
