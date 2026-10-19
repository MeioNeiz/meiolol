---
status: answered
priority: now
area: ui
tags: [ux, ux/layout, ux/uncertainty, ux/trust, ux/charts, ux/colour, ux/features]
description: What the site leads with and how it shows numbers, spread and thin data, for players and for Riot's production key reviewers
---
# What should meiolol's site show first and how should it present numbers so players and Riot reviewers trust and use it?

Feeds: docs/backlog.md "Site build and deploy", docs/plan/site.md "Before the production review"; the UI
pass order (Your games example, landing page, matchup pages, champion pages, nav,
Squads)

## Answer

Two readers, one page order. Riot's reviewers reject product URLs that are broken,
blank or unclear and want a working site showing the whole flow, with screenshots
rather than demo logins (C1); DevRel judging rewards polish, clear presentation, a
written method and novelty over another stats site (C2). Players want facts they can
judge for themselves, not verdicts (C3), and the one thing no big site shows is how a
matchup unfolds minute by minute: they reduce the timeline to a single number such as
GD@15 (C4), while "wins lane" and "wins game" disagree per matchup (C5). So the site
should lead with a matchup curve and a worked Your games example a reviewer can open
without logging in, with the method one click away (C15, C17).

On numbers: readers confuse spread with uncertainty of the mean and misread error bars,
so every chart says which it shows and gives n (C6, C16). Thin matchups are the main
trust risk: visible errors break trust (C8) and a 59% on 120 games is the classic
misleading number (C7). Rivals either hide matchups below 100 games or shrink them
towards a baseline (C7); meiolol already shrinks (curve-statistics-method), so the
choice left is presentation: mark thin data visibly and never sort it to the top
(C16). At low and mid ranks familiarity beats counter-picking (C13), which argues
against "hardest counter first" framing. Smaller points: no Overwolf, ads or bloat is
itself a selling point (C10); daily puzzles keep people when there is a shared daily
answer, an archive and shareable results, and Riot values social, shareable features
(C11, C12); a colour-blind mode is something players ask for (C9), so red to green
win-rate colours should change (C18, weakly supported).

## Claims

- C1: Riot rejects production apps whose URL is blank, broken or unclear, and wants a functioning site showing the full flow; screenshots or video can show it, demo credentials are typically not used. for: [[gh-devrel-1139#^f2]], [[gh-devrel-1139#^f5]], [[gh-devrel-1139#^f6]], [[riot-faqs#^f1]], [[riot-faqs#^f7]], [[riot-faqs#^f11]]
- C2: Riot DevRel judging weighs polish, clarity of presentation, documentation or a method write-up, and novelty beyond op.gg-style stats tools. for: [[riot-api-challenge-2018#^f5]], [[riot-lor-dev-challenge#^f4]], [[riot-lor-dev-challenge#^f5]], [[riot-rift-rewind-2025#^f4]], [[riot-rift-rewind-2025#^f7]]
- C3: Players want facts to judge for themselves, not a tool saying what they should have done; stats sites are accepted when they leave conclusions to the player. for: [[lol-wave-states-replay-tool#^f5]], [[lol-overlays-ai-cheating#^f9]], [[draftgap#^f6]]
- C4: Big sites reduce a matchup's timeline to one snapshot (GD@15) and none shows a per-minute matchup curve or how the lane plays out. for: [[ugg-darius-counter#^f1]], [[ugg-darius-counter#^f5]], [[opgg-darius-counters#^f7]], [[lolalytics-darius-vs-garen#^f7]], [[leagueofgraphs-darius-stats#^f8]], [[overwolf-porofessor#^f7]]
- C5: "Wins lane" and "wins game" rank a champion's matchups differently (U.GG's win-rate and GD@15 lists disagree). for: [[ugg-darius-counter#^f2]], [[ugg-darius-counter#^f4]]
- C6: Spread (s.d., percentiles) and uncertainty of the mean are different things that readers confuse; only 22% judged error-bar separation within a factor of 2; state which is shown. for: [[krzywinski-altman-error-bars#^f1]], [[krzywinski-altman-error-bars#^f2]], [[krzywinski-altman-error-bars#^f5]]
- C7: Thin matchups mislead (59% on 120 games should not be shown, per a Riot analyst); LoLalytics hides matchups under 100 games, DraftGap shrinks them with pseudo-games towards an additive baseline. for: [[riot-august-ugg-sample-size#^f3]], [[lolalytics-counters-threshold#^f1]], [[draftgap#^f8]], [[draftgap#^f10]]
- C8: Numbers players can see are wrong break trust in a stats tool. for: [[lol-yearin-wrapped#^f8]], [[riot-august-ugg-sample-size#^f3]]
- C9: A popular daily League game added a colour-blind mode after player feedback. for: [[lol-loldle-launch#^f7]]
- C10: Being free of Overwolf, ads and bloat decides tool choice for some players and stands out. for: [[lol-recorder-no-overwolf#^f3]], [[lol-recorder-no-overwolf#^f5]], [[lol-overlays-ai-cheating#^f8]]
- C11: Daily puzzle players want a shared once-a-day answer plus an archive, and share results Wordle style with friends; friends look at recap stats together. for: [[lol-loldle-launch#^f4]], [[lol-loldle-launch#^f5]], [[lol-yearin-wrapped#^f3]], [[lol-yearin-wrapped#^f4]]
- C12: Riot values social and shareable features, and a draft-guessing game got a production key soon after a traffic spike. for: [[riot-api-challenge-2018#^f2]], [[riot-rift-rewind-2025#^f3]], [[reddit-aramguessr-update#^f2]], [[reddit-aramguessr-update#^f3]]
- C13: At low and mid ranks champion familiarity matters more than counter-picking; counter gaps are small (2-4%). for: [[lol-mastery-analysis#^f1]], [[lol-mastery-analysis#^f2]], [[ss-dont-counterpick-unfamiliar#^f1]], [[ss-dont-counterpick-unfamiliar#^f5]]
- C14: Players want context for their numbers, such as a percentile against the player base. for: [[lol-yearin-wrapped#^f5]]
- C15 (inferred): Lead the landing page with a minute-by-minute matchup curve and a Your games example, not a win-rate table. from: C2, C3, C4, C5
- C16 (inferred): Every chart names its band (spread or uncertainty) and its n; thin data is marked visibly and never sorted first. from: C6, C7, C8
- C17 (inferred): A reviewer must reach a working Your games example and the method page without logging in or looking anything up. from: C1, C2
- C18 (inferred): Win-rate colours should not rely on red against green. from: C9

## Disagreements

- Thin data, hide or shrink (C7): LoLalytics' 100-game floor (B) hides the noise but
  also the matchup; DraftGap's pseudo-games (B, code read) show every matchup but lean
  on the baseline. meiolol already shrinks (curve-statistics-method C11); what would
  settle the display is how players read a greyed, baseline-heavy curve, untested.
- Daily puzzle shape (C11): the same thread wants an endless mode and an archive while
  others value the single shared daily answer. An archive keeps both.

## Open

- No source on how players read a lane curve with a band; a few hallway tests would
  beat more reading
- C18 rests on one game's change; check a colour-blind-safe diverging palette against a
  simulator rather than research more
- Whether reviewers look past the landing page at all; no Riot statement either way
- Mobile: no evidence gathered on how many players use stats sites on phones
