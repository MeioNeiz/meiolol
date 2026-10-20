---
title: 'Settles and Meeder 2016: A Trainable Spaced Repetition Model for Language Learning'
url: https://research.duolingo.com/papers/settles.acl16.pdf
kind: paper
commit: 
for: [teach-draft]
looked: 2026-10-20
depth: docs (abstract, sections 2, 3.3, 4.3-4.4)
relevance: medium
grade: A/strong
description: Duolingo's ACL 2016 paper on half-life regression, the spaced repetition model behind its strength meters, with two A/B tests on retention
---
# Settles and Meeder 2016: A Trainable Spaced Repetition Model for Language Learning

Why: how a drill product decides what to make the learner practise next, and whether it
moves retention.

## Assessment

- Evidence: A. Peer-reviewed (ACL 2016), production A/B tests on just under 1 million and
  3.3 million students, model released.
- Reasoning: strong. Compares baselines, reports a failed variant (overfitting lexeme
  weights) and the fix.
- Interests: Duolingo authors on their own product; retention numbers are theirs.
- Weigh: trust the mechanism and the A/B design; the 5% monthly growth link is their claim.

## Findings

- [learning] Spaced practice spread over days beats cramming: the spacing effect, the
  base idea of the drill schedule. ^f1
  > people tend to remember things more effectively if they use spaced repetition practice (short study periods spread out over time) as opposed to massed practice
- [learning] [ux/features] Each skill shows a strength meter: the estimated chance the
  learner can recall a random word from it; it decays over time until practised. ^f2
  > These meters represent the average probability that the student can, at any moment, correctly recall a random target word from the lessons in this skill
  > As time passes, strength meters continuously update and decay until the student practices.
- [learning] Practice sessions are ordinary lessons whose exercises are picked from the
  learner's weakest items, the ones due by the model. ^f3
  > Practice sessions are identical to lessons, except that the exercises are taken from those indexed with words (lexeme tags) due for practice according to student model
- [learning] [fun] A better review schedule raised daily engagement 12% in production. ^f4
  > HLR was able to improve Duolingo daily student engagement by 12% in an operational user study
- [learning] [ux/trust] Learners distrusted practice that did not target what they felt
  weak at; they practised only to keep the meter gold. ^f5
  > many students claimed that they would practice instead of learning new material “just to keep the tree gold,” but that practice sessions did not review what they thought they needed most
- [learning] [ux/trust] Items that decayed fast no matter how often practised frustrated
  learners; a simpler model fixed it and raised all three retention metrics. ^f6
  > active students pointed out that particular words or skills would decay rapidly, regardless of how often they practiced
  > All three retention metrics were significantly higher for the HLR -lex group.
- [learning] The model also learns which concepts are hard (shorter half-lives), so item
  difficulty comes from learner data, not from authors. ^f7
  > HLR can capture the inherent difficulty of concepts that are encoded in the feature set
- [learning] (inferred) For meio.lol Learn: a per-concept strength that decays, and a
  practice round drawn from the weakest concepts, is the drill half of a puzzle game;
  it needs a stored per-visitor history (browser storage is enough). ^f8
- [fun] Checked, not there: the paper does not cover streaks, XP or other game rewards. ^f9

## Read

- Abstract, introduction, section 2 (Duolingo), 3.3 (HLR), 4.3-4.4 (user experiments).

## Not read

- Section 4.1-4.2 model comparison tables; appendix on lexeme tags.
