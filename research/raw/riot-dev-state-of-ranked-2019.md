# /dev: State of Ranked – League of Legends

<https://web.archive.org/web/20191008143834/https://nexus.leagueoflegends.com/en-us/2019/03/dev-state-of-ranked/>

[Explore  
League](https://na.leagueoflegends.com/en/)

League of Legends

[Home Explore League of Legends](https://na.leagueoflegends.com/en/) [News Catch up on League news](https://na.leagueoflegends.com/en/news/) [Game Learn about League](https://na.leagueoflegends.com/en/game-info/) [Universe Explore the League universe](https://universe.leagueoflegends.com/en_US/)

[Nexus Look behind the scenes of League](https://nexus.leagueoflegends.com/) [Esports See pros battle for glory](https://www.lolesports.com/en_US/) [Community Connect & Contribute](https://boards.na.leagueoflegends.com/en/) [Support Get the help you need](https://support.riotgames.com/hc/en-us)

Riot Games

[Merchandise Equip yourself IRL](https://na.merch.riotgames.com/en/)

Nexus [Overview](https://nexus.leagueoflegends.com/en-us/) [Champions](https://nexus.leagueoflegends.com/en-us/search/champions/) [Ask Riot](https://nexus.leagueoflegends.com/en-us/search/ask-prcnt-20riot/) [/dev](https://nexus.leagueoflegends.com/en-us/search/-prcnt-2Fdev/)

Service Status

[Play Now](https://signup.na.leagueoflegends.com/en) Login

North America (English)

# Ask Riot

Ask a question about League or Riot, and we’ll try to answer it. Answers go live every other Thursday at 1:30 pm (PT)

Thank you for submitting a question!

Next Article

[/dev](https://nexus.leagueoflegends.com/en-us/search/-prcnt-2Fdev/)

# /dev: State of Ranked

We reflect on the season, reveal the rollback of position ranks, and detail a partial reset for Diamond+.

By [Riot SapMagic](https://nexus.leagueoflegends.com/en-us/search/riot-prcnt-20sapmagic/)

7 months ago

**TLDR: We’re happy with some of the Ranked changes like the placements rework, and positional matchmaking is an improvement in several areas. However, the reception of position** **_ranks_** **hasn’t been as positive, so we’re discontinuing the global rollout and ending the position ranks preview in KR and NA on** **March 13****. We also concluded our investigation into Diamond+ matchmaking/rank issues. To fix them, we’ll be setting all Master+ players to Master 0 LP and demoting Diamond players by one division, floored at Diamond IV, by late March.**

Hey everyone, Ed “SapMagic” Altorfer here, back again to talk about Ranked. Last week, [we recapped](https://boards.na.leagueoflegends.com/en/c/developer-corner/voxV8l2u-ranked-2019-dev-update-3) some of the biggest issues we’re facing with position ranks, high-skill matchmaking, and the top of the ladder. In this article, we’re detailing our solutions and timeline for fixing those issues. Since this is likely to reach a broader audience than our initial update, we’ve included some information that might feel repetitive if you’ve been following along. Alright, enough introduction—let’s dive in and talk about the state of Ranked.

## What’s Working

So far, many players seem to be enjoying the placements rework, which starts you off at a more predictable rank and gives you feedback after each game. We’re also excited to see what we can do with splits—we think rewards that unlock and rank up with you in real time have a ton of promise.

On the matchmaking side, we’re happy with how positional matchmaking—not to be confused with position **ranks**—is working. Queue times have improved for many players and off-position win rates have gone up. On top of that, primary position rates have improved, and in many cases, autofill rates have gone down.

With some of our other changes, it’ll take more time before we know whether we need to make additional tweaks—specifically, we’re interested in your feedback on split reward content, borders, and past rank banner trims.

## Position Ranks

With position ranks, we decided to run a preview in North America and Korea as a way to gather feedback and iterate on the feature before rolling it out more broadly. Six weeks into the season and after numerous bug fixes and tweaks, a significant number of you are still frustrated with the grindiness, low satisfaction of off-position games, and teammates not taking off-position games seriously enough.

That’s not just on social media either. We’re constantly polling players to understand what they like or don’t like about League. Since position ranks launched, we’ve seen a dramatic negative shift—by 20 to 30%—in satisfaction with the feature in both North America and Korea.

After reviewing your feedback, we regrouped and considered all the changes we could make to improve the system. Ultimately, we didn’t feel like we could make position ranks the experience you deserve by tweaking LP splashing or making changes to promotion series. Many of you simply aren’t happy with the core trade-offs of the system.

Since the beginning, we vowed to develop this feature _with_ you and promised we would roll it back if you weren’t enjoying it. We stand by that promise, so **on March 13** **we’re** **ending the position ranks preview** **in North America and Korea and discontinuing the rollout of position ranks globally**.

Here’s how the rollback will work:

-   **Your highest position rank becomes your new rank. We’ll preserve your rank, LP, and promotion series status and progress. If your highest rank is provisional, it will carry over with the same number of games remaining.**
-   **You’ll keep your rewards. Your Ranked Armor and any split rewards will stick around and you won’t lose any progress.  
    **
-   **All Promotion Helper benefits carry over. We’ll remember the highest rank you’ve achieved across all positions and use that to determine Promotion Helper eligibility.**

**Even though we’re ending the position ranks preview, we made a ton of improvements to matchmaking in the process of building the feature—like faster queue times and higher primary position rates—that we’ll be keeping. We’re also looking into keeping positional matchmaking, which would make off-position games more fair even **_without_** position ranks. We’ll share more when we have a solid plan.**

## High MMR Matchmaking/Ranks

We’ve also seen numerous matchmaking issues affecting players in Diamond and above. Some of this is expected since we rebalanced the top tiers and expanded the size of Master, [as I noted in our previous update](https://boards.na.leagueoflegends.com/en/c/developer-corner/voxV8l2u-ranked-2019-dev-update-3), but there are some legitimate issues we need to fix as well. There are two in particular we want to address.

First, adding Iron and Grandmaster tiers introduced a bug that allowed a nontrivial number of players—up to 155 on one server—to get to Grandmaster despite having a win rate below 40%. Another related bug allowed some Diamond players to climb to higher ranks than they should’ve been able to.

In both cases, we fixed the underlying issues that let players get to higher ranks than they should’ve, but now players feel stuck since they’re losing more LP than they gain while their rank recalibrates. On top of that, we’ve heard consistent feedback that the top of the ladder feels less legitimate due to the lingering effects of these bugs.

Given enough time, decay and normal play would get these players back to where they belong based on their skill, but it could take several months or longer for that to happen, during which time high-skill players would continue to feel frustrated about the quality of their games.

Instead of leaving the ladder in its current state for a large chunk of the season, **we’re going to perform a** **partial ladder reset** **in all regions in late March for players in Diamond and above**. While we’re currently targeting late March, we need to thoroughly test our approach or we could risk introducing new problems. Once we have a firm date, or if we need to adjust the timing, we’ll share the details with you.

Here’s how the reset will work:

-   **Master, Grandmaster, and Challenger players will become Master 0 LP.** Resetting the top of the ladder will accelerate the demotion of players who got to Master through exploiting early season bugs and help normalize LP gains.  
    
-   **Diamond players will be demoted one division, floored at Diamond IV.** These demotions will improve—but not completely fix—LP gains for players who got to higher ranks than they should have early in the season.  
    
-   **You’ll keep your rewards, but they’ll match your new rank. You won’t lose any reward _progress_, but if you have the Split 1 emote or armor upgrade, they’ll match your post-reset rank.  
    **
-   **Grandmaster and Challenger will temporarily lock. Grandmaster will unlock one week after the reset and Challenger will unlock the week after that.**

A mid-season partial reset is painful, so we want to limit it to as few players as necessary to fix the issues outlined above. We’re not seeing these problems at lower ranks, so it would be unfair and unnecessary to reset progress for all players. We’re deeply sorry for the frustration we know this will cause for players who earned their spot legitimately, but we believe this partial reset is necessary to preserve the integrity of the top of the ladder.

## What’s Next

On behalf of the team, thank you for working together with us on position ranks and the rest of the Ranked changes. We’re committed to working with you to build experiences you love. Sometimes that means taking big swings and missing the mark. We’re hope that over time we’ll get to share the benefits of this approach to development, and we hope you’ll be willing to join us on the next journey… wherever that may take us.

Until then, if you’re seeing any other issues that aren’t captured here or you just have feedback on Ranked, let us know in the comments. Thanks again for all your help and patience, and we’ll see you on the Rift!

[Riot SapMagic](https://nexus.leagueoflegends.com/en-us/search/riot-prcnt-20sapmagic/)

UX Lead for Teamfight Tactics

Ed Altorfer

SapMagic heads up the team working on Ranked. His favorite type of shirt (and meta) is tank tops.

-   
-   
-   
-   

[Next Article

# LCS Week 7 Day 2 Featured Match: OPT VS. TSM

](https://nexus.leagueoflegends.com/en-us/2019/03/lcs-featured-match-week-7-day-2-opt-vs-tsm/)

-   [About League Of Legends](http://gameinfo.na.leagueoflegends.com/en/game-info/get-started/what-is-lol/)
-   [Prepaid Cards](http://na.leagueoflegends.com/en/page/league-legends-prepaid-game-cards/)
-   [Help Us Improve](http://leagueoflegends.na-surveyen2.sgizmo.com/s3/)
-   [Service Status](http://status.leagueoflegends.com/?en_US#na)
-   [Support](https://support.riotgames.com/hc/en-us)
-   [Esports Pro Site](http://www.lolesports.com/en_US)

© 2019 Riot Games, Inc. All rights reserved. Riot Games, League of Legends and PvP.net are trademarks, services marks, or registered trademarks of Riot Games, Inc.
