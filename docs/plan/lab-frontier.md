# Plan: lab frontier (gpu-box experiment programme)

Try everything, push past what we have, many models and ensembles. Two aims, kept
apart:
1. The most accurate pre-game model we can build, any input, internal only: the
   teacher. It is the yardstick for every shipped model and the thing we explain
2. Understand why drafts win (main, pair, comp effects; what is causal; what moves over
   time), so the shipped model and the site's reasons are right, not just accurate

Both serve the data edge (J24, docs/plan.md "Our edge"): what moves across patches,
seasons and ranks is found here, then used by the site's estimate and the shipped model
(estimates.md E3-E5, E11).

Research behind each item: research/questions/frontier-experiments.md and its six
children (ceiling, tabular-ensembles, interactions, causal, dynamics, pretrain). Items
cite them as [ceiling C10] etc. Everything runs on the protocol in docs/model.md
("Shared protocol"), is written up there, and gets a learned.md line when final.

## The bar

With a calibrated true win logit of sd s, accuracy ~50% + 20 s points and log loss gain
over a coin ~s^2/8 [ceiling C10]:

| s | accuracy | log loss | vs today |
| --- | --- | --- | --- |
| 0.25 | 54.9% | 0.6853 | shipped model today (54.8%, 0.6855) |
| 0.30 | 55.9% | 0.6819 | -3.6 milli-nats |
| 0.35 | 56.9% | 0.6778 | -7.7 |
| 0.40 | 57.8% | 0.6731 | -12.4 |

Today's ladder (1320Z folds, chained, dev only): win-draft -> additive v2 -1.08 -> set
net on v2 -0.78, ~55.3%. Internal player history was -5 to -7 milli-nats on ratings at
2253Z (53.7 -> 56.1%) with 16 days of history. So: draft-only models probably top out
near 55.5%, a model that knows the players near 57%+.

## Already tried (don't redo blind)

Full inventory with numbers: data/team/2026-10-21-frontier/inventory.md. Open gaps:
player history never combined with the best draft model; mastery for all ten and rank
at start never in a win model; one patch boundary ever tested; no test look since 1320Z;
bans unused.

## Results so far (dev only; write-ups in docs/model.md)

- P1 pin snap-20261023T2004Z with seat stats merged, mastery_pre and 16.21: "The new
  pin, snap-20261023T2004Z: coverage and wave 1"
- P2 same-split head-to-head: half of v2's gain over the shipped model was the damage
  mix (needs champion-role profiles on the box); the set net on v2 is the best single
  model (-0.74 on v2) and hasn't grown with data since 1320Z: "P2: same-split
  head-to-head"
- E1 drift or noise: noise. At equal N newest, oldest and spread tie; doubling N gains
  1.7, so old history is not dead weight. Open: the set net gains less on the newest
  window: "E1: drift or noise at equal N"
- A1 scaling: no plateau for pair models and nets (1.1-2.3 a doubling at 1.19M games);
  nets add nothing under ~300k games; big may pass set on v2 within the next doubling
  (forecast). Train loss still to log: "A1: scaling curves"
- A2 ensemble selection on 1320Z preds: logistic stack -0.49 ± 0.09 vs setid-wa,
  greedy -0.11: "Lab frontier wave 1"
- B4 site table reliability: a matchup's raw rate at ~80 games is a third signal, half
  at ~300; confirms the site's usualK shrinkage: "Lab frontier wave 1"
- D1 strength at fixed mastery: the raw rate's mastery bias has sd 0.59 pp over
  champion-roles; the lane card's expertise bonus double counts (fix: centre on the
  champion-role's mean mastery): "Strength at fixed mastery (D1)"
- B1 draft ceiling: gate not met, see "Order and gates"
- C0 planted check of the Mobius reading (Python, one untuned net a scenario): exact on
  a known truth; a net that learnt pairs shows no false higher orders but invents pairs
  in empty blocks, on which its seeds agree; a hidden 2 pp class triple was not learnt;
  direct shrunk cells name pairs better from 50 games up: "Planted check of the 10-seat
  Möbius reading (C0)"

