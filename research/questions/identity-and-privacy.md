---
status: answered
priority: now
area: policy
tags: [policy, privacy]
description: How can players look themselves up and opt into Squads without RSO, and what do Riot policy and GDPR require for storing and showing player data?
---
# How can players look themselves up and opt into Squads without RSO, and what do Riot policy and GDPR require for storing and showing player data?

Feeds: docs/concept.md "Your games" and "Squads" (lookup and opt-in design), the dynamic
service, the site privacy policy and ToS, the production application

## Answer

Showing anyone's normal and ranked history is allowed: League policy only requires
opt-in (or RSO) for custom-game history and has no consent rule for looking up a Riot ID,
which is how op.gg and others operate (C1). The limits are general: no de-anonymising
players hidden by the game, no breach of privacy rights or law (C3). Where Riot does
demand consent (VALORANT), consent means RSO linking, so RSO remains the end state (C2).

Without RSO, ownership proof is narrow. The third-party-code endpoint is gone since 2022
(C4) and Discord stopped exposing Riot account links on 10 July 2026 (C5). The working
prior art is a profile-icon challenge: ask the player to set a given starter icon, then
re-read it via summoner-v4; tools frame it as a stand-in until RSO (C6).

Data duties: Riot treats API data as possibly personal data under GDPR, passes erasure
lists to developers, and recommends refreshing stored players every 30 days (C7). Big
lookup sites rely on legitimate interests and offer little to players who never signed
up (C8). Legitimate interests needs a written assessment, disclosure in the privacy
notice and honouring objections (C9). As a UK controller: pay the ICO fee (micro
organisation £52 a year, no exemption fits) (C10), and appoint an EEA representative
unless processing is occasional and low risk, which a 24/7 crawler may not be (C11).
Counterwatch is a small-site model: legitimate interests, objection open to anyone after
proving ownership, 24-month retention (C12). Riot publishes no checklist for app privacy
policies or ToS; it only reviews them.

For meiolol (C13): "Your games" works for any Riot ID on legitimate interests, with an
objection and removal form gated by the icon check and the Riot erasure lists applied.
Squads should be consent-based: each member proves their Riot ID with the icon check
before joining. Move both to RSO once the production key arrives.

## Claims

- C1: League policy has no consent or opt-in rule for showing any Riot ID's normal or ranked match history; only custom-game history needs opt-in or RSO. for: [[riot-docs-lol#^f15]], [[riot-docs-lol#^f16]], [[riot-docs-lol#^f17]]
- C2: Where Riot requires opt-in (VALORANT), consent means RSO account linking plus a disclaimer that linking makes data public. for: [[riot-docs-valorant#^f1]], [[riot-docs-valorant#^f2]], [[riot-docs-valorant#^f3]]
- C3: Products must not de-anonymise players who cannot reasonably be identified from visible information, nor violate privacy rights or law. for: [[riot-policies-general#^f10]], [[riot-dev-terms#^f13]]
- C4: The third-party-code ownership endpoint no longer exists (removed March 2022). for: [[hextechdocs-third-party-code#^f1]], [[riotapi-schema#^f17]]
- C5: Discord OAuth no longer reveals a user's Riot account (since 10 July 2026). for: [[discord-riot-connections-deprecation#^f1]], [[discord-riot-connections-deprecation#^f2]]
- C6: Without RSO the profile-icon challenge (set a given icon, re-read via summoner-v4) is the working ownership check in current prior art, framed as temporary until RSO. for: [[lolsite-icon-verify#^f1]], [[lolsite-icon-verify#^f4]], [[moon-poro-bot#^f1]], [[moon-poro-bot#^f2]], [[moon-poro-bot#^f3]], [[riotapi-schema#^f18]]
- C7: Riot treats API data as possibly GDPR personal data, passes erasure lists to developers, and recommends refreshing stored players at least every 30 days. for: [[riot-dev-terms#^f14]], [[riot-dev-terms#^f6]], [[riot-devrel-gdpr-rtbf#^f2]], [[riot-devrel-gdpr-rtbf#^f3]]
- C8: Large lookup sites rely on legitimate interests and describe no removal process for players who never signed up; OP.GG removes nothing until Riot deletes the account. for: [[opgg-privacy-policy#^f3]], [[ugg-privacy#^f6]], [[opgg-help-privacy#^f1]], [[opgg-help-privacy#^f3]], [[leagueofgraphs-privacy#^f3]] against: [[opgg-privacy-policy#^f2]]
- C9: Legitimate interests needs a documented three-part assessment, disclosure in the privacy notice, and stopping on objection unless there are compelling grounds. for: [[ico-legitimate-interests#^f2]], [[ico-legitimate-interests#^f5]], [[ico-legitimate-interests#^f6]]
- C10: A UK controller must pay the ICO fee; a micro organisation pays £52 a year and no exemption fits a public lookup site. for: [[ico-data-protection-fee#^f2]], [[ico-fee-exemptions#^f1]]
- C11: A UK controller serving EEA players must appoint an EEA representative unless processing is occasional and low risk. for: [[ico-european-representatives#^f1]], [[ico-european-representatives#^f2]], [[ico-european-representatives#^f4]]
- C12: A small tracker's model for non-users: legitimate interests, objection open to anyone, ownership check before removal, pseudonymised archive, 24-month retention. for: [[counterwatch-data-request#^f1]], [[counterwatch-data-request#^f3]], [[counterwatch-privacy#^f2]], [[counterwatch-privacy#^f5]]
- C13 (inferred): "Your games" can rest on legitimate interests with an icon-gated objection form; Squads should be consent-based with each member proving their Riot ID by the icon check; both move to RSO with the production key. from: C1, C6, C9, C12

## Disagreements

- OP.GG's privacy policy grants erasure of game data ([[opgg-privacy-policy#^f2]]) but
  its help centre says it never deletes or modifies summoner data
  ([[opgg-help-privacy#^f3]]). Only a regulator decision would settle whether mirroring
  the API satisfies erasure
- Retention: League of Graphs keeps player ids 10 years after last play
  ([[leagueofgraphs-privacy#^f4]]), Counterwatch 24 months ([[counterwatch-privacy#^f5]]),
  U.GG open-ended ([[ugg-privacy#^f3]]). Riot sets no period beyond deletion on
  termination and 30-day refresh
- Icon pool size: Moon Poro picks from 28 icons, lolsite from 5 (a guess passes about 1 in
  5; our arithmetic)

## Open

- Does Riot accept the icon check as opt-in for Squads? No evidence either way; ask in the
  production application
- Does a 24/7 crawler count as monitoring behaviour (ruling out the "occasional"
  exemption for an EEA representative)? EDPB territorial scope guidelines queued
- Are Riot IDs of streamer-mode players returned by match-v5 after the match? Untested
- Current Riot Channels deletion mechanism needs a portal login; not checked
- No regulator action against a League lookup site found; deeplol privacy policy queued
