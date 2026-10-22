---
title: How to Use the Mobalytics Desktop App (2019 guide)
url: https://mobalytics.gg/blog/how-to-use-the-mobalytics-desktop-app-guide/
kind: docs
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole article)
relevance: high
grade: B/fair
description: Mobalytics' own walkthrough of its desktop app (Sep 2019, still live): champ select pick and ban suggestions from your pool and recent losses, player scouting badges (Fatigue, Hot Streak), power spikes, matchup advice, gank map, session stats, post game rankings and badges, GPI loop
---
# How to Use the Mobalytics Desktop App (2019 guide)

Why: the most detailed first-party description of the Mobalytics Live Companion per
phase, including how its pick and ban suggestions are made.

## Assessment

- Evidence: B. Vendor's own guide by Agilio Macabasco, September 3, 2019; still served
  in Oct 2026.
- Reasoning: fair. Explains the basis of each recommendation.
- Interests: vendor.
- Weigh: pre-dates Riot's 2022 champ select name hiding and later rules; read it as what
  Mobalytics built and how it reasoned, not as what ships now (current list:
  [[overwolf-mobalytics-desktop]]).

## Findings

- [tools/phase] Champ select: the Live Companion mirrors the lobby from the moment champ
  select starts (named for normal draft and ranked flex); the browser version could only
  help at loading screen. ^f1
  > queue up for a League of Legends game on Summoner’s Rift (normal draft, ranked flex) and then accept your game. As soon as you’re in champ select, you’ll see the Live Companion transform to mimic your lobby.
  > the browser version which can only provide analysis after champ select during the loading screen (due to technical limitations)
- [tools/phase] [draft] Champ select bans, three kinds: most popular in your role, what you
  lost to in your last 20 matches, and a strong champion from another lane. ^f2
  > **What you struggle against**: This takes a look at your most recent 20 matches and recommends a ban based off of that.
- [tools/phase] [draft] Champ select picks, three kinds: a pocket pick from your pool,
  recent good performance, and a meta champion that is also in your pool. ^f3
  > **Pocket pick:** This suggestion is based on a strong pick from your champion pool that may not necessarily be part of the current meta.
  > The champs that pop up here take into account the most popular champs in the current meta (usually in line with our [tier list]
- [draft] Framed as improving odds of winning, not as a best pick. ^f4
  > Games can be won and lost at champ select so we want to prepare you as much as we can to give you the best odds of winning.
- [tools/phase] After lock-in: player scouting (rank, runes, spells, win rates) with badges
  such as Fatigue (over 6 hours of play) and Extra Hot Streak (5 wins in a row). ^f5
  > “Fatigue” which refers to a player who has been playing for more than 6 hours straight or Extra Hot Streak for someone who is on a 5 game winning streak.
- [tools/phase] After lock-in: team damage type split, champion and team power spikes
  (green, yellow, red by game stage), lane matchup advice up to level 6, gank difficulty
  per lane, build import. ^f6
  > The Live Companion provides power spikes for every champion in your match, as well as the collective power spikes for each team.
  > The advice tends to be most relevant for the laning phase, basically up to level 6.
- [tools/phase] [needs] Between games: current session stats (time played, win and loss
  streak), with a nudge to take breaks. ^f7
  > the current session statistics tool, which measures how long you’ve played and your win/loss streak during that timeframe.
- [tools/phase] Post game: MVP and 1st to 10th player ranking, build overview with item
  timings, personal achievement badges, team summary, paired stat toggles. ^f8
  > Next to each summoner’s name, you’ll see a ranking ranging from 1st
- [tools/phase] [learning] Between games: dashboard with ranked goals, GPI over 8 skills
  with advice, progress analysis over time; a suggested loop before, during and after a
  session. ^f9
  > We crunch all of your matches for a particular role and game mode and then measure them across 8 skills
- [tools/accounts] Sign-in is required, with the app set to your summoner name. ^f10
  > Once you’re signed in and you’re set to your summoner name, you’re ready to go!
- [ux/features] The vendor admits the champ select screen can overwhelm and advises
  picking the few tools you need. ^f11
  > At first, the Live Companion might seem overwhelming due to the sheer amount of information that’s presented to you.
- [tools/removed] (inferred) Teammate badges in champ select (Fatigue, Hot Streak) are the
  scouting Riot later limited in Ranked Solo/Duo ([[overwolf-riot-compliance#^f3]]); the
  2026 listing keeps scouting only as "Pre Game" ([[overwolf-mobalytics-desktop#^f3]]). ^f12

## Read

- Whole article

## Not read

- mobalytics.gg/blog/lol-how-to-use-mobalytics-live-companion/ (newer guide, may show
  what changed after 2022)
