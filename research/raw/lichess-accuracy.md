# Lichess Accuracy metric • lichess.org

<https://lichess.org/page/accuracy>

[

lichess.org

](https://lichess.org/)

[Play](https://lichess.org/)

[Create lobby game](https://lichess.org/?any#hook)[Arena tournaments](https://lichess.org/tournament)[Swiss tournaments](https://lichess.org/swiss)[Simultaneous exhibitions](https://lichess.org/simul)

[Puzzles](https://lichess.org/training)

[Puzzles](https://lichess.org/training)[Puzzle Themes](https://lichess.org/training/themes)[Puzzle Dashboard](https://lichess.org/training/dashboard/30)[Puzzle Streak](https://lichess.org/streak)[Puzzle Storm](https://lichess.org/storm)[Puzzle Racer](https://lichess.org/racer)

[Learn](https://lichess.org/learn)

[Chess basics](https://lichess.org/learn)[Practice](https://lichess.org/practice)[Coordinates](https://lichess.org/training/coordinate)[Study](https://lichess.org/study)[Coaches](https://lichess.org/coach)

[Watch](https://lichess.org/broadcast)

[Broadcasts](https://lichess.org/broadcast)[Lichess TV](https://lichess.org/tv)[Current games](https://lichess.org/games)[Streamers](https://lichess.org/streamer)[Video library](https://lichess.org/video)

[Community](https://lichess.org/player)

[Players](https://lichess.org/player)[Teams](https://lichess.org/team)[Forum](https://lichess.org/forum)[Blog](https://lichess.org/blog/community)

[Tools](https://lichess.org/analysis)

[Analysis board](https://lichess.org/analysis)[Openings](https://lichess.org/opening)[Board editor](https://lichess.org/editor)[Import game](https://lichess.org/paste)[Advanced search](https://lichess.org/games/search)

[Donate](https://lichess.org/patron)

[Sign in](https://lichess.org/login?referrer=/page/accuracy)[Register](https://lichess.org/signup)

# Lichess Accuracy metric

The Accuracy metric indicates **how well you play** - according to [Stockfish](https://stockfishchess.org/), the strongest chess engine.

An accuracy of 0% means you only played terrible moves; 100% means you played all the preferred Stockfish moves.

## What accuracy percentage is considered "good"?

It is flawed to compare accuracy to a numerical grade you would get on a test. In more complex positions it is harder to find the best moves, so your accuracy might drop accordingly. Conversely, in lopsided positions most moves don't change the winning chances meaningfully, so the accuracy score may be high even if your conversion of the position wasn't clinical. While Stockfish can assess the soundness of our moves, it can't tell us how difficult it is to find them.

## My opponent had an accuracy of 96%. Were they cheating?

A very high accuracy percentage isn't necessarily indicative of superhuman, "GM-level" play. If you blunder early on or play consistently subpar moves, your opponent will have greater chances to capitalize on your mistakes. This can lead to a very high accuracy. That said, if you suspect your opponent was cheating, please use [the report form](https://lichess.org/report).

## Do higher-rated players have a higher accuracy score?

While there is some correlation between the players' ratings and their accuracy, it is not straightforward. A more skilled player tends to play more principled, theory-heavy openings and put more tactical pressure on the opponent. This can create more complicated positions and provoke inaccurate play on both sides. Moreover, lower-rated players are often more reluctant to resign. As we discussed above, protracted lopsided endgames can increase the accuracy score.

## How is move accuracy computed?

**Accuracy%** represents how much you deviated from the best moves, i.e. how much your winning chances decreased with each move you made. Indeed in chess, from a chess engine standpoint, good moves don't exist! You can't increase your winning chances by playing a move, only reduce them if you make a mistake. Because if you have a good move to play, then it means the position was already good for you before you played it.

### First, compute **Win%**

**Win%** represents your chances of winning the game from a given position. It's based on a Stockfish evaluation in centipawns. We then apply an equation to make it more intelligible:

```
Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1)
```

It looks like this:

_Win% by Stockfish centipawn evaluation_

Here's a [link to the graphed equation](https://www.geogebra.org/graphing/dvwthwyb), and another [the Lichess source code](https://github.com/lichess-org/scalachess/blob/master/core/src/main/scala/eval.scala#L66) implementing it.

The equation is based on [real game data](https://github.com/lichess-org/lila/pull/11148). Note that we might update it in the future, to better map centipawns to win chances.

### Then, compute **Accuracy%**

Now that we have a **Win%** number for each position, we can compute the accuracy of a move by comparing the **Win% before and after the move**. Here's the equation:

```
Accuracy% = 103.1668 * exp(-0.04354 * (winPercentBefore - winPercentAfter)) - 3.1669
```

It looks like this:

_Accuracy% by difference of Win% from a position to the next one_

This gives you the **accuracy of a move**. Here's a [link to the graphed equation](https://www.geogebra.org/graphing/swv4epxf), and another [the Lichess source code](https://github.com/lichess-org/lila/blob/master/modules/analyse/src/main/AccuracyPercent.scala#L47-L55) implementing it.

Note that we might change this equation in the future, to better map **Win%** to move accuracy (**Accuracy%**).

## What about game accuracy?

The accuracy of a game is not necessarily the same as its average move accuracy. The simple move average can be misleading if one side completely dominates or makes a one-move blunder in a completely equal game. So the accuracy of a game has been tweaked and tuned to better match player expectations of what the accuracy should _feel_ like. Here's how it is currently calculated:

1.  Divide the game into sliding windows. The window size is determined by the length of the game.
2.  Compute the volatility of each window by calculating its standard deviation. In this case we use the standard deviation of the **Win%** of each move in the window.
3.  Compute the **[volatility weighted mean](https://en.wikipedia.org/wiki/Weighted_arithmetic_mean "https://en.wikipedia.org/wiki/Weighted_arithmetic_mean")** of the move accuracies using the volatility as weights for each move.
4.  Compute the **[harmonic mean](https://en.wikipedia.org/wiki/Harmonic_mean "https://en.wikipedia.org/wiki/Harmonic_mean")** of the move accuracies.
5.  Take the **average** of the **volatility weighted mean** and the **harmonic mean** to yield the final **game accuracy.**

Here is the [source code](https://github.com/lichess-org/lila/blob/2e653ad1e2b9fad31b4a092394019ef8fafdedb8/modules/analyse/src/main/AccuracyPercent.scala#L81-L112 "https://github.com/lichess-org/lila/blob/2e653ad1e2b9fad31b4a092394019ef8fafdedb8/modules/analyse/src/main/AccuracyPercent.scala#L81-L112") implementing it.

## Why not just use Stockfish centipawns?

Centipawns are great for developing chess engines, which is their main use. But not so much for human comprehension.

A major issue with centipawns is that they're dependent of the position evaluation. For example, losing 300 centipawns in an equal position is a major blunder. But losing 300 centipawns when the game is already won or lost makes almost no difference and is largely irrelevant.

Thus, _"300 centipawns"_ has no meaning on its own for a human. That's the problem we aim to solve with **Win%** and **Accuracy%** . These new values are derived from centipawns, but they try to be independent of the position evaluation. 30 **Accuracy%** should mean the same thing whether the position is equal or winning/losing.

Also see [Centipawns Suck](https://zwischenzug.substack.com/p/centipawns-suck) by Nate Solon.

## Where are **Win%** and **Accuracy%** used?

-   Lichess has been using these for years, to identify inaccuracies/mistakes/blunders in [game analysis](https://lichess.org/GBGpiydB/black).
-   Winning chances is the underlying metric used when displaying fluctuations in all of our evaluation bars. It is also the metric used when plotting all of our computer evaluation graphs.
-   Winning chances are also used when running our [puzzle generator](https://github.com/ornicar/lichess-puzzler/blob/585cc33128d74a773f0b6df3d8d146f7a884d6a8/generator/util.py#L44 "https://github.com/ornicar/lichess-puzzler/blob/585cc33128d74a773f0b6df3d8d146f7a884d6a8/generator/util.py#L44") as well in a client-side [puzzle reporter](https://github.com/lichess-org/lila/blob/f72bd014970f5ad12055cdfa2c9ce44b72368a42/ui/lib/src/ceval/winningChances.ts#L37-L56 "https://github.com/lichess-org/lila/blob/f72bd014970f5ad12055cdfa2c9ce44b72368a42/ui/lib/src/ceval/winningChances.ts#L37-L56") to verify that a puzzle does not have multiple "_winning"_ solutions.

They're also visible and usable in Lichess Insights. Examples:

-   [Accuracy by opening family during the opening and middlegame](https://lichess.org/insights/thibault/accuracy/openingFamily/phase:1,2) (averaged with harmonic mean)
-   [Tactical Awareness by game phase](https://lichess.org/insights/thibault/awareness/phase) (how often you spot opponent mistakes)

They may become visible in other parts of the site in the future.

## I analyzed my game on both Lichess and Chess.com and got different accuracy scores. How is that possible?

There is no universally accepted way to compute accuracy percentages. Different websites use different formulas, engines and analysis depths. On Lichess, the server-side analysis is carried out by the latest Stockfish NNUE. We use games among 2300-rated players as a benchmark to determine empirical winning chances.
