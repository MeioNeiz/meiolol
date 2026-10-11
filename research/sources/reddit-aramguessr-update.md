---
title: '[UPDATE] I made AramGuessr (r/leagueoflegends, 2023-11-10)'
url: https://www.reddit.com/r/leagueoflegends/comments/17s7z5p/
kind: thread
commit:
for: [league-tools-landscape]
looked: 2026-10-11
depth: listed (post and top comments via safereddit)
relevance: high
grade: B/fair
description: Creator's update post for AramGuessr (now LeagueGuessr), a guess-the-winner-from-draft game; got a production key quickly, RSO login, ads to break even
---
# [UPDATE] I made AramGuessr (r/leagueoflegends, 2023-11-10)

Why: is there a draft-based guessing game already, did it get a Riot production key, and
how did it do?

## Assessment

- Evidence: B. First-hand report by the developer; 713 upvotes, 95% upvoted, 366 comments; a Riot lead champion designer played it. Site still live in Oct 2026 as LeagueGuessr ([[leagueguessr-site]]).
- Reasoning: fair. Says what changed and why (traffic, cost), no numbers on users or revenue.
- Interests: the developer promoting their own site.
- Weigh: trust the key and RSO facts (first-hand, 2023; review was faster then); no traffic or revenue figures, only that ads were needed to cover costs.

## Findings

- [fun] [draft] Guess the winner of a real past ARAM from the two team comps only ("think loading screen"). ^f1
  > you'll have to guess the outcome of past ARAM games only based on team comp (think loading screen).
- [market] First post two weeks earlier drew more traffic than the small site could handle. ^f2
  > It had a decent amount of success and my small site was not ready to handle so much traffic.
- [policy] [data] Riot granted a production key after the traffic spike, raising limits from 100 per 2 minutes to 500 per 10 seconds (2023). ^f3
  > Riot dev team was very responsive and provided me with a Production API key (For reference the rate limit was 100 requests every 2 minutes, now it's 500 requests every 10 seconds)
- [policy] [fun] Riot also enabled RSO login; logged-in players can guess on a sample of their own ARAM history. ^f4
  > Thanks to Riot dev team, you can now log in with your Riot Games account
  > When logged in with your Riot account, you can play against your own ARAM history (random sample)
- [fun] [ux] Social features: challenge friends without an account; no daily limit (it is endless, not a daily puzzle). ^f5
  > You don't need an account to challenge friends in a guessing match
  > No daily limit of games played
- [market] Monetisation: small ads only to try to break even; developer struggling with hosting costs. ^f6
  > I'm having a hard time breaking even regarding the maintenance cost for the site.
  > I display a small amount of ads to just try to break even with the maintenance cost.
- [data] Hint features cost API calls: mastery reveal needs one call per player, called resource-consuming. ^f7
  > I could implement masteries but it would need 10 separate API calls, one for each player, which is pretty resource-consuming.
- [fun] [draft] Riot's lead champion designer played it and found "more tanks" a strong heuristic, until itemisation broke it. ^f8
  > I got a bunch correct in a row by just selecting the team with more tanks until I picked a team with Tahm/Voli/MF that all decided to build full AP.

## Read

- Post body and first ~40 comments.

## Not read

- Original post 17icv8t (two weeks earlier): launch reception.
