# #1194 [Account] Production application fails: Selected app type is not available

Opened 2026-09-20T13:59:46Z by carry-max, state open

**Account Information**
Riot ID: FCY cary#fcy
I have played Riot games and created this Developer Portal account to register a public VALORANT coaching product.

**Issue Description**
Submitting a production application for a VALORANT product fails after all required fields, policy acknowledgements, and VALORANT API requirement checkboxes are completed. The portal returns:

`Failed to create application!`
`Selected app type is not available`

Product: RadiantAI
Public URL: https://radiantai.jp
Game focus: VALORANT
Tournaments: No
Date reproduced: September 20, 2026

The application is for a public, post-match coaching product. It uses Riot Sign On after approval and only reviews the connected player's permitted match history. It does not provide real-time advice, opponent scouting, or in-match decision support.

**What I've Tried**
- [x] Logged out and back into the Developer Portal
- [x] Confirmed the Developer Portal account and development app exist
- [x] Submitted with the Default Group
- [x] Created a separate group named RadiantAI and submitted with that group
- [x] Confirmed the product URL, Terms, and Privacy pages are publicly accessible
- [x] Confirmed all VALORANT acknowledgements were checked

Both the Default Group and RadiantAI group submissions return the same error. No production application is created.

**Repro Steps**
1. Sign in to the Developer Portal.
1. Select Register Product.
1. Choose production API Key.
1. Accept the General and Tournament policies.
1. Enter a product name, full description, valid public URL, VALORANT as the game focus, No for tournaments, and select a product group.
1. Accept the VALORANT policy modal.
1. Select all seven VALORANT API requirements acknowledgements.
1. Click Submit.
1. Observe `Selected app type is not available` and the application is not created.

**Issue Context**
Could you enable the production application type for this Developer Portal account, or advise which eligibility or account setting is missing? The product and public review pages are ready, and no API key or secret is included in this report.


## Comment by Cypherous (NONE) at 2026-09-20T22:36:49Z

It let me create a valorant prod key request using the default group, are you sure your browser isn't blocking something?


## Comment by GuikRocha (NONE) at 2026-09-21T19:37:05Z

Same here: VALORANT, Production key, Default Group, today (2026-09-21).

Flow: Register Product (Production) > I Agree on the General and Tournament policies > form filled (name, full description with a link to a public prototype page, product URL, Game Focus = VALORANT, tournaments = No) > NEXT > all 7 VALORANT acknowledgements checked > SUBMIT. Every time: redirect to /app-type with "Failed to create application! Selected app type is not available", and no application is created under the account. Tried twice from a clean session (straight from /terms-general/?type=production), same result.

Re @Cypherous: Chrome, logged in normally; the form POST itself goes through (the flash message comes back from the server), so it does not look like something blocked client-side. Will retry from another browser and report back.

Account: GuikRocha. Product: https://guikrocha.com.br (live).


## Comment by GuikRocha (NONE) at 2026-09-21T22:00:51Z

Follow-up: reproduced again from a clean browser profile (no extensions, no blockers), same account, Default Group, VALORANT, Production key. Full flow: Register Product > General + Tournament policies accepted (redirect to /terms-general/?type=production) > form > NEXT > VALORANT policies modal accepted > all 7 acknowledgements checked > SUBMIT. Response is still the redirect to /app-type with "Failed to create application! Selected app type is not available", and nothing is created under /apps.

So it is not browser-side. Opened a support ticket as well and will report back if it gets resolved there.


## Comment by Cypherous (NONE) at 2026-09-21T22:11:06Z

Well i would try with a fresh account that has played valorant to see if its your account, if you're getting the same issue on a fresh account then its likely not something serverside


## Comment by 1Terrikola (NONE) at 2026-10-08T09:00:57Z

@Cypherous 

Do you know if it's mandatory to keep updating the API key every day until we get a response from Riot?

I applied for an API key for LoL more than a month ago. I've been reading comments saying you have to wait approximately 3-8 months, and it's kind of boring having to update the API key every day.


## Comment by pepeipto (NONE) at 2026-10-20T02:57:36Z

Update from a League of Legends developer: this is still happening on 2026-10-20, and it is **not account-specific**.

- Product: Coach LoL IA (https://www.coachlolia.com), a free LoL companion app (LEAGUE-V4, MATCH-V5, CHAMPION-MASTERY-V4).
- Flow: Register Product → Production API Key → accept the General + Tournament policies → form (Default Group, public product URL with Privacy/Terms pages, Game Focus: League of Legends, tournaments: No) → Submit → redirected to `/app-type` with "Failed to create application! Selected app type is not available", and nothing is created under `/apps`.
- Reproduced on 2026-10-19 and 2026-10-20 on **two different Riot accounts**, from a clean session. This answers the "try a fresh account" suggestion above: a second account fails the same way.
- **Personal** keys fail with the exact same error, so no new application of any type can be created.
- Support ticket 139751800 opened on 2026-10-19, no reply yet.

So far this affects VALORANT and League of Legends, Production and Personal, on several accounts. That points to the server-side app-type check rather than to individual accounts or browsers.

@GuikRocha @carry-max did your support tickets get any answer, or did anything (a different group, region or game) let you submit? And has anyone created a new application successfully since 2026-09-20?



## Comment by Cypherous (NONE) at 2026-10-20T03:08:05Z

Have you tried using a different device or browser, I have had no issues completing these steps myself, make sure you aren't accidentally blocking a script etc

@1Terrikola you should be able to just leave it, they mainly want to see what the site does and you can just have a guide showing the user flow in detail, they also have the ability to reactivate the key if they need to


## Comment by pepeipto (NONE) at 2026-10-20T03:24:08Z

Thanks @Cypherous! Tried that just now (2026-10-20):

- A completely separate browser (a clean Chromium-based profile with no extensions, no ad/script blockers) on the same PC, plus the original Chrome with a fresh session.
- Two different Riot accounts.
- Production and Personal.

Same result every time: Submit → redirected to `/app-type` with "Failed to create application! Selected app type is not available", nothing created under `/apps`. The form itself loads fine (Default Group selected, Game Focus = League of Legends, tournaments = No) and no request is blocked in the browser.

I'll try from a different device/network as well. If anyone has a working path (e.g. a specific group, or applying from an existing app's page), I'd really appreciate it.



## Comment by 1Terrikola (NONE) at 2026-10-20T08:59:07Z

Thanks @Cypherous, thanks for the answer, this saves me a lot of time updating the API key


## Comment by pepeipto (NONE) at 2026-10-21T23:15:02Z

Update: it worked for me on 2026-10-22 by switching browser engine. Every attempt in Chrome and in another Chromium-based browser failed with "Selected app type is not available"; the same flow in **Firefox** created the Production application straight away, and the portal then showed the riot.txt verification step.

So if you're still stuck: try Firefox (or Safari on another device) instead of any Chromium-based browser. A developer in the community Discord reported the same fix on 2026-10-11 ("tried in a diff browser, it works").

Thanks @Cypherous for the suggestion!


