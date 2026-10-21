# /dev: Champion Balance Framework

<https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/#f755e033-36d1-4361-80a2-32ed32555b04)

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

](https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/#)[Patch Notes](https://na.leagueoflegends.com/en-us/news/tags/patch-notes)[Support

](https://support.riotgames.com/riot/)[News

](https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/#)[DISCOVER

](https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/#)[PBE](https://www.leagueoflegends.com/en-us/pbe/)

PLAY NOW

PLAY NOW

# /dev: Champion Balance Framework

How we go about making balance tweaks.

[Dev](https://www.leagueoflegends.com/en-us/news/dev/)

RiotRepertoir

5/30/2019

Conversations around balance can be rough. Over the past 9(!) years, we have found that players don’t necessarily always understand what we’re trying to accomplish (or can accomplish) in a patch cycle. But we want to change that.

Introducing the Champion Balance Framework, a source for all players to hold the “balance” team accountable for how we approach buffing/nerfing champions on a patch-to-patch basis. We’ve been making changes internally on the way we view champion balance for Summoner’s Rift. Now that we’ve had some time to see that change in action, we wanted to formalize this approach so if players dislike a change we make, they can at least understand why we decided to make that change.

What follows is our way of establishing consistent understandings of how we evaluate champions’ power level, especially for the purposes of determining if they ought to be buff or nerf candidates on any given patch. The hope here is that this approach will result in balance targets that feel much more consistent, and thus more understandable.

## **Champion Balance in the Past**

The main improvement we’d like to make by creating a more visible balance strategy is that players feel like the approach to League’s balance decisions is consistent. We expect that a more consistent approach can be more easily trusted–inconsistency with our approach to balance can be the most frustrating thing for players, even more than any individual balance issues of the past or future.

To achieve this, we are putting in place a system that seeks to limit subjectivity in the assessment of (not the reasons for) a champion’s power level. By doing so, we should have fewer champs fly under the radar in either overpowered or underpowered states, and we also avoid risky bias-based balancing.

## **Updating Our Approach**

In the past, we’ve operated under the rough guideline of “we balance for Plat+ play.” Despite that, we’ve demonstrated that we also make balance decisions under other conditions or for other reasons. As such, we’re now formally recognizing the four audiences for which we balance Summoner’s Rift, as well as the parameters that we view as underpowered, overpowered, and reasonably balanced. Here are the audiences:

_Average Play_

This group contains most players, everything below the top 10% of solo queue (approximately up through Gold). While some may argue that the game should be balanced around only the very best players of the game, we think a balanced experience is an important part of what makes League compelling regardless of skill level. That said, we also think this group’s experience is less sensitive to exact balance conditions, and so our definitions of what is too strong for them is less restricted.

Win rate tells us most of what we need to know about champions’ power level here, and combined with their ban rate, gives us a good view of what is too strong for this group of players. The more a champion is banned beyond the global average ban rate (ABR, currently ~7%), the more we use their ban rate as an expression of the champion’s power level in the tier, and the tighter a band we put on their win rate.

-   Top End: \[54.5%WR if <ABR\] to \[52.5%WR at 5x ABR\]
-   Bottom End: 49%WR

_Skilled Play_

This group contains the top 10% of solo queue players, except the very top players (the next group). This group is similar to the _Average Play_ group, but with higher sensitivity to power level. As such, the parameters we use to determine what is too strong for this group are a bit more restricted.

-   Top End: \[54%WR if <ABR\] to \[52%WR at 5x ABR\]  
-   Bottom End: 49%WR

_Elite Play_

This group contains the top 0.1% of solo queue players, the best-of-the-best in solo queue. This group is the most sensitive to balance changes out of all the solo queue groups, and also has unique balance needs. Unlike the other solo queue groups, we rarely have sufficient win rate data to determine if something is too strong here (sample size is small due to the extremely limited size of the player audience). Even if we did, these players have mastered the game to such an extent that their champion select behaviors can be trusted as accurate representations of power level. To that end, we draw conclusions about power level based on pick rates in addition to ban rates, and we notably do not consider pick rate a strong indicator of power at any other solo queue tier. We introduce the concept of Presence in this tier, where Presence is the combined Pick and Ban rate of the champion.

-   Top End: 45% Ban Rate
-   Bottom End: 5% Presence

_Professional Play_

This group is the top five recognized leagues of competitive play (currently LPL, LCK, LEC, LCS, and LMS). Somewhat similar to Elite, we determine power level based on this group’s champion select behaviors more so than the results of the games in which they are picked. It’s arguable that just because a champion isn’t picked on a certain patch, that they’re not actually underpowered for this group, but rather that the meta just doesn’t currently allow them to be picked. Despite this reasonable stance, we will consider these champions underpowered in the context of the current meta, and we will balance around the champions’ power level within that meta.

-   Top End: 90% Presence on the current patch OR 80% presence in consecutive patches.
-   Bottom End: 5% Presence

Moving forward, we will consider a champion balanced for Summoner’s Rift if they can be considered balanced for any of these audiences. **They will be considered overpowered if they cross the top end for ANY of the audiences, and they will holistically be considered underpowered if they are below the bottom end for ALL of the audiences.**

Translating that understanding into action, our champion balance priorities are to immediately address champions that are overpowered, then address champions that are underpowered across the board, and when those are accounted for, working on making champions balanced across several audiences (for example, in cases where they might only be balanced for one or two audiences).

## **Turning Data Into Changes**

Once we’ve identified champions that are out of balance, we get into the meaty stuff pertaining to how to actually adjust things. For this, there’s no definitive framework. We’ll continue to use our understanding of audiences’ needs and experiences to make good change. Our hope is that the above system for identifying imbalances allows us to more easily move beyond what is out of whack and get into the why that’s the case, as well as how we ought to address it. Put simply, the framework more easily gets us to the point of agreement on the fact that a champion like Hecarim (for a recent example) is overpowered, and then we get to work on how to fix it.

##   

## BUT WHAT ABOUT…

## 

## **New and Reworked Champions?**

New and updated champs won’t abide by these exact parameters for about one month after release. These champions are still actively being learned by the player base—both by those playing the champs and those playing with/against them—and we can expect the champions’ actual power levels to be much different from their statistical performance around launch.

Over the past year, we don’t think we’ve done a great job at balancing new and updated champions, so we’ve put new systems in place outside of our typical strategy to better accommodate them.

These systems focus on things like… a champion’s expected power level at release, their expected performance growth over the first few days/weeks, and plans for if their performance doesn’t match these expectations. This should help ensure no new or reworked champions remain underpowered or overpowered for significant periods of time after release in the future.

## **Champions With High Play Rates?**

We’re pretty wary about punishing a champion for their popularity, as some champs will naturally be played more than others, even at statistically similar power levels—Yasuo and Lee Sin are two examples or champs who’re played pretty consistently, regardless of overall performance. We’ve considered using “play rate change” as a way to account for this, but we didn’t think it added enough value to the framework because play rate doesn’t seem to have a significant correlation to power level. The only exception to this is at the highest levels of play, where we do use play rate as an indication of power.

## **Champions With High Mastery Curves?**

A [mastery curve](https://boards.na.leagueoflegends.com/en/c/developer-corner/635MVdLk-quick-gameplay-thoughts-august-24) is a representation of how much more effective a player becomes on a champ as they play them more. Champions with steep mastery curves, like Aurelion Sol and Katarina, typically have a much higher win rate when played by experienced players than newcomers to the champion.

We are intentionally leaving out mastery curve data when considering which champions to buff or nerf because we don’t want to enact a system that might punish the investments players make into mastering a champion. We’re also optimistic that if a champion’s power when mastered is out of line, then it will show up as highly present in Pro play or highly banned in Elite play—both of which will lead to nerfs.

## **Really Frustrating Champs?**

There are a lot of reasons a champion could be frustrating to play with or against, ranging from their current power level to their mobility. Using this framework—in tandem with things like survey data and player conversation—will help us to pinpoint exactly what’s causing the trouble. By having clear and objective balance breakpoints, we can better gauge when we can move on from balance work and into designing to reduce overly frustrating gameplay. These two things aren’t mutually exclusive though: Riven’s increased E cooldown in patch 9.10 is an example of a change aimed to reduce a champions’ power level and their “frustration factor” simultaneously.

## **Regional Differences?**

The data we’re drawing from is globally aggregated rather than region-specific. There is potential for a champion’s performance to vary from region to region, but we feel that keeping the data global helps players focus on identifying what problem is being solved by the change regardless of what region plays it better (or not).

If we start changing champions based on a small number of regions’ experiences that can wildly vary from the rest of the world, we are likely to run into issues where the patch notes don’t make sense for players in the other regions. We believe if a trend or an especially spicy playstyle continues to persist, they will show up more prominently in the global data, in which we can then make changes to mitigate them.

It really is about limiting how random changes in the patch notes can feel to players. We expect it to be much easier to explain why we make balance changes based on different “audiences” (every region has average, skilled, and elite players) than to explain that a certain nerf is to account for something a specific region is experiencing.   

## **If No (or Few) Champions Fall Into Buff or Nerf Territory?**

Then we’ve finally balanced League of Legends. Time to pack it up.

But really, if we’re in a stable state where we’ve dealt with most of the overly strong and weak champions, then our next priority is to make champions more balanced across multiple audiences, or consider reevaluating if the current power bands meet the game’s modern needs. It’s possible these bands shrink gradually over time, to some degree. There’s also always work to consider on runes, items, positions, and more to make sure all of these are balanced against one another.

## **So What About Items, Summoner Spells, and the Jungle?**

There’s much more that goes into a balanced League experience than just the power level of champions. But champions are also the lens through which players experience the game, and the piece of the game that tends to resonate most strongly with players.

Most other patch work can be done in service to this approach. For example, we changed the Rift Scuttler’s spawn timer to open up the jungle to a wider variety of champions. We nerfed/changed Ardent Censer to make it so players didn’t feel like they absolutely had to pick enchanters. Generally speaking, when the power level of systemic content is so high that it dictates the champions you want to play, League is a much less compelling game for most players.  

## **If I Have Thoughts About The New System or Balance In General?**

Please let us know! We think this new approach will ultimately lead to better, more consistent champion balance for players across all skill levels, but if the champions we’re targeting for buffs and nerfs don’t seem to make sense from your experience, we’re very open to adjusting it. We don’t expect to reach a point where perception lines up perfectly with the champs we buff and nerf, but we do hope this system brings us closer to that.

We’ll be around in the comments today to answer some of your questions and read your thoughts. On behalf of the entire Summoner’s Rift team, thanks for reading!

## Related Articles

1.  [
    
    Dev
    
    10/20/2026
    
    /dev: Mel Midscope
    
    We’re updating Mel, and here’s the how and why.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-mel-midscope)
2.  [
    
    Dev
    
    10/14/2026
    
    /dev: League Classic
    
    What’s changing with League Classic.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-league-classic)
3.  [
    
    Dev
    
    9/8/2026
    
    Dev Update: Team Voice, Classic & More
    
    Pabro, Meddler, FeralPony, and Phreak talk about Team Voice, Classic, Mayhem, Ranked 5s, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=9vrcrlJqqvY)
4.  [
    
    Dev
    
    9/8/2026
    
    TL;DW: Team Voice, Classic & More Dev Update
    
    A short rundown of changes from today’s Dev Update.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/tldw-team-voice-classic-more-dev-update)
5.  [
    
    Dev
    
    7/14/2026
    
    TL;DW: Classic, Mayhem & More Dev Update
    
    A short rundown of changes from today’s Dev Update.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/tldw-classic-mayhem-more-dev-update)
6.  [
    
    Dev
    
    7/14/2026
    
    /dev: League of Legends Classic
    
    Welcome back, Summoners.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-league-of-legends-classic)
7.  [
    
    Dev
    
    7/14/2026
    
    Dev Update: Classic, Mayhem & More
    
    Pabro, Meddler, FeralPony, and Phreak talk about Classic, Mayhem, Hall of Legends, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=KV1ArTWlEFU)
8.  [
    
    Dev
    
    6/26/2026
    
    200 YEARS OF EXPERIENCE
    
    Pabro has a breakthrough, he just needs Meddler on board.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=fTH-CylOvcc)
9.  [
    
    Dev
    
    5/27/2026
    
    Dev Update: Mayhem, Ranked 5s & More
    
    Pabro, Meddler, Phlox, and Cadmus talk about ARAM: Mayhem, Ranked 5s, skins, MSI, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=3_0h_vuIKv4)

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
