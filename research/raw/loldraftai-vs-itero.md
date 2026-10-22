# iTero vs LoLDraftAI: A Detailed Comparison

<https://loldraftai.com/blog/itero-vs-loldraftai-comparison>

[LoLDraftAI](https://loldraftai.com/)

[Home](https://loldraftai.com/)[Draft Analysis](https://loldraftai.com/draft)[Champions](https://loldraftai.com/champions)[Blog](https://loldraftai.com/blog)[Download](https://loldraftai.com/download)[Pricing](https://loldraftai.com/pricing)

[Sign in](https://loldraftai.com/auth/login)

# iTero vs LoLDraftAI: A Detailed Comparison

April 19, 2026

## Table of Contents

-   [How iTero's model actually works](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#how-iteros-model-actually-works)
-   [Qualitative example: a draft that can't reach its win condition](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#qualitative-example-a-draft-that-cant-reach-its-win-condition)
-   [Does seed #20 generalize? A look across all 100 drafts](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#does-seed-20-generalize-a-look-across-all-100-drafts)
-   [Tournament results](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#tournament-results)
-   [Feature coverage: what each tool actually ships](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#feature-coverage-what-each-tool-actually-ships)
-   [Where iTero is ahead](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#where-itero-is-ahead)
-   [Related comparisons](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#related-comparisons)
-   [Try LoLDraftAI](https://loldraftai.com/blog/itero-vs-loldraftai-comparison#try-loldraftai)

[iTero](https://www.itero.gg/drafting-tool) is a trained model over the same lolalytics-style pairwise aggregates that other pairwise-stats tools wrap in a formula (its API response signature is consistent with a gradient-boosted tree ensemble, more on that below). That architecture has a structural limit: it evaluates champions pair by pair, never as a whole draft, and it exposes no team-level win probability you can score against real matches. So this post tests iTero the only way you can: by making it draft head-to-head against LoLDraftAI across 100 scenarios, and letting a third-party judge (DraftGap itself) score the outcomes.

The setup: **100 head-to-head greedy drafts**, 50 starting scenarios (each given a different first pick for variety), each played twice, once with LoLDraftAI on Blue and once on Red, to cancel out side advantage. At each pick, the active model greedily selects its top recommendation under the standard `B-R-R-B-B-R-R-B-B-R` pick order. Both candidate sets are filtered at ≥ 0.5% playrate per (champion, role) on the current patch. Each final 5v5 is then scored by two judges: **DraftGap** (a third-party tool, neutral to both contestants) and LoLDraftAI's own win-probability head (flagged as non-independent).

## How iTero's model actually works

We can tell a lot about iTero's model from what its API returns. For each candidate champion in a lane, the response includes "feature importances", signed contributions for keys like `champ_wr`, `champ_gold`, `counter_MIDDLE_wr`, `syn_JUNGLE_wr`, `gold_multiplier`, `match_tier`, `mastery`, plus "ratings" on a 0-5 scale for archetype traits (`eco`, `snowball`, `early_scaling_diff`, etc.). Their methodology article confirms a **two-stage design**: "I have a separate model which first predicts the Gold @ 12 minutes before then going on to predict the outcome."

That signature (per-feature contribution scores, SHAP-style: each feature's signed pull on the final prediction, over hand-crafted pairwise features brute-forced over all ~160 champions for each lane) is consistent with a **gradient-boosted tree ensemble over lolalytics-style aggregates**: champion solo winrates, pair synergies, pair counters, per-role gold differentials. DraftGap is a simpler deterministic formula over the same kind of aggregates, not a trained model, just an arithmetic combination of the pairwise stats. Both iTero and DraftGap are therefore **pairwise-statistics tools**: they consume the draft as a bag of champion-pair numbers. Neither has any mechanism to reason about composition-level dynamics.

LoLDraftAI, by contrast, is a deep neural network trained end-to-end on raw match records, not aggregates. It learns its own champion embeddings and reasons about the draft as a whole. That architectural difference is what drives most of the disagreements below.

## Qualitative example: a draft that can't reach its win condition

The cleanest way to see where iTero's approach falls short is one of the 100 drafts from the tournament described above: a Master+ scenario where the two tools made the following picks:

-   **Blue (LoLDraftAI)**: Shen, Bel'Veth, Swain, Draven, Lux (Lux SUP was the forced first pick that seeded the scenario).
-   **Red (iTero)**: Ornn, Rek'Sai, Aurelion Sol, Yasuo, Milio.

iTero outputs no team-level win probability, so its "verdict" on this 5v5 is implicit: these are the five champions it picked on Red, in order, under the same pick sequence LoLDraftAIused for Blue. And Red's draft is fine on paper. Four of the five isolated 1v1 lane matchups favor Red; three of Red's four carries (Ornn, Aurelion Sol, Yasuo) are dominant late-game champions, and Milio is a scaling enchanter built specifically to keep Yasuo alive into that late game. If you read the draft as five independent matchups, which is all a pairwise-stats model like iTero or DraftGap is architecturally able to do, Red looks at worst even.

LoLDraftAI reads the draft as a whole and disagrees: **62.1% for Blue, +3,523 gold at 15 minutes**. The model's per-duration breakdown explains why in one picture:

The time-bucketed chart on the right is unambiguous: LoLDraftAI itself agrees Red wins ~68% of 35+ minute games. The problem is the 0–25 minute bucket is **77.9% Blue** and the crossover point sits around minute 27. In Master+, games that are 3.5k gold down at 15 rarely reach minute 35; one side closes the game before the scaling curve ever catches up.

Masking champions out (using LoLDraftAI's unknown-champion feature to see how each pick contributes) pins down the load-bearing picks. Removing Bel'Veth drops Blue's 0–25 minute WR from 77.9% to 65.8%; removing Aurelion Sol cuts Red's 35+ minute WR by 7.9 points and no other pick moves the late-game bucket by more than ~3. That isn't a coincidence. [Bel'Veth](https://loldraftai.com/champions/belveth/jungle) and [Aurelion Sol](https://loldraftai.com/champions/aurelionsol/mid)are two of the most skewed early-vs-late champions in the game, as the "Win Rate by Game Length" panel on their pages shows. The whole match comes down to whether Blue can close before Aurelion Sol comes online; in Master+, it usually can.

DraftGap rates the same 5v5 at **35.5% for Blue**. Its formula has no column for "the game ends before Aurelion Sol's third item" because no such column exists in a lolalytics dataset. The 27-point gap between the two judges is the whole story of this article in one draft: pairwise stats can evaluate a teamfight at minute 35, they can't evaluate whether the game ever gets to minute 35.

### Does seed #20 generalize? A look across all 100 drafts

For each of the 100 final 5v5s from the tournament we computed:

-   **Disagreement** = `p(Blue wins)` by LoLDraftAI − `p(Blue wins)` by DraftGap.
-   **Predicted gold lead at 15 minutes** from LoLDraftAI's per-position gold regression heads (summed over five roles, Blue − Red).

The two quantities are strongly correlated: **Pearson r = +0.59** (n = 100). Pearson r measures how tightly two numbers move together: 0 means unrelated, ±1 means perfect lockstep. A permutation test with 5,000 random re-pairings gives _p_< 0.001: a correlation this strong arose in less than 0.1% of shuffles. When LoLDraftAIthinks Blue gets ahead early, it also thinks Blue wins more often, and that's exactly when DraftGap disagrees with it.

Slicing the same 100 drafts by the magnitude of the predicted gold lead makes the effect more concrete. The mean absolute disagreement between the two judges trends up with the predicted lead:

| |Predicted gold lead @ 15min| | n | Mean |LoLDraftAI − DraftGap| |
| --- | --- | --- |
| Q1: 32 – 497 g | 25 | 10.4 pp |
| Q2: 497 – 1,108 g | 25 | 13.3 pp |
| Q3: 1,108 – 2,162 g | 25 | 12.6 pp |
| Q4: 2,162 – 4,882 g | 25 | 14.8 pp |

When the predicted early-game swing is small, the two models mostly agree. When LoLDraftAIpredicts that one side is going to be thousands of gold ahead by minute 15, DraftGap can't see any of that and the judges drift ~50% farther apart. This is the numerical version of the seed-#20 story: pairwise stats structurally can't encode tempo.

## Tournament results

Scoring all 100 final 5v5s with both judges gives the headline scoreboard:

| Judge | LoLDraftAI win rate | Mean WR margin (LoLDraftAI) |
| --- | --- | --- |
| DraftGap (third-party) | 55.0% (45.0–65.0) | +0.6% (−1.0 to +2.2) |
| LoLDraftAI (non-independent) | **93.0%** (88.0–98.0) | **+13.2%** (+11.6 to +14.9) |

Two different judges look at the same 100 drafts and reach very different verdicts. DraftGap's formula calls it a near-tie (55.0%, CI 45.0–65.0); LoLDraftAI's own head calls it a decisive +13-point margin. We should discount the second number heavily (LoLDraftAI judging drafts it itself picked is textbook circular), but the _disagreement_ between the two judges is the story. **DraftGap and iTero are both pairwise-statistics tools** built on the same kind of lolalytics-style aggregates (DraftGap is the formula version, iTero is the trained tree ensemble version), so a judge built on pairwise stats will systematically under-rate the tempo dynamics we demonstrated above. DraftGap can't see what LoLDraftAI sees, and that gold-correlation result from the last section is exactly why.

Full tournament data (all 100 drafts, per-pick decisions, both judges' scores, and LoLDraftAI's predicted gold at 15 min per draft) is available at [drafts\_scored.jsonl](https://media.loldraftai.com/blog/itero-vs-loldraftai-comparison/drafts_scored.jsonl).

## Feature coverage: what each tool actually ships

Beyond predictive accuracy, the other reason to choose one tool over the other is simply whether it supports what you want to do with it. Here's a concrete comparison, based on observing both tools' web UIs and APIs. Legend: **✔** supported, **~** partial / limited, **✘** not available.

| Feature | LoLDraftAI | iTero |
| --- | --- | --- |
| Calibrated team win probability for a full 5v5 | ✔ (side-aware + side-agnostic modes) | ✘ (per-candidate score only; no team WR) |
| User-selectable patch | ✔ (historical patches) | ✘ (current patch only, not even labeled) |
| Pro play model (fine-tuned on pro drafts) | ✔ (Plus tier) | ✘ |
| Rune / perk recommendations evaluated by the WR model | ✔ (web tool) | ✘ on web; desktop-only, not built on a WR model |
| Item build recommendations | ✔ (conditioned on the full draft, runes, elo, and patch) | ✔ (desktop app; builds adapt to the enemy comp, e.g. anti-heal / anti-shield) |
| Timeline prediction (win % by game duration) | ✔ (0-25, 25-30, 30-35, 35+ min buckets) | ✘ (early/mid/late _scaling diffs_ only) |
| Predicted gold lead per position | ✔ (5 positions at 15 min) | ~ (single predicted gold number per candidate) |
| Side-agnostic / side-aware switch | ✔ | ✘ (side is fixed input, no merged mode) |
| Per-champion / per-matchup SEO pages | ✔ (every champion × role, per patch) | ✘ (only blog articles) |
| Bans in the drafting UI | ✔ (desktop app) | ~ (API supports bans; web UI does not expose them) |
| Partial-draft recommendations | ✔ | ✔ |
| Desktop app with League Client auto-detection | ✔ (Base/Plus tier) | ✔ (free) |
| Mastery-aware recommendations | ✘ | ✔ (optional "Consider Mastery" toggle) |
| Champion Pool Builder (tiered S+/S/A+ recs) | ✘ | ✔ |
| Personality Quiz / champion suggestion by playstyle | ✘ | ✔ |
| In-game overlays (map timers, skill order, damage, etc.) | ✘ | ✔ (desktop-only) |
| Account-level macro coaching | ✘ | ✔ (desktop-only, "AI Macro Coach") |

The split is roughly: LoLDraftAI is deeper on the draft-analysis model itself (calibrated WR, patch awareness, pro mode, timeline, side-awareness, WR-grounded rune recommendations, plus draft-conditioned item builds), while iTero is broader in scope with features outside the draft-prediction core (personality quiz, pool builder, in-game overlays, macro coach).

## Where iTero is ahead

iTero ships product features LoLDraftAIdoesn't: in-game overlays, a Champion Pool Builder, and more polished mastery integration. If those matter to you more than draft-prediction accuracy, iTero is a reasonable choice. But on the drafting model itself, LoLDraftAI has the deeper architecture, broader input coverage (patches, pro play, timeline), and a calibrated win-probability output you can evaluate against real matches.

## Related comparisons

-   [DraftGap vs LoLDraftAI](https://loldraftai.com/blog/draftgap-vs-loldraftai-comparison) — the formula version of the same pairwise-stats architecture, scored on a 33,000-match strict holdout with log loss and calibration metrics.
-   [LoLTheory vs LoLDraftAI](https://loldraftai.com/blog/loltheory-vs-loldraftai-comparison) — a per-elo logistic regression over ~14,500 pairwise features, scored on the same 33k-match holdout.

## Try LoLDraftAI

LoLDraftAI is free to use in the browser, or as a desktop app that auto-imports your draft from the League client.

-   [Web tool](https://loldraftai.com/draft) — no install
-   [Desktop app](https://loldraftai.com/download) — live draft tracking

Navigation

-   [Home](https://loldraftai.com/)
-   [Draft Analysis](https://loldraftai.com/draft)
-   [Champions](https://loldraftai.com/champions)
-   [Download](https://loldraftai.com/download)
-   [Pricing](https://loldraftai.com/pricing)
-   [Dashboard](https://loldraftai.com/dashboard)
-   [Blog](https://loldraftai.com/blog)

Support

-   [Discord](https://discord.gg/MpbtNEwTT7)
-   [Contact support](mailto:support@loldraftai.com)
-   [FAQ](https://loldraftai.com/#faq)
-   [Legal](https://loldraftai.com/legal)

Last model update: October 17 on patch 16.20. Expect a few days delay after new patches. Early patch data may be combined with the previous patch data for better predictions.

LoLDraftAI isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.
