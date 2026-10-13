# VALORANT Systems Health Series - Smurf Detection

<https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-smurf-detection/>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-smurf-detection/#cf5efbe4-f6ac-414d-b068-c7c06033c404)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

GAME INFO

[

MEDIA

](https://playvalorant.com/en-us/media)

[

NEWS

](https://playvalorant.com/en-us/news/)

SUPPORT

Our Socials

[

ESPORTS

](https://valorantesports.com/)

[

Merch

](https://merch.riotgames.com/en-us/category/valorant/?page=1&sort=dateDesc)

More

[GAME INFO

](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-smurf-detection/#)[MEDIA](https://playvalorant.com/en-us/media)[NEWS](https://playvalorant.com/en-us/news/)[SUPPORT

](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-smurf-detection/#)[Our Socials

](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-smurf-detection/#)[ESPORTS

](https://valorantesports.com/)[Merch

](https://merch.riotgames.com/en-us/category/valorant/?page=1&sort=dateDesc)[Frag or Die](https://ftw.riotgames.com/valorant/challenges/champions-conflict-frag-or-die)

[

PLAY NOW

](https://playvalorant.com/en-us/platform-selection/)

[PLAY NOW](https://playvalorant.com/en-us/platform-selection/)

# VALORANT Systems Health Series - Smurf Detection

The latest on our work to combat smurfs, some results, and next steps.

[Dev](https://playvalorant.com/en-us/news/dev/)

Brian “Riot South Korea” Chang

12/20/2022

This article is a part of a series of deep dives on topics in the Competitive/Social & Player Dynamics space of VALORANT. Learn more about the series [here](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-intro/).

Hello, Brian Chang back with another addition to our VALORANT Systems Health series. It’s been a while since we shared anything with you here (the last article was in February of this year!). Hopefully the wait was worth it, because this article is going to deep dive into the single most requested topic since we started this article series: **alternate accounts/smurfs**.

Fair warning—this is a longer read than our previous articles in this series. Here’s the TL;DR:

-   Earlier this year, we **implemented Automated Smurf Detection** to adjust smurf account MMRs. The experiment was successful, leading to a **significant reduction in matches with a smurf in them that resulted in stomps**.

-   In addition, **changes to 5-stack restrictions** have caused a **meaningful reduction in smurf activity**, which also led to an **increase in match fairness** in the same period. 5-stack matchmaking continues to be the fairest type of matches in all of VALORANT.

-   **Overall, smurf counts are down ~17%** compared to earlier in the year, and **newly created smurfs are getting to their “correct” MMR 2–3 times faster**. More improvements and additions are planned in 2023!

This article will be broken down into the following sections:

1.  What are alternate accounts, and why do we care about them?
2.  What work has been done to reduce alternate accounts?
3.  What are the results, and what future work do we have planned?

**PART 1: What are alternate accounts/smurfs, and why do we care about them?**

An alternate account, sometimes referred to as a “smurf,” is an account that is played by someone who already has another account.

On VALORANT, **we think about alternate accounts as a symptom of multiple motivations.** The better we address the underlying motivations behind creating alternate accounts, the less likely we are to see them exist in our game.

Some of these underlying motivations are perfectly legitimate motivations. A good example is the desire to play competitively with your friends that may be of a different rank than you. On the other hand, there are malicious motivations that we don’t want to enable. Examples include creating alternate accounts to stomp easier opponents (which is typically the primary way the term “smurfing” is used), or creating new accounts because your main was banned for violating rules.

**By far the most common reason that players have for creating alternate accounts is to play competitively with friends of different ranks.** This is a legitimate motivation that we want to enable in VALORANT. However, creating a new account should not be the way to fulfill that motivation; we should try to provide avenues for allowing social competitive play without the need to play on multiple accounts (but more on that later).

Finally, it’s worth noting that **some of the malicious motivations** behind smurfing are also associated with behaviors that are explicitly against our terms of service, and will result in a ban. These behaviors **include sharing accounts between multiple users, purchasing accounts, or intentionally tanking an account’s MMR by losing/forfeiting games**. All of these behaviors are being actively tracked, detected, and removed from our game.

So that’s what smurfing is and why people create alternate accounts. Why do we care about them, and why do we want to remove them from VALORANT?

-   **Alternate accounts/smurfs are more likely to bring instability to matchmaking fairness:** A new account that is being played on by an experienced player will take time to get to their “correct” MMR/rank. During this time, the matchmaker will have a harder time making fair matches. When you enter a match of VALORANT, we want you to have confidence that you are entering a fair match, and smurfs compromise our ability to guarantee this.
-   **Alternate accounts/smurfs are more likely to be behaviorally disruptive in VALORANT:** Our data shows that accounts that we’ve identified as alternate accounts/smurfs are reported more often (not just for gameplay behaviors, but also for text and voice toxicity), and are also more likely to be punished for being disruptive. This could be because players on these accounts “care less” if their secondary accounts are banned, or it could be because anyone playing on a smurf is more likely to be disruptive in the first place (even on their main).
-   **Perhaps most importantly, YOU care about alternate accounts/smurfs:** In surveys that we’ve launched pretty much since the game’s launch, the single most frequently mentioned issue that players bring up with Competitive VALORANT play is the prevalence of smurfs. Based on our data, we do think that the perception of smurfs likely outsizes reality, but that’s also part of the problem we need to tackle. We can’t just work on reducing alternate accounts in VALORANT; we have to show you the work we’re doing/the results so you know how things have changed.

**PART 2: What work has been done to reduce alternate accounts?**

Now that we have established what problem we’re trying to address, let’s talk about some of the solutions (and their results)!

### Automated Smurf Detection

Our VALORANT Data Ops team focuses on leveraging data and machine learning to make the game more fun for players. With Automated Smurf Detection, the primary goal was to use data to place smurf accounts within their correct MMR as quickly as possible, dramatically decreasing the number of games where players experience unfair matches. In order to test our detections, the team conducted a test in North America ([in Patch 5.01](https://playvalorant.com/en-us/news/game-updates/valorant-patch-notes-5-01/)) to validate that we could accurately identify smurf accounts and successfully bump their MMR to be as close as possible to their primary account.

We can’t get too into the details of _how_ we identify smurfs (this would make it easier for players to bypass detections), but we absolutely can share the results of our automated detections!

For the first test, we measured the rate of stomp matches (when one team wins by 8 or more rounds). For reference, before the changes, the stomp rate for smurfs was a whopping 32%

across all games of VALORANT (so in other words, 1 in 3 matches with smurfs was ending in a stomp).

Our goal was to get this stomp rate number closer to the “regular,” non-smurf stomp rate. Keep in mind that it’s impossible to get the stomp percentage to 0%. Sometimes, a match of 10 very similarly skilled players can still end in a stomp (you suddenly pop off and have the best game of your life, you hit a wall and have the worst game of your week, a player’s internet disconnects and the game is a 4v5, etc.).

To test our systems, we started off by adjusting MMRs for only 50% of the detected smurfs, while leaving the other 50% alone (this is called the control group). We do this in order to determine whether the adjustments we made actually had a material impact on fairness.

By the end of the NA test, we saw that the 50% of detected smurfs whose MMRs we adjusted **were within 1% of our target stomp rate,** while the 50% of detected smurfs that we didn’t adjust in our control group were still stomping in 25% of their matches!

With these very positive early results, we decided to expand automated smurf detection globally through one final experiment where we once again allowed smurf detection to adjust 50% of detected smurf’s MMRs, while leaving the other 50% alone throughout August. Throughout the test, we saw similar improvements in the percentage of stomp matches.  

We also wanted to take this a step further and understand how many games it took to place the typical smurf back in the same MMR as their primary account. According to our data, **smurfs that we adjusted were landing in their appropriate MMR in as little as 4 matches**, whereas the smurfs left alone in the control group were still ~3 divisions away from their correct MMR after playing 10 matches.

With all of these exciting results, we officially launched smurf detection worldwide to all regions in September! A**s a next step, the team is looking into ways** **of making sure no smurfs slip through the cracks** by bolstering the ways we identify smurfs during matches, and by experimenting with the amount of MMR we adjust to detected smurfs (putting them at the same MMR as their main account even faster). In fact, the team is already working on these updates.

### 5-stack Changes

In addition to addressing smurfs by identifying them and putting them in fair matches, **we’ve also made specific changes to lower the incentive to create alternate accounts in the first place**.

One of those changes we made in [Patch 3.10](https://playvalorant.com/en-us/news/game-updates/valorant-patch-notes-3-10/) (a year ago!) was to allow players of any rank to 5-stack together (where high discrepancy 5-stacks would receive and lose diminished Ranked Ratings). Since then, we’ve made additional changes to the restrictions as we learn more about queue times, match fairness, and overall receptivity to our changes.

Why does this change help reduce alternate accounts? As noted earlier, the single largest reason players create alternate accounts is to play competitively with friends. Allowing higher skill-discrepancy 5 stacks to exist was an attempt to let players fulfill that motivation without the need to create smurfs.

So what do the results look like? To start—here’s the percentage of all matches that happened in Competitive VALORANT, split by party size:

As you can see, **there’s a jump in Patch 3.10 (when we made the changes to 5-stacking)**, **but after that, there isn’t too much of a difference over time.** The frequency with which 5-stacks were jumping into Competitive stayed roughly the same.  

However, here’s the same distribution of 5-stacks that played Competitive, split by whether they were a “normal” 5-stack (one that would have been able to play prior to the changes in Patch 3.10) vs. a “high discrepancy” 5 stack (a party that only was able to form after the changes made):

While there wasn’t a major difference in the rate at which 5-stacks were participating in Competitive, there was a significant shift in the makeup of those 5-stacks. A large number of 5-stacks today are ones that would not have been able to play together before the changes in Patch 3.10.  

One question we received from players when we made this change was “wouldn’t this negatively affect match fairness?” Thankfully, **the data shows us that match fairness did not meaningfully shift downward as a result of the 5-stack changes**. In fact, 5-stack matches became more close after we made these changes; since players were playing less on their smurfs and more on their mains, it was easier for our matchmaking to ensure a fair match. Today, over a third of all 5-stack matches end in a 13-10 or closer. 5-stack matches are actually closer in score than any other match in Competitive!

**PART 3: What are the results, and what future work do we have planned?**  

So we made a number of changes and saw improvements, but did we actually reduce alternate accounts in VALORANT?

Short answer: **Yes**!

Here’s a graph that shows the estimated number of secondary accounts active in VALORANT, split by patch:

\[We see an overall reduction in secondary accounts, and specifically, the steepest reductions happened when we launched the various initiatives mentioned earlier.

But we’re not done yet! There’s still additional work to be done (some of which is ongoing). These include:

-   **More improvements/additions to our smurf detection methodology,** so we can find and act on smurfs even faster
-   **Continued efforts to detect and act against boosting, account sharing and account purchasing,** which are both against our Terms of Services and often associated with secondary accounts. Again, we can’t share too much information here (since revealing how we detect this type of behavior would compromise the very detection systems), but we are looking into this.
-   **Additional ways for players of varying skill levels to play VALORANT competitively together**. Recently, we announced the [Alpha test of Premier](https://playvalorant.com/en-us/news/announcements/announcing-valorant-s-premier-alpha-test/), a high-stakes team-based competitive system in VALORANT. We hope that these systems will provide more avenues for players to play socially without feeling the need to create secondary accounts.

**If you’ve made it this far, thanks!** There was a lot of information that we were excited to share about our efforts to reduce the need to create secondary accounts in VALORANT.

Smurfing/secondary accounts is one of the most commonly brought up topics from you, the players. One thing to note is that there are instances where players _believe_ that they are playing with someone who “doesn’t belong” in a rank, when in reality that player might just be having an unusually great game. For that reason, **we know that we’ll never be able to completely eradicate any and all concerns that players have around secondary accounts and smurfing in VALORANT.**

**But that doesn’t mean that we’re planning on stopping efforts on this front anytime soon.** While a lot of work has been done to address your concerns, we know there’s still much more we can do to make sure that your competitive VALORANT experience is fun and fair. Thank you for sharing your thoughts, and please keep letting us know about what you want to see change in VALORANT in the future!

## Related Articles

1.  [
    
    Dev
    
    4/11/2023
    
    VALORANT Systems Health Series - AFK and Queue Dodge Update
    
    We are updating our participation-related penalties in Patch 6.07.
    
    
    
    
    
    
    
    
    
    
    
    ](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-afk-and-queue-dodge-update/)
2.  [
    
    Dev
    
    5/30/2022
    
    VALORANT Systems Health Series - Map Diversity
    
    Dropping by to help you understand how we’re tuning map diversity in the Competitive queue.
    
    
    
    
    
    
    
    
    
    
    
    ](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-map-diversity/)
3.  [
    
    Dev
    
    2/10/2022
    
    VALORANT Systems Health Series - Voice and Chat Toxicity
    
    Members of the Social and Player Dynamics team update you on ongoing future work on voice and chat toxicity.
    
    
    
    
    
    
    
    
    
    
    
    ](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-voice-and-chat-toxicity/)
4.  [
    
    Dev
    
    12/16/2021
    
    VALORANT Systems Health Series - AFK
    
    Members of the Social and Player Dynamics team drop the latest on AFK data and work.
    
    
    
    
    
    
    
    
    
    
    
    ](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-afk/)
5.  [
    
    Dev
    
    12/15/2021
    
    VALORANT Systems Health Series - Intro
    
    We lay out our plans for months-long communications around game systems health.
    
    
    
    
    
    
    
    
    
    
    
    ](https://playvalorant.com/en-us/news/dev/valorant-systems-health-series-intro/)

-   [Download Riot Mobile Companion App](https://riotmobile.go.link/d0lYd)

-   [Twitter](https://twitter.com/valorant)
-   [YouTube](https://www.youtube.com/@valorant)
-   [Instagram](https://instagram.com/valorant)
-   [TikTok](https://www.tiktok.com/@valorant)
-   [Facebook](https://www.facebook.com/playvalorant/)
-   [Discord](https://discord.gg/valorant)

© 2020-2026 Riot Games, Inc. RIOT GAMES, VALORANT and any associated logos are trademarks, service marks, and/or registered trademarks of Riot Games, Inc.

-   [Privacy Notice](https://www.riotgames.com/en/privacy-notice)
-   [Terms of Service](https://www.riotgames.com/en/terms-of-service)
-   [Cookie Preferences](javascript:void\(0\);)
