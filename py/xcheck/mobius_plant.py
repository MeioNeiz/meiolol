"""Planted check of the exact 10-seat Mobius decomposition (docs/plan/lab-frontier.md C0).

Real drafts of SNAP/nn (played dev-visible games; real results never read), winners
re-drawn from a planted logit h(blue, red) - h(red, blue): champion-role mains, a pair
table per role-pair block (half champion-level low rank shared across blocks, half iid
per cell; two blocks left at 0), optionally a 3-way class term on top, jungle, support.
A net (seat embeddings into an antisymmetric MLP, plus linear mains) is fitted to those
labels and decomposed: per explained draft the Mobius term of every seat coalition under
the marginal value function (absent seats take another real draft's champions, the same
backgrounds for every coalition). Printed per scenario: power by order for truth and net
(cross-product of two background halves, so background noise adds nothing), how the
net's terms line up with the truth's, and per block the planted pair cells recovered by
the net's purified four-corner term and by a shrunk per-cell residual on a mains-only
fit (spread by method of moments). Scenarios: pairs (two net seeds), mains (pairs off:
all pair and higher power is noise), triple 2 and 1 pp.

--fm D adds a dot-product term of width D per role-pair block (a field-aware FM), the
form that can learn the low-rank half.

--dump PATH writes the triple2 truth's tables, the first --dump-n explained drafts, their
backgrounds and the float64 Mobius terms (two halves), and stops: `meiolol-lab mobius
plant-check PATH` recomputes them in Zig (C1's tool gate). --fixture PATH the same from
made-up drafts of 8 champions, no SNAP: src/testdata/lab/mobius-plant.bin, the lab test.

usage: mobius_plant.py SNAP [--fm 0] [--explain 3000] [--bg 32] [--cellbg 512]
       [--only NAMES] [--dump PATH [--dump-n 500]]
       mobius_plant.py --fixture PATH
"""

import argparse
import copy
import math
import struct
import time

import numpy as np
import torch
import torch.nn.functional as F

import nnsets

PP = 25.0  # win pp at 50% per logit unit
LANE_PP = [2.3, 1.2, 1.9, 1.2, 1.3]
ROLES = ["top", "jng", "mid", "bot", "sup"]
NULL_ALLY = (0, 2)
NULL_ENEMY = (0, 4)
TRIPLE_ROLES = [0, 1, 4]
BANDS = [(10, 50), (50, 200), (200, 1000), (1000, 10**9)]


def ally_pp(r, s):
    if (r, s) == NULL_ALLY:
        return 0.0
    return 1.45 if (r, s) == (3, 4) else 0.3


def enemy_pp(r, s):
    if r == s:
        return LANE_PP[r]
    if (r, s) == NULL_ENEMY:
        return 0.0
    return 0.95 if (r, s) in ((2, 3), (3, 4)) else 0.5


class Truth:
    """h(own, enemy); ids are dense champion indices, [B, 5] per team, role = column"""

    def __init__(self, n_champ, pick, seed, pair_scale, triple_pp, dev):
        g = torch.Generator().manual_seed(seed)
        c = n_champ
        self.main = torch.randn(5, c, generator=g) * (1.5 / PP)
        u = torch.randn(4, c, 4, generator=g)

        def table(sd, lo_a, lo_b):
            low = (u[lo_a] @ u[lo_b].T) / 2.0
            iid = torch.randn(c, c, generator=g)
            return (low + iid) * math.sqrt(0.5) * sd / PP * pair_scale

        self.ally = torch.zeros(5, 5, c, c)
        self.enemy = torch.zeros(5, 5, c, c)
        for r in range(5):
            for s in range(r, 5):
                if s > r:
                    self.ally[r, s] = table(ally_pp(r, s), 0, 1)
                    self.enemy[r, s] = table(enemy_pp(r, s), 2, 3)
                else:
                    self.enemy[r, r] = table(enemy_pp(r, r) / math.sqrt(2), 2, 3)
        tag = (torch.rand(c, generator=g) < 0.3).float()
        z = torch.zeros(5, c)
        for r in TRIPLE_ROLES:
            p = (pick[r] * tag).sum()
            z[r] = (tag - p) / math.sqrt(float(p * (1 - p)))
        self.z = z.to(dev)
        self.triple = triple_pp / PP
        self.main, self.ally, self.enemy = (t.to(dev) for t in (self.main, self.ally, self.enemy))
        self.r = torch.arange(5, device=dev)

    def h(self, own, en):
        out = self.main[self.r, own].sum(1)
        for r in range(5):
            for s in range(r, 5):
                if s > r:
                    out = out + self.ally[r, s, own[:, r], own[:, s]]
                out = out + self.enemy[r, s, own[:, r], en[:, s]]
        if self.triple:
            t = TRIPLE_ROLES
            out = out + self.triple * self.z[t[0], own[:, t[0]]] * self.z[t[1], own[:, t[1]]] * self.z[t[2], own[:, t[2]]]
        return out

    def logit(self, x):
        return self.h(x[:, :5], x[:, 5:]) - self.h(x[:, 5:], x[:, :5])


