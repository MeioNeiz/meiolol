---
status: answered
priority: soon
area: policy
tags: [policy, data, tools]
description: Would Riot grant meiolol a production API key, and what does the application need?
---
# Would Riot grant meiolol a production API key, and what does the application need?

Feeds: whether and when to apply for a production key; what to build before applying; feature limits (no plan file yet)

## Answer

Uncertain, leaning approvable, but slow. Champ select pick recommenders, including ML ones showing
win rates, run publicly at scale (iTero, LoLDraftAI, Mobalytics, Porofessor, Blitz, U.GG) and Riot's
champ select restrictions target player identity and automation, not pick suggestions (C1, C2). Riot's
own rules draw the line at apps that "dictate player decisions" or "solve our games"; offering several
options with reasons is explicitly allowed (C3). No public record of a Riot decision on a draft/AI app
exists; two comparable 2026 applications are still pending (C4). Review is 3-9 months in practice (C5),
reported rejections are about broken or unclear sites (C6), a new production key starts near dev
limits with increases via a later ticket (C7). Personal keys are not upgraded in place and cannot serve
the public (C8). Nothing in Riot's terms or policies addresses ML training; the licence is framed
around displaying Game Information and Riot claims derivatives (C9). Must not show other players'
names or stats in Ranked Solo/Duo champ select (C10). Memory access is blocked from 6 Oct 2026; LCU
status under that change is unstated (C11).

## Claims

- C1: Pick recommenders with win rates, including ML-based ones, run publicly without Riot removing the feature. for: [[loldraftai-site#^f2]], [[itero-home#^f2]], [[itero-companion-apps#^f2]], [[ugg-app#^f2]], [[mobalytics-app-download#^f2]], [[overwolf-riot-compliance#^f7]]
- C2: Riot's champ select restrictions target identity (names/stats in solo/duo) and automation, not pick suggestions. for: [[overwolf-riot-compliance#^f3]], [[riot-champ-select-anon-apps-1222#^f1]], [[itero-companion-apps#^f5]], [[itero-companion-apps#^f8]]
- C3: Riot rejects apps that dictate decisions or solve the game, but allows highlighting decisions with multiple choices. for: [[riot-docs-lol#^f10]], [[riot-docs-portal#^f3]], [[riot-policies-general#^f6]], [[riot-support-third-party-apps#^f3]], [[pcgamesn-blitz-plugins#^f3]]
- C4: No public Riot decision on draft/AI apps; comparable 2026 applications still pending. for: [[gh-devrel-1138#^f5]], [[gh-devrel-1192#^f2]], [[gh-devrel-1188#^f1]], [[gh-devrel-staff-activity#^f6]]
- C5: LoL production review observed at 3-9 months in 2026, against an official 1-3 weeks. for: [[darkintaqt-riot-app#^f6]], [[gh-devrel-1126#^f2]], [[gh-devrel-1188#^f5]], [[gh-devrel-1139#^f1]] against: [[riot-faqs#^f2]]
- C6: Reported rejections are for broken, blank or unclear product URLs; Riot wants a working site with user flow, ToS and privacy policy. for: [[gh-devrel-1139#^f2]], [[gh-devrel-1139#^f6]], [[riot-faqs#^f7]], [[riot-docs-portal#^f4]], [[riot-docs-lol#^f7]]
- C7: New production keys start near dev limits; increases need a separate ticket after approval. for: [[darkintaqt-riot-app#^f4]], [[gh-devrel-1126#^f3]], [[gh-devrel-1188#^f4]] against: [[riot-docs-portal#^f9]]
- C8: Personal keys cannot serve the public (incl. open betas) and are not upgraded in place; PUUID encryption is per key. for: [[riot-docs-portal#^f8]], [[gh-devrel-1188#^f3]], [[darkintaqt-riot-app#^f8]]
- C9: No Riot document addresses ML training on API data; licence covers displaying Game Information and Riot claims derivatives. for: [[riot-dev-terms#^f2]], [[riot-dev-terms#^f3]], [[riot-dev-terms#^f12]], [[riot-policies-general#^f9]]
- C10: No other players' names or stats in Ranked Solo/Duo champ select. for: [[riot-champ-select-anon-apps-1222#^f1]], [[overwolf-riot-compliance#^f3]], [[riot-docs-lol#^f5]]
- C11: From 6 Oct 2026 memory access is blocked; official API the only allowed route; LCU not named. for: [[riot-memory-access-removed#^f1]], [[riot-memory-access-removed#^f2]], [[riot-memory-access-removed#^f7]]
- C12: LCU use goes on the same product's application (note on app), one app per game per product. for: [[riot-docs-lol#^f13]], [[riot-faqs#^f4]]
- C14: Riot has denied keys on business model too, not only broken sites (betting/wager site Gamestars, 2016); a 2025 AI-recommendation app was denied production with no stated reason. for: [[gamestars-key-refused#^f1]], [[gh-devrel-1099#^f4]]
- C13 (inferred): Frame meiolol as several explained options that teach draft, never a single "best pick" or uplift claim. from: C3, C1

## Disagreements

Review time: Riot FAQ says weekly, up to three weeks (A, but stale) vs 3-9 months from many
independent 2025-2026 developer reports (B/C). Practice wins. Starting limits: docs say 500/10s
(stale since at least 2022) vs community "same as dev". A recent approval quoting its limits would settle it.

## Open

- Does Riot count the LCU as an "official API" under the 2026 memory change?
- Would Riot object to training ML models on match-v5 data? Ask in the application itself.
- Porofessor and OP.GG desktop FAQs not read (403); leads logged.
