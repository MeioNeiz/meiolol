# Plan: lab frontier (gpu-box experiment programme)

Jacob, 21 Oct: try everything, push past what we have, many models and ensembles. Two
aims, kept apart:
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

Full inventory with numbers: data/team/2026-10-21-frontier/inventory.md. Gaps it found:
nothing measured above fit 600k; player history never combined with the best draft
model; mastery for all ten and rank at start never in a win model; pair cells never
borrow strength; one patch boundary ever tested; no test look since 13 Oct; bans unused;
stacking only at 35k games.

## Phase 0: before the gpu-box runs (CPU, Mac or box)

- P1 New pin, ~1.3M+ games: seat stats merged for every game (1007Z has ~24% of seats:
  profile models silently degrade, lab-constraints 13 Oct), mastery_pre for all ten,
  rank_start in dev, 16.21 in dev. Report coverage per split first
- P2 Same-split head-to-head on P1: win-draft, additive v2, set net on v2 (why the shipped
  model trails v2 by ~1.1, inventory gap 5). Port v2 into `meiolol eval`
- P3 Pre-declare the test-look rule for this programme (one look per final model, sealed
  seeds, pass rule form from model.md 1320Z) and get Jacob's go
- P4 One Python harness for per-game predictions: every model writes preds.tsv per
  block (folds, dev-val) keyed by match id, so ensembles, decompositions and the ceiling
  work read one format (nnsets.py rebuilds blocks already)

### P3 proposal: the test-look rule (draft, 23 Oct; for Jacob to accept or change)

Nothing here has run; no test game has been scored. Template: model.md "Nets on the
shipped model, 2026-10-18" (rule declared before results, sealed seeds, 2.1x).

Test window: snap-20261023T2004Z's test games (P1's pin, made 23 Oct; 1007Z was pruned
that night), start >= 20 Oct 14:44Z (its test cut) to 23 Oct 20:04Z, every platform:
238,153 played games, 224,188 of them on 16.21. No lab model has scored them, and all
are newer than every game any frontier model was developed on (1007Z's newest: 18 Oct
10:07Z). Final fits use every played game below that cut (2004Z's seat stats merge the
archive, P1). Models developed later on 2004Z's dev blocks may join the queue under the
same rule. Since 94% of the test is a patch the dev work never saw, the look also asks
whether the gains carry to a new patch: reported per patch and per day since 16.21.
Profiles come from fit games only, so a test game's own stats are never read.

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

## Wave 1: cheap and decisive (CPU hours, first days)

- B1 Draft ceiling by variance accounting [ceiling C4, C5, C11]. Per block
  (champion-role, ally pairs, enemy pairs, comp residual), excess spread of held-out
  residual cells over a null simulated on the real schedule; sum, convert with s^2/8.
  Validate by flipping a known share of labels (estimate shrinks by (1-2r)^2); joint
  REML or Haseman-Elston for overlap. Same for own-seat terms and all-ten history.
  Gate: total near s 0.27 -> stop draft architecture work, effort to players and product
- E1 Drift or noise? Equal-N test [dynamics C2, C12]: at each N, newest N vs N spread
  over all days vs oldest N, same forward folds. Expected tie within ~0.3. If newest wins
  clearly, strength needs time terms and old history is dead weight
- A1 Fixed-block scaling curve on P1 at 1/16 to 1 of fit games: ratings, additive v2,
  set+emb on v2, big, bigres. Log train loss too: train and test bracket each family's
  limit [ceiling C6]. Answers the plateau question properly and whether nets cross v2
- A2 Ensemble selection over existing preds [tabular C7, C8, C9]: greedy with
  replacement, sorted start, 20 bags; weights fitted forward on folds 2-5, scored on
  dev-val and sealed seeds. Expected -0.3 to -0.8. Members: win-draft, v2, set seeds,
  bigres, big, champcomp, embx
- D1 Strength at fixed mastery [causal C2, C3]: refit with seat log mastery as a
  covariate, report strength at 50k points. Rankings that move -> tier list and "safe
  blind" show strength at the user's mastery; also fixes double counting in the lane
  card's expertise bonus
- B4 Split-half reliability of every site table (champion-role per patch, matchups,
  duos) with Spearman-Brown [ceiling C5]: tables under 0.3 get harder shrinkage or a
  luck note

## Wave 2: the teacher (gpu-box)

Build up, each step measured on the one before:
- A3 TabM (k=32) residual on v2, same inputs as the big net [tabular C4, C10]: should
  match the 10-seed big net in one run; replaces seed ensembles if it does
- A4 Pair cells that borrow strength: field-aware FM (fields = 10 role slots) residual
  on v2, and inside v2 matchup cells shrunk toward kit group x kit group and low-rank
  u.v instead of 0 [tabular C5]. CPU-shippable; FM is dot products in Zig
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

- C1 Interaction-order spectrum [interactions C1, C3, C12]: exact 10-seat Mobius
  decomposition (1,024 coalitions a draft) of the draft teacher, absent seat filled by
  legal same-role picks weighted by pick rate; share of each order per seed and
  resample against a shuffled-outcome net. Says whether the gain is pairs, comp traits
  or 3-way
- C2 Pair table from the teacher, refit as shrunk terms: four-corner swap score per
  pair, select, refit, judge on held-out log loss. Knockoff seats (dummy seat per role
  from the pick distribution) for 20% FDR, planted 0.5/1/2 pp pairs for power, keep a
  pair only if its sign holds over 10 seeds, two resamples and the logistic fit
  [interactions C4, C5]. Decides which named pairs may go on the site
- C3 Distil the teacher into v2's form (out-of-fold soft targets, squared error on
  logits, mains then pairs) and compare term by term with the label fit
  (distil-explainable C8, C11): the shippable student, now that a teacher beats the
  label fit
- C4 Triple power test: plant 3-way kit-group terms, find the smallest detectable at
  1.4M games, then test real class triples. Expected undetectable under ~2 pp
  [interactions C8, C9]
- C5 Purify before display: re-centre shipped and teacher terms under seat-weighted
  data so mains don't hide in pairs [interactions C2]

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
(A8). Wave 3 needs a teacher that beats v2 sealed. Wave 4's patch items need 16.21 in
dev; D4 needs API budget. Rough gpu-box time: wave 1 under a day, wave 2 two to four
days, wave 3 a day, wave 4 a day plus the ARAM crawl.
