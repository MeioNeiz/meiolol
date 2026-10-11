# Matchmaking and Champion Select - Fall 2022

<https://www.leagueoflegends.com/en-us/news/dev/matchmaking-and-champion-select-fall-2022/>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://www.leagueoflegends.com/en-us/news/dev/matchmaking-and-champion-select-fall-2022/#57ad704d-35f3-43ee-88f1-4f6a63e4f4fc)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

[

Game Overview

](https://na.leagueoflegends.com/en-us/how-to-play/)

[

League of Legends Classic

](https://www.leagueoflegends.com/en-us/classic/)

Champions

[

Patch Notes

](https://na.leagueoflegends.com/en-us/news/tags/patch-notes)

[

Support

](https://support.riotgames.com/riot/)

[

PBE

](https://www.leagueoflegends.com/en-us/pbe/)

More

[Game Overview](https://na.leagueoflegends.com/en-us/how-to-play/)[League of Legends Classic](https://www.leagueoflegends.com/en-us/classic/)[Champions

](https://www.leagueoflegends.com/en-us/news/dev/matchmaking-and-champion-select-fall-2022/#)[Patch Notes](https://na.leagueoflegends.com/en-us/news/tags/patch-notes)[Support

](https://support.riotgames.com/riot/)[News

](https://www.leagueoflegends.com/en-us/news/dev/matchmaking-and-champion-select-fall-2022/#)[DISCOVER

](https://www.leagueoflegends.com/en-us/news/dev/matchmaking-and-champion-select-fall-2022/#)[PBE](https://www.leagueoflegends.com/en-us/pbe/)

PLAY NOW

PLAY NOW

# Matchmaking and Champion Select - Fall 2022

Insight from the Game Loop team on some recent and upcoming changes

[Dev](https://www.leagueoflegends.com/en-us/news/dev/)

Riot Auberaun

9/30/2022

It’s been a while since we’ve talked about some of our around-game systems, so let’s get into it. To set some context, internally we’re called the Game Loop team, and we’re responsible for all of the _around game_ things that contribute to and affect your experience _in the game_, like Matchmaking, Champion Select, and the various Summoner’s Rift queue types you use to select the type of play you want. Overall what we want to do is set you up with fair matches and then after you hit that “Accept!” button, give you the tools that let you prepare yourself and your team for in-game success.

## Recent updates

First, let’s get into updates on some of the things [we talked about last time.](https://www.leagueoflegends.com/en-us/news/dev/the-state-of-competitive-spring-2022/)

-   **Revival MMR:** Updates to calibrating the skill of players just getting back into the game rolled out in 12.16 to normal queues. Since then, we’ve seen a jump in returning player first-game winrates from 44.5% to 48%, reaching 50% by game 10 (up from 48% by game 10).
-   **Solo Only Mode:** We’re **not** **currently** planning to separate solo and duo parties in Ranked. While we still believe in the logic for why this _could_ be a good idea, we first need to make sure that duo players have another place for a compelling competitive experience. Flex queue doesn’t currently meet that bar.
-   **Re-evaluating our Summoner’s Rift queue portfolio:** Related to the above bullet, this is something we’re interested in digging into going into next year. Specifically, we think there’s a lot of untapped potential in the spaces Blind Pick and Normal Draft are serving (which by the way a _big_ proportion of players queue up for today, not everyone plays ranked!).

In a similar vein, we’ve been able to tackle some other new work that’s shipped recently.

-   **Role Parity Matchmaking Improvements:** In 12.16 we made changes to matchmaking to put additional emphasis on matching players by position preference in Ranked Solo/Duo. In other words, trying to match primaries against primaries, secondaries against secondaries, and autofills against autofills. These changes have been quite successful, increasing the total number of games with role parity by around 15-30% depending on region. In other words, you’re less likely to be playing secondary top against that 800 game Riven main.
-   **Rank-Based Matchmaking Adjustments:** A side effect of using visible rank to define fair matchmaking is that after the initial ranked rush in January, returning players, late season starters, and smurfs end up matched together frequently. This is because they all have significantly mismatched MMR and visible rank, whereas everyone else has already stabilized. In 12.17 we made tweaks to ranked matchmaking to more quickly accept differences based on visual rank.

## What’s coming next

Now the more fun stuff! We’re exploring several updates to Champion Select functionality that we think will upgrade the experience in ways that haven’t been touched in a while. Optimistically, we’ll be getting these out by the end of the year:

-   **Champion Select Anonymity:** Today, a lot of players use external websites and third-party apps that provide all sorts of information about their teammates. With this information, players are drawing conclusions that aren’t necessarily correct and pressuring their teammates into things that they might not want to do, like picking the exact same champion every game because it’s their highest winrate or most played. We think the best version of League is not one where you metagame based on the players in your lobby, weigh who’s on a win or loss streak or playing a different champion, and dodge or pressure others to dodge when your setup doesn’t meet perfect conditions. We’re still thinking about details of implementation here, but our starting point is likely to be hiding all Summoner names in Champion Select for Ranked Solo/Duo.  
      
    _To expand on this point, we recognize that there are legitimate reasons that someone might need to dodge a lobby, but there are also a lot that aren’t done in good faith. We want to impact the motivations behind why dodging occurs to reduce the frequency in a natural way._
-   **Pick Order Swapping:** This is a commonly requested feature that we already see in Wild Rift. Today, you have to go through an extensive discussion in chat to effectively swap your pick order - can I pick for you? Do you have my champion? Do I have your champion? There are a lot of ways this can break down in one way or another, and this is assuming that everyone in the lobby even speaks the same language! By letting teams swap pick order with the press of a button, we hope to streamline the process of crafting your draft to be successful.  
    
-   **Loadout Recommender:** Like we provide item recommendations in the game, we want to provide rune and Summoner Spell recommendations during champ select. This should help narrow the gap between players who are comfortable with the rune and Summoner Spell systems and those who aren’t. We want to reduce barriers to entry and ensure players have the best possible experience with the runes system when initially ramping up on the game. Additionally, this should be helpful for more veteran players who might currently go to external websites or apps to learn what to take on a champion they’re not familiar with.

That’s it for now! Given some recent reorganization and a sharper focus, we’re optimistic about being able to move more quickly in these spaces than we have in the past, and are continuing to evaluate new opportunities and some big bets for next year.

* * *

## Related Articles

1.  [
    
    Dev
    
    9/8/2026
    
    Dev Update: Team Voice, Classic & More
    
    Pabro, Meddler, FeralPony, and Phreak talk about Team Voice, Classic, Mayhem, Ranked 5s, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=9vrcrlJqqvY)
2.  [
    
    Dev
    
    9/8/2026
    
    TL;DW: Team Voice, Classic & More Dev Update
    
    A short rundown of changes from today’s Dev Update.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/tldw-team-voice-classic-more-dev-update)
3.  [
    
    Dev
    
    7/14/2026
    
    /dev: League of Legends Classic
    
    Welcome back, Summoners.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-league-of-legends-classic)
4.  [
    
    Dev
    
    7/14/2026
    
    TL;DW: Classic, Mayhem & More Dev Update
    
    A short rundown of changes from today’s Dev Update.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/tldw-classic-mayhem-more-dev-update)
5.  [
    
    Dev
    
    7/14/2026
    
    Dev Update: Classic, Mayhem & More
    
    Pabro, Meddler, FeralPony, and Phreak talk about Classic, Mayhem, Hall of Legends, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=KV1ArTWlEFU)
6.  [
    
    Dev
    
    6/26/2026
    
    200 YEARS OF EXPERIENCE
    
    Pabro has a breakthrough, he just needs Meddler on board.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=fTH-CylOvcc)
7.  [
    
    Dev
    
    5/27/2026
    
    Dev Update: Mayhem, Ranked 5s & More
    
    Pabro, Meddler, Phlox, and Cadmus talk about ARAM: Mayhem, Ranked 5s, skins, MSI, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=3_0h_vuIKv4)
8.  [
    
    Dev
    
    4/21/2026
    
    /dev: Apex Tier Ranked Reset
    
    Why we’re doing a Ranked reset for Master+ in NA, EUW, EUNE, BR, LAN, and TR in 26.9.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-apex-tier-ranked-reset)
9.  [
    
    Dev
    
    4/21/2026
    
    New Events and Augments Head to the Arena
    
    Prepare for a new season of glorious Arena combat that kicks off on Patch 26.09.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=rVYts-6Jdas)

-   [ABOUT LEAGUE OF LEGENDS](https://na.leagueoflegends.com/en/game-info/get-started/what-is-lol/)
-   [Server Status](https://status.riotgames.com/?locale=en_US&region=na)
-   [Support](https://support.riotgames.com/riot/)
-   [Esports Pro Site](https://www.lolesports.com/en-US/)
-   [Download Riot Mobile Companion App](https://www.riotgames.com/en/riot-mobile-download)

-   [Youtube](https://www.youtube.com/user/riotgamesinc)
-   [Twitter](https://twitter.com/leagueoflegends)
-   [Facebook](https://www.facebook.com/leagueoflegends)
-   [Instagram](https://www.instagram.com/leagueoflegends/)
-   [Reddit](https://www.reddit.com/r/leagueoflegends/)

™ & © 2026 Riot Games, Inc. League of Legends and all related logos, characters, names and distinctive likenesses thereof are exclusive property of Riot Games, Inc. All Rights Reserved.

-   [Privacy Notice](https://www.riotgames.com/en/privacy-notice)
-   [Terms of Service](https://www.riotgames.com/en/terms-of-service)
-   [Cookie Preferences](javascript:void\(0\);)

Blood  
Fantasy Violence  
Mild Suggestive Themes  
Use of Alcohol and Tobacco  
Online Interactions Not Rated by the ESRB
