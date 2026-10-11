---
status: answered
priority: now
tags: [stats, method, data]
description: How should per-matchup per-minute lane curves be estimated robustly when many pairs are thin?
---
# How should per-matchup per-minute lane curves be estimated robustly when many pairs are thin?

Feeds: docs/concept.md "Matchup curves" and data needs; meiolol-b5 (building curves);
the public method write-up on the site

## Answer

Estimate every curve as "champion baseline plus a shrunk matchup effect", then smooth
across minutes; all steps are closed form. Raw per-pair means predict worse than
shrinking toward a group baseline (C1). The optimal pull is k pseudo-games of the
baseline, k = within-pair variance / between-pair variance, the same k whatever n (C2);
estimate the between-pair variance by unweighted method of moments with a small floor,
not n-weighted ML, because popular pairs differ systematically (C3). The baseline should
be the additive two-champion expectation, not the role mean (C4); DraftGap does exactly
this for win rates with a fixed 1000-game prior (C9). A discrete penalised smoother
(Whittaker / P-spline on the minute grid) smooths across minutes and fills thin minutes
in a pentadiagonal solve (C5). Before 15 minutes almost every game is still running;
after 15 the curve means "among games still running" and must say so (C6). Show the
game-to-game spread band and the uncertainty of the mean as separately labelled things
(C7). Same-player games and decay weights shrink effective n (C8); champion effects are
stable across patches, which supports pooling patches with decay (C10).

