# How does Leetify Rating actually work?

<https://leetify.com/blog/leetify-rating-explained/>

-   [← Back to Leetify](https://leetify.com/)

-   [Blog Home](https://leetify.com/blog/)
-   [Sign up for Leetify](https://leetify.com/signup)

How does Leetify Rating actually work?

[Leetify Rating](https://leetify.com/blog/tag/leetify-rating/)

# How does Leetify Rating actually work?

The complete guide to understanding how Leetify Rating works.

-   ## Danny Hsieh
    
    Read [more posts](https://leetify.com/blog/author/mahone/) by this author.
    

#### [Danny Hsieh](https://leetify.com/blog/author/mahone/)

25 Nov 2024 • 6 min read

# **Table of contents**

-   [What is Leetify Rating?](https://leetify.com/blog/leetify-rating-explained/#what-is-lr)
-   [How should I interpret this number?](https://leetify.com/blog/leetify-rating-explained/#lr-interpretation)
-   [How is this number calculated?](https://leetify.com/blog/leetify-rating-explained/#lr-calculation)
-   [How is rating gained or lost?](https://leetify.com/blog/leetify-rating-explained/#lr-gain-loss)
-   [How is Win Probability calculated?](https://leetify.com/blog/leetify-rating-explained/#lr-wp)
-   [How is Saving handled?](https://leetify.com/blog/leetify-rating-explained/#lr-saving)
-   [What happens if the round ends with players surviving on both teams?](https://leetify.com/blog/leetify-rating-explained/#lr-players-surviving)
-   [Frequently Asked Questions (FAQ)](https://leetify.com/blog/leetify-rating-explained/#lr-faq)

## **What is Leetify Rating?**

Leetify Rating is a performance metric that rates how well you've played in a match.

It's a system that rewards kills while considering economy, the number of players alive in the round, and the context of the round.

You've likely seen this number in the post-match page or on your profile page.

Leetify Rating on the match page

Leetify Rating is a number centered around zero. It can be positive or negative. Positive numbers mean you've done well, while negative numbers mean you've done poorly.

## **How should I interpret this number?**

When you see your Leetify Rating, it helps to visualize the number on a bell curve to understand your performance. Look at the graphic below.

Leetify Rating bell curve visualization

In a evenly matched game, most players will have an average performance. While players who have great or poor performances will lean towards the edges.

-   Great: Above +5.12
-   Good: +2.09 to +5.12
-   Average: -2.09 to +2.09
-   Subpar: -5.12 to -2.09
-   Poor: Below -5.12

The bell-curve effect is the result of how Leetify Rating was built. If you add up all the ratings of all the players in the game, it equals zero. Leetify Rating is a zero-sum metric, as rating gained for one player means rating lost for another.

## **How is this number calculated?**

The Leetify Rating you see on the scoreboard is the average Leetify Rating you gained in each round.

The amount you gain in a round depends on your contribution.

## **How is rating gained or lost?**

Rating is gained or lost primarily through kills. Not all kills are rewarded the same amount. The reward for a kill varies based on the situation.

The size of the kill reward is based entirely on the **Change in Win Probability**.

**Change in Win Probability** is based on how much a kill improves their team's chances of winning in the current round. This depends on the economy of both teams, how many people are alive in the current round, and which side got the previous kill.

Based on this amount, players are rewarded for their contribution to the kill.

-   35% for the player who got the kill
-   30% for all players who did damage to the victim
-   15% for the player who gets a flash assist
-   20% for the player who gets their death traded

If any of these are absent, then the remaining ones are scaled up. See the chart below to see the different situations:

Here are a number of scenarios to better understand who gets rewarded when a kill happens.

As mentioned previously, Leetify Rating is a zero-sum metric. Although the reward for kills can be distributed to multiple people, the punishment for deaths is placed only on the person who died.

## **How is Win Probability calculated?**

Win probability is calculated at the start of the round and changes after each kill until the end of the round. The calculation only considers factors in the current round.

At the start of each round, we look at what weapons and equipment both teams have. We determine which economy group they're in. The economy groups vary slightly for CTs and Ts to account for the different weapon prices.

Based on the groups, we calculate the chances of winning the round for both teams.

These act as the starting odds for the round. Once the round starts, they change when kills happen.

We also consider which side dies just before an XvX situation. For example, a 4v4 can stem in two ways, either the CTs initially had the 5v4 advantage or the Ts had it first. Both of these lead to different percentages.

Leetify Rating only considers rounds in isolation. There is no consideration to what the current scoreline is.

The percentages for every situation are based on historical data from every Counter-Strike 2 match played on HLTV. We use HLTV as the data source because it’s the most optimized level of play while still having enough matches to cover every situation.

## **How is saving handled?**

We reward players for saving their equipment into the next round.

The amount depends on how much the saved equipment raises the team's chances of winning in the following round. Each player gets rating based on their contribution.

Surviving players on the winning team are punished equally for letting players on the losing team survive.

## **What happens if the round ends with players surviving on both teams?**

As a reminder, these are three possible scenarios where players on both teams survive: the bomb explodes (CTs save), the bomb is defused (Ts don't kill the defuser), time expires (Ts don't make a move).

Players are rewarded or punished based on the final change in odds. Each surviving player on the winning team gets positive ratings while each surviving player on the losing team gets negative ratings. They are distributed equally.

This means that although you'll receive rating for saving your weapons into the next round, you also have to consider how much you'll lose by not attempting the objective.

You will lose rating from saving if the extra weapons don't do much to improve your team's economic situation, or if your chances of winning the current round outweigh the benefits of saving.

## **Frequently Asked Questions (FAQ)**

**What are all the ways you can gain rating?**

-   Getting a kill
-   Damaging a player who eventually dies
-   Flash assists
-   Getting your death traded
-   Saving your weapon into the next round
-   Winning the round through objectives (bomb explodes as a T, time expires as a CT, bomb is defused as a CT)

**What are all the ways you can lose rating?**

-   Dying
-   Losing the round through objectives (bomb explodes as a CT, time expires as a T, bomb is defused as a T)
-   Not hunting down the last surviving players

**My friend plays at a much lower rank than me, but they have a higher Leetify Rating than I do. Does that mean they're better?**

Leetify Rating is a performance metric, not a skill metric. If your friend has a higher Leetify Rating, it simply means they're performing at a higher level in **their** games compared to you in **your** games.

If you were both playing in the same games (with the same teammates and opponents), then this is a case where your friend might actually be better.

**I feel like I had a great game but my Leetify Rating is so low. Why?**

There are generally two reasons why: it could mean you were getting low impact kills or your deaths were impactful for the other team.

Low impact kills could be getting kills in rounds where your opponents have pistols when you have rifles, or getting the kill on the last player when your team is already up in a 5v1.

Impactful deaths could mean dying in a lot of 2v2 or 1v1 situations. These deaths swing the round heavily in the other team's favour, resulting in a large punishment.

**My Leetify Rating is really high, but somehow my aim rating is really low?**

Aim Rating is completely separate from Leetify Rating. They measure different aspects of the game. Leetify Rating is meant to measure your overall impact on winning the game, while Aim Rating measures your mechanical ability.

**There's a smurf who's clearly better than everyone else in my game. Do I get more Leetify Rating for killing them?**

No, everyone is treated equally. Leetify Rating does not look into the history of players and it doesn't account for anyone who might be on a "hot streak." Each player is treated the same throughout the entire match.

## Track your CS Performance

Celebrate your best plays, compare accomplishments with your friends, and see who carried with our automatic match reports.

[Sign up](https://leetify.com/signup)

### More in [Leetify Rating](https://leetify.com/blog/tag/leetify-rating/)

-   #### [Leetify Rating: clutch weighting changed & bug fixes](https://leetify.com/blog/leetify-rating-update-2026-02-25/)
    
    19 Mar 2026 – 3 min read
    
-   #### [Leetify Rating has been updated for CS2](https://leetify.com/blog/leetify-rating-update/)
    
    25 Nov 2024 – 5 min read
    
-   #### [How to Use: Leetify Rating Breakdown Tab](https://leetify.com/blog/rating-breakdown/)
    
    23 Jun 2023 – 5 min read
    

[See all 7 posts →](https://leetify.com/blog/tag/leetify-rating/)

[

Leetify Rating

## Leetify Rating has been updated for CS2

Leetify Rating has been recalibrated for CS2, plus a few upgrades to more accurately assess your performance.

](https://leetify.com/blog/leetify-rating-update/)

-   Danny Hsieh
    

[Danny Hsieh](https://leetify.com/blog/author/mahone/) 25 Nov 2024 • 5 min read

[

CS2 Statistics

## CS2 Rank Distribution - Premier, CS2 to CSGO, Competitive, Wingman

The current CS2 Rank Distribution as of September 2024 for Premier, Competitive, Wingman, and what your CS2 rank would be in CS:GO.

](https://leetify.com/blog/cs2-ranks/)

-   Danny Hsieh
    
-   Jaret Anderson
    

[Danny Hsieh](https://leetify.com/blog/author/mahone/), [Jaret Anderson](https://leetify.com/blog/author/jaret-anderson/) 18 Oct 2024 • 5 min read

#### Follow us for more content:

©2026 Leetify. All rights reserved.