## Phase 0: before the gpu-box runs (CPU, Mac or box)

- P3 Pre-declare the test-look rule for this programme (one look per final model, sealed
  seeds, pass rule form from model.md 1320Z) and get Jacob's go: proposal below
- P4 One Python harness for per-game predictions: every model writes preds.tsv per
  block (folds, dev-val) keyed by match id, so ensembles, decompositions and the ceiling
  work read one format (nnsets.py rebuilds blocks already)

### P3 proposal: the test-look rule (for Jacob to accept or change)

Nothing here has run; no test game has been scored. Template: model.md "Nets on the
shipped model, 2026-10-18" (rule declared before results, sealed seeds, 2.1x).

Test window: snap-20261023T2004Z's test games (P1's pin), start >= 20 Oct 14:44Z (its
test cut) to 23 Oct 20:04Z, every platform: 238,153 played games, 224,188 of them on
16.21. No lab model has scored them, and all are newer than every game any frontier
model was developed on (1007Z's newest: 18 Oct 10:07Z). Final fits use every played game
below that cut (2004Z's seat stats merge the archive, P1). Models developed later on
2004Z's dev blocks may join the queue under the same rule. Since 94% of the test is a
patch the dev work never saw, the look also asks whether the gains carry to a new patch:
reported per patch and per day since 16.21. Profiles come from fit games only, so a test
game's own stats are never read.

One look per final model:
- A final model is a spec written into model.md before its run: commit, build flags,
  command, seeds. It fits on every played game below the test cut and scores every test
  game once. The command counts the look (netcheck `--blocks test`, `meiolol eval
  --setnet --test-look`; champcomp needs a final mode first). The result is written up
  whatever it shows. No second look at the same model, and no change then a look on
  this window: a failed model waits for a fresh window and a new declaration
- Nets score with never-run seeds, their mean the model: set nets 7-9 (1-6 used in dev),
  big and bigres 21-30
- Each contrast is paired per game against a named reference fitted on the same games

Pass rule per contrast: d the mean paired log loss difference (model minus reference,
nats a game) over the test games, h its 95% half-width. Nets, and stacks with net
members: pass when d + 2.1 h < 0 (2.1: 2253Z's measured A/A widening for nets, as at
1320Z). Models without seeds: d + h < 0. Reported, never deciding: test minus
test-exclude.tsv (say so if 2004Z has none), per patch, per day, per platform group (EUW1, KR,
rest), accuracy, AUC, the top tenth's said vs won.

Two families, each at 5%:
- The ladder, read in fixed order (a step is read only if the one before passed;
  otherwise "not tested"):
  1. Set net + embedding on additive v2 (setid-wa: -Dcand win-additive, `--net set
     --ids 1`, 18 Oct options) vs additive v2 (win-additive). Dev: -0.78 ± 0.12 on 1320Z's
     folds (sealed seeds 4-6); 1007Z dev-val -0.72 ± 0.19 (seeds 1-3), -0.94 ± 0.24
     (4-6). At ~238k games h ~0.11, so it passes if the true gain is ~0.25 or more
  2. A2 stack vs setid-wa: logistic stack weights fitted on all six 1320Z dev blocks
     (dev-seed preds), frozen, applied to the members' test logits. Members: the CPU six
     (win-draft, additive v2, setid-wa, setid-wd, set-wd, champcomp with kit groups):
     -0.29 ± 0.08 vs setid-wa on 1320Z (ensel.py, 23 Oct); or all twelve (-0.49 ± 0.09)
     if the gpu-box can run big and bigres seeds 21-30. Needs ensel.py to freeze and
     apply weights, and champcomp's final mode
  Secondary for step 1, never deciding: setid-wa vs the shipped model (the eval port:
  `eval --setnet`, a correction on additive v2's shipped form) and vs win-draft
- Comp leans (plan/data-and-model.md step 1; its own question, the site's reasons):
  champcomp with kit groups on win-draft, as declared 17 Oct ~16:20Z, vs win-draft:
  d + h < 0. Reported: of the 22 clear leans, how many keep their sign with |z| > 1.96;
  champgroups' six kit groups and Rammus jungle into auto-attackers as declared 18 Oct.
  The leans on today's shipped model (additive v2) would need a dev run first, then
  their own declaration

Not queued: big from scratch (failed its 1320Z rule), the within-team set net
(dominated), A4 and wave 2 (still in dev: P1's window).

Cost: on the Mac, setid-wa seeds 7-9 (~4 min), setid-wd and set-wd, eval --setnet
(~15 min), champcomp final once written; big and bigres only on the gpu-box.

For Jacob: (a) this window (2004Z's test), or a later pin's; (b) the ladder order, and the CPU six
or all twelve in the stack; (c) comp leans on win-draft as declared, or on additive v2
after a dev run.

## Wave 1: cheap and decisive (CPU hours)

Done: B1, E1, A1, A2, B4 (Results so far). Left:
- A1: log train loss, so train and test bracket each family's limit [ceiling C6]
- A2 on 2004Z's preds once P4's harness exists; members: win-draft, v2, set seeds,
  bigres, big, champcomp, embx
- D1 refit: strength with seat log mastery as a covariate in the model, reported at
  50k points, and the slope's own interval [causal C2, C3]. Rankings that move -> tier
  list and "safe blind" show strength at the user's mastery
- A1 at today's size: the daily eval has been flat since ~2.4M games (0.6826 at 3.4M),
  but its test set moves (newest 15%, now across 16.22). Rerun A1 on a new pin with
  fixed held-out games, v2 and the set net, sizes to 3.5M+. Done when each has its
  gain per doubling past 1.2M, and whether the net now beats v2
- A10 Meio's lessons in v2 (estimates.md): (a) champion-role strength shrinks to a line
  in its log share of the role, not 0 (Meio: off-role picks under 100 games win 34%);
  (b) champion-role x rank bracket terms, rank at game start, never the stored rank;
  (c) region terms are PT6's A8; (d) day 0 of a patch is E3/W4 with Meio's M8 exposure.
  Scored overall and per slice: Iron-Silver, Gold-Emerald, Diamond+, EUW1, patch days
  0-3, rare champion-roles, plus the pick metric; slices matter more than the overall,
  since the ceiling (B1) leaves ~0.8 points of accuracy. Done when (a) and (b) each have
  a paired difference vs v2 per slice

## Wave 2: the teacher (gpu-box)

Build up, each step measured on the one before:
- A3 TabM (k=32) residual on v2, same inputs as the big net [tabular C4, C10]: should
  match the 10-seed big net in one run; replaces seed ensembles if it does
- A4 Pair cells that borrow strength: the parent form shipped; left: a field-aware FM
  (fields = 10 role slots) residual on v2 and low-rank u.v cells [tabular C5].
  CPU-shippable; FM is dot products in Zig
- A5 Multi-task set net: win plus gold14, lanediff14, game length, kill pace heads
  (the draft explains 6-22% of those, Q2) and a masked-pick head [pretrain C7, C12].
  Side product: P(champion | role, other nine), the pick model D2 needs
- A6 Validation protocol [tabular C11]: pick epochs on an older slice, refit on all
  games including the newest. If it helps, every net and stacker refits this way
- A7 LightGBM with v2's logit as base margin on cross-fitted dense features: comp
  profiles, shrunk term values, patch age, bans, lobby rank spread [tabular C12, C13]
- A8 The internal teacher: best draft stack + all-ten player history + all-ten mastery
  + rank_start + duo, as offsets and as player tokens in the set net. Answers "how
  predictable is a game before it starts" (target 57%+). Internal only, never app or
  site (docs/production-key.md)
- A9 Final stack: A2's selection over everything above, sealed, one test look

## Wave 3: why (explain the teacher)

Methods, best first [interactions C19; C0 in Results so far]:
1. A named champion pair comes from the direct fit: v2's shrunk cells with A4's
   parents, purified before display (C5)
2. The teacher is read by exact 10-seat Mobius terms (1,024 coalitions a draft): each
   order's share and what the net adds to v2; no Shapley index unless order 3+ is large
3. What the teacher adds ships by distilling into v2's form (C3), not by quoting the
   net; a name read off a net needs a knockoff block, a planted twin and agreeing seeds
Not run [C13, C17, C18]: H-statistic (per seat pair, no null), EBM/FAST (pair terms cut
champions in index order), neural GAMs (nothing at champion level over shrunk cells),
seat-masked training as the main reading (describes how picks go together, not the model).

- C1 Order spectrum of the teacher (declared 13 Nov, nothing run; dev only, nothing public)
  - Models: B = additive v2 with pair parents (win-additive), T = the set net with
    champion-role embedding on it (setid-wa, 18 Oct options), seeds 1-6 and their mean.
    snap-20261023T2004Z, netcheck's dev block: fit below the dev cut, explain played
    dev-val games (a seeded 20,000 for power, all for (3)). No test game is loaded
  - Reading: Mobius terms of the logit per draft; absent seats from 32 fit drafts
    sharing no champion with it (every mix legal), the same for all coalitions, in two
    halves; an order's power = mean over drafts of the halves' summed product, pp^2.
    Tool: `meiolol-lab mobius` (to write), checked by py/xcheck/mobius_plant.py
  - (1) Tool gate: B without the damage mix has order 3+ power under 1e-6 pp^2, its pair
    terms match its purified cells (r > 0.999), and Zig and Python agree on a planted
    truth to 1e-4 pp. Else nothing is read
  - (2) Higher orders there? H3 = T's order 3+ power. Twins: B and T (seeds 1-2) refitted
    on three `plant:` relabellings of the fit games, mains and pair cells at v2's block
    spreads, no mix. Yes when the smallest H3 of the six real seeds is over twice the
    largest of the six twins (C0's twins: 0.3-1.6% of power)
  - (3) Do they predict? T against its own terms up to pairs, paired log loss per game:
    yes when d + 2.1 h < 0
  - Both yes: C4 runs, C3's student gets comp terms beside pairs, the seat sets carrying
    order 3+ are listed. Either no: the net's gain is main and pair structure single
    cells can't hold; C3's student is v2's form alone, C4 waits for twice the games
  - Reported, not deciding: power per order for B, T - B and T, per seed; T - B's pair
    power per block; pair terms with the other seats absent against present [C15]
- C2 Pairs the net moved: cells whose T - B term is over three times a knockoff
  block's sd (a dummy seat per role), same sign in 6 of 6 seeds, refit as shrunk terms in
  v2 and judged on held-out log loss [interactions C4, C5]: the pairs the site may name
- C3 Distil the teacher into v2's form (out-of-fold soft targets, squared error on
  logits, mains then pairs; `netcheck --fit-preds 1`, `effects --soft`) and compare term
  by term with the label fit (distil-explainable C8, C11)
- C4 Triple power test, only if C1 says yes: plant 3-way kit-group terms, smallest
  detectable at this size, then real class triples [interactions C8, C9]
- C5 Purify shipped and teacher terms under seat-weighted data before display, so mains
  don't hide in pairs [interactions C2]

## Wave 4: causal and time

- D2 Does following the lane card win more? Pick model from A5 (champion | role, top
  15 pool, enemy laner) as propensity; IPS and doubly robust value of "top option" vs
  players' own picks [causal C9]. Decides whether the app may ever say more than
  "ranked by your mastery"
- D3 Matchup terms with player effects or double ML on mastery, ranks and the rest of
  the draft [causal C8]: if counters shrink 10-30%, matchup pages say so
- D4 ARAM natural experiment [causal C10]: 50-100k ARAM games (queue 450) of players
  with mastery; win on log mastery within player. Tests whether the expertise effect is
  causal. Costs Riot API budget: Jacob's go, likely after the production key
- E2-E3 run as docs/plan/patch-transfer.md PT1-PT5 (J25): scored on latest-patch games
  only, day by day; E4-E5 only if PT3 finds a jump worth modelling
- E2 Per-patch offsets with 16.21 in dev, scored by day since patch, shuffled-patch
  control, share of games on unseen patches [dynamics C11]
- E3 Patch-day prior: changed champions start at minus k x last deviation plus the sign
  of the Data Dragon stat diff, first 3 days vs zero start [dynamics C5]
- E4 Mastery-adjusted drift: patch offsets with and without the expertise term
  [dynamics C8, causal C11]
- E5 Kickscore or Kalman strength only if E2 or E3 find a real jump [dynamics C4]
- E6 Chance by game length (tester note 68): v2 refit with a term per length bucket
  (<25, 25-30, 30-35, 35+ min; or A5's length head), scored on held-out games within
  each bucket vs v2. Only if a bucket beats v2 beyond its interval does the Draft tester
  show the chance per bucket with ranges. gpu-box, from Mon 2 Nov

## Wild ideas (speculative, after the waves)

- W1 The size of the prize: with the teacher and D2's pick model, per held-out draft
  the win chance of the best legal pick from the player's own pool vs what they picked.
  The average gap is what perfect drafting is worth, per role and rank; the app's
  ceiling as a product number
- W2 Last-pick value in-model: since match-v5 has no pick order, compute per role how
  much the teacher gains from choosing last (best response to the full enemy team) vs
  blind; compare with app users' logged turn order later (needs consent and a product
  decision)
- W3 Cold-start priors [pretrain C3, C11]: leave-one-champion-out, replay recent
  releases with 0/1/3/7 days of data; role average vs d8 stat embedding vs bge-small
  embedding of ability text; then id dropout in the set net (DropoutNet)
- W4 LLM patch-note parser: signed stat changes per champion as E3's prior. Counting
  buffs fails [pretrain C10]; only magnitudes might help
- W5 TabICLv2 yardstick on a dense table with a 50-100k subsampled context: can't
  ship (and TabPFN-3 can't be used at all), but beating v2 would mean our features hold
  signal the hand-built model misses
- W6 In-game upper bound: per-minute LightGBM on the pre-game logit plus state at
  minutes 1, 2, 3, 5; bounds the pre-game ceiling from above (~59% expected)
- W7 Synthetic drafts (a real draft with one slot swapped) labelled by the teacher to
  feed rare pairs into the student (distil-explainable C6)

## Ruled out by the research (don't run without new evidence)

TabPFN-3 (licence bars production use), contrastive pretraining, LLMs as draft
predictors, DCN-v2 as a priority, Kalman/Glicko variance tracking as such, kNN Bayes
error bounds, 3-way champion-level terms, in-game chance as score or soft label
(model.md 20 Oct), GBDT on one-hot picks.

## Order and gates

Phase 0 -> wave 1 (B1, E1, A1, A2 run in parallel; D1, B4 on CPU) -> gate: B1's ceiling
and A1's curves decide how much of wave 2 is draft architecture (A3, A4, A7) vs players
(A8). Wave 3 needs a teacher that beats v2 sealed (C1 alone runs on dev before). Wave 4's
patch items need 16.21 in dev; D4 needs API budget. Rough gpu-box time: wave 1 under a
day, wave 2 two to four days, wave 3 a day, wave 4 a day plus the ARAM crawl.

B1's gate (docs/model.md "Draft ceiling (B1) rerun on 2004Z"): not met. Four blocks
known perfectly: s 0.33 (~56.5%); the set net on v2 is 4.8 ± 0.9 milli-nats short, all
in pair cells too thin to estimate one by one: wave 2's borrowing across cells (A4, A3)
and more games both stay worth it.
