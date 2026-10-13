---
title: Google autocomplete for LoL learning and itemisation prefixes (2026-10-12)
url: https://suggestqueries.google.com/complete/search?client=firefox&hl=en&gl=gb&q=learning
kind: dataset
commit: 
origin: google-autocomplete-lol
for: [search-demand]
looked: 2026-10-12
depth: ran (25 prefixes, UK IP, English)
relevance: high
grade: B/fair
description: Google suggest for learning-intent LoL prefixes (how to play/beat X, guide, when to build, items against, build vs, improve); suggestion lists, not volumes
---
# Google autocomplete for LoL learning and itemisation prefixes (2026-10-12)

Why: second batch after [[google-autocomplete-lol]], for learning and item searches.
The url's trailing `q=learning` only distinguishes this batch; each prefix was its own
request.

## Assessment

- Evidence: B. Google's own suggestions; no volumes.
- Reasoning: fair. Our reading of patterns; one snapshot, UK, English.
- Interests: none.
- Weigh: as [[google-autocomplete-lol]].

## Findings

- [market] [learning] "how to beat <champ>" completes mostly to "as <my champ>": the learning search is a champion pair seen from the player's side. ^f1
  > how to beat darius => how to beat darius as garen | how to beat darius | how to beat darius as sett
  > how to beat yasuo => how to beat yasuo as yone | how to beat yasuo | how to beat yasuo as fizz
- [market] [learning] "how to play <champ>" completes to role and then to lane opponents. ^f2
  > how to play darius => how to play darius | how to play darius top | how to play darius vs garen
- [market] [learning] "<champ> build vs" completes to lane opponents, and for an ADC first to tanks: build-by-opponent and build-vs-comp-type are both typed. ^f3
  > jinx build vs => jinx build vs tanks | jinx build vs caitlyn
  > darius build vs => darius build vs garen | darius build vs teemo | darius build vs mordekaiser
- [market] [learning] "lol items against" completes to enemy traits first (tanks, shields, lethality, lifesteal, CC), then champions. ^f4
  > lol items against => lol items against tanks | lol items against shields | lol items against lethality | lol items against lifesteal | lol items against cc
- [market] [learning] Item questions are about choosing between classes of item and timing: lethality vs crit, on-hit vs crit, anti-heal. ^f5
  > when to build lethality vs crit | when to build lethality | when to build pc | when to build on hit vs crit
  > lol when to build anti heal
- [market] [learning] Itemisation searches want guides and tools, per role. ^f6
  > lol itemization => lol itemization guide | lol itemization | lol itemization tool | lol itemization reddit
- [market] [learning] Improvement searches end in "reddit", "for beginners", "mechanics", "fast". ^f7
  > how to get better at league => how to get better at league of legends | how to get better at league | how to get better at league of legends for beginners | how to get better at league mechanics | how to get better at league of legends reddit
- [market] [learning] "matchup guide" completes per champion (Riven, Fiora, Gwen, Jax): skill tops whose players study matchups. ^f8
  > lol matchup guide => lol matchup guide | lol riven matchup guide | lol fiora matchup guide | lol gwen matchup guide
- [market] Checked, not there: "when to build zhonyas" and "when to build executioners" give no suggestions. ^f9

## Read

- All 25 prefix lists
