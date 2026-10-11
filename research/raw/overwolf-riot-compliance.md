# Riot Games compliance | Overwolf Developers

<https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/>

###### We care about your privacy

We use cookies to improve your experience and increase the relevancy of content when using Overwolf. Our cookies are used for analytics, optimization, and advertising operations. [Learn more](https://legal.overwolf.com/docs/overwolf/cookies-policy/)

 

[Skip to main content](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#__docusaurus_skipToContent_fallback)

[Login](https://dev.overwolf.com/login?returnTo=%2Fow-electron%2Fguides%2Fgame-compliance%2Friot-games%2F)

[

Overwolf Native

](https://dev.overwolf.com/ow-native/getting-started/overview)[

Overwolf Electron

](https://dev.overwolf.com/ow-electron/getting-started/overview)

[Changelog](https://dev.overwolf.com/ow-electron/getting-started/changelog/ow-changelog)

[Roadmap and Blog](https://dev.overwolf.com/ow-electron/getting-started/changelog/roadmap)

-   [Onboarding Journey](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    
-   [Monetization](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    
-   [Real-time Game Events (GEP)](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    
-   [Developers Console](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    
-   [Guides](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    
    -   [Product guidelines](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
        
    -   [Developer tools](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
        
    -   [Testing and debugging](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
        
    -   [Growth](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
        
    -   [Game Compliance](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
        
        -   [App compliance for in-Game overlays and ads](https://dev.overwolf.com/ow-electron/guides/game-compliance/overview)
        -   [Riot in-game ads rules](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-in-game-ads)
        -   [Riot games compliance](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games)
        -   [Call of Duty: Warzone](https://dev.overwolf.com/ow-electron/guides/game-compliance/call-of-duty-warzone-caldera)
        -   [League of Legends](https://dev.overwolf.com/ow-electron/guides/game-compliance/league-of-legends)
        -   [Dota 2](https://dev.overwolf.com/ow-electron/guides/game-compliance/dota-2)
        -   [New World](https://dev.overwolf.com/ow-electron/guides/game-compliance/new-world)
        -   [Rainbow 6 Siege](https://dev.overwolf.com/ow-electron/guides/game-compliance/rainbow-6-siege)
        -   [Teamfight Tactics](https://dev.overwolf.com/ow-electron/guides/game-compliance/teamfight-tactics)
    -   [Webinars](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
        
-   [API Reference](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    
-   [Support and Communication](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#)
    

# Riot Games compliance

# Riot Games compliance

Competitive integrity is one of Overwolf's core values, and it is enforced diligently both in-house and through cooperation with game developers.

## Riot Games app approval

Avoid using the official Riot Logo. Riot asks that you ensure that your standard messaging (below) is located somewhere that users can see it and doesn’t mention their approval or endorsement of your app.

> \[Your app name\] isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games and all associated properties are trademarks or registered trademarks of Riot Games, Inc.

If you wish to integrate your app with any of Riot’s games, you are required to seek their approval through their 3rd party [application process](https://developer.riotgames.com/docs/portal#_getting-started).

Important

These guidelines hold even if you do not intend to use the Riot API itself. Do note that apps which reach the publication phase and do not yet possess a Riot approval will be asked to provide one before proceeding.

note

For information about specific Riot in-game ads, see [Riot Games In-Game Ads Compliance](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-in-game-ads).

## Teamfight Tactics game compliance guidelines[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#teamfight-tactics-game-compliance-guidelines "Direct link to Teamfight Tactics game compliance guidelines")

# Teamfight Tactics

Game ID:5426

Tracking ID: 21570

[Events API & Status](https://dev.overwolf.com/ow-native/live-game-data-gep/supported-games/teamfight-tactics)

Events status:

### Augments and Legends data[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#augments-and-legends-data "Direct link to Augments and Legends data")

Riot Games is committed to creating a fair environment for all players, while reducing metagaming when possible. As such apps should make sure that they do not:

-   Do not display Legend Win rates
-   Do not display Augment Win rates
-   Do not display Augment average game placements

For more details about this policy, see the relevant [Teamfight Tactics Changelog](https://www.leagueoflegends.com/en-pl/news/game-updates/teamfight-tactics-patch-13-12-notes/).

## Valroant game compliance guidelines[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#valroant-game-compliance-guidelines "Direct link to Valroant game compliance guidelines")

# Valorant

Game ID:21640

[Events API & Status](https://dev.overwolf.com/ow-native/live-game-data-gep/supported-games/valorant)

Events status:

Spike timers are not allowed to be shown during a live match, as they give players an unfair advantage and violate Riot’s TOS.

important

Due to recent updates to the [Valorant Developer API Policy](https://support-developer.riotgames.com/hc/en-us/articles/22698769097107-VALORANT), Overwolf has updated the requirements for all related applications:

-   _**Private Apps**_—private apps are no longer accepted regardless of whether or not they utilize the game's API.
-   _**Public Apps**_—public applications must now receive _**formal approval**_ from both **Riot Games** and **Overwolf** before being hosted.

These restrictions apply to all Valorant related projects to ensure full compliance with Riot's ecosystem standards.

## League of Legends game compliance guidelines[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#league-of-legends-game-compliance-guidelines "Direct link to League of Legends game compliance guidelines")

# League of Legends

Game ID:5426

[Events API & Status](https://dev.overwolf.com/ow-native/live-game-data-gep/supported-games/league-of-legends)

Events status:

### General feature compliance[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#general-feature-compliance "Direct link to General feature compliance")

It is strictly prohibited to provide:

-   Notifications that alert players when a power spike hits (e.g. X champion has hit level 6).
-   Notifications that dictate player action based on the current game state (e.g. Enemy champion is underleveled, go gank top lane).
-   Tracking of enemy ability cooldowns, or facilitating players tracking these with timers.
-   Tracking of enemy summoner spells cooldowns, or facilitating players tracking these with timers.

### Timers[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#timers "Direct link to Timers")

-   The use of _**Ultimate timers**_ is strictly forbidden since this may provide an unfair advantage.

### Champion Select Anonymity[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#champion-select-anonymity "Direct link to Champion Select Anonymity")

Riot Games is working to prevent metagaming and queue dodging (among other things). As such apps should make sure that Summoner Names in `Ranked Solo/Duo` champion select should be obfuscated. More specifically:

-   All instances of non-party Summoner Names in Champion Select should be replaced with `Ally #` (`Ally 1`, `Ally 2` and so on). This includes:
    -   In-lobby text chat.
    -   Summoner names displayed inside the draft area.
-   Player designations should be consistent for all players in the lobby. (`Ally 1` should refer to the same player on all clients).

Do note that this only applies during Champion Select, and only to players who are not a part of your party. More specifically:

-   Your own name is not anonymous to yourself.
-   Players who queued in the same party are de-anonymized to each other.
-   Once in the loading screen, players will be able to see summoner names.

### Brawl game mode[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#brawl-game-mode "Direct link to Brawl game mode")

-   Match history for the new _Brawl_ game mode in League of Legends will **NOT** be available through Riot's public API.
-   Riot Games does **NOT** approve any Brawl related data being aggregated or visible on third-party products/apps.

### League Classic[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#league-classic "Direct link to League Classic")

-   Match history for _League Classic_ will **NOT** be available through Riot's public API.
-   Riot Games does **NOT** approve any League Classic data being aggregated or displayed to users, in any form, on third-party products/apps, in order to preserve the spirit of League Classic.

### API restrictions[​](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#api-restrictions "Direct link to API restrictions")

Data no longer available from the API responses:

-   Minor rune data will no longer be visible.

[

Riot in-game ads rules

](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-in-game-ads)[

Call of Duty: Warzone

](https://dev.overwolf.com/ow-electron/guides/game-compliance/call-of-duty-warzone-caldera)

-   [Teamfight Tactics game compliance guidelines](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#teamfight-tactics-game-compliance-guidelines)
    -   [Augments and Legends data](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#augments-and-legends-data)
-   [Valroant game compliance guidelines](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#valroant-game-compliance-guidelines)
-   [League of Legends game compliance guidelines](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#league-of-legends-game-compliance-guidelines)
    -   [General feature compliance](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#general-feature-compliance)
    -   [Timers](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#timers)
    -   [Champion Select Anonymity](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#champion-select-anonymity)
    -   [Brawl game mode](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#brawl-game-mode)
    -   [League Classic](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#league-classic)
    -   [API restrictions](https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games/#api-restrictions)

-   ##### Legal
    
    -   [App Developer Terms](https://legal.overwolf.com/docs/overwolf/developers/developer-terms)
    -   [App Developer Privacy Policy](https://legal.overwolf.com/docs/overwolf/developers/developer-privacy-policy)
    -   [App Developer CCPA](https://legal.overwolf.com/docs/overwolf/developers/developer-california-privacy-act)
    -   [App Developer DPA](https://legal.overwolf.com/docs/overwolf/developers/data-processing-agreement)
    -   [Overwolf Terms](https://legal.overwolf.com/docs/overwolf/website/terms-of-use)
    -   [Overwolf Privacy Policy](https://legal.overwolf.com/docs/overwolf/website/privacy-policy)
-   ##### Support
    
    -   [Discord](https://discord.gg/overwolf-developers)
    -   [Facebook](https://facebook.com/OverwolfDevs)
    -   [X (formerly Twitter)](https://x.com/OverwolfDevs)
-   ##### Overwolf Native
    
    -   [Changelogs](https://dev.overwolf.com/ow-native/getting-started/changelog/ow-changelog)
    -   [API](https://dev.overwolf.com/ow-native/reference/ow-api-overview)
    -   [App Creation Process](https://dev.overwolf.com/ow-native/getting-started/project-roadmap)
    -   [Best Practices](https://dev.overwolf.com/ow-native/guides/general-product/best-practices)
    -   [Game Events Status](https://dev.overwolf.com/ow-native/live-game-data-gep/game-events-status-health)
-   ##### Overwolf Electron
    
    -   [Changelogs](https://dev.overwolf.com/ow-electron/getting-started/changelog/ow-changelog)
    -   [API](https://dev.overwolf.com/ow-electron/getting-started/overview)
    -   [App Creation Process](https://dev.overwolf.com/ow-electron/getting-started/project-roadmap)
    -   [Overwolf Electron technical overview](https://dev.overwolf.com/ow-electron/getting-started/onboarding-resources/ow-electron-technical-overview)
    -   [Game Events Status](https://dev.overwolf.com/ow-electron/live-game-data-gep/game-events-status-health)
-   ##### Information
    
    -   [Careers](https://www.overwolf.com/careers/)
    -   [Fund](https://overwolf.com/fund)
    -   [Roadmap](https://dev.overwolf.com/ow-native/getting-started/changelog/roadmap/)
    -   [Developers Newsletter](https://blog.overwolf.com/tag/developers/)
    -   [Developers Blog](https://medium.com/overwolf)
    -   [Overwolf Appstore](https://www.overwolf.com/appstore)
    -   [Advertise on Overwolf](https://www.overwolf.com/ads/)

Ⓒ 2026 Overwolf. All rights reserved.
