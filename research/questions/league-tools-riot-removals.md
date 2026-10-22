---
status: answered
priority: soon
area: policy
parent: league-apps-feature-matrix
tags: [tools/removed, policy, privacy]
description: What has Riot made League tools remove or change, when, and what does that predict for new features?
---
# What has Riot made League tools remove or change, when, and what does that predict for new features?

Feeds: which features the public app and the private "op" tool may build ([[league-apps-feature-matrix]] C17, C18); docs/production-key.md "Product rules".

## Answer

Riot removes features by DevRel announcement, usually relayed through Overwolf, and does not
exempt apps that already ship them; the pace has risen to several a year (C1). The cuts follow
two lines. Identity in a live lobby: names and stats of others in ranked solo/duo champ select
(12.22, Nov 2022), then streamer-mode players in loading screen and in game (17 Oct 2025);
post-game data stays open (C2, C3). Live in-game help: enemy ult timers (13 Mar 2025), then all
enemy cooldowns, power spike alerts and decision prompts (27 Aug 2025) (C4, C5). Alongside:
data access (LCU rules 2019, Vanguard 2024, memory block 6 Oct 2026) (C6), monetisation (no ads
in game, loading screens or client, 29 May 2025) (C7), and automation (auto-accept gone by Sep
2025; Valorant bans instalock tool users from Sep 2026) (C8).

Nothing so far touches champ select pick suggestions, draft win rates or post-game review
(C9). Riot's own stated trigger is when players start to "need" a tool (C10). For meiolol:
post-game and between-games features are the safest investment; champ select help is tolerated
as suggestions; anything in game or any automation is the next likely cut, even in a private
tool (C11).

## Claims

- C1: Riot cuts common features by announcement with no grandfathering: 2022, three times in 2025, 2026. for: [[riot-champ-select-anon-apps-1222#^f1]], [[mein-mmo-ult-timer-ban#^f3]], [[overwolf-aug-2025-riot-guidelines#^f1]], [[overwolf-riot-creators-response#^f1]], [[porofessor-standalone-reddit#^f4]]
- C2: 12.22 (Nov 2022): no player names or stats in ranked solo/duo champ select, also obfuscated in the API; teammates were scouted before (Mobalytics Fatigue and Hot Streak badges, Tracker multi-search). for: [[riot-champ-select-anon-apps-1222#^f1]], [[riot-champ-select-anon-apps-1222#^f2]], [[overwolf-riot-compliance#^f3]], [[mobalytics-desktop-guide#^f5]], [[tracker-lol-v2#^f4]]
- C3: From 17 Oct 2025 apps cannot identify streamer-mode players in a live game; post-game data unaffected; tools must not analyse hidden players. for: [[sheep-streamer-mode-apps#^f1]], [[riot-dev-streamer-mode-2025#^f2]], [[riot-docs-lol#^f5]]
- C4: Enemy ultimate timers banned from 13 Mar 2025, manual ones included; Porofessor added them weeks before. for: [[mein-mmo-ult-timer-ban#^f1]], [[mein-mmo-ult-timer-ban#^f2]], [[porofessor-standalone-reddit#^f4]], [[riot-developer-api-policy#^f4]]
- C5: Season 3 guidelines (deadline 27 Aug 2025): enemy ability and summoner spell cooldowns, power spike alerts, decision prompts and minor rune data must go; OP.GG's spell tracker went "due to policy changes by Riot Games". for: [[overwolf-aug-2025-riot-guidelines#^f2]], [[overwolf-aug-2025-riot-guidelines#^f3]], [[overwolf-aug-2025-riot-guidelines#^f4]], [[overwolf-aug-2025-riot-guidelines#^f5]], [[opgg-help-desktop#^f1]]
- C6: Data access narrowed: LCU apps need notice and approved endpoints, none in Korea (2019); Vanguard (2024) broke memory readers on purpose; memory blocked for unknown apps from 6 Oct 2026. for: [[riot-devrel-lcu-api-policy#^f2]], [[riot-devrel-lcu-api-policy#^f3]], [[riot-devrel-lcu-api-policy#^f4]], [[lol-dev-vanguard-x-lol#^f3]], [[riot-memory-access-removed#^f1]]
- C7: Since 29 May 2025 no third-party ads in game, loading screens or the Riot Client; Overwolf requires opt-in ad overlays and no upsell in game. for: [[overwolf-riot-creators-response#^f1]], [[riot-policies-general#^f12]], [[overwolf-riot-in-game-ads#^f1]], [[overwolf-riot-in-game-ads#^f3]]
- C8: Automation of selection is out: auto-accept removed from all apps (by Sep 2025), Valorant penalises instalock tool users (Sep 2026); hover automation is still shipped. for: [[itero-companion-apps#^f5]], [[overwolf-team-advisor#^f4]], [[playerone-valorant-instalock#^f1]], [[overwolf-team-advisor#^f2]]
- C9: No removal so far targets champ select pick suggestions, draft win rates or AI review (absence in the 2025 list and three searches). for: [[overwolf-aug-2025-riot-guidelines#^f7]], [[overwolf-riot-compliance#^f7]], [[itero-companion-apps#^f8]]
- C10: Riot's enforcement trigger is when players start to "need" a tool to compete. for: [[pcgamesn-blitz-plugins#^f3]]
- C11 (inferred): Build post-game and between-games depth first; treat in-game help and any automation as off-limits for both products, since cuts carry no grandfathering and bind every product. from: C1, C5, C8, C9, C10

## Disagreements

Auto-accept: iTero says Riot removed it from all apps, but no Riot source was found (C8 rests
on a vendor article and user reviews). Mobalytics still advertises power spike notifications on
Overwolf after the Aug 2025 rule ([[overwolf-mobalytics-desktop#^f4]]): stale copy or a
narrower feature.

## Open

- Riot DevRel X posts for the ult-timer and ad bans (leads); a Riot source for auto-accept
- Any Riot statement on AI or voice coaches (OP.GG AI voice); searches saturated, none found
