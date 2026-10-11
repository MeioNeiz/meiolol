# Riot Developer Portal

<https://developer.riotgames.com/docs/valorant>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://developer.riotgames.com/docs/valorant#d8a2a468-358e-44c6-85e1-01e257db7e2d)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

-   [APIs](https://developer.riotgames.com/apis)
-   Docs
    
-   Policies
    
-   [Faqs](https://developer.riotgames.com/docs/faqs)
-   Channels
    
-   [Support](https://support-developer.riotgames.com/)

-   [Login](https://developer.riotgames.com/login)

[Developer API Policy](https://developer.riotgames.com/docs/valorant#developer-api-policy)

[Registration](https://developer.riotgames.com/docs/valorant#developer-api-policy_registration)

[Monetization](https://developer.riotgames.com/docs/valorant#developer-api-policy_monetization)

[Security](https://developer.riotgames.com/docs/valorant#developer-api-policy_security)

[Game Integrity](https://developer.riotgames.com/docs/valorant#developer-api-policy_game-integrity)

[Tournament Policies](https://developer.riotgames.com/docs/valorant#developer-api-policy_tournament-policies)

[Game Policy](https://developer.riotgames.com/docs/valorant#game-policy)

[Use Cases](https://developer.riotgames.com/docs/valorant#game-policy_use-cases)

[RSO Integration](https://developer.riotgames.com/docs/valorant#rso-integration)

[Getting a Production Key](https://developer.riotgames.com/docs/valorant#rso-integration_getting-a-production-key)

[Implementing RSO](https://developer.riotgames.com/docs/valorant#rso-integration_implementing-rso)

[Assets](https://developer.riotgames.com/docs/valorant#rso-integration_assets)

[Valorant Official APIs](https://developer.riotgames.com/docs/valorant#valorant-official-apis)

[Valorant Tournament Policies](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies)

[Community Competition Tiers](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_community-competition-tiers)

[I. Application Process](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_i-application-process)

[II. Trademarks or Affiliation](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_ii-trademarks-or-affiliation)

[III. Entry Fees](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_iii-entry-fees)

[IV. Prizing](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_iv-prizing)

[V. Duration](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_v-duration)

[VI. Broadcasting](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_vi-broadcasting)

[VII. Sponsors & Partners](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_vii-sponsors-partners)

[VIII. Merchandising](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_viii-merchandising)

[IX. Riot Games’ Rights to Content](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_ix-riot-games-rights-to-content)

[X. Legal Terms](https://developer.riotgames.com/docs/valorant#valorant-tournament-policies_x-legal-terms)

[Getting Help and Staying Up-to-date](https://developer.riotgames.com/docs/valorant#getting-help-and-staying-up-to-date)

[Terms](https://developer.riotgames.com/terms)  ·   [Privacy](https://www.riotgames.com/en/privacy-notice)

© 2021 Riot Games, Inc. All rights reserved. League of Legends and Riot Games are trademarks, service marks, and registered trademarks of Riot Games, Inc.

Valorant

# Developer API Policy

Before you begin, read through the [General](https://developer.riotgames.com/policies/general) and [Game Policies](https://developer.riotgames.com/policies/game-specific#_legends-of-runeterra), [Terms of Use](https://developer.riotgames.com/terms) and [Legal Notices](https://www.riotgames.com/en/legal). Developers must adhere to policy changes as they arise.

## Registration

If your product serves players, you must register it with us regardless of whether or not your product uses official documented APIs. You must make sure its description and metadata are kept up to date with the current version of your product.

## Monetization

To monetize your product, you must abide by the following:

-   Your product cannot feature betting or gambling functionality.
-   Your product must be registered on the Developer Portal and your product status is either Approved or Acknowledged.
-   You must have a free tier of access for players, which may include advertising.
-   Your content must be transformative if you are charging players for it.
-   What is transformative?
    -   Was value added to the original by creating new information, new aesthetics, new insights, and understandings? If so, then it was transformative.
-   Acceptable ways to charge players are:
    -   Subscriptions, donations, or crowdfunding.
    -   Entry fees for tournaments.
    -   Currencies that cannot be exchanged back into fiat.
-   Your monetization cannot gouge players or be unfair, as decided by Riot.

If you are unsure if your monetization platform is acceptable, contact us through the Developer Portal.

## Security

You must adhere to the following security policies:

-   Do not share your Riot Games account information with anyone.
-   Do not use a Production API key to run multiple projects. You may only have one product per key.
-   Use SSL/HTTPS when accessing the APIs so your API key is kept safe.
-   Your API key may not be included in your code, especially if you plan on distributing a binary.
-   This key should only be shared with your teammates. If you need to share an API key for your product with teammates, make sure your product is owned by a group in the Developer portal. Add additional accounts to that account as needed.

## Game Integrity

-   Products cannot alter the goal of the game (i.e. Destroy the Nexus).
-   Products cannot create an unfair advantage for players, like a cheating program or giving some players an advantage that others would not otherwise have.
-   Products should increase, and not decrease the diversity of game decisions (builds, compositions, characters, decks).
-   Products should not remove game decisions, but may highlight decisions that are important and give multiple choices to help players make good decisions.
-   Products cannot create alternatives for official skill ranking systems such as the ranked ladder. Prohibited alternatives include MMR or ELO calculators.
-   Products cannot identify or analyze players who are deliberately hidden by the game.

## Tournament Policies

-   Tournaments must:
-   Follow all monetization policies above.
-   Allot at least 70% of the entry fees to the prize pool.
-   Win conditions must be fair and transparent to players (we determine fair).
-   Must have at least 20 participants.
-   Not include any gambling.
-   If you are a tournament organizer operating in the US or Canada please refer to, and adhere to, Valorant Tournament Policies section at the bottom of this page or download the [comprehensive document](https://static.developer.riotgames.com/docs/VAL/NA%20VALORANT%20Community%20Competition%20Guidelines%20v1.5.pdf).
-   If you are a tournament organizer operating in Europe/Asia/Pacific, please refer to, and adhere to, these [European tournament organizer policies](https://riot.eurcommunitycompetition.com/games/valorant/guidelines).

# Game Policy

**Note:** Personal Key Applications are currently not supported.

## Use Cases

Riot analyzes two main factors when evaluating applications:

-   Is the use case good and approved?
-   Does the developer show they will deliver on that use case?

To demonstrate that your app meets the use case, you should have one or more of the following:

-   Be an established brand that wants to add Riot Games to its portfolio.
-   New app that is fully functional and testable by Riot.
-   Prototype that is mostly testable by Riot.
-   Mockups where Riot can clearly express your intent and the user flow.
-   A deck that shows your ambition and intent and some of the user flow.

Riot needs to see the user flow to understand what your intended player experience is, such as account creation process, login pipeline, or queuing up for match pipeline.

You must also send a link to a working site, mockup, prototype, or rendering where it is easy to understand the user flows of the tool.

**Note:** All apps must include functionality requiring a player to opt-in to sharing their data. This is done through RSO integration, as well as a disclaimer within your app that account linking makes player data public.

**Disclaimer:** All third-party Valorant sites approved for RSO must include a disclaimer for Opt-in policies, where all players must first sign up for their service to display their stats/gameplay data. If players have not opted into data sharing in their ecosystem, their information should not be made available to other players through their website, applications, or game overlays.

### Examples of Approved Use Cases

#### Require Player Opt-in

The following accepted use cases require a player to opt-in:

-   Showing player stats.
-   Running tournament brackets with verified players.
-   Tournaments.
-   Training tools that allow players to view their own match histories and aggregate stats.
-   LFG tools.
-   Apps to assist live streaming, such as pulling player stats.
-   Discord Bots showing community leaderboards, stats for server members.

#### Do Not Require Player Opt-in

The following accepted use cases do not require a player to opt-in:

-   Aggregate player stats without any specific players.
-   Official ladder leaderboards.

  

### Examples of Unapproved Use Cases

The following use cases will not be approved:

-   Scouting, which is seeing an opponents stats before a match starts.
-   Apps that are not public and are designed for personal use only.
-   Online store tracking or updates. The technology for this does not currently exist in the API.
-   In-game apps and overlays that include any real-time data that would improve a player’s performance immediately by altering player behavior (i.e. ‘go here now’), vs altering it upon reflection, learning and coaching the player game over game.
-   Static in-game overlays that block parts of the map.

# RSO Integration

All VALORANT apps must request that users opt-in to sharing their personal data. To do this, your application will need to verify players using an OAuth flow. This is done through Riot Sign On (RSO) using an RSO Client.

RSO or Riot Sign On, allows players to safely link their Riot Account to other applications. This access is only available to developers with Production Level API Keys.

## Getting a Production Key

Before you can get started with RSO, you will need a production key. If you do not have one, please request one at [developer.riotgames.com](https://developer.riotgames.com/) after reading through our policies. If approved, we will contact you in the developer portal app messaging to kick off the RSO integration process.

## Implementing RSO

All VALORANT apps must request that users opt-in to sharing their personal data. To do this, your application will need to verify players using an OAuth flow. This is done through Riot Sign On (RSO) using an RSO Client.

-   Client Secret Basic RSO instructions: [Implementing Riot Sign On](https://docs.google.com/document/d/1_8i2PvPA3edFHIh1IwfO5vs5rcl04O62Xfj0o7zCP3c/edit?pli=1)
-   JWT RSO instructions: [Implementing RSO - JWT](https://docs.google.com/document/d/e/2PACX-1vTSthxkWOIqPFe8Xqqjv4Ona5pRa5W3X6bLg4I47X15gJjG9ae-HU5a0by7VIVLWdPMgB9fTr5gvQcY/pub)
-   [Sample RSO Node App](https://static.developer.riotgames.com/docs/rso/rso-example-app.zip)

Players should be directed to login at this link:

[https://auth.riotgames.com/authorize?client\_id=&redirect\_uri=&response\_type=code&scope=openid+offline\_access](https://auth.riotgames.com/authorize?client_id=&redirect_uri=&response_type=code&scope=openid+offline_access).

After logging in, players are redirected back to the redirect\_uri you specified.

Your RSO client has access to endpoints that will allow you to identify who logged in. For VALORANT, you will use [/riot/account/v1/accounts/me](https://developer.riotgames.com/apis#account-v1/GET_getByAccessToken):

```
curl --location --request GET 'https://americas.api.riotgames.com/riot/account/v1/accounts/me' --header 'Authorization: Bearer {accessToken}'
curl --location --request GET 'https://europe.api.riotgames.com/riot/account/v1/accounts/me' --header 'Authorization: Bearer {accessToken}' 
curl --location --request GET 'https://asia.api.riotgames.com/riot/account/v1/accounts/me' --header 'Authorization: Bearer {accessToken}' 
```

## Assets

### Public Content Catalog

The public content catalog is a set of VALORANT assets, including icons, logos, text, etc. that is free to use. The file contains both images and a .json with all the textural information.

Updating the public content catalog after each VALORANT patch is a manual process, so it is not always updated immediately after a patch.

[https://valorant.dyn.riotcdn.net/x/content-catalog/PublicContentCatalog-release-08.09.zip](https://valorant.dyn.riotcdn.net/x/content-catalog/PublicContentCatalog-release-08.09.zip)

# Valorant Official APIs

For the most comprehensive information on our APIs, see the [Developer API site](https://developer.riotgames.com/apis).

| API | Method | Description |
| --- | --- | --- |
| [VAL-CONTENT-V1](https://developer.riotgames.com/apis#val-content-v1) | `/val/content/v1/contents` | Get content; optionally filtered by locale |
| [VAL-MATCH-V1](https://developer.riotgames.com/apis#val-match-v1) | `/val/match/v1/matches/{matchId}` | Get match by ID |
|  | `/val/match/v1/matchlists/by-puuid/{puuid}` | Get matchlist for games played by PUUID |
|  | `/val/match/v1/recent-matches/by-queue/{queue}` | Get recent matches |
| [VAL-RANKED-V1](https://developer.riotgames.com/apis#val-match-v1) | `/val/ranked/v1/leaderboards/by-act/{actId}` | Get leaderboard for the competitive queue |
| [VAL-STATUS-V1](https://developer.riotgames.com/apis#val-status-v1) | `/val/status/v1/platform-data` | Get VALORANT status for the given platform |

# Valorant Tournament Policies

## Community Competition Tiers

| Tier | Organizer | Platform / Scale | Organizer Goal | Riot’s Contribution |
| --- | --- | --- | --- | --- |
| **Small Tournaments** | Players, PC Cafes, Community Organizers | Prize Pool ≤$10,000 USD (or $12,000 in non-cash); Local event only | Fun, Organized, Social Play | No IP use other than the IP provided[here](https://developer.riotgames.com/docs/valorant#) |
| **Medium Tournaments** | Endemic Amateur TOs, Esports Orgs, Influencers | Prize Pool ≤ $50,000 USD; No guaranteed implications in VALORANT Global Esports | Monetization / Brand or Business Growth | Based on agreement with regional Riot team |
| **Major Tournaments** | Major Esport Event Organizers (e.g., ESL, DreamHack, OGN) | Official Semi-Pro; Part of Global Competitive Ecosystem | Monetization + Contribution to Global Ecosystem | Based on agreement with global Riot team |

## I. Application Process

-   **Small Tournaments**: No application needed; follow these guidelines.
-   **Medium Tournaments**: Custom license required. Apply to your regional Riot Esports team.
-   **Major Tournaments**: Custom license required. Apply to the Global Riot Esports team.

## II. Trademarks or Affiliation

-   **Small Tournaments**:
    
-   May use "VALORANT" name but not "Championship", "League", etc.
    
-   No Riot logos or trademarks.
-   Must display: _"This competition is not affiliated with or sponsored by Riot Games, Inc. or VALORANT Esports."_
-   **Medium & Major Tournaments**:
    
-   May request permission to use Riot/VALORANT assets.
    
-   No title sponsors or branded tournaments.

## III. Entry Fees

-   Entry fees allowed to cover event costs or fund prize pools.
-   Crowdfunding allowed but funds must go to event costs or prizes.

## IV. Prizing

-   **Small**: Max $10,000 per event; $100,000/year.
-   **Medium**: Max $50,000 per event; $200,000/year.
-   **Major**: Riot may contribute.

## V. Duration

-   **Small & Medium**:
-   Max 8 weeks total.
-   High school/college events: Max 5 months (Aug–Dec or Jan–May).

## VI. Broadcasting

-   **Small**:
-   Free to stream on any platform (except TV); must moderate chat and disable "Show Blood".
-   **Medium & Major**:
-   Must follow broadcast terms in custom license.
-   Riot may request promotion of Riot channels if they contribute/support.

## VII. Sponsors & Partners

-   **Small**:
    
-   Sponsors allowed (unless on **Prohibited List**).
    
-   Max $10,000 per tournament / $100,000 per year.
-   **Medium & Major**:
    
-   Same sponsor restrictions. Riot may assist monetization.
    

**Prohibited Sponsors Include**:

-   Other video games or publishers
-   Gambling, tobacco, alcohol, firearms, adult content
-   Cryptocurrencies, political campaigns, unreputable charities, etc.

## VIII. Merchandising

-   **Small**: No sale of Riot/VALORANT-branded merchandise.
-   **Medium & Major**: Riot may allow merchandise or provide items.

## IX. Riot Games’ Rights to Content

By using the Community Competition License:

-   Riot can promote your competition and use its content.
-   You license Riot free and perpetual use of your competition’s media (broadcasts, highlights, etc.).

## X. Legal Terms

-   All competitions must comply with:
-   Riot's guidelines, Terms of Service, and Legal Jibber Jabber
-   Local laws and platform policies (e.g., Twitch, YouTube)

Riot grants a **limited, non-transferable, revocable license** to run VALORANT competitions, but retains the right to shut down any competition that violates policies or values.

# Getting Help and Staying Up-to-date

If you run into any difficulties or are having technical issues, please join [Developer Discord](https://discord.gg/riotgamesdevrel) for support. Follow our [Twitter](https://twitter.com/RiotGamesDevRel) for the latest updates.
