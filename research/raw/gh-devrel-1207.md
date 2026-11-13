# #1207 [Application Review] Production API Key - Pending Review ~6 months (App ID: 835226, LOL Guided Review)

Opened 2026-11-06T22:44:16Z by renanborgescampos, state open

**Account Information**
- Riot ID: Jogador 1987#BR1
- Long-time League of Legends player; this account was not created only for the Developer Portal.

**Application Information**
- App ID: 835226
- Product name: LOL Guided Review
- Key type: Production API Key, League of Legends (no Tournament API)
- Product URL: https://lolguidedreview.com
- Verification file: https://lolguidedreview.com/riot.txt
- Submitted: 11 May 2026
- Current status: Pending Review (179 days as of 6 November 2026)
- Support ticket: 00552L-9ZG60, opened 29 May 2026, no reply beyond the automatic acknowledgement

**What the product does**
LOL Guided Review is a post-game review tool. A player links their own Riot ID, the app pulls their recent matches with timeline data, and turns each game into a guided self-review: auto-graded fundamentals, a breakdown of each death, and progress goals over time. It only looks at the player's own games after they end. It has no live-game features and gives no in-game advantage.

**Riot API usage**
- account-v1 (Riot ID lookup when the player links their account)
- match-v5 (match list by PUUID, match details, match timeline)
- league-v4 (ranked entries by PUUID, for rank display)

Match and timeline payloads are cached, so each match is fetched once and requests stay well within the key's limits.

**Issue Description**
The application has been in Pending Review since 11 May 2026 with no approval, rejection, or request for more information. The Developer Portal FAQ says applications are reviewed weekly and can take a few weeks during busy periods; this is now close to six months.

As far as I can tell, nothing is outstanding on my side:
- Domain ownership was verified at submission, and the verification file is still being served at the URL above.
- The product is deployed, so there is a working app to review.
- There are no unread messages in the MESSAGES tab on the Developer Portal.
- I have not edited or resubmitted the application since 11 May, to avoid losing my place in the queue.
- Paid plans are switched off until the product is approved, as the policy requires, and the product keeps an ongoing free tier after approval.

**Request**
Could someone from Developer Relations take a look at App ID 835226, or let me know if anything else is needed to move the review forward? I am happy to provide a demo account, a video walkthrough, or any other information.

Thank you for your time.


