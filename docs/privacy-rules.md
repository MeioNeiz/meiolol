# Privacy rules: what is required and what we chose

Audit 20 Oct 2026 after J10 (docs/plan/decisions.md): public games are public data, so
self-imposed privacy rules go; keep only what law (UK/EU GDPR) or Riot policy requires.
Quotes are from research/ (josearch store; `josearch show <slug>#^fN`). Verdicts:
**Riot** or **law** (required, with the source), **self** (our choice, may go), **self,
keep** (our choice, cheap and harmless, or it deletes data: only Jacob changes it).

## Riot policy

| Rule | Where | Verdict |
| --- | --- | --- |
| No other players' names or stats in Ranked Solo/Duo champ select | src/lcu/session.zig redact, src/lanecard.zig, app_main.zig, docs/production-key.md "Product rules" | Riot: "Apps that reveal player names or stats in Champ Select will be asked to remove this feature immediately. This specifically applies only to Ranked Solo/Duo" (riot-champ-select-anon-apps-1222#^f1) |
| Same, in every other queue's champ select (flex, normals) | same code: redact runs on every session | self, keep: the Riot application text promises "never shows other players' names or statistics" for the app; changing it means editing the application (Jacob) |
| Other players' ranks only post-game (lab win chance scopes) | src/lab/api.zig Scope | self in part: Riot allows from the loading screen, "you will as soon as you hit the loading screen" (riot-champ-select-anon-apps-1222#^f4). Lab only, no page; loosen if an in-game feature needs it |
| Never show or analyse players hidden by the game (streamer mode, champ select) | docs/legal/lia.md safeguards, method page | Riot: "Products cannot identify or analyze players who are deliberately hidden by the game" (riot-docs-lol#^f5); "Products cannot de-anonymize players who cannot reasonably be identified from visible information" (riot-policies-general#^f10). Streamer mode hides the Riot ID "in third party apps" (riot-dev-streamer-mode-2025#^f1), "only for the duration of the match. Match History and Replays are not affected" (riot-support-anonymizing-riot-id#^f2); match-v5 neither blanks nor marks those players (match-v5-streamer-check#^f1, riotapi-schema#^f22), only spectator-v5 does (riotapi-schema#^f21). So: no live games or champ select names; finished games may name everyone (research/questions/streamer-mode-names.md) |
| No MMR or hidden rank inference | method page "never does", lia.md | Riot: "Prohibited alternatives include MMR or ELO calculators" (riot-policies-general#^f7) |
| Several options with reasons, no auto pick/ban/lock, no dodge advice | production-key.md, prose.zig download | Riot: "may highlight decisions that are important and give multiple choices" (riot-policies-general#^f6); "Apps that dictate player decisions" unapproved (riot-docs-lol#^f10). Not privacy, listed for completeness |
| Custom game history only with opt-in | none shown (we crawl ranked only) | Riot: "may not publicly display a player's match history from the custom match queue unless the player opts in" (riot-docs-lol#^f15) |
| Honour Riot's deletion lists | `meiolol forget --list`, api.cache.forget | Riot: "we will be passing the request to all active developers by sharing a list of identifiers" (riot-dev-terms#^f6); GDPR erasure |
| Refresh stored players every 30 days, drop accounts Riot reports gone | crawler writer (hourly prune, 404 deletes), api 30-day prune | Riot (recommended): "we recommend updating the accounts of players at least once every 30" days (riot-devrel-gdpr-rtbf#^f3) |
| Do not break privacy rights or law | everything below | Riot: "Using the Riot Games API for any Application to violate anyone's privacy rights" is prohibited (riot-dev-terms#^f13) |

## Law (UK GDPR and EU GDPR)

| Rule | Where | Verdict |
| --- | --- | --- |
| Lawful basis: legitimate interests, with a written assessment | docs/legal/lia.md, privacy page | law: "You should keep a record of your legitimate interests assessment" (ico-legitimate-interests#^f5) |
| Objection and erasure for anyone: "Remove a Riot ID" (icon check), email, do-not-collect list, erasure reaching backups, archive, snapshots | src/api (forget), `meiolol forget`, backup.zig, lab/archive.zig forget, docs/data-safety.md | law: on objection "you must stop unless you can show that you have compelling legitimate grounds" (ico-legitimate-interests#^f6). The icon check is identity verification before acting on a request: keep |
| A true privacy page (what, why, how long, rights) | src/site/prose.zig privacy, docs/legal/privacy.md | law (transparency): disclosure in the privacy notice is part of legitimate interests (identity-and-privacy C9). Quote of Art 13/14 not yet in research/ |
| Some retention limit on personal data | writer 24-month PUUID blank, backup.sweepAged, archive-age, 30-day Your games prune, 14-day server logs | law requires a limit (storage limitation, Art 5(1)(e); not yet quoted in research/). The lengths (24 months, 30 days, 14 days) are ours: **self, keep** (they delete data; Jacob only) |
| ICO fee, EEA representative | not built | law: identity-and-privacy C10, C11. Open, for Jacob |

## Self-imposed

| Rule | Where | Verdict |
| --- | --- | --- |
| Daily Draft game at least a week old | src/daily.zig min_age_days, daily page, method page "Daily Draft" | self (Q2, dropped by J10). daily2's area |
| Daily Draft and Learn puzzles carry no names, Riot IDs, match ids, dates; only team totals and one approximate tier | src/daily.zig, src/learn.zig, privacy page | self. Showing per-seat ranks or stats is allowed by J10; daily2 decides. If added, the privacy page's Daily Draft line and lia.md "Safeguards" must say so |
| "Never shows other players" site-wide (method page lead and "never does" list) | src/site/prose.zig method | self beyond champ select: narrowed to champ select (Riot) and hidden players on 20 Oct |
| Your games showed no teammate or opponent names | src/api/game.zig, api/cache.zig, review.js | self, dropped 20 Oct (J18): a Players panel names all ten as at the game (api.db `match_names`, erased with the player); lia.md rebalanced |
| Your games example player anonymised | src/api/example.zig, `meiolol your-example` | self, keep: a reviewer demo, a real name adds nothing |
| Raw archive drops Riot IDs, hashes PUUIDs and match ids | src/lab/archive.zig, anonymise.rewriteMatch | self, keep: rewrites stored data; changing it is a data job (Jacob) |
| Analysis snapshots (Mac, gpu-box) salted-hashed | src/lab/anonymise.zig, deploy/snapshot-gpu.sh | self, keep: lab copies, no page; hashing costs nothing |
| nginx keeps no access log for /api/, the service never logs Riot IDs, no record of who looked up whom | jomify nginx, api service, docs/your-games.md | self, keep: costs nothing, and logs would otherwise need their own retention and erasure |
| Admin log redaction | src/admin.zig redact | not a player privacy rule (keeps secrets and commit subjects off the admin page) |

## For Jacob (not changed: data, retention, application text or servers)

- Retention lengths: 24 months for PUUIDs in matches, backups and the archive; 30 days
  for Your games players; 14 days for server logs. All ours; law only asks for a limit
- Raw archive: keep stripping Riot IDs, or keep them for 24 months like PUUIDs?
- Riot application text (docs/production-key.md draft 18 Oct) says Daily Draft has "no
  player names" and the app never shows other players: true today; update it if Daily
  Draft gains names or ranks
- Names on public pages (J18): done for Your games 20 Oct, lia.md rebalanced (privacy
  agent, data/team/2026-10-20-morning/privacy.md). Daily Draft still names nobody: see
  that note's questions. Streamer mode: match-v5 does not mark it, Riot hides names
  only during the match; we show no live games
