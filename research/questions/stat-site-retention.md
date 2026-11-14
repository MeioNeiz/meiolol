---
status: answered
priority: soon
area: product
tags: [fun, market, needs, policy, tools/accounts]
description: What brings League players back to a stat site week after week for scouting their own games, which return features have evidence they work, and which fit Riot policy?
---
# What brings League players back to a stat site week after week for scouting their own games, which return features have evidence they work, and which fit Riot policy?

Feeds: docs/plan/site.md "Bringing players back" (return features for Your games, Daily Draft, Learn, Pool)

Builds on [[competitor-first-visit-returning]] (what rivals offer returning users) and
[[postgame-review-compare]] (C12: return hooks are progress, sharing, streaks).

## Answer

Rivals bring players back mostly through paid, account-based loops: OP.GG favourites with
game-start alerts, U.GG's paid Discord squad bot, Mobalytics Plus progress tracking, plus
the last-20-games-against-the-season block on OP.GG profiles (C1). None publishes what
these do to retention. The measured evidence comes from outside League: self-tracking and
health-app research ties return use to self-monitoring with feedback, goals, prompts,
rewards and social support (C2), and players review slow-moving personal data weekly
rather than daily (C3). Improvement-minded League players build the missing piece by
hand: a per-game "what to work on" note and per-matchup notes (C4).

What works, with numbers: reminders lift return visits when each one is fresh and about
the user's own activity, and wear out when repeated (C5); sending fewer messages to core
users loses nothing, more to lapsing users brings them back (C6). Streaks work when one
small action keeps them and misses are forgiven (C7); a broken streak is a quit point and
"get back on track" messages don't help (C8). Year recaps get reach and Riot backs them:
Riot emailed its own 2024 recap and handed its 2025 recap to the fan site YearIn.LoL on
Riot ID lookup (C9); trust breaks on visible wrong counts. No source measures a weekly
recap's effect on return visits in games (C3 is self-tracking, not games).

Policy: Riot's stated line is "play first, then analyse and reflect later" and it names
stat tracking as a good use (C10); everything ranked here is post-game. Limits: no MMR
estimates; until the production key nothing public or advertised, so shares, public
ladders and messages to strangers wait (C11). No Riot rule found on emailing a player
about their own finished games; the block is ours: accounts.md stores no email.

Ranked for meiolol (C12): RT1 "since you were last here": new games, then a weekly
roll-up on Your games (replaces site.md RV2: lane gold at 14, deaths, win chance lows
over 10+ games); RT2 season and year review by December; RT3 one focus a week from the
player's numbers; RT4 forgiving streaks and weekly marks for Daily and Learn; RT5 Squads
ladder by who improved most; RT6 opt-in weekly reminder (web push or, if Jacob allows
email, a digest).

## Claims

