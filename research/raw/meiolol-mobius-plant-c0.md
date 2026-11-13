### Planted check of the 10-seat Möbius reading (C0), 2026-11-13 (rinteract)

Question (lab-frontier wave 3): if we decompose a trained draft net exactly into main,
pair and higher terms, do we get the effects that are there, at our data shape (10 seats,
173 champions, a near-coin outcome)? Python only, gpu-box: py/xcheck/mobius_plant.py on
snap-20261023T2004Z's `nn-export` tensors (HEAD a1f9e723; runs
20261113T210508Z-mobius-plant, plain net; 20261113T210845Z-mobius-plant-fm8, `--fm 8`;
~1 min a scenario). No real result is read: real drafts of the played dev-visible games
(fit 1,214,271, newest 134,918 for early stopping and the explained drafts), winners
re-drawn from a planted logit. No test game loaded.

Planted: champion-role mains sd 1.5 pp; a pair table per role-pair block at learned.md's
sizes (lanes 1.2-2.3 pp, bot with support 1.45, mid v bot and bot v support 0.95, other
enemy blocks 0.5, other ally blocks 0.3), half of each champion-level low rank shared
across blocks, half its own per cell; two blocks at 0 (top+mid allies, top v support);
logit sd 0.285, the truth calls 55.6% right. Scenarios: pairs (two net seeds), mains
(pair tables off), and pairs plus a 3-way class term on a team's top, jungle and support
(a hidden tag on 30% of champions) at 2 and 1 pp.

Reading: per explained draft (3,000) the Möbius term of each of the 1,024 seat
coalitions; an absent seat takes another fit draft's champions, the same 32 backgrounds
for every coalition (marginal value function; duplicates not filtered). Power by order =
mean over drafts of the summed product of two 16-background halves, so background noise
adds nothing. Pair cells: the four-corner second difference over 512 backgrounds, for
every cell with 10+ fit games (both sides pooled), against (a) the same reading of the
truth and (b) the direct estimate: per-cell residual sums on a mains-only logistic fit,
shrunk by a spread from the method of moments per block.

Net: seat embeddings 16 into an antisymmetric MLP (2 x 256) plus linear mains; with
`--fm 8` also a dot-product term per role-pair block. One untuned fit each.

| scenario, net | val gain under a coin: mains / net / truth, milli-nats | power pp^2 order 1 / 2 / 3+: truth | net | net order 3+ share |
| --- | --- | --- | --- | --- |
| pairs, plain MLP (seeds 1, 2) | 4.29 / 4.27, 4.36 / 9.62 | 24.3 / 25.9 / 0 | 19.4 / 0.44 / 0.19; s2 order 2 1.32 | 0.9%, 1.6% |
| pairs, fm 8 (seeds 1, 2) | 4.29 / 5.48, 5.57 / 9.62 | 24.3 / 25.9 / 0 | 23.8 / 12.8 / 0.11; s2 23.5 / 12.9 / 0.17 | 0.3%, 0.5% |
| mains, fm 8 | 3.64 / 3.38 / 3.80 | 20.9 / 0 / 0 | 16.1 / 0.35 / 0.08 | 0.5% |
| triple 2 pp, fm 8 | 4.30 / 5.52 / 10.74 | 24.2 / 25.9 / 7.5 | 23.0 / 12.6 / 0.11 | 0.3% |
| triple 1 pp, fm 8 | 4.28 / 5.49 / 9.80 | 24.3 / 25.9 / 1.9 | 22.8 / 12.6 / 0.17 | 0.5% |

Pair cells, pairs scenario, fm 8 seed 1 (correlation with the truth's cell):

| block (planted sd pp) | cells | net | direct | 10-49 games: net, direct | 50-199 | 200-999 | 1000+ | cell sd: net, direct | two seeds agree |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| lane top (2.36) | 5,633 | 0.40 | 0.44 | 0.23, 0.20 | 0.34, 0.39 | 0.61, 0.74 | 0.79, 0.86 | 0.90, 1.05 | 0.89 |
| lane mid (1.94) | 4,773 | 0.33 | 0.41 | 0.18, 0.23 | 0.29, 0.33 | 0.48, 0.63 | 0.75, 0.84 | 0.65, 0.79 | 0.83 |
| bot with support (1.45) | 5,504 | 0.29 | 0.34 | 0.16, 0.13 | 0.24, 0.29 | 0.39, 0.48 | 0.67, 0.77 | 0.49, 0.47 | 0.82 |
| mid v bot (0.99) | 6,061 | 0.24 | 0.30 | 0.09, 0.11 | 0.17, 0.16 | 0.36, 0.41 | 0.68, 0.66 | 0.50, 0.33 | 0.77 |
| jungle v mid (0.51) | 8,120 | 0.13 | 0.16 | 0.04, 0.07 | 0.09, 0.10 | 0.23, 0.21 | 0.38, 0.38 | 0.37, 0.12 | 0.67 |
| top+jungle (0.30) | 8,620 | 0.03 | 0.09 | 0.01, 0.04 | 0.02, 0.05 | 0.04, 0.15 | 0.14, 0.23 | 0.21, 0.01 | 0.34 |
| top+mid (0) | 10,422 | - | - | | | | | 0.22, 0.00 | 0.34 |
| top v support (0) | 9,360 | - | - | | | | | 0.29, 0.02 | 0.52 |

- The machinery is exact: the truth's own reading has 0.000 power above order 2 without
  the triple and 7.5 pp^2 with it; orders 1 and 2 match the planted variances
- A net that has not learnt the pairs has nothing to read. The plain MLP stayed at the
  mains fit's loss; its pair power (0.4-1.3 pp^2 of 25.9 planted) is noise, and its two
  seeds' cells correlate 0.01-0.05. Same order of pair power as a net fitted to
  mains-only labels (0.16-0.35): that is the noise floor, not a pair signal
- A net that learns pairs shows no false higher orders: with fm 8 (22-24% of the
  mains-to-truth gap) order 3+ holds 0.3-0.5% of its power, as with mains-only labels
- A planted 3-way class effect was not read, because the net never learnt it: at 2 pp a
  team (7.5 pp^2, 13% of the truth's power) the net's order-3 power is 0.10, as without
  it, and its terms on the planted seats correlate 0.01 with the truth. The tag was
  hidden; a net given kit features may do better (C4)
- For naming a champion pair the direct shrunk cell has the lower error in every block
  and, in the three strongest blocks, the higher correlation from 50 games up (lane top
  at 200-999 games 0.74 against 0.61). At 10-49 games and in the weak blocks the two are
  level: there the net borrows the shared half. Its terms understate (slope 0.40 on the
  truth's)
- The net invents pairs where none are planted, and its seeds agree on them: cells in the
  two empty blocks have sd 0.22-0.29 pp (direct: 0.00-0.02) with seed correlation
  0.34-0.52. Seed agreement alone does not make a pair real; an empty reference block
  (knockoff seats) gives the size to beat, here about 0.3 pp
- Limits: one untuned net per scenario, not our teacher (v2 plus the set net on
  profiles); planted cells half unshared, which favours per-cell estimates; backgrounds
  not filtered for duplicate champions. C1 in docs/plan/lab-frontier.md runs the same
  reading on the teacher with these as its null

