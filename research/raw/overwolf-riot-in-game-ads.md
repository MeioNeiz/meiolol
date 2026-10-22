# Riot in-game Ads Rules | Overwolf Developers

<https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/>

###### We care about your privacy

We use cookies to improve your experience and increase the relevancy of content when using Overwolf. Our cookies are used for analytics, optimization, and advertising operations. [Learn more](https://legal.overwolf.com/docs/overwolf/cookies-policy/)

 

[Skip to main content](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#__docusaurus_skipToContent_fallback)

[Login](https://dev.overwolf.com/login?returnTo=%2Fow-native%2Fguides%2Fgame-compliance%2Friot-in-game-ads%2F)

[

Overwolf Native

](https://dev.overwolf.com/ow-native/getting-started/overview)[

Overwolf Electron

](https://dev.overwolf.com/ow-electron/getting-started/overview)

[Changelog](https://dev.overwolf.com/ow-native/getting-started/changelog/ow-changelog)

[Roadmap and Blog](https://dev.overwolf.com/ow-native/getting-started/changelog/roadmap)

-   [Onboarding Journey](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    
-   [Monetization](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    
-   [Real-time Game Events (GEP)](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    
-   [Developers Console](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    
-   [Guides](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    
    -   [Product guidelines](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
    -   [Developer tools](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
    -   [Testing and debugging](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
    -   [Maintain Your App](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
    -   [Growth](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
    -   [Game Compliance](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
        -   [App compliance for in-Game overlays and ads](https://dev.overwolf.com/ow-native/guides/game-compliance/overview)
        -   [Riot in-game ads rules](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads)
        -   [Riot games compliance](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-games)
        -   [Call of Duty: Warzone](https://dev.overwolf.com/ow-native/guides/game-compliance/call-of-duty-warzone-caldera)
        -   [Dota 2](https://dev.overwolf.com/ow-native/guides/game-compliance/dota-2)
        -   [New World](https://dev.overwolf.com/ow-native/guides/game-compliance/new-world)
        -   [Rainbow 6 Siege](https://dev.overwolf.com/ow-native/guides/game-compliance/rainbow-6-siege)
    -   [Webinars](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
        
-   [API Reference](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    
-   [Support and Communication](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#)
    

# Riot in-game Ads Rules

Overwolf is committed to ensuring that all apps on its platform strictly adhere to Riot's in-game ad rules. Continuous monitoring and support are provided to app developers to prevent any violations that could impact gameplay or player experience.  
  
This proactive approach helps maintain a trusted ecosystem where players can confidently use apps without concern. Overwolf provides clear guidelines and resources to developers to promote compliance and encourage the creation of high-quality, respectful applications.  
  
For information about specific Riot games, see [Riot games compliance](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-games).  
  
Overwolf recommends that you follow the [Best practices](https://www.figma.com/community/file/1524784631366197139) examples.

## Rule 1 - Overlays with ads must be opt-in by the user[​](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-1---overlays-with-ads-must-be-opt-in-by-the-user "Direct link to Rule 1 - Overlays with ads must be opt-in by the user")

Overlays that display ads must be explicitly enabled by the user through an opt-in action to ensure transparency and consent. This ensures that users maintain control over their experience and are not shown advertisements without their prior agreement.

_**What does this mean?**_

1.  Only show ad-supported overlays after an explicit player action (e.g. hotkey, button, or widget click).
2.  You can auto-launch your app, but any in-game windows containing ads must not appear automatically and should only open in response to a user action, such as a hotkey press or mouse click.
3.  Signal availability with a quiet, static icon or notification. Also avoid flashing, animating, or otherwise grabbing the screen's attention.

| **Non-compliant actions** | **Compliant actions** |
| --- | --- |
| Open windows with ads **automatically** in-game. | Have a Notification or Widget to opt-in. |
| Flash or animate elements to grab the player's attention. | Use subtle indicators to show overlays are available. |

## Rule 2 - Large size ad overlays must dim the game[​](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-2---large-size-ad-overlays-must-dim-the-game "Direct link to Rule 2 - Large size ad overlays must dim the game")

Large ad overlays must not interfere with gameplay or confuse the player about what is part of the game experience. This means any ad shown during gameplay must be clearly distinguished from the game itself to maintain immersion, clarity, and player control.

_**What does this mean?**_

1.  Any large overlay, or window with an ad shown over gameplay must include a dimmed background to visually separate it from the game.
2.  The overlay must also have a clear hotkey or button that allows the player to return to the game.
3.  This ensures the player always understands they've left the core Riot experience and are now inside a third-party tool.

Disclaimer

This rule applies only to large size overlays.  
Small companion sized screens (e.g., widgets or compact side panels) don't require dimming.

| **Non-compliant actions** | **Compliant actions** |
| --- | --- |
| Show ad supported overlays without darkening the background. | Apply a dimming background to distinguish overlays from the game. |

## Rule 3 - Overlays can't hide important game UI elements[​](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-3---overlays-cant-hide-important-game-ui-elements "Direct link to Rule 3 - Overlays can't hide important game UI elements")

Overlays should always respect the visibility of essential in-game information and not disrupt the flow of gameplay, or negatively impact the user's performance. It's important that overlays are carefully positioned so they enhance the experience without interfering with the core functionality or clarity of the game's interface.

_**What does this mean?**_

1.  Overlays must be placed so they don't cover important UI elements, such as minimaps, scoreboards, shops, ability bars, or system menus.
2.  Players should never feel like part of the game is unusable or hidden.
3.  Position widgets and overlays responsibly. This ensures full visibility of essential gameplay areas at all times.

| **Non-compliant actions** | **Compliant actions** |
| --- | --- |
| Cover critical UI elements, game menus, and views. | Position Overlays and Widgets in a way that isn't disruptive to gameplay or the game UI. |

## Rule 4 - No floating ads[​](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-4---no-floating-ads "Direct link to Rule 4 - No floating ads")

Ads that hover over the game window independently and follow the player's view are intrusive and interfere with gameplay. To maintain app compliance, all ads must stay inside the app and never cover or get in the way of the game.

_**What does this mean?**_

1.  Ads must always be part of a screen or overlay that provides real value or content to the user.
2.  Placing an ad alone on top of the game, without context or user interaction, is not allowed.
3.  If you're going to show ads, they must appear inside an overlay the player intentionally opened and not float over gameplay like a banner.

| **Non-compliant actions** | **Compliant actions** |
| --- | --- |
| Have ads floating without content or over the game screen. | Have ads as part of an overlay screen or other app content value. |

## Rule 5 - No in-game CTAs for ad removal or upgrades[​](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-5---no-in-game-ctas-for-ad-removal-or-upgrades "Direct link to Rule 5 - No in-game CTAs for ad removal or upgrades")

In-game calls-to-action (CTAs) that promote ad removal or paid upgrades disrupt gameplay and take the player out of the core game experience are not allowed.

_**What does this mean?**_

1.  You must not show subscription offers or upgrade CTAs inside any in-game overlay, even if the user opted into that overlay.
2.  This includes banners, buttons, or links encouraging players to pay to remove ads or unlock premium features as long as they're still in a game session.
3.  All subscription call to action messaging must happen outside of the game's context (e.g., in the app's home screen or pre/post-game flow).

| **Non-compliant actions** | **Compliant actions** |
| --- | --- |
| Include Premium Subscription CTA’s on in-game overlays. | Promote Subscriptions outside of the game session. |

## Rule 6 - Be visually distinct by design[​](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-6---be-visually-distinct-by-design "Direct link to Rule 6 - Be visually distinct by design")

Apps must be visually distinct from the game to avoid confusing the player. Clear visual separation helps ensure users always understand which elements come from the game and which come from the third-party app.

_**What does this mean?**_

1.  Your overlay should never look like it's part of the official Riot game UI. Players must always be able to tell when they're interacting with a third-party tool, not the game itself.
2.  If your app mimics Riot's colors, layout, or menus — it creates confusion, breaks player trust, and violates this rule.

Disclaimer

Overwolf reserves the right to review each case individually and determine whether an app is in violation of this guideline. If the visual distinction is not maintained, Overwolf may take appropriate action to ensure compliance.

| **Non-compliant actions** | **Compliant actions** |
| --- | --- |
| Copy Riot Games UI design. | Use a unique visual style. |
| Use game fonts, colors, or interface elements. | Apply your own fonts, colors, and buttons. |
| Leave out clear app branding. | Show your app name or logo clearly. |

[

App compliance for in-Game overlays and ads

](https://dev.overwolf.com/ow-native/guides/game-compliance/overview)[

Riot games compliance

](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-games)

-   [Rule 1 - Overlays with ads must be opt-in by the user](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-1---overlays-with-ads-must-be-opt-in-by-the-user)
-   [Rule 2 - Large size ad overlays must dim the game](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-2---large-size-ad-overlays-must-dim-the-game)
-   [Rule 3 - Overlays can't hide important game UI elements](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-3---overlays-cant-hide-important-game-ui-elements)
-   [Rule 4 - No floating ads](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-4---no-floating-ads)
-   [Rule 5 - No in-game CTAs for ad removal or upgrades](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-5---no-in-game-ctas-for-ad-removal-or-upgrades)
-   [Rule 6 - Be visually distinct by design](https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads/#rule-6---be-visually-distinct-by-design)

-   ##### Legal
    
    -   [App Developer Terms](https://legal.overwolf.com/docs/overwolf/developers/developer-terms)
    -   [App Developer Privacy Policy](https://legal.overwolf.com/docs/overwolf/developers/developer-privacy-policy)
    -   [App Developer CCPA](https://legal.overwolf.com/docs/overwolf/developers/developer-california-privacy-act)
    -   [App Developer DPA](https://legal.overwolf.com/docs/overwolf/developers/data-processing-agreement)
    -   [Overwolf Terms](https://legal.overwolf.com/docs/overwolf/website/terms-of-use)
    -   [Overwolf Privacy Policy](https://legal.overwolf.com/docs/overwolf/website/privacy-policy)
-   ##### Support
    
    -   [Discord](https://discord.gg/overwolf-developers)
    -   [LinkedIn](https://www.linkedin.com/showcase/overwolf-for-developers)
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
    -   [Subscribe to the newsletter](https://overwolf.us15.list-manage.com/subscribe?u=5542885c5f38ae9a4108ab154&id=e07c3e8158)
    -   [Developers Blog](https://blog.overwolf.com/tag/developers/)
    -   [Overwolf Appstore](https://www.overwolf.com/appstore)
    -   [Advertise on Overwolf](https://www.overwolf.com/ads/)

Ⓒ 2026 Overwolf. All rights reserved.
