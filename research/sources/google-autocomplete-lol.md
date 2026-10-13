---
title: Google autocomplete for League of Legends query prefixes (2026-10-12)
url: https://suggestqueries.google.com/complete/search?client=firefox&hl=en&gl=gb&q=
kind: dataset
commit: 
for: [search-demand]
looked: 2026-10-12
depth: ran (45 prefixes, UK IP, English)
relevance: high
grade: B/fair
description: Google's public suggest endpoint queried for 45 LoL prefixes (champion names, counter, vs, team comp, tanks, climb, draft); suggestion lists, not volumes
---
# Google autocomplete for League of Legends query prefixes (2026-10-12)

Why: Google Trends refused us (429), so autocomplete is the free signal for which LoL
query patterns people actually type.

## Assessment

- Evidence: B. Google's own suggestions; they reflect what people search, filtered and
  personalised by locale, but give no volumes and only rough ordering.
- Reasoning: fair. Our reading of patterns; one snapshot, UK, English.
- Interests: none.
- Weigh: a suggestion means real demand exists; its absence means low volume for that
  exact phrasing, not none. Order within a list is only a hint.

## Findings

- [market] [seo] A champion name alone suggests "counters" and "build" as its LoL completions (Darius: counters before build; Yasuo: build, counters, runes). ^f1
  > darius jackson | darius counters | darius mccrary | darius slayton | darius build
  > yasuo => yasuo build | yasuo | yasuo counters | yasuo aram mayhem | yasuo runes
- [market] [draft] "<champ> vs" completes to ten lane opponents: the one-matchup page is a typed query. ^f2
  > darius vs => darius vs garen | darius vs mordekaiser | darius vs sett | darius vs nasus
  > jinx vs => jinx vs caitlyn | jinx vs mf | jinx vs jhin | jinx vs ashe
- [market] [draft] "best champion against/vs" completes to single lane opponents (Nasus, Sett, Garen, Darius, Mordekaiser, Teemo) plus two class-level asks: tanks and ranged tops. ^f3
  > best champion vs tanks | best champion vs nasus
  > best champ against ranged top
- [market] [draft] Tanks are the comp archetype people type: "lol vs tanks" completes to items and champions vs tanks, and "best adc against tanks" is its own query family. ^f4
  > lol vs tanks => lol items vs tanks | lol jhin vs tanks | lethality vs tanks.lol | lol ezreal vs tanks | lol mages vs tanks
  > best adc against tanks => best adc against tanks | wild rift best adc against tanks | best adc against tanks lol | best adc against tanks reddit
  > lol best champion against tanks => lol best champs against tanks | lol best champs vs tanks
- [market] [draft] Checked, near absent: "lol counter team comp" gives only "lol team comp counter"; "how to beat tank comp lol" and "how to play against poke lol" give no suggestions; "lol poke" gives only "lol poke comp" and poke champions. Comp-counter phrasing is rare as typed searches. ^f5
  > lol counter team comp => lol team comp counter
- [market] [draft] "team comp" searches are tool-shaped: builder, generator, calculator, analyzer, maker, guide, types. ^f6
  > lol team comp => lol team comp builder | lol team comps | lol team comp generator | lol team comp calculator | lol team comp analyzer
- [market] [draft] "lol draft" completes to simulator, pick, tool, analyzer, ai, helper. ^f7
  > lol draft => lol draft | lol draft simulator | lol draft pick | lol drafter | lol draft tool | lol draft game | lol draft analyzer | lol draft ai
- [market] "what to build against" completes to enemy champions and damage types: build-vs-opponent is a typed intent. ^f8
  > what to build against => what to build against lethality | what to build against nasus | what to build against mordekaiser
- [market] [learning] "<champ> matchup" completes to spreadsheet, guide, sheet, chart: players look for matchup sheets. ^f9
  > darius matchup => darius matchups | darius matchup spreadsheet | darius matchup guide | darius matchup sheet | darius matchup chart
- [market] [learning] Climbing searches are role-specific and Reddit-seeking. ^f10
  > how to climb in league => how to climb in league of legends | how to climb in league | how to climb in league reddit | how to climb in league of legends reddit | how to climb in league as support
- [market] Generic "lol how to" completions are client and settings help (mythic essence, ping, region, name), not gameplay. ^f11
  > lol how to => lol how to get mythic essence | lol how to show ping
- [market] Tier lists complete by role and year. ^f12
  > lol tier list => lol tier list | lol tier list maker | lol tier list jungle | lol tier list mid | lol tier list 2026
- [market] [learning] Gold difference searches are about seeing it live or in replays (overlay, graph); power spikes complete to lists per champion and role. ^f13
  > lol gold diff => lol gold difference overlay | gold difference lol | lol gold difference graph
  > lol power spikes => lol power spikes list | lol power spikes | lol champion power spikes | lol adc power spikes
- [market] "how to get out of silver" lists LoL eighth, behind Valorant, Rocket League, Overwatch, R6, CS2 and Marvel Rivals. ^f14
  > how to get out of silver marvel rivals | how to get out of silver lol

## Read

- All 45 prefix lists in the raw file

## Not read

- Other locales (EUW languages), mobile suggestions, People Also Ask boxes