- C1: Rivals' return hooks for your own games are favourites with alerts, a paid squad
  bot, paid progress tracking and recent-vs-season blocks, with no published retention
  effect. for: [[opgg-membership#^f4]], [[ugg-plus#^f2]], [[mobalytics-plus#^f2]], [[opgg-profile-ui#^f5]], [[porofessor-home#^f2]]
- C2: Goal setting, self-monitoring, feedback, prompts, rewards and social support go
  with engagement in self-improvement apps (associational). for: [[milne-ives-2023-bct-engagement#^f1]], [[milne-ives-2023-bct-engagement#^f4]], [[eugeneyan-push#^f3]]
- C3: People review slow personal data weekly or monthly, few daily; forgetting turns
  into quitting; resuming after a lapse is an open design problem. for: [[epstein-2015-lived-informatics#^f3]], [[epstein-2015-lived-informatics#^f2]], [[epstein-2015-lived-informatics#^f5]]
- C4: Improvement-minded players keep per-game and per-matchup notes by hand and ask for
  recent-vs-earlier comparisons. for: [[reddit-ss-tracking-spreadsheet#^f1]], [[reddit-ss-tracking-spreadsheet#^f4]], [[reddit-mobalytics-valuable#^f6]]
- C5: Reminders lift return visits when fresh and about the user's own activity, and
  wear out when repeated. for: [[duolingo-notification-bandit#^f1]], [[duolingo-notification-bandit#^f2]], [[eugeneyan-push#^f2]], [[eugeneyan-push#^f6]]
- C6: Unwelcome messages lose the channel; fewer to core users costs nothing, more to
  marginal users brings them back. for: [[eugeneyan-push#^f1]], [[eugeneyan-push#^f4]], [[eugeneyan-push#^f5]]
- C7: Streaks retain best with a low bar (one action) and forgiven misses, goals kept
  apart. for: [[duolingo-improving-streak#^f2]], [[duolingo-improving-streak#^f3]], [[duolingo-streaks#^f4]]
- C8: A broken streak often ends the activity, and failure-pointing nudges don't bring
  people back. for: [[barasch-broken-streaks#^f1]], [[barasch-broken-streaks#^f2]], [[barasch-broken-streaks#^f3]]
- C9: Riot backs yearly recaps: its own 2024 email, the 2025 one via YearIn.LoL on Riot ID
  lookup; players received YearIn.LoL well and dispute wrong counts. for: [[esportsgg-2025-lol-recap#^f1]], [[esportsgg-2024-lol-recall#^f1]], [[lol-yearin-wrapped#^f2]], [[lol-yearin-wrapped#^f8]], [[riot-rift-rewind-winners#^f3]]
- C10: Riot wants post-game reflection and names stat tracking as a good use. for: [[riot-support-third-party-apps#^f3]], [[riot-support-third-party-apps#^f4]], [[riot-rift-rewind-2025#^f1]]
- C11: Limits: no unfair advantage or MMR calculators; personal keys can't serve the
  public; no Riot consent rule for League found. for: [[riot-policies-general#^f7]], [[riot-docs-portal#^f8]], [[riot-policies-general#^f11]]
- C12 (inferred): For meiolol, in order: RT1 weekly "since you were last here" roll-up,
  RT2 season and year review, RT3 one weekly focus, RT4 forgiving streaks, RT5 Squads
  improvement ladder, RT6 opt-in reminder. from: C2, C3, C4, C5, C7, C8, C9, C10, C11

## Options

| Feature | Claims for | Claims against | Would change if |
| --- | --- | --- | --- |
| RT1 since last visit, weekly roll-up (folds site.md RV2) | C2, C3, C4, C10 | none found | players open it daily, not weekly |
| RT2 season and year review, card shared after the key | C9, C10 | C9 (wrong counts hurt); personal-key fetch cost | Riot picks another partner or ships its own in client |
| RT3 one focus a week, picked from own numbers | C2, C4, C7 | none found | focus goals go unused (track picks) |
| RT4 streaks: one action, forgiven, weekly marks | C7, C8 | C8 (a break still loses some) | our Daily retention data says otherwise |
| RT5 Squads ladder by most improved | C2 (social support), C1 (rivals sell it) | needs opt-in and the key to be public | Riot requires RSO opt-in for League |
| RT6 opt-in weekly reminder | C3, C5, C6 | C6 (lost channel); accounts.md "No email" | Jacob allows email, or web push proves enough |

## Disagreements

Praise and streak pressure: Duolingo reports streaks raise retention (C7) while Barasch's
field data shows broken streaks end the activity (C8). Both fit a forgiving design;
neither measures a weekly cadence. Spotify Wrapped is often credited with retention, but
only reach and download spikes are published (the Wrapped search found no causal source).

## Open

- No game stat site has published a retention effect for any return feature; our own
  Daily and Learn day marks could measure RT4 (api.db daily_answers has no sender, so only
  totals per day)
- App-store reviews of Blitz, Mobalytics, Porofessor on returning use not read
- Leetify yearly Recap and a Strava recap critic queued as leads
- Silverman and Barasch 2023 (JCR) read through the university article, not the paper
