---
title: 'Hextechdocs: [Obsolete] Using third-party-code to verify account ownership'
url: https://hextechdocs.dev/using-third-party-code-to-verify-account-ownership/
kind: article
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (whole article)
relevance: high
grade: B/fair
description: Community dev docs guide to the old third-party-code ownership check, marked obsolete since its removal in March 2022
---
# Hextechdocs: [Obsolete] Using third-party-code to verify account ownership

Why: does the old summoner third-party-code endpoint still exist, and what preceded it?

## Assessment

- Evidence: B. Hextechdocs is the Riot API community's docs site (run from the third-party
  developer Discord); article dated 15 Aug 2021, banner added after removal, citing a
  RiotGamesDevRel tweet.
- Reasoning: fair. Explains the history (rune page rename, then third-party-code, then RSO)
  and the endpoint's known flakiness.
- Interests: none known.
- Weigh: removal confirmed independently: the current OpenAPI schema has no
  third-party-code path ([[riotapi-schema#^f17]]).

## Findings

- [policy] [data] Third-party-code API removed by Riot; developers told to move to RSO;
  unusable from 7 March 2022. ^f1
  > the Third Party Code API has been removed and users are encouraged to migrate over to RSO in lieu of using this endpoint. Anything noted in this document is no longer usable as of the 7th of March 2022.
- [privacy] [tools] Before that, sites verified ownership by asking the player to rename a
  rune or mastery page to a given string; Runes Reforged removed those endpoints. ^f2
  > sites and services verified account ownership by asking a user to rename either a rune or a mastery page to a specific string. When the new rune system came out, Riot removed the respective endpoints
- [privacy] Third-party-code was a stopgap until Riot's OAuth2 (RSO) became available. ^f3
  > gave us [third-party-code](https://developer.riotgames.com/apis?ref=hextechdocs.dev#third-party-code-v4/GET_getThirdPartyCodeBySummonerId) as a replacement while Riot's OAuth2 solution becomes generally available.
- [privacy] Flow: site generates a string, player types it into the client's settings
  under Verification, site reads it back from the endpoint. ^f4
  > you generate a string on your end, ask the user to input it and then confirm that action using the
  > This can be done in the settings menu under Verification.
- [privacy] Advice: codes expire, so verify once and persist the link in your own account
  system. ^f5
  > make a basic user account system that allows you to persist this information and attach it to something a bit more persistent.
- [privacy] (inferred) Every pre-RSO method relied on the player changing something on
  their account that the API exposes; today the only such writable field visible via
  summoner-v4 is the profile icon ([[riotapi-schema#^f18]]). ^f6

## Read

- whole article

## Not read

- the RiotGamesDevRel tweet itself (X needs JS)
