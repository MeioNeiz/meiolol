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
- E2-E5 made concrete, with arms, newest-only rolling evaluation and the train-vs-eval
  curve: docs/plan/patch-transfer.md (21 Oct; 16.21's day one moved champions 0.75 pp)
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
