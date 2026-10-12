---
title: I made a tool that draws wave states into your replay (r/leagueoflegends, Aug 2026)
url: https://old.reddit.com/r/leagueoflegends/comments/1vlf5k0/i_made_a_tool_that_draws_wave_states_into_your/
kind: thread
commit:
for: [player-tool-needs]
looked: 2026-10-11
depth: docs (post and all loaded comments)
relevance: high
grade: B/fair
description: 6.1k-upvote launch post for middiff.gg, a replay review tool marking wave states, missed CS and blunders; comments are a wishlist for learning tools
---
# I made a tool that draws wave states into your replay (r/leagueoflegends, Aug 2026)

Why: what learning features excite ranked players, and how they want feedback framed.

## Assessment

- Evidence: B. 6.1k upvotes, 97% upvoted, ~240 comments, Aug 2026 (current); most
  upvoted comments are jokes, but dozens of concrete feature requests from players.
- Reasoning: fair. Players argue about what an automated reviewer can judge.
- Interests: the author builds the tool (middiff.gg, linked to a broadcast telestrator).
- Weigh: enthusiasm for a demo video, not usage. Commenters say it relies on memory
  reading of replays, which Riot blocked from 26.20 ([[riot-memory-access-removed]]), so
  the approach may be dead; the demand it shows is what matters.

## Findings

- [learning] [needs] Pitch: replay review that marks where you fumbled (missed CS and its
  gold, skillshots tanked, dying with summoners up), framed as a habit builder: one focus
  per game. ^f1
  > It goes through your game and marks the moments where you fumbled, then shows them in the replay.
  > The idea is to kind of build a habit builder and breaker. It reminds you what to focus on in the next game
- [market] Reception: 6.1k upvotes, 97% upvoted, ~240 comments (counts from the capture). ^f2
  > Edit: dang, this blew up haha, currently in the gym
- [learning] [needs] Players want missed-CS gold shown and say Riot never added it. ^f3
  > Now THIS is something I've wanted in this game for a LOOOOONG time, and I got NO idea why Riot hasnt implemented it.
- [learning] [needs] Feature requests: warding habits, death analysis, recall timing, gold
  spending, summoner spell efficiency, jungle clears. ^f4
  > I'd love to see warding habits tracked
  > Death analysis (e.g. "you've died X times too deep into their half with no vision"
- [learning] [ux/trust] Several players warn against a tool that says what you should have done;
  they want facts to judge for themselves. Author agrees: visualise, don't judge. ^f5
  > Just be careful not to dip into ‘here’s what you should’ve done’ territory because an automated tool won’t be able to reliably say that.
  > stick with the facts. let the player figure out the why without the tool trying to suggest meaning.
- [learning] [data] Players see per-minute Riot API timeline data as too coarse for real
  game review; the author calls API plus AI coaching guessing. ^f6
  > most tools rely on the riot api that gives them data points once a minute, then feed that in some ai to get some "feedback" on your gameplay. We think that's a shit approach
  > doesn't exist in existing tools due to the snapshot frequency
- [learning] Comparison players reach for is chess.com's game review. ^f7
  > Nice, it feels like those reviews on
- [policy] (inferred) Built on replay memory reading per a commenter; not confirmed by the
  author ("can't go into more detail"). ^f8
  > it's 100% memory reading. there's no other way to get minion's positions.
- [learning] Amateur coaches see it as a VOD review aid. ^f9
  > I used to "coach" a team of silver players for a league they were in and something like this would have been a really nice visual indicator on replays during VoD review.

## Read

- Post and every comment loaded in the redlib capture (collapsed "more replies" not opened)

## Not read

- Collapsed reply chains; middiff.gg site itself
