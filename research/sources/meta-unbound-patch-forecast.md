---
title: 'KinetraFPS/meta-unbound: Deadlock and Overwatch meta site with a backtested patch-note forecast (GitHub, Nov 2026)'
url: https://github.com/KinetraFPS/meta-unbound
kind: project
commit: 145db020688e40df8d6ad3787abe66daaabe75b3
for: [early-patch-forecast]
looked: 2026-11-14
depth: code (README, src/impact.js, src/patchParser.js, config.js; backtest numbers read from the published docs/data.js and docs/overwatch/data.js)
relevance: high
grade: D/fair
description: A nine-day-old hobby meta site for Deadlock and Overwatch that turns patch-note lines into a signed score per hero, fits one constant (pp of win rate per unit of score) on past patches, and uses pre-patch win rate plus that forecast as the prior for the new patch's games
---
# KinetraFPS/meta-unbound: Deadlock and Overwatch meta site with a backtested patch-note forecast (GitHub, Nov 2026)

Why: the only project found that does the whole thing we would test: parse patch notes
to a signed size, forecast each hero's win-rate move, use it as the prior mean for the
new patch, and score it against "no change".

## Assessment

- Evidence: D. Created 5 Nov 2026, 0 stars, 2 contributors, 1 commit in the shallow
  history; LLM pass on the Anthropic SDK and the README's shape suggest agent-built.
  Backtest is in-sample (k fitted on the points it is scored on), 43 and 53 hero-patch
  points, no intervals; 34 of Deadlock's 43 points come from one patch with 5.3 days
  after it.
- Reasoning: fair. States the model in one line, scores against a no-change baseline,
  shows rules-only vs LLM side by side, shrinks win rates before differencing.
- Interests: none known (hobby project).
- Weigh: the design is the cleanest statement of the method; the numbers are a hint
  that a notes score carries sign (about 72-74%) and a little size, not evidence it
  would beat a zero-mean shrunk offset out of sample.

## Findings

- [method/dynamics] Model: predicted win-rate change = k x signed score, k fitted by
  least squares through the origin on past patches' (score, observed change) pairs.
  `src/impact.js:1` ^f1
  > "Patch-impact model: predicted win-rate change = k × (signed change score)."
- [method/dynamics] Score per hero: sum over its patch-note lines of direction x
  relative size of the number change (capped at 0.6; 0.08 for a line with no numbers)
  x weight (base stats 1.6, upgrade tiers 0.6, ultimates 0.8) x parser confidence.
  `src/patchParser.js:126` ^f2
  > "score ≈ Σ direction × magnitude × weight × confidence. Unclassified lines add uncertainty instead."
- [method/dynamics] [stats] The forecast is the prior mean for the new patch, updated
  by the new patch's games as a beta-binomial. `README.md` "How it works" ^f3
  > "prior = pre-patch WR + patch forecast + expert shift"
  > "posterior = prior ⊕ post-patch games  (beta-binomial)"
- [method/dynamics] [stats] Backtest design: per past patch, each changed hero's win
  rate in up to 10 days before vs up to 10 days after (shrunk toward 50% by 400 games,
  heroes with 500+ games each side), scored by correlation, sign hit rate and mean
  absolute error against predicting no change. `src/impact.js:15`, `config.js` ^f4
  > "const maeNaive = mean(obs.map(Math.abs));"
- [method/dynamics] [stats] Published result, Deadlock (docs/data.js at this commit,
  read by script, no quote): 43 hero-patch points over 6 patches, r 0.67, sign right
  74.4%, mean absolute error 1.45 pp vs 1.73 pp for no change (16% lower), k 2.3 pp
  per unit of score; 34 of the 43 points are one patch (30 Oct 2026). ^f5
- [method/dynamics] [stats] Published result, Overwatch (docs/overwatch/data.js): 53
  hero changes, r 0.50, sign right 71.7%, error 1.78 pp vs 2.13 pp for no change (16%
  lower). ^f6
- [method/pretrain] An optional LLM pass re-labels the lines the rules were unsure of
  (direction, a size on a 0.03-0.6 scale, confidence), and the audit page replays
  rules-only beside it to show whether the LLM improves the backtest. `README.md` "LLM
  pass", `src/llmClassifier.js:22` ^f7
  > "so you can see whether the LLM actually improves forecasts"
- [method/dynamics] Checked, not there: a held-out patch (k is fitted on the scored
  points), intervals or a noise floor for the observed changes, a mean-reversion
  baseline (pre-patch win rate predicting the move), a per-day score after the patch,
  any use of pick-rate change. ^f8
- [method/dynamics] (inferred) This is our candidate arm in miniature: offset mean =
  k x notes score instead of 0, k from earlier patches, scored against the zero-mean
  arm. Their in-sample gain is 16% of the absolute move; our A3 (looser prior for
  changed champions, no sign) gained nothing once the sd was estimated, so the open
  part for us is the sign and size, which A3 did not use. ^f9
- [method/dynamics] [stats] Prior strength is set by hand and is looser for changed
  heroes: the pre-patch number counts as 15,000 games for an unchanged hero and 4,000
  for a changed one (not fitted, not backtested). `config.js:20` ^f10
  > "priorGames: { unchanged: 15000, changed: 4000 },"

## Read

- `README.md`: whole
- `src/impact.js`: whole (backtest and fit)
- `src/patchParser.js`: direction rules and score (lines 50-140)
- `config.js`: impact, shrink and LLM settings
- `docs/data.js`, `docs/overwatch/data.js`: backtest objects only (not snapped, 1.5 MB)

## Not read

- `src/score.js` (how prior and games combine, prior strength), `overwatch/build.js`
  (its own backtest code), the live site's Audit tab, per-point residuals.
