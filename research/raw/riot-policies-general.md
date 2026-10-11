# Riot Developer Portal

<https://developer.riotgames.com/policies/general>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://developer.riotgames.com/policies/general#6b1328f4-024a-4944-a227-912879ed8da6)

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

[Overview](https://developer.riotgames.com/policies/general#_overview)

[Core Policies](https://developer.riotgames.com/policies/general#_core-policies)

[Product Registration](https://developer.riotgames.com/policies/general#_product-registration)

[Monetization](https://developer.riotgames.com/policies/general#_monetization)

[Game Integrity](https://developer.riotgames.com/policies/general#_game-integrity)

[Tournament Policies](https://developer.riotgames.com/policies/general#_tournament-policies)

[Developer Safety](https://developer.riotgames.com/policies/general#_developer-safety)

[Terms](https://developer.riotgames.com/terms)  ·   [Privacy](https://www.riotgames.com/en/privacy-notice)

© 2021 Riot Games, Inc. All rights reserved. League of Legends and Riot Games are trademarks, service marks, and registered trademarks of Riot Games, Inc.

Policies

### LAST UPDATED: MAY 29, 2025

## Overview

Our goal is to provide developers with a set of tools to create products that will enrich the Riot Games community and provide better player experiences. When working with the Riot Games API and other Developer Tools, we have several conditions set forth in our [Terms of Use](https://developer.riotgames.com/terms) and [Legal Jibber Jabber](https://www.riotgames.com/en/legal). Please be sure that you are familiar with those documents prior to developing your product. In addition to those documents, we also provide the following General Policies that all products in the Riot Games third-party ecosystem must adhere to. Failure to meet these policies may result in either suspension or cancellation of your API access or legal recourse.

In order for these policies to best serve the Riot Games ecosystem, they will inevitably change over time. As a result, developers must remain up to date with these policies. Developers are expected to adhere to these policy changes as they arise.

## Core Policies

-   Products cannot violate any laws
-   Do not create or develop games utilizing Riot’s Intellectual Property (IP)
-   No cryptocurrencies, no blockchain
-   Products cannot closely resemble Riot’s games or products in style or function
-   Use the following assets in the development and marketing of your product:
    -   [Data Dragon](https://developer.riotgames.com/docs/lol#data-dragon)
    -   [Press Kit](https://www.riotgames.com/en/press)
        -   Using Riot logos, trademarks etc. from the Press Kit must be limited to those cases where such use is inevitable to serve the core value of the product
    -   [TFT Assets](https://developer.riotgames.com/docs/tft#static-data)
    -   [LOR Assets](https://developer.riotgames.com/docs/lor#data-dragon)
-   You must post the following legal boilerplate to your product in a location that is readily visible to players
    
    > _\[Your product\] isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc._
    

## Product Registration

-   All products must be registered in, and audited by Riot Games through the Developer Portal
    -   Any new features or changes to a product must be audited through the product’s page in the Developer Portal
-   Products should use supported services from Riot Games for data ingestion
-   If your product utilizes the League Client API
    -   Read the [League Client documentation](https://developer.riotgames.com/docs/lol#league-client-api)
    -   [Register your product](https://developer.riotgames.com/app-type) through the Developer Portal

## Monetization

-   Your product cannot feature betting or gambling functionality.
-   You may monetize your product as long as your product is registered on the Developer Portal and your product status is either Approved or Acknowledged.
    -   You must have a free tier of access for players, which may include advertising
    -   Your content must be transformative if you are charging players for it
        -   _What is transformative?_  
            Was value added to the original by creating new information, new aesthetics, new insights, and understandings? If so, then it was transformative.
    -   Acceptable ways to charge players are:
        -   Subscriptions, donations, or crowdfunding
        -   Entry fees for tournaments
        -   Currencies that cannot be exchanged back into fiat
    -   Your monetization cannot gouge players or be unfair (_yes, we get to decide that_)
    -   If you are unsure if your monetization platform is acceptable, contact us through the Developer Portal
    -   You may not place advertisements in Riot properties, which include in-game, loading screens, and the Riot Client.

## Game Integrity

-   Products cannot alter the goal of the game (i.e. Destroy the Nexus).
-   Products cannot create an unfair advantage for players, like a cheating program or giving some players an advantage that others would not otherwise have.
-   Products should increase, and not decrease the diversity of game decisions (builds, compositions, characters, decks).
-   Products should not remove game decisions, but may highlight decisions that are important and give multiple choices to help players make good decisions.
-   Products cannot create alternatives for official skill ranking systems such as the ranked ladder. Prohibited alternatives include MMR or ELO calculators.
-   Products cannot de-anonymize players who cannot reasonably be identified from visible information.

## Tournament Policies

-   Tournaments must
    -   Follow all monetization policies above
    -   Allot at least 70% of the entry fees to the prize pool
    -   Win conditions must be fair and transparent to players (we determine fair)
    -   Must have at least 20 participants
    -   Not include any gambling
-   If you are a tournament organizer operating in the US or Canada, please refer to, and adhere to, these [North American tournament organizer policies](https://developer.riotgames.com/policies/na-tournaments).
-   If you are a tournament organizer operating in Europe, please refer to, and adhere to, these [European tournament organizer policies](https://riot.eurcommunitycompetition.com/).

## Developer Safety

-   Don't share your Riot Games account information with anyone
-   Do not use a Production API key to run multiple projects (one product per key)
-   Make sure that you are using SSL/HTTPS when accessing the APIs so that your API key is kept safe.
-   Do not include your API key in your code, especially if you plan on distributing a binary

_Note that for teams working together on a product, there will be an obvious need to share an API key for your product. Our intention is not to discourage sharing along these lines, but rather sharing with people outside of your organization or who are working on other projects. To properly share an API key within an organization, be sure that your product is owned by a “group” in the Developer Portal, then add additional accounts to that group._
