# Riot Developer Portal

<https://developer.riotgames.com/docs/faqs>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://developer.riotgames.com/docs/faqs#a5e5e9b9-608b-4271-b8c1-d04d301e0d04)

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

[The Basics](https://developer.riotgames.com/docs/faqs#_the-basics)

[Response Times](https://developer.riotgames.com/docs/faqs#_response-times)

[Using Multiple Applications](https://developer.riotgames.com/docs/faqs#_using-multiple-applications)

[RSO (Riot Sign On)](https://developer.riotgames.com/docs/faqs#_rso-riot-sign-on)

[Production Key Applications](https://developer.riotgames.com/docs/faqs#_production-key-applications)

[Verification for Production Applications](https://developer.riotgames.com/docs/faqs#_verification-for-production-applications)

[Reporting Issues](https://developer.riotgames.com/docs/faqs#_reporting-issues)

[Vanguard](https://developer.riotgames.com/docs/faqs#_vanguard)

[App Messaging Deprecation](https://developer.riotgames.com/docs/faqs#_app-messaging-deprecation)

[Terms](https://developer.riotgames.com/terms)  ·   [Privacy](https://www.riotgames.com/en/privacy-notice)

© 2021 Riot Games, Inc. All rights reserved. League of Legends and Riot Games are trademarks, service marks, and registered trademarks of Riot Games, Inc.

FAQS

## The Basics

### I need help with non-API related game issues, can you help me?

Unfortunately, we can only provide assistance for API questions. Please visit [Riot Games Support](https://support.riotgames.com/hc/en-us) for more help.

### Can you help me with code/integrating the API in my application?

Unfortunately, we are unable to provide technical support for development questions, unless it pertains to an issue/bug with the API. We recommend reaching out to the [community Discord](https://discord.gg/riotgamesdevrel) for help with coding and using the API.

### What is the difference between a Personal Key and a Production Key?

Personal keys are meant for smaller-size, personal projects, such as testing the API, products for yourself and a small group, or for creating prototypes to later submit for a production key. For more details, please refer to our [game docs](https://developer.riotgames.com/policies/game-specific).

Production keys are meant for larger-size, professional projects. For production keys, we need to see a functioning website/application or a prototype that demonstrates you’ll be able to fully execute on your use case. For more details, please refer to our [game docs](https://developer.riotgames.com/policies/game-specific).

### Can I have a Personal Key for VALORANT?

Unfortunately, personal keys are not offered for VALORANT. If you are just getting started with APIs, we encourage you to experiment with a personal key for a different game before applying for a VALORANT production key. However, please note that personal key applications requesting VALORANT access will not be approved.

## Response Times

### How long will it take you to approve my application?

Applications are typically reviewed weekly for the previous week. However, due to overwhelming amounts of requests, sometimes the review process can take up to three weeks.

### How long will it take you to respond to my message?

Like applications, each week we review messages from the week prior. Due to an overwhelming amount of messages, sometimes it can take up to two weeks to respond. Since we review specific date ranges, submitting multiple messages may kick you to the back of the queue.

## Using Multiple Applications

### Am I allowed to have multiple applications?

Yes, you can have one application per game per product. This means if you have one product/website, you can have up to four applications (one for each game we offer), plus one RSO client. If you have multiple products/websites, you may have additional applications for these. Please note you may NOT have multiple applications to bypass rate limits.

### Am I allowed to use a single API key for multiple applications?

No, only one product/website per API key is allowed. Your API key is approved only for the use case and game within your description.

### Can I have endpoints for multiple games on one API key?

No. We’re unable to assign multiple game API’s to a single application/key. You’ll need to submit a separate application request for each game that you want. After you’re approved, we can tie these applications together so they can share data. The exceptions to this are RSO clients - a single RSO client will be assigned even if the developer has multiple games and applications.

## RSO (Riot Sign On)

### What is RSO?

RSO (Riot Sign On) is how we allow third parties to safely request access to a player’s account or game data by redirecting players to login via RSO. RSO utilizes OAuth2 for authentication which lets players authorize third parties to obtain access to their account or game information without the player having to share their password. After the player has acknowledged they’re granting a third party access to their data, they’re redirected back to the third party with a token which the third party can use to access player information.

### What is an RSO Client?

An RSO Client is an additional application that contains a client ID and token to allow you to integrate RSO with your game application(s). This is the same as any OAuth2 client.

### How do I request an RSO Client?

RSO Clients are only available for applications that have an existing, approved production application ID. All newly approved production applications will receive a link inviting them to apply for RSO access. If you already have an approved production application but never received RSO instructions, feel free to send us a message in the app notes.

### Where can I learn more about implementing RSO?

You can review basic RSO instructions in any of our [game docs](https://developer.riotgames.com/policies/game-specific). We use Single Sign On (SSO) with OpenID for authentication. Any article covering this topic can help with the knowledge needed to integrate with RSO.

### I have multiple applications. Do I need a separate RSO client for each one?

No. If you have multiple applications, these will share a single RSO client. You’ll request the relevant games as part of the RSO application process and we’ll make sure all your app data is tied together on our end.

## Production Key Applications

### Why do I need a website for a production key?

Production keys are reserved for fully functioning applications that can clearly demonstrate their user flows. We need to see a website to understand what your app does, view your Terms of Service and Privacy Policy, and to make sure your app is in a good state for a production key.

### Can I have a production key if I don’t have a website?

In most cases, no. Production keys are for applications that are in a completed or near-complete state. If you’re very early in the development process, we recommend applying for a personal key to get you started.

### Can I submit my Github for a production key?

No. Unfortunately, we are unable to accept Github repositories and source code in lieu of a functioning application/site.

### I have a functioning mobile app, but no website, can I still have a production key?

In most cases, we still require you to host your native app on a domain you own. This is so that users can easily see what your product does, where to download it, where you list your Terms of Service and Privacy Policy, and so we can verify that you’re the owner of the app. If you plan to host your app, ToS and Privacy Policy on an app store instead, it must first be in a verified state and approved by us in the developer portal.

### My product is a Discord bot, do I still need a website?

Yes. Discord bots still need a website so users can easily see what your product does, where to access it, and where you list your Terms of Service and Privacy Policy, and so we can verify your app.

### How can I show you what I’m going to develop without an API key?

There are a lot of ways. If you are developing for League of Legends, Teamfight Tactics, or Legends of Runeterra, you can request a personal key to help get you started. We don’t offer personal keys for VALORANT, but you can create the framework of your site using placeholder data or a developer key. Other ways are video demos, screenshots, or Figma files that clearly demonstrate your user flow. Try reaching out to the [community Discord](https://discord.gg/riotgamesdevrel) if you need more tips!

## Verification for Production Applications

### What is verification?

Site verification is how we validate that you own the domain where your application is hosted. After submitting your production application, you’ll receive a text string to upload to your URL that proves you’re the website owner.

### I don’t have a website. Do I still have to be verified?

Yes. We cannot grant production keys to applications without a verified website.

### Why does my application say “unverified”?

If your application is unverified, that means you did not upload the text string correctly. We are unable to process your application until you get it into a verified state.

### I’m still struggling with verification. Is there another way to get verified?

We have no alternative ways to prove your product ownership at this time. If you’re still struggling, please check out the following resources for more help:

1.  [How To Verify Site](https://developer.riotgames.com/how-to-verify-site.html)
2.  [Community Discord](https://discord.gg/riotgamesdevrel)
3.  [Hextechdocs](https://hextechdocs.dev/) (Community maintained developer documentation)

## Reporting Issues

### I found a bug/issue with the API. Where do I report this?

You can drop us a message in the app notes or submit a ticket to the community Github.

### How long will it take to fix the issue?

Issues get internally escalated to the appropriate team for evaluation and prioritization. While we’re unable to timebox fixes, we strive to get things patched up as quickly as possible.

## Vanguard

### What is Vanguard?

Riot Vanguard is Riot Games’ custom game security software, designed to uphold the highest levels of competitive integrity for our offerings. Vanguard is currently live for VALORANT and will be coming to League of Legends and Teamfight Tactics in early 2024. For more details about Vanguard for League of Legends, check out [this article](https://support-leagueoflegends.riotgames.com/hc/en-us/articles/24169857932435-Riot-Vanguard-League-of-Legends).

### When will Vanguard be live?

Vanguard is now live in the Philippines as of Patch 14.8 (April 16, 2024). Vanguard is currently planned to be live for all regions other than China with patch 14.9 on April 30, 2024. Please follow the [patch notes](https://www.leagueoflegends.com/en-us/news/tags/patch-notes) for the most recent information.

If you'd like to test things out, Vanguard is now available in PBE. If you don’t already have access, you can get it [here](https://support-leagueoflegends.riotgames.com/hc/en-us/articles/360001714088-League-of-Legends-PBE-Client-Download). Testing your app on the PBE server will be the most efficient way to figure out if you’ll be impacted by Vanguard.

### What happens to existing apps that use memory reading?

Overlays and internal tools using the API, game client, and in-game APIs should continue to function. External tools reading memory will no longer work, and you’ll need to change methods.

### Is it possible to get on an allow list?

No - There is absolutely no allow list for Vanguard. If you expect your tool will be impacted, it is up to you to redevelop it to account for Vanguard’s restrictions. If this isn’t possible, this means the tool is unfortunately not something that will be allowed.

### Will the LCU be impacted by Vanguard?

Apps developed using the LCU and in-game APIs are still expected to work. Please note the LCU and in-game APIs are not owned by Developer Relations and we cannot offer support or guarantee updates when using these methods.

### Will replays/spectating be impacted by Vanguard?

Apps developed using the spectator and replay services should still work.

### Can I talk to someone about how this impacts my specific application?

Unfortunately not. We have thousands of active developers in our ecosystem and we just don’t have the bandwidth to address Vanguard questions at the individual level.

However, if during testing, you find Vanguard behaves in an unexpected way that contradicts what we've explained here, feel free to submit a ticket on [our support site](https://support-developer.riotgames.com/) so we can take a look.

### Will everyone be expected to follow the same guidelines, or are certain developers getting an exception?

As mentioned above, no one is exempt from these changes, and everyone must adapt to Vanguard in League of Legends and Teamfight Tactics. This means Developer Relations can make no exceptions, carve out any loopholes, or perform any secret handshakes to invite anyone to a mythical allow list - that’s right, not even that developer. If you see a tool continuing to function after Vanguard is live, this means that they have restructured their tool to meet the new guidelines.

That being said, we’re unable to comment on relationships that may exist between specific creators and other teams at Riot, as these are managed outside of Developer Relations’ purview.

## App Messaging Deprecation

### What happened to app messaging?

We’re beginning to transition away from app messages as of April 26, 2024, in favor of our new [support site](https://support-developer.riotgames.com/), which offers faster responses for our community

### What if I have an ongoing conversation via app messaging?

We’ll do our best to make sure any ongoing conversations won’t be impacted by the cutoff date, but turning these back on is a manual process and if you find yourself unable to reply unexpectedly, please send us a message on the [support site](https://support-developer.riotgames.com/) so we can be sure to continue the conversation.

### What if Riot has questions about my application?

For now, we’ll still be sending approvals/rejection reasons and RSO instructions in app messages. If we need more info from you on a pending application, we’ll turn on app messages for you.

### Can I still see my app message history?

Yes! You’ll still be able to view your full message history. You just won’t be able to send new messages in this section.

### Why are you getting rid of app messaging?

App messaging, as we’re sure you’ve noticed, is a very slow process. There are no notifications on either side for replies, leading to extremely lengthy wait times. Our new support site offers a lot more functionality, allowing us to reply much faster in most cases. That being said, we are still a ways off from being able to fully phase out app messages.