Recipe for meiolol-b5 (per role, bracket, metric gold/XP/CS diff, minute t = 1..30;
defaults are ours, to tune on box data, C11):
1. Clean: in-role games only; drop remakes and disconnects (any player under 500 damage
   taken by minute 7, SIDO's rule)
2. Weights: w = 0.5^(patch_age / h), h = 1 patch; regions pooled. Per pair and minute
   keep weighted mean m, variance s^2, raw n, n_eff = (sum w)^2 / sum w^2; divide n_eff
   by 1 + rho(mbar - 1) (mbar games per player in the pair; rho per role from player
   means); optionally cap games per player at 20
3. Baseline b_AB(t) = mu_t + a_A(t) - a_B(t) by backfitting (5 to 10 passes, weights
   n_eff); average both directions of a pair
4. tau^2_t = max(floor, unweighted mean over pairs of (r^2 - s^2/n_eff)), r = m - b;
   floor ~1% of median s^2; sigma^2_t pooled within-pair variance; k_t = sigma^2/tau^2
5. Shrink: est = b + n_eff / (n_eff + k_t) * r; posterior var ~ (n_eff/s^2 + 1/tau^2)^-1
6. Smooth: solve (W + lambda D2'D2) z = W y over minutes, W = 1 / posterior variance;
   lambda by leave-one-out CV per role
7. From minute 15: only games still running; second line for share of games ended
8. Brackets: nest the same step, bracket estimate shrinks toward all-bracket estimate
9. Show: 25-75th percentile band of per-game diffs at n >= 200, else the baseline band
   labelled; n and +-2 SE as text; grey when n_eff / (n_eff + k) < 0.5 ("mostly
   champion baseline") as well as n < 200; publish k per role and minute on the method
   page as "games to stabilise"
10. Win rates: (wins + m p0) / (games + m), p0 additive logit expectation, m by method
    of moments

No paper on per-matchup lane gold curves in LoL or Dota was found (three searches).

## Claims

- C1: Shrinking thin units toward a group baseline beats raw means and the grand mean out of sample (about 40% less squared error in Brown's test). for: [[brown-2008-batting-eb#^f1]], [[brown-2008-batting-eb#^f2]], [[brown-2008-batting-eb#^f5]], [[robinson-eb-baseball#^f1]], [[robinson-eb-baseball#^f5]]
- C2: Optimal shrinkage adds k baseline pseudo-observations, k = within-unit variance / between-unit variance, independent of n (Tango, Buhlmann credibility, hierarchical Bayes with point-estimated variance). for: [[gelman-luck-skill#^f1]], [[gelman-luck-skill#^f2]], [[gelman-luck-skill#^f3]], [[gelman-luck-skill#^f5]], [[gelman-luck-skill#^f6]], [[brown-2008-batting-eb#^f3]]
- C3: Estimate between-unit variance by unweighted method of moments, not n-weighted ML, when n correlates with the true value; floor it above zero. for: [[brown-2008-batting-eb#^f4]], [[brown-2008-batting-eb#^f6]], [[gelman-2005-anova#^f4]]
- C4: Shrink a matchup toward the additive two-champion baseline (main effects plus a shrunk interaction batch), not the role mean. for: [[gelman-2005-anova#^f1]], [[gelman-2005-anova#^f2]], [[brown-2008-batting-eb#^f8]], [[robinson-eb-baseball#^f6]], [[counterwatch-method#^f1]]
- C5: A discrete second-difference penalised smoother on the minute grid is fast, closed form, fills gaps, and lambda can be set as a variance ratio or by CV. for: [[eilers-marx-2010-splines#^f1]], [[eilers-marx-2010-splines#^f3]], [[eilers-marx-2010-splines#^f4]], [[eilers-marx-2010-splines#^f5]], [[eilers-marx-2010-splines#^f6]], [[eilers-marx-2010-splines#^f7]]
- C6: Before 15 minutes nearly all games are running (no surrender except with an AFK, remakes by 2:25); after 15 the honest estimand is the partly conditional mean among games still running. for: [[lol-wiki-surrender#^f1]], [[lol-wiki-surrender#^f2]], [[lol-wiki-surrender#^f3]], [[kurland-2009-truncated-by-death#^f1]], [[kurland-2009-truncated-by-death#^f2]], [[kurland-2009-truncated-by-death#^f5]]
- C7: Spread (s.d. or percentiles) and uncertainty of the mean (SE, CI) answer different questions, readers confuse them, so label which is shown. for: [[krzywinski-altman-error-bars#^f1]], [[krzywinski-altman-error-bars#^f2]], [[krzywinski-altman-error-bars#^f3]], [[krzywinski-altman-error-bars#^f5]]
- C8: Effective n falls with unequal weights (Kish) and with same-player clustering (1 + rho(m - 1)); player and player-champion effects are real in LoL and confound champion effects. for: [[practools-design-effects#^f1]], [[practools-design-effects#^f2]], [[practools-design-effects#^f3]], [[practools-design-effects#^f4]], [[sido-lol-performance#^f6]], [[lol-skill-decomposition#^f1]], [[lol-skill-decomposition#^f2]]
- C9: Prior art: DraftGap shrinks matchup win rates with pseudo-games at an additive logit expectation (default 1000, user-set 250 to 3000); LoLalytics only applies a 100-game display floor; Counterwatch removes both baselines with no low-n handling. for: [[draftgap#^f7]], [[draftgap#^f8]], [[draftgap#^f9]], [[draftgap#^f10]], [[lolalytics-counters-threshold#^f1]], [[counterwatch-method#^f1]], [[counterwatch-method#^f6]]
- C10: Champion effects on gold are stable across patches (concordance above 0.8 on EUW and NA), and hierarchical shrinkage suits scarce, imbalanced LoL data. for: [[sido-lol-performance#^f2]], [[sido-lol-performance#^f7]]
- C11 (inferred): Recipe above: additive baseline, MoM tau^2 with floor, pseudo-game shrinkage, minute smoother, partly conditional after 15, labelled bands. from: C1, C2, C3, C4, C5, C6, C7, C8

## Disagreements

- Prior strength fixed or estimated: DraftGap fixes 1000 games ([[draftgap#^f10]]);
  method of moments estimates it per role and minute (C3). Settled by our own tau^2 on
  box data; a rough guess for win rates lands near 1000 games
- Point estimate of tau^2: Brown backs it ([[brown-2008-batting-eb#^f5]]); Gelman warns
  near-zero values are falsely precise ([[gelman-2005-anova#^f4]]). Hence the floor

## Open

- Real sigma_t and tau_t for gold, XP, CS diff per role (sets k and thresholds): needs
  box data, first thing meiolol-b5 should print
- Whether tau^2 should vary by minute or be smoothed as well
- How much patches and brackets differ (sets half-life h and bracket pooling); rho for
  one-tricks
- No published low-n method for op.gg, leagueofgraphs, Dotabuff or Stratz; leads: Dotabuff
  "Disadvantage", Robinson beta-binomial regression, arXiv 1803.10402 (Dota hero pairs)
- Efron-Morris 1977 skipped (scanned PDF); Brown 2008 used instead
