---
title: 'U.GG: summoner profile and match list, Oct 2026'
url: https://u.gg/lol/profile/euw1
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of Overview and Champion Stats; screenshots desktop and phone)
relevance: high
grade: A/fair
description: U.GG profile of a Challenger EUW player: season rank chips, rank card, champion stats, played-with table, one-line last-20 summary, match cards with LP change, phone card in two lines
---
# U.GG: summoner profile and match list, Oct 2026

Why: lol-site-ui, kind 2. Complements [[ugg-profile]] (22 Oct, feature list only).
Screenshots in data/team/2026-10-24-ui/refs/profile/ (gitignored): ugg-profile-top.png,
ugg-profile-rows-friends.png, ugg-phone.png.

## Assessment

- Evidence: A. One of the two biggest LoL stats sites.
- Reasoning: fair. Calmer than OP.GG: fewer blocks, smaller summary.
- Interests: ad funded; PLUS and the desktop app sold in a 48 px top banner and the header.
- Weigh: the summary line and the phone card are the parts to copy.

## Findings

- [ux/layout] Header: past season ranks as a row of small chips (S15 Master ... S9
  Diamond), then name, ladder rank, Update; tabs Overview, Champion Stats, Live Game,
  PLUS Tier List. First match card at about 545 px on desktop (screenshot 24 Oct). ^f1
  > S15 Master | S14-3 Master | S14-2 Master
- [ux/postgame] [ux/density] Summary over the list is one 60 px strip: a small win rate
  ring, "40% WR Last 20 games", KDA with K/D/A, the top three champions with win rate,
  record and KDA. No role bars, no AI prompts. ^f2
  > Match History | All Matches | 40% WR | Last 20 games | 1.9 KDA | 5.7 / 6.9 / 7.4 | 44% (7W 9L) | 1.99 KDA
- [ux/postgame] [ux/density] Match card about 100 px: queue, time ago, LP change set big
  (an arrow and "35 LP") over LOSS/WIN and duration; champion, spells, runes; K/D/A, KDA,
  CS with per minute, vision; items in two rows of four; ten names; expand arrow. LP is
  the biggest number on the row. ^f3
  > Ranked Solo | 17 hours ago | NEW | 35 LP | LOSS | 24:22 | 12 | 3 / 10 / 5 | 0.80 KDA | 133 CS (5.5) | 19 vision
- [ux/postgame] Played with: a real table (Summoner, Played, W - L, Win Ratio) for the
  last 20 games, eight rows. ^f4
  > Recently Played With | Last 20 games | Summoner | Played | W - L | Win Ratio
- [ux/postgame] Champion Stats tab: a plain sortable table, one row per champion: win rate
  with W/L, KDA, net LP gained on that champion, max kills and deaths, CS, damage, gold,
  multi-kills. Net LP per champion is a number OP.GG does not show. ^f5
  > Rank | Champion | Win Rate | KDA | LP | Gain | Max | Kills | Max | Deaths | CS | Damage | Gold
- [ux/layout] Phone (390 px): match cards fold to two lines with no teammates: result,
  duration and LP on top, champion, K/D/A, KDA, items and CS below, about 75 px each;
  but the list starts after the rank, champion stats and played-with blocks, about
  1,600 px down (screenshot ugg-phone.png). ^f6
- [ux/charts] Checked, not there: no LP chart and no recent-vs-season comparison. ^f7

## Read

- Overview, Champion Stats; phone Overview.

## Not read

- Live Game, PLUS Tier List.
