---
title: 'Chess.com Help: How does Game Review work?'
url: https://support.chess.com/en/articles/8584089-how-does-game-review-work
kind: docs
commit:
for: [postgame-review-compare]
looked: 2026-11-06
depth: docs (whole article and its collapsed FAQ answers)
relevance: high
grade: A/fair
description: Chess.com help article (Sep 2026) on the web Game Review flow: Highlights screen, ten move labels, Coach with voice, Next to key moves, Retry and Show, settings, free limit FAQ
---
# Chess.com Help: How does Game Review work?

Why: our game page borrows from Game Review; what is the flow screen by screen, and what
is free.

## Assessment

- Evidence: A. The vendor's own help page for a feature used by millions; updated 25 Sep
  2026. FAQ answers were collapsed on the page and taken from the rendered DOM (appended
  to the raw under "FAQ answers").
- Reasoning: fair. Describes what each piece is, rarely why.
- Interests: vendor; the FAQ frames the paywall.
- Weigh: trust for what is on screen; screenshots in the article are not in the raw.

## Findings

- [ux/postgame] [tools/phase] Entry point: a green Game Review button on the game over
  pop-up and in the side panel, straight after the game. ^f1
  > After finishing a game on Chess.com, you’ll see a green 'Game Review' button on the game over pop-up message as well as on the right side of the screen.
- [ux/postgame] First screen is Highlights: a game graph of who was ahead after each
  move, a one-line Coach summary of how the game went, and Accuracy 0 to 100. ^f2
  > **Game Graph:** This graph **indicates who had the advantage at each stage of the game.**
  > The Coach provides a brief, one-line summary of how the game unfolded.
  > This score, ranging from 0 to 100, **represents how accurately you played according to the engine’s evaluations.**
- [ux/postgame] Ten move labels, each with an icon and a one-line plain gloss: Brilliant,
  Great, Best, Excellent, Good, Book, Inaccuracy, Mistake, Miss, Blunder. ^f3
  > A move that missed a tactical opportunity or a chance to punish the opponent
  > A very bad move that also loses material or the game
  > A move that altered the course of the game!
- [ux/postgame] Miss is a label for the chance you did not take (missed tactic, failed to
  punish), separate from moves that made your position worse. ^f4
  > A move that missed a tactical opportunity or a chance to punish the opponent
- [ux/postgame] [learning] A Coach character (choosable avatar) narrates each move in a
  speech bubble, and can read it aloud; the text updates as you step through moves. ^f5
  > you can **have the Coach read the game review aloud**, letting you focus entirely on the board
  > The coach's feedback will be updated with each move.
- [ux/postgame] Two ways through: step move by move with arrows or keys, or press Next
  to jump between key moves only. ^f6
  > Alternatively, **click 'Next' to review the key moves in the game.**
- [ux/postgame] [learning] The first key move is usually the last book move; its bubble
  names the opening, how often you have played it and your results, and suggests a
  course. ^f7
  > **The first key move is usually the last book move.**
  > The **number of times you have played that opening** and the results achieved.
- [ux/postgame] [learning] At a key move that could have been better: buttons in the
  bubble show the idea (Show Fork, Show Lost Piece, Show Checkmate, Show Idea), Best
  shows the strongest move, Retry replays the position for you to find it; a correct
  retry shows the score you would have had, a wrong one gets Coach feedback. ^f8
  > If a key move could have been better, you’ll have the chance to 'Retry' the move.
  > You'll find options like 'Show Fork,' 'Show Lost Piece,' 'Show Checkmate,' 'Show Idea,' and more.
  > If you choose incorrectly, the Coach will provide feedback on your selected move.
- [ux/postgame] Settings let the player trim the screen: arrows (best move, Coach
  visuals, both, none), key moves for you, opponent or both, label icons on the board,
  Coach avatar, course suggestions, Skills, time spent per move. ^f9
  > Choose whether Game Review highlights key moves for you, your opponent, or both players.
  > Show or hide how much time was spent on each move during timed games.
- [tools/paid] Free members keep Accuracy, labels and Self Analysis; unlimited Game
  Review needs Premium; deeper engine and Cloud Analysis are Diamond. ^f10
  > Free members can still use Game Review to see key insights like Accuracy, move classifications, and Self Analysis. However, unlimited Game Review and some advanced analysis features require a Premium membership.
- [tools/paid] Reopening a game already reviewed does not use up the daily free review. ^f11
  > Viewing a previously generated Game Review doesn't count against your daily free Game Review limit.
- [ux/trust] The game over screen's quick labels can differ from the full review's
  (a Brilliant can vanish), and labels can differ by device or engine strength. ^f12
  > The summary shown immediately after your game uses a faster analysis than the full Game Review.
  > For example, a move initially marked as Brilliant may later be classified differently after the full review.
- [ux/trust] Accuracy is framed as not your rating nor a measure of strength. ^f13
  > It isn't the same as your Chess.com rating and shouldn't be viewed as an overall measure of your playing strength.
- [ux/postgame] Game Review is the guided path (accuracy, labels, key moments, Coach,
  retries); Self Analysis is the free-roam engine board for the curious. ^f14
  > Game Review provides a guided breakdown of your game, including:
  > Self Analysis lets you explore the game on your own using engine evaluations, suggested lines, arrows, and other analysis tools.
- [ux/postgame] Checked, not there: the article does not list per-label counts or Game
  Rating on Highlights in text (Game Rating appears only in the FAQ, see
  [[chesscom-game-rating]]). ^f15

## Read

- Whole article, settings table and all FAQ answers.

## Not read

- Linked: Cloud Analysis, analysis depth, why classifications change (11845102).
