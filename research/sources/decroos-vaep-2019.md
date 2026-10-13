---
title: 'Decroos et al. 2019: Actions speak louder than goals, valuing player actions in soccer (VAEP)'
url: https://arxiv.org/pdf/1802.07127
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (sections 3-4, 6.1, 7)
relevance: high
grade: A/fair
description: KU Leuven KDD 2019 paper behind socceraction; values every on-ball action as the change in short-horizon scoring and conceding probabilities, with scoreline as context
---
# Decroos et al. 2019: Actions speak louder than goals, valuing player actions in soccer (VAEP)

Why: the canonical action-value framework (VAEP), widely used in football analytics; its
choices (short horizon labels, separate offence and defence, scoreline as context) are the
template for valuing a LoL event.

## Assessment

- Evidence: A. KDD 2019, the reference framework in football action valuation, open
  source (socceraction), used by clubs and copied across sports; 11,565 games.
- Reasoning: fair. Explains the label horizon and context window as tuned choices; names
  limitations (on-ball only, league and team strength); no causal claim, no intervals.
- Interests: academic (with SciSports ties).
- Weigh: trust the recipe; note it values the action as observed, so strong teams make
  more valuable actions (they say so), the same "already ahead" leak in another form.

## Findings

- [method] An action's value is the change it makes to the probability of scoring soon
  plus minus the change to the probability of conceding soon (offence plus defence).
  Section 3.1, eq. 3 ^f1
  > Valuing an action for a team then requires assessing the change in probability for both scoring and conceding as a result of action ai moving the game from state Si−1 to state Si .
  > The total VAEP value of an action is the sum of that action’s offensive value and defensive value.
- [method] Scoring and conceding are kept separate because their effects can be
  asymmetric and context dependent. Section 3.1 ^f2
  > We treat the effect of an action on scoring and conceding separately as these effects may be asymmetric in nature and context dependent.
- [method] Labels use a short horizon: did the team score (or concede) within the next
  k = 10 actions, not the match result. Section 4.1 ^f3
  > if the team possessing the ball after action ai scored a goal in the subsequent k actions
  > In this paper, we chose k = 10 based on domain knowledge and preliminary experiments.
- [method] The state is approximated by the last three actions plus scoreline context
  (goals for, against, difference), because teams change play with the score. Section 4.2 ^f4
  > we only consider the previous three actions [ai−2 , ai−1 , ai ].
  > We include these features because teams often adapt their playing style to the current scoreline
- [method] [stats] Probabilities must be well calibrated; gradient boosted trees
  (CatBoost) won, Brier and AUC used for evaluation. Section 4, 6.1 ^f5
  > estimates should be well-calibrated [22]. We use CatBoost [26]
  > CatBoost performs best in all cases, with XGBoost a close second.
- [method] Values carry team and league strength: valuable actions are easier in weaker
  leagues and in top clubs with strong teammates. Section 7 ^f6
  > it is generally easier to perform valuable actions in a top club with strong teammates, than in a mid-table club with weaker teammates.
- [data] 11,565 games of Wyscout event data from seven European top divisions. Section 5 ^f7
  > We apply the VAEP framework to 11565 games played in the 2012/2013
- [stats] Checked, not there: no confidence intervals on action values and no causal
  design; values are prediction deltas. ^f8
- [method] (inferred) For LoL the short-horizon idea maps to "next tower or inhibitor
  within N minutes" or "gold lead in 5 minutes" as well as the final win, which is far
  less noisy per event than win/loss and gives a gold equivalent directly. ^f9
- [method] (inferred) Their scoreline features are our gold, kill and tower differences
  at the event minute; the "strong teammates" leak is our pre-game strength (draft
  win chance, average rank), which belongs in the state too. ^f10

## Read

- Sections 3 (framework), 4 (labels, features), 6.1 (model choice), 7 (challenges)

## Not read

- Section 5 player ratings and case studies (football specific)
