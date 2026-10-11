---
title: 'developer-relations #1154: release ARAM Mayhem match data without win/loss'
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1154
kind: thread
commit:
for: [match-v5-queues]
looked: 2026-10-11
depth: listed (issue and all 12 comments)
relevance: high
grade: C/fair
description: Player request (open since 2026-04) to expose Mayhem match history without win/loss; thread explains why it stays private and the client-side workaround
---
# developer-relations #1154: release ARAM Mayhem match data without win/loss

Why: whether Mayhem data is reachable at all, and how others get it.

## Assessment

- Evidence: C. No Riot staff reply; open since 2026-04-22. Useful comments from
  geozukunft (runs yearin.lol, "processing billions of League games") on special access and
  how match-v5 works. Some heat in the thread.
- Reasoning: fair. Arguments on both sides, unverified.
- Interests: requester wants personal history; geozukunft has privileged access.
- Weigh: confirms Mayhem still private in mid-2026; special-access and LCU claims are
  single-developer reports.

## Findings

- [queues] [policy] (claim) Mayhem was made private so aggregator sites cannot publish win
  rates that "solve" the meta. `raw/gh-devrel-1154.txt` ^f1
  > I read that this information is removed to keep people trying new things in Mayhem and to prevent aggregator sites from publishing win/loss statistics to "solve" the meta.
- [queues] [policy] (claim) One site has Mayhem access under rules agreed with Riot's Game
  Modes team, so private does not mean unreachable for an approved partner. ^f2
  > And **I** do have legitimate access to all Mayhem games for the purposes of my website with a very strict set of rules agreed upon between the Game Modes team and me
- [queues] [data] As of 2026-06 the only route for ordinary developers is the local client
  (LCU) match history; one developer pulled the last 200 games with timelines that way, in
  an older (v4-like) format. ^f3
  > I ended up setting up a little python tool based on those and am able to pull the last 200 games from the local client API, including timeline data.
  > the data from the local API seems to be structured in an older format (the v4 format?), not the v5 match data format
- [queues] [data] Desktop apps such as OP.GG track Mayhem history from the client. ^f4
  > Also, many desktop apps (like OP.GG) keep track of your game history.

## Read

- Issue body and all comments

## Not read

- github.com/Yhprum/mayhem-tracker (logged as a lead)
