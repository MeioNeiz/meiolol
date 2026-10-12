---
status: decided
decision: docs/concept.md
priority: soon
area: product
tags: [needs, learning, fun]
description: What do ranked and casual League players want from third-party tools that they don't get today?
---
# What do ranked and casual League players want from third-party tools that they don't get today?

Feeds: docs/concept.md persona runs (new player, climber, one-trick, casual with friends, coach)

## Answer

Players most want help reviewing their own games afterwards, shown as facts they interpret
themselves, not verdicts (C1). They see post-game analysis as fair and live in-game help as
unfair, and split on draft (C2). At low and mid elo, experience on a champion outweighs
counter-picking, so pick advice that ignores the player's pool misleads (C3). Stats sites say
what wins, not how; players stitch the how together from streamers and subreddits (C4), and
forget advice once the game starts (C10). Overwolf-free and ad-free is a selling point (C5).
Casual players and friend groups love fun, shareable personal stats (C6) and daily puzzles
(C7); casual modes are under-served (C8). Visibly wrong numbers break trust (C9).

All evidence is Reddit (B/C, vote counts as signals); no surveys or Riot player research.
Two of the most upvoted 2026 learning tools read game memory during replays, which 26.20
blocks: the demand is real, those methods are not.

## Claims

- C1: Players most want help reviewing their own finished games, shown as facts not verdicts. for: [[lol-wave-states-replay-tool#^f1]], [[lol-wave-states-replay-tool#^f5]], [[lol-overlays-ai-cheating#^f3]], [[lol-overlays-ai-cheating#^f4]]
- C2: Post-game analysis is accepted as fair, live in-game help rejected, draft help split. for: [[lol-overlays-ai-cheating#^f1]], [[lol-overlays-ai-cheating#^f3]], [[lol-overlays-ai-cheating#^f6]] against: [[lol-overlays-ai-cheating#^f5]]
- C3: At low and mid elo, champion experience matters more than counter-picking (<10k mastery ~44% vs 51.5%; counter gaps 2-4%). for: [[lol-mastery-analysis#^f1]], [[lol-mastery-analysis#^f2]], [[lol-mastery-analysis#^f3]], [[ss-dont-counterpick-unfamiliar#^f1]], [[ss-dont-counterpick-unfamiliar#^f5]]
- C4: Stats sites show what wins, not how; players stitch the how from OP.GG, mains subreddits and streamers. for: [[ss-dont-counterpick-unfamiliar#^f4]], [[ss-dont-counterpick-unfamiliar#^f6]], [[ss-streamers-by-champion#^f1]]
- C5: Being free of Overwolf, ads and bloat is a selling point in itself. for: [[lol-recorder-no-overwolf#^f2]], [[lol-recorder-no-overwolf#^f3]], [[lol-recorder-no-overwolf#^f5]], [[lol-overlays-ai-cheating#^f8]]
- C6: Fun, shareable personal stats (recaps, odd leaderboards) draw big audiences and friend groups use them together. for: [[lol-yearin-wrapped#^f2]], [[lol-yearin-wrapped#^f3]], [[lol-yearin-wrapped#^f4]], [[lol-ranked-stats-tab#^f2]], [[lol-ranked-stats-tab#^f4]]
- C7: Daily League puzzles keep an audience; players want shared daily answers plus an archive. for: [[lol-loldle-launch#^f2]], [[lol-loldle-launch#^f3]], [[lol-loldle-launch#^f4]]
- C8: Casual-mode players lack their own stats and augment documentation; split on win rates. for: [[aram-mayhem-not-tracked#^f3]], [[aram-mayhem-not-tracked#^f5]], [[aram-mayhem-informative-ui#^f3]] against: [[aram-mayhem-not-tracked#^f1]]
- C9: Numbers players can see are wrong break trust in a stats tool. for: [[lol-yearin-wrapped#^f7]], [[lol-yearin-wrapped#^f8]]
- C10: Players forget guide advice once a game starts: the gap is applying, not reading. for: [[ss-tips-in-game#^f1]]
- C11: Coaches and casters want tools to explain play visually on replays. for: [[lol-replay-drawing-tool#^f1]], [[lol-replay-drawing-tool#^f3]], [[lol-wave-states-replay-tool#^f9]]

## Disagreements

Draft help: the overlays thread wants all live help banned, while iTero's users defend
draft tools ([[lol-overlays-ai-cheating#^f5]]). Win-rate tracking in casual modes: some want
it, some want fun without it.

## Open

- No surveys or Riot/Mobalytics player research; one-tricks and coaches lack a direct source.
- Does the API serve special modes like ARAM Mayhem? ([[aram-mayhem-not-tracked#^f6]] says
  not; check queue ids in match-v5.)
