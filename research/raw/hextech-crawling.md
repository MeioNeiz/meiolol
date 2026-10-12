# Crawling matches using the Riot Games API

<https://hextechdocs.dev/crawling-matches-using-the-riot-games-api/>

-   [LOL](https://hextechdocs.dev/tag/lol/)
-   [LCU](https://hextechdocs.dev/tag/lcu/)
-   [TFT](https://hextechdocs.dev/tag/tft/)
-   [VAL](https://hextechdocs.dev/tag/val/)
-   [LOR](https://hextechdocs.dev/tag/lor/)
-   [FAQ](https://hextechdocs.dev/tag/faq/)
-   [Discord](https://discord.gg/F2wPwukGYs)
-   [CommunityDragon](https://www.communitydragon.org/)

[riot-api](https://hextechdocs.dev/tag/riot-api/) Featured

# Crawling matches using the Riot Games API

-   

#### [Ray](https://hextechdocs.dev/author/ray/)

15 Aug 2021 • 3 min read

[Share](https://hextechdocs.dev/crawling-matches-using-the-riot-games-api/#/share)

One of the most popular use cases of the match-5 API is providing statistics like winrates, playrates, banrates and common runes/builds on a per champion rather than a per player basis. Doing this requires access to as many matches as possible to provide accurate information. This guide will show 2 methods (with their individual pros and cons) to efficiently fetch as many matches as possible.

* * *

## Disclaimer

While both of the methods we're going to talk about can be used on a development API key, we'd recommend not aiming for a large sample size while developing the application.

For the approval process, we recommend using mock data to simulate the behavior of the application. Riot won't need the exact winrate numbers for the approval process, they just want to see your site in action. _(just don't claim that nunu has a 80% winrate with cleanse ghost)_

As for development, we recommend getting enough matches where you're completely able to oversee everything that goes into each of the endpoints (fetching participants, fetching matchlists, etc..) but not going as far as waiting hours for matches to flow in.

* * *

## Method 1: Using league-v4 in conjunction with match-v5

League-v4 has a really powerful endpoint called [getLeagueEntries](https://developer.riotgames.com/apis?ref=hextechdocs.dev#league-v4/GET_getLeagueEntries) that allows you to fetch every single ranked player in a given division. All you need to do is call `/lol/league/v4/entries/{queue}/{tier}/{division}` and paginate over each division you're interested in, fetch the accountId of each individual summoner and using the matchlist endpoint and getMatch, you should see all the matches pouring in.

You can optimize this by storing all the matches in a database or a cache layer to avoid fetching matches twice as well as using the tier/division filter to avoid fetching games you may not be interested in.

### Pros:

-   If all you care about is ranked data, this method can guarantee that you'll have access to every ranked game for a given season.
-   You are able to filter out the players based on their current division, allowing you to focus on matches from a specific tier(s)/division(s)

### Cons:

-   Unfortunately, league-v4 uses summonerIds while match-v5 uses puuids meaning we have to make one additional call per summoner to be able to have access to their accountIds.
-   This method is only useful for ranked people. It cannot help you if you're after normal games or ARAM games

Overall this method could be beneficial if you're willing to maintain a cache of IDs to avoid calls to summoner-v4 when updating your playerbase over the course of the season. If you don't have the storage capacity and you're looking for a solution where you can throw away the data after you're done, you're better off choosing method 2.

* * *

## Method 2: The pure match-v5 method

This method is the only one we had available before the getLeagueEntries method and despite its age, it's still a widely used method for crawling large amounts of match data.

This method requires one puuid to get going (it can be yours, it can be anyone) and it only uses the match APIs. The core concept is you take the matchlist of the initial accountId, you fetch all the games from that matchlist using getMatch and using the other 9 participants from that match, you start building up your list of players. Once you're done with the initial puuid, you repeat this process for every single puuid you collected in the process and this should give you more and more puuids to work with.

With the core concept out of the way, let's look at pros and cons:

### Pros:

-   This method only uses endpoints you'd have to use anyway, making it a pretty ideal approach for lower limit keys
-   This method can also work with normal game data and ARAM data if you're able to keep feeding enough ARAM/normal player accountIds to the system

### Cons:

-   Since you're not making any calls to league-v4, you won't be able to filter the data based on ranked tiers
-   While highly unlikely, it is possible that the system will run out of puuids before it'd get a good enough sample size (possible if the initial puuid is a bad one)

* * *

## Conclusion

That's all she wrote! These are the 2 most efficient methods you can utilize to have access to a lot of matches using the Riot Games API. If you have any questions, feel free to join Riot’s 3rd party developer community on discord and ask your question there. There are a lot of knowledgeable members who are willing to answer them!

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