class Net(torch.nn.Module):
    def __init__(self, n_champ, emb=16, hidden=256, fm=0):
        super().__init__()
        self.c = n_champ
        # fm > 0: a dot-product term per role-pair block (field-aware FM), [5C, 5 partner
        # roles, fm]: ally and enemy sides each
        self.fm = fm
        if fm:
            self.fa = torch.nn.Parameter(torch.randn(5 * n_champ, 5, fm) * 0.01)
            self.fe = torch.nn.Parameter(torch.randn(5 * n_champ, 5, fm) * 0.01)
            self.fo = torch.nn.Parameter(torch.randn(5 * n_champ, 5, fm) * 0.01)
        self.own = torch.nn.Embedding(5 * n_champ, emb)
        self.en = torch.nn.Embedding(5 * n_champ, emb)
        self.main = torch.nn.Embedding(5 * n_champ, 1)
        torch.nn.init.zeros_(self.main.weight)
        self.mlp = torch.nn.Sequential(
            torch.nn.Linear(10 * emb, hidden), torch.nn.ReLU(), torch.nn.Dropout(0.1),
            torch.nn.Linear(hidden, hidden), torch.nn.ReLU(), torch.nn.Dropout(0.1),
            torch.nn.Linear(hidden, 1, bias=False),
        )
        self.register_buffer("off", torch.arange(5) * n_champ)

    def h(self, own, en):
        o, e = own + self.off, en + self.off
        x = torch.cat([self.own(o).flatten(1), self.en(e).flatten(1)], 1)
        out = self.mlp(x).squeeze(1) + self.main(o).sum((1, 2))
        if self.fm:
            a, fo, fe = self.fa[o], self.fo[o], self.fe[e]
            for r in range(5):
                for s in range(5):
                    if s > r:
                        out = out + (a[:, r, s] * a[:, s, r]).sum(1)
                    out = out + (fo[:, r, s] * fe[:, s, r]).sum(1)
        return out

    def logit(self, x):
        return self.h(x[:, :5], x[:, 5:]) - self.h(x[:, 5:], x[:, :5])


def batched(fn, x, size=1 << 18):
    with torch.no_grad():
        return torch.cat([fn(x[i : i + size]) for i in range(0, len(x), size)])


def loss_of(fn, x, y):
    return F.binary_cross_entropy_with_logits(batched(fn, x), y).item()


