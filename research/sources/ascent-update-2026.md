---
title: '[UPDATE] I made an automatic recorder that doesn''t use Overwolf (Ascent, r/leagueoflegends, Mar 2026)'
url: https://old.reddit.com/r/leagueoflegends/comments/1rq5nze/update_i_made_an_automatic_recorder_that_doesnt/
kind: thread
commit: 
for: [league-apps-feature-matrix, player-tool-needs]
looked: 2026-10-22
depth: docs (post and all loaded comments, via redlib mirror)
relevance: medium
grade: B/fair
description: Ascent's one-year update (877 points, 96% upvoted): 40k users, free recorder with a paid tier (150 GB cloud, downloads of others' VODs, Discord role, AI game review); comments compare Outplayed, Medal, Insights Capture
---
# [UPDATE] I made an automatic recorder that doesn't use Overwolf (Ascent, Mar 2026)

Why: the lead from [[lol-recorder-no-overwolf]]: a year on, what does a non-Overwolf League recorder offer per phase, what is paid, and what do players say about Outplayed and Insights?

## Assessment

- Evidence: B. 877 points, 96% upvoted, 10 Mar 2026; developer answers many questions in the thread.
- Reasoning: fair. Developer is candid (OBS replay buffer is as good if you only want the last 30 s).
- Interests: the developer's own promotion; same origin as the 2025 launch post.
- Weigh: paid tier contents and user counts come from the developer; complaints about Outplayed and praise for "no Overwolf" are from users. Read through a redlib mirror (old.reddit blocked the fetcher).

## Findings

- [market] Ascent claims over 40k users a year after launch; "no ads, no overwolf". ^f1
  > Since then we’ve continued developing it and we’ve hit over 40k users and polished the app a ton.
- [tools/paid] Almost everything free; paid tier adds more cloud storage, downloading others' VODs, a Discord role and AI analysis. ^f2
  > Nearly everything is accessible without payment. Paid features include increased cloud storage, ability to download others’ VODs, discord role, and AI analysis
- [tools/paid] Cloud storage: 150 GB for pro, 5 GB free; developer says paid subscribers far exceed storage costs. ^f3
  > Currently pro is given 150 gb of cloud storage while free users are given 5
  > The paid subscribers far exceed the storage costs
- [tools/phase] [learning] Post game: the AI feature is a game review for League ranked games, opt-in and subscribers only. ^f4
  > it's a game review feature for League ranked games
  > The AI is opt-in and only enabled for subscribers
- [tools/phase] [ux/features] Post game: VODs searchable by champion and role, kills, deaths and objectives marked on the timeline, gold difference and APM graphs on playback; match history shown. ^f5
  > In Ascent you can search through your VODs by champion, role, etc. You can also track events like kills/objectives for review.
  > One feature I really like is the ability to have gold difference on the timeline when playing it back.
- [needs] A user asks for a live scoreboard (items, summoner cooldowns, gold, shutdowns) beside playback and a CS per minute graph. ^f6
  > Would be cool to be able to see a live updated scoreboard (items, summoner CDs, gold values and shutdowns) on the side of the playback.
- [needs] A user wants pick and ban recorded too: the recorder starts at game load, not champ select. ^f7
  > wow i wanted to record pick&ban too
- [needs] [ux/trust] Overwolf distaste is the main pull again: "invasive", "spyware"; a user replaced Outplayed for its ads, another calls Outplayed buggy for months. ^f8
  > It's very invasive. I'm not sure if there's like privacy stuff that's wrong with it, but it definitely feels like it invades your PC
  > the ads in Outplayed were annoying enough for me to switch over.
  > I hate Outplayed, its been a buggy mess for months
- [tools] Insights Capture now has a standalone app without Overwolf (user report); the developer disputes its lower performance impact. ^f9
  > insights capture even with overwolf was better in that regard and now they have a standalone app that doesnt require overwolf
- [tools/accounts] Registration and premium appear tied to Discord: a user asks for both outside Discord (unanswered). ^f10
  > do you ever gonna consider make this outside of Discord ? so registration or the premium feature?
- [ux/trust] Praise for "no acc bs": the recorder works without forcing an account. ^f11
  > Really thankful for all the no acc bs and just everything working!
- [ux/trust] Trust frictions: antivirus and Edge flag the installer as PUA or trojan dropper; "Zero performance impact" wording challenged; frontend called vibe coded. ^f12
  > My antivirus says it detects the Ascent.exe as a Trojan-Dropper, do you know why this could be?
  > On the front page of the website, it says "Zero performance impact"
- [tools] Built in Rust on open-source OBS and FFmpeg forks; Windows only, no Mac plans. ^f13
  > It's written in Rust while other apps are often written in Javascript. We also use a highly optimized fork of OBS for recording
  > Not at the moment. There doesn't seem to be enough demand
- [ux/trust] Fear of losing footage when a cloud recorder dies (Plays.tv precedent) argues for local storage. ^f14
  > Plays TV? Now overtaken by medal TV? I lost 5 years of footage after I took a break and came back to find out they went under

## Read

- Post and all loaded comments

## Not read

- tryascent.gg site and blog ("is Ascent open source")
