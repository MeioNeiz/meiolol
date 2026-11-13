---
status: answered
priority: now
area: policy
parent: riot-production-key
tags: [policy]
description: What does Riot's production key review look like in late 2026: wait, what reviewers check, why apps fail, and what changed this year?
---
# What does Riot's production key review look like in late 2026: wait, what reviewers check, why apps fail, and what changed this year?

Feeds: docs/production-key.md and docs/plan/review.md (what the live site
must show when Riot looks, and how long to keep it up). Base answer: [[riot-production-key]];
this note adds Oct-Nov 2026 evidence.

## Answer

The wait is long and getting no shorter: LoL applicants report 6-12 months in Oct-Nov
2026, and the nearest analogue to meiolol (a post-game review of the player's own games)
sat at 179 days on 6 Nov with no reply (C1, C2). Riot's own docs still say weekly, up to
three weeks, and were unchanged on 13 Nov (C6). No staff reply on any pending thread;
community advice is wait, don't edit, keep riot.txt served (C3). meiolol applied 11 Oct
2026, so a look is plausible from about April 2027 and could be much later.

What reviewers check (Riot's words): a working, near-complete site that shows the user
flow, ToS and privacy policy, verified ownership, policy compliance and player benefit;
video, screenshots or Figma count as user-flow evidence (C4). The only known 2026
rejection reason is the site being unreachable at review time, with no appeal and a
re-review that then waited months (C5). A community helper predicts rejection for a
build site whose win rates steer picks (C7, weak). Features added after submitting are
re-audited (C8).

Changed in 2026: memory access blocked from 6 Oct (grace for known tools to April 2027;
riot-production-key C11); otherwise no new written rule on champ select, AI or reviews
(C6). The portal relaunch planned in 2023 (no personal/production split, an approved-apps
index) is still only an RSO request page for approved products (C9). New applications
failed for several developers from 20 Sep to at least 20 Oct (C10): a re-application
after a rejection may not even be possible quickly, so avoiding a rejection is worth more.

## Claims

- C1: LoL production reviews run 6-12 months in late 2026 reports. for: [[gh-devrel-1207#^f2]], [[gh-devrel-1208#^f1]], [[gh-devrel-1208#^f2]], [[gh-devrel-1197#^f8]], [[gh-devrel-1143#^f5]], [[gh-devrel-1192#^f8]]
- C2: A post-game own-games review app (closest analogue) was still pending at 179 days with only an automatic ticket reply. for: [[gh-devrel-1207#^f1]], [[gh-devrel-1207#^f2]], [[gh-devrel-1207#^f5]]
- C3: No Riot staff reply on any pending-review thread Oct-Nov 2026; backlog of 14+ open threads. for: [[gh-devrel-1205#^f1]], [[gh-devrel-1205#^f2]], [[gh-devrel-1208#^f4]], [[gh-devrel-1194#^f3]], [[gh-devrel-staff-activity#^f6]]
- C4: Reviewers check a working near-complete site with user flow, ToS and privacy policy, verified domain; video or screenshots show the flow. for: [[riot-faqs#^f1]], [[riot-faqs#^f7]], [[riot-faqs#^f8]], [[riot-faqs#^f11]], [[riot-faqs#^f12]], [[riot-docs-portal#^f2]], [[riot-docs-portal#^f4]], [[gh-devrel-1194#^f2]]
- C5: A site down at review time got an app rejected after 8 months, with no appeal and a re-review still unanswered 8 months on. for: [[gh-devrel-1143#^f2]], [[gh-devrel-1143#^f3]], [[gh-devrel-1143#^f5]]
- C6: Riot's portal, FAQ, LoL docs, general policies and memory-access page were unchanged between Oct and 13 Nov 2026. for: [[riot-docs-lol#^f19]], [[riot-docs-portal#^f16]], [[riot-faqs#^f16]], [[riot-policies-general#^f15]], [[riot-memory-access-removed#^f8]], [[riot-developer-api-policy#^f7]]
- C7: Community view: win rates shown to steer what to pick or build invite rejection. for: [[gh-devrel-1192#^f7]]
- C8: New features or changes after registration are re-audited. for: [[riot-policies-general#^f3]]
- C9: The 2023 portal relaunch is still at step one in Nov 2026: beta handles RSO requests for approved apps only; no approved-apps index. for: [[riot-devrel-new-portal-beta#^f1]], [[riot-devrel-new-portal-beta#^f2]], [[riot-dev-portal-beta#^f1]], [[riot-dev-portal-beta#^f2]], [[gh-devrel-1181#^f1]]
- C10: From 20 Sep to at least 20 Oct 2026 new applications (any type) failed for several developers. for: [[gh-devrel-1194#^f1]]
- C11: Applicants of our kind keep paid plans off until approval and keep a free tier. for: [[gh-devrel-1207#^f3]], [[riot-policies-general#^f5]]
- C12 (inferred): For meiolol: keep meio.lol up and alerting through 2027, show the user flow (app screenshots, video) on the site, keep the site matching the application, and don't add features that change the product described. from: C4, C5, C8, C1

## Disagreements

Wait: Riot FAQ (A, unchanged) says weekly to three weeks; every 2026 report (C, many
independent) says months. Practice wins, as in riot-production-key.

## Open

- No 2026 approval of a LoL stats or draft site found with a date; one would calibrate
  the wait (3 searches found none).
- Whether reviewers read the live site, the application text, or both, and how strictly
  they compare numbers (game counts, regions) between them: no source.
