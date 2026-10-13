# LoL: How to win your Solo Queue Draft - a statistical analysis of 1M+ games | iTero - League of Legends Companion Coach

<https://www.itero.gg/articles/draft-sq>

-   [Consent](https://www.itero.gg/articles/draft-sq#)
-   [Details](https://www.itero.gg/articles/draft-sq#)
-   [About](https://www.itero.gg/articles/draft-sq#)

This website uses cookies

We use cookies to personalise content and ads, to provide social media features and to analyse our traffic. We also share information about your use of our site with our social media, advertising and analytics partners who may combine it with other information that you’ve provided to them or that they’ve collected from your use of their services.

 

[Drafting Simulator](https://www.itero.gg/drafting-simulator)[Champion Pool Builder](https://www.itero.gg/champion-pool-builder)[Quiz](https://www.itero.gg/quiz)[Champions](https://www.itero.gg/champion-statistics-table)[ARAM](https://www.itero.gg/aram-builds)[Articles](https://www.itero.gg/articles)

Language[Download now](https://d2p8l77jawz1l9.cloudfront.net/The%20iTero%20Companion%20App.exe)

# LoL: How to win your Solo Queue Draft - a statistical analysis of 1M+ games

September 8, 2022

Games are both won and lost in Champ Select, here’s a statistical overview of the biggest contributors to that result.

So, we finished off our series on drafting in professional games (you can find them [all here](https://www.itero.gg/articles) if you’re late to the party). The question remains: can we translate any of our lessons to solo queue?

If you follow me elsewhere, you know I actually answered this question a while ago and used it to launch our first product: [The iTero drafting coach.](https://www.itero.gg/articles/draft-sq#)

This article is quantifying those results, visualising what we found from studying 1M+ solo queue games in order to train the AI.

## “Master Yourself, Master the Enemy”

It should come at no great surprise to anyone that by far the most impactful of all is the level of Mastery you have on a Champion.

> How Champion Mastery Impacts Win Rate

It’s not even that you need hundreds of games before a Champion becomes an acceptable pick — it’s just that so many players insist in mid-elo insist on first timing in ranked! The drop off is considerable, with sub-5k Mastery players averaging a win rate of just 41.5%, compared to the 54.5% enjoyed by 500k+ players. The increase is fast, but diminishing returns hits fast. The gain from 75k to 175k is not even a single percentage point, whilst going from 2.5k to 7.5k is almost 8%.

There is a simple lesson here: don’t first pick in Ranked.

## Champion Win Rate

There’s not so much point graphing the correlation between a Champion’s win rate and how many games that player ends up winning — since they are practically the same thing (apart from some sampling randomness). So, instead — let’s look at the sort of values we tend to see in our ranked games.

> The Distribution of Champion Win Rates

A grand majority of Champions sit between the 46–54% range, with few outliers. Of course, all else being equal it’s better to sit at the top of this scale where you can, but there’s not a huge range.

## Counters & Pairs

If you play ranked, the chances are that you will occasionally look at the top lane counters to face up against your opponent. However, how often do we consider any other lane. Sure, your mid laner counters their mid laner, but how does it fair **against** their jungler? Or the **synergy** with your support?

The game is only isolated to the 1v1 for a relatively short period of the game when compared to all those skirmishes and team fights that will happen post-laning phase. No doubt, your 1v1 lane match-up will have the most significant impact — but that doesn’t mean you should ignore everything else!

> The impact of each lane win rate counters

This grid shows you the impact each lane counter has, where the darker the colour the more it sways the final outcome. For instance, the mid vs. mid match-up is by far the most important for those playing that lane, whilst for ADC’s is far more diverse with an almost equal impact across the board.

## Econ & “Snowballatility”

This one’s not so straight forward, so bare with me. I’ve written [an entire article](https://www.itero.gg/articles/snowballatility) dedicated just to this statistic, if you wanted to really get into the details then head over there.

The simple summary is that certain Champions have a better chance of winning a game than others even if their laning phase went the same. If an **Ornn** goes 0–5 by 12 minutes, his win chances go down **BUT** not nearly as badly as if it was 0–5 **Irelia**. We call this a Champion’s econ.

The flipside is what I call **“snowballatility”**. A 5–0 **Irelia** can do more with that lead than a 5–0 **Ornn**, for instance.

To visualise this I’ve selected around 17,000 games where the lanes gone badly. The players all have around 70–75% of the average Gold @ 12 minutes for that lane. I.e. they’re about half an item behind schedule. I’ve then split these in to two categories depending on whether that Champion has a good or bad econ rating. Here’s some examples of the Champions in each:

-   **BAD Econ:** Irelia, Tristana, Renekton, Aatrox, Riven
-   **GOOD Econ:** Ornn, Malphite, Galio, Singed, Malzahar

> How a Champion's Econ Rating Impacts Win Rate's for a Losing Lane

For all players, things are bad — averaging around 27.5% win rate if they’re set this far behind so early in the game. However, the **BAD** econ Champions have win rates **almost 5% lower** than the **GOOD** ones.

Obviously, the question is: “well how do you know how the laning phase will go?”. The technical answer is I have a separate model which first predicts the Gold @ 12 minutes before then going on to predict the final result.

In practice however, it’s very difficult. As a general rule it makes sense to consider this when blind picking or counter picking a Champion.

Know who you’re against and **reckon you can face-roll** the lane and get ahead? **High “snowballatility”** champions will maximise your win chance.

**Blind picking** and worried about getting countered yourself? **High econ** Champions will be good damage mitigation.

## Team Composition

Obviously, you have far less control over the totality of your compositions strengths and weaknesses. However, there’s one that is worth considering: **the AD Ratio.**

By building a composition that is too one dimensional in their damage type you offer the enemy the opportunity to efficiently buy defensive items. Their tanks can use all 6 slots to build items effective against your entire team, when usually they would be forced to balance the two.

> How Damage Type of Team Composition Impacts Win Rate

If AD accounts for around 20–80% of your team’s damage — you’ll be sitting bang average, just above the 50% mark. However, for those few games that fall on either side of this green zone there is a very real decrease in their win chance.

For some reason, <20% AD seems to be more painful than >80%. In other words, if you had to choose between the two you’d choose a full AD team over a full AP team. Potentially as there tends to be a greater selection of AD Champions with high and consistent true damage that can still handle the tanks.

## And More…

There is of course many more elements to the draft, each bringing their own nuances that require consideration as you move through the drafting phase.

However, in the 30 seconds we have to make our decision there is simply too much to weigh up. Hence, I’d recommend sticking to these key points based on the findings above if you want to make that final climb:

-   **Don’t first time.** Above anything, it’s consistently the worst offender in mid-elos. You want a minimum of 5 games on a Champion before you take it to ranked. That’s a minimum.
-   **There’s a reason Champions with high win rates have high win rates.** This doesn’t supersede the first point. Of your highest played Champions, pick the ones with the highest win rates.
-   Lane Counters are super effective. Just remember **non-lane counters are ALSO effective.** We keep track of all matchup win rates in Silver/Elo on [iTero.gg](https://www.itero.gg/statistics) if you’re unsure.
-   Blind picking? Consider **high econ** Champions. Got them on the ropes? **High snowballatility.**
-   **Diversify your damage.** If you’re Jungling and the mid locks in Zed, consider an AP Champion. Last picking support and your team is 4 AP Champions? Consider Pyke or Pantheon.

Remember, this list is also in order of priority. If you’ve never played an AD support then avoid them, even if it locks you in to 90% AP damage. Quinn is a Garen counter — once you’ve played the matchup a handful of times AND she’s in a strong position in the meta.

If you aren’t an android from the future, chances are it’ll be extremely to consider all this in the moment. It’s why we made our drafting tool, afterall: [The iTero AI Drafting Tool.](https://www.itero.gg/drafting-simulator)

Simply type in your Summoner name, Region and the draft so far (you can even leave it empty if you want to see your best first picks) then hit “GET RECOMMENDATIONS”. The AI will calculate all the above and more, to give you recommendations based on your account. From our initial tests we’ve found that players using our recommendations consistently win more game— it’s as simple as that.

## Thanks for Reading!

Here are some other articles that may be of interest.

## LoL: Introducing the iTero Drafting Coach, in partnership with Overwolf

Introducing a new cutting-edge AI tool: The iTero AI Coach. Capable of analysing draft, recommending runes, studying your account and much more.

August 19, 2022

## LoL: Evaluating Teams with Betting Odds

How we can use esports odds to help predict play-off scenario percentages for the League of Legends (LoL) European Champions (LEC).

August 11, 2022

## LoL: How to Win Draft in Pro Play

A statistical analysis of winning draft in League of Legends (LoL) esports games. From metas to counters, win rates to experience.

August 5, 2022
