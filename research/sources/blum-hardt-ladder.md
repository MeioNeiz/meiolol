---
title: 'The Ladder: A Reliable Leaderboard for Machine Learning Competitions (Blum, Hardt, 2015)'
url: https://arxiv.org/pdf/1502.04585
kind: paper
commit: 
for: [llm-experiment-agent]
looked: 2026-10-12
depth: skimmed (abstract, sections 1, 3 Ladder, 4 parameter-free, 5 boosting attack, conclusion)
relevance: high
grade: A/strong
description: Ladder mechanism (ICML 2015): a leaderboard that only reveals a new score when it beats the previous best by a significant margin (paired t-test), resisting holdout overfitting
---
# The Ladder: A Reliable Leaderboard for Machine Learning Competitions (Blum, Hardt, 2015)

Why: how to let a searcher see held-out scores many times without the leaderboard being
overfitted; this is the closest analogue to an agent loop keeping a best-so-far score.

## Assessment

- Evidence: A. Canonical reference (ICML 2015) by recognised experts; proofs (upper
  and lower bounds), an adversarial attack experiment and a real Kaggle competition's
  submission files.
- Reasoning: strong. Explains the Kaggle mechanism's failure, gives bounds, and says
  plainly that its significance test is heuristic and uncorrected for multiple
  comparisons.
- Interests: none known (academic; authors' own method).
- Weigh: trust the mechanism and the attack demonstration. The parameter-free variant's
  paired t-test is the same shape as our paired log-loss interval, so it ports directly.

## Findings

- [lab] [stats] Repeated leaderboard evaluation lets participants overfit the holdout;
  Kaggle's existing defences are heuristics (bit precision, resubmission rate). Abstract ^f1
  > As participants are allowed to repeatedly evaluate their submissions on the leaderboard, they may begin to overfit to the holdout data that supports the leaderboard.
  > Existing approaches therefore often resort to poorly understood heuristics such as limiting the bit precision of answers and the rate of re-submission.
- [lab] [stats] Kaggle's public/private split protects the final ranking but not the
  public scores, which forums report as inflated. Section 1 ^f2
  > While this solution increases the quality of the private leaderboard, it does not address the problem of maintaining accuracy on the public leaderboard.
- [lab] [stats] Ladder: only release a new score if it beats the previous best by a
  margin; otherwise repeat the previous best. Section 3, Figure 1 ^f3
  > If the estimate is below the previous best by some margin, it releases the estimate and updates the best estimate. Importantly, if the estimate is not smaller by a margin, the algorithm releases the previous best loss (rather than the new estimate).
- [lab] [stats] Error of naive leaderboards grows like sqrt(k) in the number of
  submissions; the Ladder's grows only with log(k), an exponential improvement. Section 1.1 ^f4
  > never worse than O((log(k)/n)1/3 ) where k is the number of submissions and n is the size of the data used to compute the leaderboard.
  > our algorithm features an exponential improvement in k.
- [lab] [stats] Parameter-free variant: the margin is a one-sided paired t-test on the
  per-example loss vectors of the new and previous best submission (threshold
  s/sqrt(n)), since paired tests have more power when losses are correlated. Section 4 ^f5
  > it is appropriate to perform a onesided paired t-test. A paired test has substantially more statistical power in settings where the loss vectors that are being compared are highly correlated as is common in a competition.
- [lab] [stats] The paper says its significance test is heuristic: adaptivity breaks the
  t approximation and multiple comparisons are not controlled. Section 4.1 ^f6
  > It is important to note, however, that our use of this significance test is primarily heuristic.
  > Besides we apply the test many times, but do not control for multiple comparisons.
- [lab] [stats] Boosting attack: submitting random label vectors and majority-voting
  those that scored better makes a submission biased on the public labels only; on the
  hidden 8000 labels it stays at chance, while Kaggle's mechanism reports a strongly
  biased loss. Section 5.1 ^f7
  > the resulting loss is close to its expected value of 1/2, i.e. the expected loss of a random 0/1-vector. What we observe, however, is that the Kaggle mechanism gives a strongly biased estimate of the loss of u ∗ .
- [lab] [stats] Under that attack the Ladder stays within the expected maximum
  deviation of k random vectors: each new best makes the next crossing less likely, so
  only O(log k) steps. Section 5.1 ^f8
  > Even with this more effective attack, the Ladder mechanism gives a result that is correct to within the expected maximum deviation of the score on k random vectors.
- [lab] [stats] An analyst who only uses the holdout to check whether the latest attempt
  is well above the previous best effectively runs the Ladder. Conclusion ^f9
  > If indeed every analyst only uses the holdout set to test if their latest submission is well above the previous best, then they effectively simulate our algorithm.
- [lab] (inferred) For meiolol: a keep-if-better agent loop should see only "new best"
  or "no significant change" from the held-out set, decided by our paired log-loss test
  against the current best, never the raw score of each variant. ^f10

## Read

- Abstract, section 1, section 3 (mechanism, statement only), section 4 and 4.1,
  section 5 and 5.1 text, conclusion

## Not read

- Proofs (Theorem 3.1 onwards) and the lower bound
- Section 6, the real Kaggle "Photo Quality Prediction" comparison in detail
