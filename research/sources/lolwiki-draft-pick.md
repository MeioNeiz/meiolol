---
title: 'League of Legends Wiki: Team drafting (draft pick, tournament draft, swaps)'
url: https://wiki.leagueoflegends.com/en-us/Draft_pick
kind: docs
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed
relevance: medium
grade: B/fair
description: Community wiki page on champion select: draft styles per queue, player order, pick order swaps, tournament draft phases
---
# League of Legends Wiki: Team drafting (draft pick, tournament draft, swaps)

Why: Daily Draft wants the real pick order; which queues fix it by rule, and who decides the order of players within a team?

## Assessment

- Evidence: B. The official-community League wiki, edited over years; matches what the client shows.
- Reasoning: fair. Describes rules, not how they are recorded in the API.
- Interests: none.
- Weigh: rules for player order and swaps are trustworthy; nothing here about API fields.

## Findings

- [draft] [data] In normal and ranked Summoner's Rift queues the order of players in champion select is random; in Clash the captain is first; in custom and tournament games it follows the lobby. ^f1
  > In the [Normal](https://wiki.leagueoflegends.com/en-us/Normal_game "Normal game") and [Ranked](https://wiki.leagueoflegends.com/en-us/Ranked_game "Ranked game") queues on  [Summoner's Rift](https://wiki.leagueoflegends.com/en-us/Summoner%27s_Rift), the order is random.
  > In  [Custom](https://wiki.leagueoflegends.com/en-us/Custom_game) and tournament games, the order is strictly one-to-one with the order shown in the lobby.
- [draft] [data] Pick order swaps exist in some matchmade modes, not in tournament modes or Clash, so even a known cell order is not the final pick order in ranked. ^f2
  > Pick Order swaps are allowed in only certain matchmade modes. They are strictly unavailable in tournament modes, which includes [Clash](https://wiki.leagueoflegends.com/en-us/Clash "Clash").
- [draft] Tournament draft (Clash and pro play): captains alternate three bans each, picks go blue 1, red 2, blue 2, red 1, then a second ban phase of two each starting with red, then red 1, blue 2, red 1. ^f3
  > Pick Phase 1** \[30s for 6 turns\]: Blue Team pick one champion, then Red Team pick two champions, then Blue Team pick two champions, then Red Team pick one champion.
  > Ban Phase 2** \[30s for 4 turns\]: Red Team issue the first ban; the team captains alternate turns banning a champion, up to two per team.
- [draft] In Draft pick blue always has first pick, so side alone fixes which team picked first and which picked last. ^f4
  > In Draft pick, the **Blue team** always has "the right to pick first"

## Read

- `raw/lolwiki-draft-pick.md`: Lobby, player order, swaps, draft styles.

## Not read

- Nothing more needed for the pick-order question.
