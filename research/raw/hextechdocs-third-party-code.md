# [Obsolete] Using third-party-code to verify account ownership

<https://hextechdocs.dev/using-third-party-code-to-verify-account-ownership/>

-   [LOL](https://hextechdocs.dev/tag/lol/)
-   [LCU](https://hextechdocs.dev/tag/lcu/)
-   [TFT](https://hextechdocs.dev/tag/tft/)
-   [VAL](https://hextechdocs.dev/tag/val/)
-   [LOR](https://hextechdocs.dev/tag/lor/)
-   [FAQ](https://hextechdocs.dev/tag/faq/)
-   [Discord](https://discord.gg/F2wPwukGYs)
-   [CommunityDragon](https://www.communitydragon.org/)

[third-party-code](https://hextechdocs.dev/tag/third-party-code/)

# \[Obsolete\] Using third-party-code to verify account ownership

-   

#### [Ray](https://hextechdocs.dev/author/ray/)

15 Aug 2021 • 3 min read

[Share](https://hextechdocs.dev/using-third-party-code-to-verify-account-ownership/#/share)

> **_As noted by Riot in [this tweet](https://twitter.com/RiotGamesDevRel/status/1491217397965258752?ref=hextechdocs.dev), the Third Party Code API has been removed and users are encouraged to migrate over to RSO in lieu of using this endpoint. Anything noted in this document is no longer usable as of the 7th of March 2022._**

Before the new rune system (also known as Runes Reforged), sites and services verified account ownership by asking a user to rename either a rune or a mastery page to a specific string. When the new rune system came out, Riot removed the respective endpoints making that approach no longer feasible and gave us [third-party-code](https://developer.riotgames.com/apis?ref=hextechdocs.dev#third-party-code-v4/GET_getThirdPartyCodeBySummonerId) as a replacement while Riot's OAuth2 solution becomes generally available.

* * *

The basics of the new system is identical to the old system, you generate a string on your end, ask the user to input it and then confirm that action using the [third-party-code](https://developer.riotgames.com/apis?ref=hextechdocs.dev#third-party-code-v4/GET_getThirdPartyCodeBySummonerId) endpoint.

## Generating the string

The string you generate is completely up to you, but it has to be less than 255 characters and it can only contains letters from the English alphabet, numbers and the dash (-) character. We generally recommend using a UUID as it aligns with these rules, most programming languages have a built-in library to generate them and they are unique enough to a point where you don't have to worry about collision.

We generally recommend these codes to be unique cause you wouldn't want to accidentally attach an account to a user just because they happened to have the same exact code typed in.

## Asking the user to input this string

Now that you have a string generated, you have to ask the user to input this code in his/her client. This can be done in the settings menu under Verification. Once the user inputs the string and clicks the save button, (s)he should be done.

## Verifying account ownership

Now that the user has the verification code saved, you should ask the user to let you know that (s)he has done these steps. Then when you call the third-party-code endpoint, it should show the string you just generated for the user. If it's something else or it gives you a 404, you should ask the user to restart his/her client as the client side is known to have some issues (and unfortunately it's a low priority for Riot with OAuth2 on the horizon)

And that's all she wrote. This should be enough to get you going with this endpoint. If you have any questions, feel free to hop on the 3rd party developer discord where you can hopefully get some answers to get you going as well. I decided to include a little miscellaneous section that should be useful for debugging your code or helping to understand what to expect from the endpoint.

Good luck with your project!

* * *

## Miscellaneous

### Response codes

Here are different response types that can come from this endpoint and what they mean exactly:

| Response code | What it means |
| --- | --- |
| 200 with a code as the body | There is a code for the given summoner that's been returned |
| 404 | There is no code for the given summoner or it expired |

### Code expiry

Third party codes don't live on forever. The user can change them to verify account ownership for a different service or they can expire. The expiry conditions are not public, but I wouldn't recommend relying on them for longer than an hour. So rather than calling third-party-code for verification, make a basic user account system that allows you to persist this information and attach it to something a bit more persistent.

### Verification has failed. Please try again later.

Sometimes the client will say that the verification has failed and sometimes it'll blindly verify it but it won't actually show up when calling third-party-code. These are all known issues but due to OAuth2 being on the horizon, they've been assigned a really low priority. In case this happens to your users, you should ask the user to try pressing the save button again and in rarer cases, restart their client, that usually fixes these issues if the code adheres to the guidelines published by Riot (length, content)

[

## Using Cloudflare Workers to make API Calls

Introduction It's been a common topic around the Riot Games API Community that CORS has prevented client side calls to the API. There is a guide that Tux made for v3 APIs with AWS Lambda functions, but what if we wanted something more up to date and flexible

](https://hextechdocs.dev/using-cloudflare-workers-to-make-api-calls/)

02 Apr 2022 4 min read

[

## How to set runes using LCU

In this Example I'm going to be using my C# Lib PoniLCU. First of all let's set our LeagueClient properly. LeagueClient leagueClient = new LeagueClient(credentials.cmd); Before we dive into it, let's look at what runes are. The client doesn't deal with

](https://hextechdocs.dev/how-to-set-runes-using-lcu/)

28 Feb 2022 3 min read

[

## Resolving spells and variables in spell texts

The DataDragon provided by Riot Games contains info on all 158 champions. But when looking at the spell texts of these champions, you often come across variables that are seemingly unresolvable (e.g., dealing <physicalDamage>{{ wdamage }} physical damage</physicalDamage>.). Now, if we look at the rest

](https://hextechdocs.dev/resolving-variables-in-spell-textsa/)

25 Jan 2022 5 min read

[Hextechdocs](https://hextechdocs.dev/) © 2026

[Powered by Ghost](https://ghost.org/)
