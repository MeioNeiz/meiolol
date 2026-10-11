---
title: 'lolsite (hardstuck.club): link a Riot ID by setting a profile icon'
url: https://github.com/brianjp93/lolsite
kind: project
commit: 71b98b3221caf8009320632905447ad34dd5a86f
for: [identity-and-privacy]
looked: 2026-10-11
depth: code (player/viewsapi.py generate_code, connect_account_with_profile_icon; player/constants.py)
relevance: high
grade: C/fair
description: Open-source match history site that verifies Riot ID ownership by asking the user to set one of five starter icons, checked via summoner-v4
---
# lolsite (hardstuck.club): profile icon ownership check

Why: working prior art for proving Riot ID ownership without RSO.

## Assessment

- Evidence: C. Source of hardstuck.club, a League match history site; repo since Feb
  2019, pushed Oct 2026, 16 stars, 3 contributors, no licence. Works for its author;
  no data on how many users linked.
- Reasoning: fair. Code is clear; no comments on why these icons.
- Interests: none.
- Weigh: the mechanism is simple and current (uses Riot ID); copy the pattern, not the
  code (no licence).

## Findings

- [privacy] [tools] Picks a random icon from a fixed list, avoiding the summoner's current
  icon, and stores it on a pending link. `player/viewsapi.py` ^f1
  > icon_id = random.choice(player_constants.VERIFY_WITH_ICON)
  > if icon_id != summoner.profile_icon_id:
- [privacy] [tools] The list is five low icon ids (0, 21, 10, 9, 25), starter icons every
  account owns. `player/constants.py` ^f2
  > VERIFY_WITH_ICON = [0, 21, 10, 9, 25]
- [privacy] [tools] Pending links expire after 2 hours. `player/viewsapi.py` ^f3
  > if now > (link.created_date + timedelta(hours=2)):
- [privacy] [tools] Verification re-fetches the summoner by Riot ID and compares its
  current profile icon to the expected one. `player/viewsapi.py` ^f4
  > if summoner.profile_icon_id == summonerlink.profile_icon_id:
- [privacy] [tools] Linking requires a site login; users can unlink. `player/viewsapi.py` ^f5
  > data = {"message": "User must be logged in."}
  > link = get_object_or_404(SummonerLink, user=user, summoner=summoner, verified=True)
- [privacy] (inferred) With 5 icons and the current one excluded, a random guess passes
  1 time in 4 or 5; a larger pool (Moon Poro uses 28, [[moon-poro-bot#^f2]]) or two
  successive icons makes accidental or guessed matches negligible. ^f6

## Read

- `player/viewsapi.py` generate_code, unlink_account, connect_account_with_profile_icon
- `player/constants.py`

## Not read

- frontend; privacy policy of hardstuck.club
