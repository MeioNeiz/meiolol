---
title: 'Ask Riot: Is ARAM Really Random? (Riot Mojibake, 2021-03-25)'
url: https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-is-aram-really-random/
kind: article
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (ARAM answer)
relevance: high
grade: A/fair
description: Riot engineer on how ARAM champ select assigns champions: a uniform draw from the player's owned plus free champions minus those already rolled, then rerolls, bench swaps and trades
---
# Ask Riot: Is ARAM Really Random? (Riot, 2021)

Why: ARAM assigns champions by lot; is the assignment random enough to serve as a natural
experiment for champion and comp effects free of pick selection?

## Assessment

- Evidence: A. Riot software engineer describing the server's own logic.
- Reasoning: fair; precise about the draw, silent on how often rerolls and swaps change
  the final champion.
- Interests: none relevant.
- Weigh: the first roll is random given the player's pool; the champion in match-v5 is
  the final one, after player choices. 2021; ARAM rules may have changed since (bench
  size, reroll counts), check before relying on it.

## Findings

- [method/causal] [queues] Each roll or reroll draws uniformly from the champions the
  player could roll at that moment: always-free ARAM champions, the free rotation and
  owned champions, minus those already rolled by either team and disabled ones. ^f1
  > Everytime you roll or reroll, the champion you get is randomly drawn from the set of available champions that you _could_ roll at that moment, but that set is not random.
  > _A_ is the set of [65 always-free-to-play ARAM champs]
- [method/causal] The initial ten rolls use the same draw, one per player. ^f2
  > The initial 10 rolls follow this process too; at the start of Champ Select, TeamBuilder simply does this once for each player, to determine everyone’s initial champion.
- [method/causal] Players can then reroll, swap with the shared bench and trade, so the
  champion played is partly chosen. ^f3
  > every roll, reroll, trade, bench swap, and lock-in is _transactional_
- [method/causal] (inferred) For causal use: the first roll is random conditional on the
  player's owned set (which itself tilts toward champions they like), and the final
  champion is random only up to rerolls and bench swaps. A design that uses the final
  ARAM champion must check how far players' mastery on it exceeds what a random draw
  from their owned set would give; the gap measures how much choice leaks in. ^f4
- [method/causal] (inferred) What ARAM can identify cleanly: whether a player's mastery
  on a champion they were (mostly) handed predicts winning (the expertise effect without
  "picked it because it fits"), and comp effects (damage mix, frontline) with team
  composition close to random. Different map, so champion strengths do not carry over
  to Summoner's Rift. ^f5

## Read

- The ARAM answer in full.
