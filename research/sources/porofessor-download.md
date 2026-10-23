---
title: Porofessor download page (Wayback, Aug 2026)
url: https://web.archive.org/web/20260815155443/https://porofessor.gg/download
kind: docs
commit: 
for: [league-apps-feature-matrix, desktop-app-layout]
looked: 2026-10-22
depth: docs (whole page, Wayback copy 2026-08-15; live site behind Cloudflare challenge)
relevance: high
grade: B/fair
description: Porofessor's own app page, Aug 2026: 16.9M downloads, draft ban and counter tips with build import, matchup review, player tags, in-game overlays, detailed match analysis, pro replays, find new friends (LFG), TFT guides
---
# Porofessor download page (Wayback, Aug 2026)

Why: Porofessor's own feature list per phase, fuller than its Overwolf listing
([[overwolf-porofessor]]).

## Assessment

- Evidence: B. Vendor page, Wayback copy of Aug 2026; live page is Cloudflare-walled.
- Reasoning: weak. Marketing headings with one line each.
- Interests: vendor; "Riot Games Compliant" links Overwolf's own blog, not Riot.
- Weigh: trust the feature list; the page's download button still points at the Overwolf
  install, the standalone is offered on Overwolf's catalogue ([[overwolf-lol-apps#^f2]]).

## Findings

- [market] (claim) Over 16,900,000 downloads, "#1 downloaded" companion app, "Riot Games
  Compliant" with a link to an Overwolf blog post. ^f1
  > Trusted by millions of users with over 16,900,000 downloads and [Riot Games Compliant]
- [tools/phase] [draft] Champ select: ban suggestions, counterpick tips, import of
  builds, spells and runes into the client. ^f2
  > get bans suggestions, counterpick tips and an easy way to import builds, spells and even runes directly into your LoL client!
- [tools/phase] [draft] Champ select: matchup review from months of games, including
  enemy damage types to pick counters. ^f3
  > Drawing on data from months of games, Porofessor breaks down how champions match against one another.
  > Understanding enemy damage types and picking counters for them can change your game!
- [tools/phase] Loading screen: player tags summarising each enemy and how to beat them. ^f4
  > Meet the Porofessor tags, a great way to quickly understand everything you need about your enemies and how you can defeat them.
- [tools/phase] In game: overlays with live stats analysis, jungle and inhibitor timers. ^f5
  > Get Ingame overlays to help you ingame, live stats analysis, jungle & inhibitor timers and more...
- [tools/phase] [learning] Post game: detailed match analysis with charts of farming,
  fighting, vision and objectives. ^f6
  > Charts about every detail of your farming, fighting, vision, objective captures & more...
- [tools/phase] Between games: meta tier list with top picks, bans and counters; pro
  replays to watch. ^f7
  > Watch top tier matches to see amazing plays and learn new tricks and strategies from the best players in the game.
- [tools/accounts] Between games: a "find new friends" feature to meet players for any
  mode and level (a looking-for-group board). ^f8
  > Find new mates to play with. For anymode you want. Of any level you want.
- [tools/paid] Checked, not there: no premium, subscription or price on the page, though
  Overwolf lists a subscription ([[overwolf-porofessor#^f1]]). ^f9
- [needs] Pitched for solo and premade play alike. ^f10
  > Whether you're climbing solo or strategizing with friends, this app ensures you make informed decisions to outplay the competition.
- [tools] League of Graphs has no desktop app of its own: Porofessor is its creator's
  companion app, and stats use the last 30 days of normal and ranked 5v5. ^f11
  > All stats are determined using the last 30 days of data for 5v5 normal and ranked games

- [ux/desktop] Loading screen and live game: ten player cards in two rows of five, one
  row per team, a blue top rule on the ally row and red on the enemy row. Each card,
  top to bottom: profile icon, Riot ID, level; champion icon with spells and runes,
  champion level, KDA coloured green / red / orange, win rate with (W / games), champion
  rank #; rank emblem with tier, LP, ranked win rate and ladder rank; three ring gauges
  (12 hr win %, main role icon, 30 day win %) with game and win counts under each; then
  a wrap of tag pills (seen in screenshot porofessor-download-matchup-review.png). ^f12
- [ux/colour] Tags are outlined pills, colour by meaning: green good (Good CSer, OTP
  Urgot, Aggressive Jungler, Millionaire: Veigar), orange watch-outs (Invader, Split
  Pusher, Roaming, Waking up), red weakness (Vulnerable Laner, Ziggs casual), blue for
  pro players (Pro: 3XA). Rings use the same colours: green at or over 50%, red low,
  orange around 50%. A card with no history shows 0% and grey (seen in screenshot
  porofessor-download-matchup-review.png). ^f13
- [ux/desktop] Tag wraps run 1 to 6 pills; long ones scroll inside the card, so card
  height stays fixed and the two rows stay aligned (seen in screenshot
  porofessor-download-matchup-review.png). ^f14
- [ux/desktop] The tags pitch: a quick read of each enemy and how to beat them. ^f15
  > Meet the Porofessor tags, a great way to quickly understand everything you need about your enemies and how you can defeat them.
- [ux/desktop] A single-player card (detail view) puts the tags under the stats, the
  champion name and "Rank #421 on Irelia, Winrate (Ranked) 56.9%" as a heading tag
  ("Godlike Irelia"), with more tags (Turrets destroyer, Stopped CSing, Bad CSer, Slow
  to end) below (seen in screenshot porofessor-download-feature-3.png). ^f16
- [ux/desktop] In game: a small stats overlay (title bar "Show / Hide Alt + Shift + X",
  gear, close) listing six rows, each metric with "(vs other team)" or "(vs Platinum)"
  in grey italics, a value and a green up or red down delta (Team gold 115K +41, CS/min
  2.03 -4.74); a separate build panel shows the next three items and gold to the next
  item; timers sit on the minimap (seen in screenshot porofessor-download-overlays.png). ^f17
- [ux/desktop] Post game: two charts across the top (team gold advantage, area blue
  above zero and red below; damage dealt bars, blue team then red team with champion
  icons as x labels), then a strip of ten champion icons to pick a player, then tabs
  Fighting, Farming, Objectives, Vision, Pings with ring gauges (Teamfights winrate,
  Duels winrate, Kills under enemy turret), and that player's tag pills in a side panel
  (seen in screenshot porofessor-download-match-analysis.png). ^f18
- [ux/desktop] Champ select detail: a narrow build panel for "Master Yi (Jungler)
  (Master+)": starting build, core build, boots, end items, level 1-2-3 skills and skill
  order as icon rows with left and right arrows for alternatives, a rune page under it
  and an "Export runes to LoL" button with an "Automatic export" checkbox; a team panel
  lists average winrate, KDA, gold, damage and wards per min plus team comp tags (Good
  frontline, Splitpush potential, Great dive) (seen in screenshot
  porofessor-download-feature-1.png). ^f19

## Read

- Whole page
- Screenshots (23 Oct): feature-1, feature-3, overlays, match-analysis, matchup-review
  (raw/porofessor-download-*.png)

## Not read

- porofessor.gg/support (desktop app support) and any premium page (Cloudflare; none in
  Wayback)
