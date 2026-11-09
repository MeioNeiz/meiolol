---
status: answered
priority: now
area: product
tags: [learning, ux/postgame, ux/trust, tools/paid]
description: What does post-game review show in League apps and in chess.com, Leetify and Stratz or Dotabuff, what do players praise, and what brings them back?
---
# What does post-game review show in League apps and in chess.com, Leetify and Stratz or Dotabuff, what do players praise, and what brings them back?

Feeds: docs/plan/site.md "Your games" (game review: moments, time frame, specifics); docs/plan/app.md APP11 (post game view); the production key application's product (game review)

## Answer

Review tools split three ways. chess.com walks the player through the game: a summary
(eval strip, each side's Accuracy, a count per move label, one coach line), then key
moves one at a time with a label icon on the piece, a best-move arrow, one sentence and
Retry (C1, C2). League tools mostly show a page, not a walk: award cards, mirrored lane
rows, a gold chart, and a per-game score (Mobalytics GPI, OP Score, Blitz gauges) (C5).
Since 2025 AI reviewers (OP.GG Premium Agent, Baron Buff, Loldosa, Mobalytics' AI
highlights) land on one format: a few key moments, then one thing to fix next game, and
that review is what they charge for (C8).

What works: praise as much as fault (chess.com added Great and eased Brilliant so good
moves get celebrated; players spend their free review on wins) (C3, C4); a headline
number tuned to feel fair and called "performance, not skill", openly noisy (C6); and
retrying a key moment rewarded with a number (C2). What fails: League per-game scores
are judged by their worst visible miss ("MVP Ornn 2/11/2", pros scoring below average)
and the vendors admit inaccuracy; one wrong tip makes players dismiss the whole system
(C9); a baseline not shown with the number confuses (C10); weakness names are blunt
badges or kind character words, never tied to a moment (C11); and the most-voiced chess
complaint is a coach that names the miss without the why (C7). Return hooks are progress
over time, sharing and friend ladders or streaks more than the single page (C12); the
paywall meters how many reviews and how much coach text, not the labels (C13).

## Claims

- C1: chess.com's review opens on a summary: eval strip, both players' Accuracy, a
  two-column count per move label with icon colours, a one-line coach verdict, Start
  Review. for: [[gothamchess-truth-game-review#^f1]], [[chesscom-game-review-help#^f1]], [[chesscom-game-review-app#^f1]]
- C2: Per move it shows the label icon on the moved piece, a best-move arrow, coloured
  coach arrows, one coach sentence with the eval; on a missed key move Show, Best and
  Retry, and a correct retry gives an adjusted accuracy. Next jumps between key moves.
  for: [[gothamchess-truth-game-review#^f3]], [[gothamchess-truth-game-review#^f4]], [[chesscom-review-arrows#^f2]], [[chesscom-game-review-app#^f4]], [[chesscom-game-review-app#^f5]], [[chesscom-game-review-app#^f6]], [[chesscom-new-game-review-2022#^f4]], [[chesscom-game-review-help#^f6]]
- C3: chess.com review is built to celebrate as much as correct: Great added and
  Brilliant eased so more good moves get praised; review pitched as reliving your best
  moves. for: [[chesscom-new-game-review-2022#^f1]], [[chesscom-new-game-review-2022#^f6]], [[chesscom-new-game-review-2022#^f7]], [[chesscom-skills#^f1]]
- C4: Players trust review when it praises them and spend their free review on wins.
  for: [[gothamchess-truth-game-review#^f10]], [[gothamchess-truth-game-review#^f11]]
- C5: League post-game pages lead with awards, mirrored lane rows and a gold chart, plus
  a per-game score (GPI, OP Score 0-10 with MVP and ACE, Blitz's 0-100 gauges); none
  walks the player through moments. for: [[mobalytics-match-ui#^f2]], [[mobalytics-match-ui#^f3]], [[leagueofgraphs-match-ui#^f3]], [[opgg-help-op-score#^f1]], [[blitz-match-ui#^f2]], [[leagueofgraphs-match-ui#^f10]]
- C6: The headline per-game number is tuned to feel fair and called performance, not
  skill: Accuracy rescaled to about 50-95, Leetify's rating shown as five words, IMP
  meters narrowed. for: [[chesscom-accuracy#^f3]], [[leetify-rating-2024#^f2]], [[leetify-rating-2024#^f7]], [[stratz-imp-is-back#^f3]], [[chesscom-game-rating#^f4]]
- C7: The top chess complaints: the coach names the miss but not why, labels assume
  perfect play and ignore the clock. for: [[gothamchess-truth-game-review#^f6]], [[gothamchess-truth-game-review#^f7]], [[gothamchess-truth-game-review#^f8]]
- C8: 2025-26 AI reviews share one format, key moments then one fix for next game, and
  are the paid part. for: [[opgg-membership#^f2]], [[baronbuff-home#^f2]], [[loldosa-topgg#^f2]], [[loldosa-topgg#^f8]], [[mobalytics-smart-highlights#^f2]]
- C9: League per-game scores are distrusted: players judge them by the worst visible
  miss, vendors call them beta or admit they can be wrong, and one wrong tip discredits
  the whole system; Leetify brought a stat-blend beta score to League in 2025, not its CS2
  win-probability one. for: [[mobalytics-letter-to-users#^f2]], [[mobalytics-letter-to-users#^f6]], [[opgg-help-op-score#^f4]], [[reddit-opgg-new-op-score#^f1]], [[reddit-mobalytics-valuable#^f1]], [[leetify-lol-rating#^f2]], [[leetify-lol-rating#^f5]]
- C10: An unstated baseline confuses (GPI's 0-100 explained as relative to own tier);
  Blitz shows a "vs" selector with its gauges. for: [[mobalytics-gpi-explained#^f2]], [[reddit-mobalytics-valuable#^f3]], [[blitz-match-ui#^f2]]
- C11: Weaknesses are named as blunt badges (Mobalytics, League of Graphs) or kind
  character words (OP.GG), never tied to a moment of the game. for: [[mobalytics-match-ui#^f9]], [[mobalytics-gpi-advice#^f6]], [[opgg-help-op-score-keywords#^f2]], [[leagueofgraphs-match-ui#^f8]]
- C12: Return hooks are progress over time, sharing, friend ladders and streaks more than
  the single game page. for: [[loldosa-topgg#^f4]], [[loldosa-topgg#^f5]], [[mobalytics-smart-highlights#^f3]], [[reddit-mobalytics-valuable#^f6]], [[leetify-improve-guide#^f2]]
- C13: Paywalls meter how many reviews and how much coach text (chess.com one full
  review a day free; Loldosa one a day then $3.99); labels and accuracy stay free;
  Dotabuff Plus sells more charts, not a verdict. for: [[chesscom-membership-levels#^f1]], [[chesscom-membership-levels#^f3]], [[loldosa-topgg#^f8]], [[dotabuff-plus#^f1]], [[dotabuff-plus#^f7]]
- C14 (inferred): For meiolol: a guided walk of the player's moments (summary, then key
  moments with what each cost and a better option where our data has one), praise as
  well as fault, the baseline printed with every number, no single per-game grade.
  from: C2, C3, C9, C10

## Disagreements

Praise vs honesty: chess.com and OP.GG flatter (C3, C11), Mobalytics' tough-love voice
does not, and STRATZ chose not to adjust IMP by hero for honesty
([[stratz-imp-is-back#^f5]]). No source measures which keeps players longer.

## Open

- Leetify Pro price and features (page did not load); its Post-Match Journal is a lead
- Reception of OP.GG's Premium AI review: none found; Blitz's gauge scoring undocumented
- STRATZ paid features unknown (match pages behind Steam login)