def fit_net(x_fit, y_fit, x_val, y_val, n_champ, seed, mains_only=False, fm=0):
    torch.manual_seed(seed)
    dev = x_fit.device
    net = Net(n_champ, fm=fm).to(dev)
    if mains_only:
        params = [{"params": net.main.parameters(), "weight_decay": 0.0}]
    else:
        params = [
            {"params": net.mlp.parameters(), "weight_decay": 1e-4},
            {"params": list(net.own.parameters()) + list(net.en.parameters()) + list(net.main.parameters()), "weight_decay": 0.0},
        ]
        if fm:
            params.append({"params": [net.fa, net.fe, net.fo], "weight_decay": 0.0})
    fn = (lambda x: net.main(x[:, :5] + net.off).sum((1, 2)) - net.main(x[:, 5:] + net.off).sum((1, 2))) if mains_only else net.logit
    opt = torch.optim.AdamW(params, lr=2e-3 if mains_only else 1e-3)
    n, batch = len(x_fit), 4096
    steps = n // batch
    best, best_state, bad = loss_of(fn, x_val, y_val), None, 0
    for epoch in range(20):
        perm = torch.randperm(n, device=dev)
        for i in range(steps):
            idx = perm[i * batch : (i + 1) * batch]
            net.train()
            opt.zero_grad(set_to_none=True)
            F.binary_cross_entropy_with_logits(fn(x_fit[idx]), y_fit[idx]).backward()
            opt.step()
            if (i + 1) % (steps // 2) == 0:
                net.eval()
                v = loss_of(fn, x_val, y_val)
                if v < best - 1e-6:
                    best, bad = v, 0
                    best_state = {k: t.clone() for k, t in net.state_dict().items()}
                else:
                    bad += 1
        if bad >= 4:
            break
    if best_state is not None:
        net.load_state_dict(best_state)
    net.eval()
    return net, fn, best


def mobius(fn, x, z):
    """x, z [P, 10] -> Mobius terms [P, 1024] of v(S) = fn(x on S, z elsewhere)"""
    dev = x.device
    m = torch.arange(1024, device=dev)
    bits = ((m[:, None] >> torch.arange(10, device=dev)) & 1).bool()
    ids = torch.where(bits[None], x[:, None, :], z[:, None, :]).reshape(-1, 10)
    a = fn(ids).reshape(len(x), 1024)
    for i in range(10):
        on = m[(m >> i) & 1 == 1]
        a[:, on] = a[:, on] - a[:, on ^ (1 << i)]
    return a


def decompose(fn, x, bg, n_bg):
    """Two half-means of the Mobius terms per explained draft, [N, 1024] each"""
    halves = [torch.zeros(len(x), 1024, device=x.device) for _ in range(2)]
    with torch.no_grad():
        for j in range(n_bg):
            z = bg[j]
            for i in range(0, len(x), 192):
                halves[j % 2][i : i + 192] += mobius(fn, x[i : i + 192], z[i : i + 192])
    return [h / (n_bg / 2) for h in halves]


def write_dump(truth, ex, bg, path, need_triple=False):
    """MOBP file, little-endian: "MOBP", u32 version 1, champions, drafts, backgrounds, the
    3 triple roles; f64 triple size; f64 main [5, C], ally and enemy [5, 5, C, C], z
    [5, C]; i32 drafts [N, 10], backgrounds [B, N, 10]; f64 terms [2, N, 1024] (half =
    background index % 2, each the mean over its backgrounds). All in float64 on the CPU.
    need_triple: False without writing when no order-3 term is over 1e-3"""
    t = copy.copy(truth)
    t.main, t.ally, t.enemy, t.z = (v.double().cpu() for v in (truth.main, truth.ally, truth.enemy, truth.z))
    t.r = truth.r.cpu()
    ex, bg = ex.cpu(), bg.cpu()
    halves = [torch.zeros(len(ex), 1024, dtype=torch.float64) for _ in range(2)]
    with torch.no_grad():
        for j in range(len(bg)):
            for i in range(0, len(ex), 192):
                halves[j % 2][i : i + 192] += mobius(t.logit, ex[i : i + 192], bg[j][i : i + 192])
    terms = torch.stack(halves) / (len(bg) / 2)
    order = torch.tensor([bin(m).count("1") for m in range(1024)])
    if need_triple and float(terms[:, :, order == 3].abs().max()) < 1e-3:
        return False
    with open(path, "wb") as f:
        f.write(b"MOBP")
        f.write(struct.pack("<7I", 1, t.main.shape[1], len(ex), len(bg), *TRIPLE_ROLES))
        f.write(struct.pack("<d", t.triple))
        for a in (t.main, t.ally, t.enemy, t.z):
            f.write(a.numpy().astype("<f8").tobytes())
        f.write(ex.numpy().astype("<i4").tobytes())
        f.write(bg.numpy().astype("<i4").tobytes())
        f.write(terms.numpy().astype("<f8").tobytes())
    power = [float((terms[0] * terms[1])[:, order == k].sum(1).mean()) * PP * PP for k in range(1, 11)]
    print(f"dump {path}: {len(ex)} drafts x {len(bg)} backgrounds, {t.main.shape[1]} champions; power pp^2 by order " + " ".join(f"{v:.6f}" for v in power))
    return True


def four_corner(fn, i, j, cells, z):
    """Purified cell of seats (i, j): mean over backgrounds of the second difference"""
    out = torch.zeros(len(cells), device=z.device)
    with torch.no_grad():
        base = fn(z)
        for k in range(0, len(cells), 256):
            c = cells[k : k + 256]
            zz = z[None].repeat(len(c), 1, 1)
            both, a_only, b_only = zz.clone(), zz.clone(), zz.clone()
            both[:, :, i] = c[:, :1]
            both[:, :, j] = c[:, 1:]
            a_only[:, :, i] = c[:, :1]
            b_only[:, :, j] = c[:, 1:]
            f = lambda t: fn(t.reshape(-1, 10)).reshape(len(c), -1)
            out[k : k + 256] = (f(both) - f(a_only) - f(b_only) + base[None]).mean(1)
    return out


def direct_cells(kind, r, s, x, resid, w, n_champ):
    """Shrunk per-cell residual estimate, both sides pooled: (count, estimate, tau)"""
    c = n_champ
    cc = c * c

    def sums(a, b, sign):
        key = a * c + b
        return (
            torch.bincount(key, minlength=cc).float(),
            torch.bincount(key, weights=resid * sign, minlength=cc),
            torch.bincount(key, weights=w, minlength=cc),
        )

    if kind == "ally":
        n1, s1, w1 = sums(x[:, r], x[:, s], 1.0)
        n2, s2, w2 = sums(x[:, 5 + r], x[:, 5 + s], -1.0)
    elif r != s:
        n1, s1, w1 = sums(x[:, r], x[:, 5 + s], 1.0)
        n2, s2, w2 = sums(x[:, 5 + r], x[:, s], -1.0)
    else:
        n1, s1, w1 = sums(x[:, r], x[:, 5 + r], 1.0)
        t = lambda v: v.reshape(c, c).T.reshape(-1)
        n2, s2, w2 = t(n1), -t(s1), t(w1)
    n, num, den = n1 + n2, s1 + s2, w1 + w2
    ok = n >= 10
    tau2 = max(float(((num[ok] ** 2).sum() - den[ok].sum()) / (den[ok] ** 2).sum()), 1e-8)
    return n, num / (den + 1.0 / tau2), math.sqrt(tau2)


def corr(a, b):
    if len(a) < 3 or a.std() == 0 or b.std() == 0:
        return float("nan")
    return float(np.corrcoef(a, b)[0, 1])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snap", nargs="?")
    ap.add_argument("--explain", type=int, default=3000)
    ap.add_argument("--bg", type=int, default=32)
    ap.add_argument("--cellbg", type=int, default=512)
    ap.add_argument("--only", default="")
    ap.add_argument("--fm", type=int, default=0)
    ap.add_argument("--dump", default="")
    ap.add_argument("--dump-n", type=int, default=500)
    ap.add_argument("--fixture", default="")
    args = ap.parse_args()
    if args.fixture:
        g = torch.Generator().manual_seed(3)
        c = 8
        for seed in range(11, 40):
            truth = Truth(c, torch.full((5, c), 1.0 / c), seed, 1.0, 2.0, torch.device("cpu"))
            if bool(torch.isfinite(truth.z).all()):
                break
        # Drafts whose backgrounds differ on the triple's seats, so order 3 is exercised
        while not write_dump(truth, torch.randint(c, (2, 10), generator=g), torch.randint(c, (2, 2, 10), generator=g), args.fixture, True):
            pass
        return
    dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    data = nnsets.load(args.snap)
    played = (data.flags & nnsets.PLAYED) != 0
    games = np.flatnonzero(played & (data.split <= 6))
    games = games[np.argsort(data.start[games], kind="stable")]
    n_val = len(games) // 10
    x_all = torch.from_numpy(data.champ[games].astype(np.int64)).to(dev)
    x_fit, x_val = x_all[:-n_val], x_all[-n_val:]
    c = len(data.meta["champions"])
    pick = torch.stack([torch.bincount(torch.cat([x_fit[:, r], x_fit[:, 5 + r]]), minlength=c).float() for r in range(5)])
    pick = (pick / pick.sum(1, keepdim=True)).cpu()
    print(f"games fit {len(x_fit)} val {len(x_val)} champions {c} device {dev}")

    g = torch.Generator(device=dev).manual_seed(7)
    ex = x_val[torch.randperm(len(x_val), device=dev, generator=g)[: args.explain]]
    bg = x_fit[torch.randint(len(x_fit), (args.bg, len(ex)), device=dev, generator=g)]
    cell_bg = x_fit[torch.randint(len(x_fit), (args.cellbg,), device=dev, generator=g)]
    order = torch.tensor([bin(m).count("1") for m in range(1024)], device=dev)
    tri = [sum(1 << r for r in TRIPLE_ROLES), sum(1 << (5 + r) for r in TRIPLE_ROLES)]

    blocks = [
        ("lane top", "enemy", 0, 0), ("lane mid", "enemy", 2, 2), ("duo bot-sup", "ally", 3, 4),
        ("mid v bot", "enemy", 2, 3), ("jng v mid (0.5)", "enemy", 1, 2),
        ("top+jng (0.3)", "ally", 0, 1), ("NULL top+mid", "ally", 0, 2), ("NULL top v sup", "enemy", 0, 4),
    ]
    scenarios = [("pairs", 1.0, 0.0, 1), ("pairs", 1.0, 0.0, 2), ("mains", 0.0, 0.0, 1), ("triple2", 1.0, 2.0, 1), ("triple1", 1.0, 1.0, 1)]
    only = [s for s in args.only.split(",") if s]
    kept = {}
    for name, pair_scale, triple_pp, seed in scenarios:
        if only and name not in only:
            continue
        t0 = time.time()
        truth = Truth(c, pick, 11, pair_scale, triple_pp, dev)
        if args.dump:
            if name == "triple2":
                write_dump(truth, ex[: args.dump_n], bg[:, : args.dump_n], args.dump)
            continue
        lg = batched(truth.logit, x_all)
        y_all = torch.bernoulli(torch.sigmoid(lg), generator=torch.Generator(device=dev).manual_seed(5))
        y_fit, y_val = y_all[:-n_val], y_all[-n_val:]
        tag = f"{name} s{seed}"
        print(f"\n## {tag}: truth logit sd {lg.std().item():.3f}, calls {((lg > 0).float() == y_all).float().mean().item() * 100:.1f}% right")
        _, mains_fn, mains_loss = fit_net(x_fit, y_fit, x_val, y_val, c, 1, mains_only=True)
        net, fn, net_loss = fit_net(x_fit, y_fit, x_val, y_val, c, seed, fm=args.fm)
        oracle = loss_of(truth.logit, x_val, y_val)
        ln2 = math.log(2)
        print(
            f"val milli-nats under a coin: mains {1e3 * (ln2 - mains_loss):.2f}, net {1e3 * (ln2 - net_loss):.2f}, "
            f"truth {1e3 * (ln2 - oracle):.2f}; net took {100 * (mains_loss - net_loss) / (mains_loss - oracle):.0f}% of mains-to-truth"
        )
        print(f"RESULT {tag} net_minus_mains_mnats {1e3 * (net_loss - mains_loss):.3f} share_of_gap {(mains_loss - net_loss) / (mains_loss - oracle):.3f}")

        ta, tb = decompose(truth.logit, ex, bg, args.bg)
        na, nb = decompose(fn, ex, bg, args.bg)
        tm, nm = (ta + tb) / 2, (na + nb) / 2
        print("| order | truth power pp^2 | net power pp^2 | net share of orders 1+ | corr net, truth | slope |")
        print("| --- | --- | --- | --- | --- | --- |")
        tot = float((na * nb)[:, 1:].sum(1).mean())
        for k in list(range(1, 6)) + [6]:
            sel = (order == k) if k < 6 else (order >= 6)
            tp = float((ta * tb)[:, sel].sum(1).mean()) * PP * PP
            npw = float((na * nb)[:, sel].sum(1).mean()) * PP * PP
            a, b = tm[:, sel].flatten().cpu().numpy(), nm[:, sel].flatten().cpu().numpy()
            slope = float((a * b).sum() / max((a * a).sum(), 1e-12))
            label = str(k) if k < 6 else "6-10"
            print(f"| {label} | {tp:.3f} | {npw:.3f} | {100 * npw / (tot * PP * PP):.1f}% | {corr(a, b):.2f} | {slope:.2f} |")
            print(f"RESULT {tag} order {label} truth_pp2 {tp:.4f} net_pp2 {npw:.4f} share {npw / (tot * PP * PP):.4f}")
        hi = order >= 3
        print(f"RESULT {tag} net_share_order3plus {float((na * nb)[:, hi].sum(1).mean()) / tot:.4f}")
        if triple_pp:
            a, b = tm[:, tri].flatten().cpu().numpy(), nm[:, tri].flatten().cpu().numpy()
            o3 = (order == 3).clone()
            o3[tri] = False
            planted = float((na * nb)[:, tri].mean()) * PP * PP
            others = float((na * nb)[:, o3].mean()) * PP * PP
            print(f"planted triple seats: corr net, truth {corr(a, b):.2f}; net power per triple {planted:.4f} pp^2 vs other triples {others:.4f}")
            print(f"RESULT {tag} triple_corr {corr(a, b):.3f} planted_pp2 {planted:.5f} other_pp2 {others:.5f}")

        resid = y_fit - torch.sigmoid(batched(mains_fn, x_fit))
        p = torch.sigmoid(batched(mains_fn, x_fit))
        w = p * (1 - p)
        print("| block | cells 10+ | truth sd pp | net rmse | direct rmse | corr net | corr direct | by games 10-49 / 50-199 / 200-999 / 1000+: corr net, direct |")
        print("| --- | --- | --- | --- | --- | --- | --- | --- |")
        for bname, kind, r, s in blocks:
            i, j = (r, s) if kind == "ally" else (r, 5 + s)
            n, est, tau = direct_cells(kind, r, s, x_fit, resid, w, c)
            idx = torch.nonzero(n >= 10).squeeze(1)
            cells = torch.stack([idx // c, idx % c], 1)
            if kind == "enemy" and r == s:
                cells = cells[cells[:, 0] < cells[:, 1]]
                idx = cells[:, 0] * c + cells[:, 1]
            tr = (four_corner(truth.logit, i, j, cells, cell_bg) * PP).cpu().numpy()
            nt = (four_corner(fn, i, j, cells, cell_bg) * PP).cpu().numpy()
            dr = (est[idx] * PP).cpu().numpy()
            cnt = n[idx].cpu().numpy()
            kept[(tag, bname)] = nt
            per = []
            for lo, hi_ in BANDS:
                sel = (cnt >= lo) & (cnt < hi_)
                per.append(f"{corr(nt[sel], tr[sel]):.2f}, {corr(dr[sel], tr[sel]):.2f} ({int(sel.sum())})")
            rm = lambda v: float(np.sqrt(((v - tr) ** 2).mean()))
            print(
                f"| {bname} | {len(cells)} | {tr.std():.2f} | {rm(nt):.2f} | {rm(dr):.2f} | {corr(nt, tr):.2f} | {corr(dr, tr):.2f} | {' / '.join(per)} |"
            )
            print(
                f"RESULT {tag} block {bname.replace(' ', '_')} cells {len(cells)} truth_sd {tr.std():.3f} net_sd {nt.std():.3f} direct_sd {dr.std():.3f} "
                f"net_rmse {rm(nt):.3f} direct_rmse {rm(dr):.3f} corr_net {corr(nt, tr):.3f} corr_direct {corr(dr, tr):.3f} tau_pp {tau * PP:.2f}"
            )
        print(f"({time.time() - t0:.0f} s)")
    if ("pairs s1", "lane top") in kept and ("pairs s2", "lane top") in kept:
        print("\n## two net seeds, same labels: corr of purified cells")
        for bname, _, _, _ in blocks:
            a, b = kept[("pairs s1", bname)], kept[("pairs s2", bname)]
            print(f"RESULT seeds block {bname.replace(' ', '_')} corr {corr(a, b):.3f}")


if __name__ == "__main__":
    main()
