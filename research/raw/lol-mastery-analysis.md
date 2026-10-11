# Champion Mastery - a statistical analysis of 1M+ games - r/leagueoflegends

<https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/>

[redlib.](https://safereddit.com/) Feeds

 in /r/leagueoflegends

[reddit](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/#popup) [settings](https://safereddit.com/settings)

[r/leagueoflegends](https://safereddit.com/r/leagueoflegends) • [u/JackWills94](https://safereddit.com/user/JackWills94) • Apr 27 '23

# Champion Mastery - a statistical analysis of 1M+ games

**TL;DR:**

-   Of the 1 million + Gold-ish Ranked Solo Queue games I looked at...
-   20% of players were on Champs they had less than 10k Mastery on.
-   Under 10k Mastery has a 44% win rate vs. 51.5% for over 10k.
-   This impact changes depending on your Champion, there's pretty graphics below plus a full table here: [MASTERY IMPACT BY CHAMPION](https://docs.google.com/spreadsheets/d/1avgTSdh0eD39jGbni6ybGTcrlYeUrw7SsJA_60j3fz4/edit?usp=sharing)
-   ADC/Supports saw the least impact with their Mastery levels, Jungle saw the most
-   There was a Heimerdinger with over 19 million Mastery.

# Champion Mastery - a statistical analysis of 1M+ games

Hi, I'm Jack J ([Twitter](https://twitter.com/JackJGaminghttps://twitter.com/JackJGaming)) and last week I wrote an article about [how to win the drafting phase in solo queue](https://safereddit.com/r/leagueoflegends/comments/125rqx7/how_to_win_your_solo_queue_draft_a_statistical/). Of all the factors I studied, from counter picking to the average Champion win rates, **Mastery** was above and beyond the **best indicator of a game’s outcome**. Actually, to be more accurate; it was the _lack_ of Mastery that made all the difference.

So, today I have decided to unpack this single metric in more detail. How is Mastery distributed? What impact does it have? Does this change per Champion? How about per role? Today, we deep dive into Champion Mastery.

​

**An Introduction to Mastery**

To begin, let’s get a broad feel for it. Mastery is gained every single game and how much you receive depends on these four factors; result, performance, game length, current mastery. Win a long game where you perform well and are playing a Champion you have a high Mastery on and you’ll get more points than vice-versa.

Although I struggled to find a concrete number, to give you some perspective it’s roughly in the region of 100-300 for a loss and 900-1100 for a win; averaging ~600 a game.

​

**A Summary of the Data**

**Data Note:** _all statistics mentioned from here refer to a dataset of just over 1,000,000 Ranked Solo Queue games on patch 13.7, roughly equally split between NA, EUW and KR. The Elo is around Gold (some high Silver/some low Plat games)_

The distribution of Champion Mastery is highly spread, with an immense right tail. **The highest Champion Mastery was 19,322,661**. A notorious Heimerdinger player ([OP.GG](https://www.op.gg/summoners/euw/GeT%20CoN%20TRollED)) called “GeT CoN TRollED”, who apparently exclusively runs TP/Heal whilst manually clicking their abilities.

The **mean was 141,877**, however the **median was only 41,322**, a significant difference. If you have some experience in statistics, you’d have expected this variance, since the extreme long-tail outliers (like our friend GeT CoN TRollED) will pull the average way up; whilst not impacting the median nearly as much.

For the graph below I cut the distribution at 250,000 to allow more focus on the grand majority of the players which are found in the sub-50,000 Mastery bracket. However, the tail continues, decreasing slowly until that final stub at 19,322,661.

Distribution of Champion Mastery

To put this into context, around **20% of all players were on Champions they had less than 10,000 Mastery on** and just under 11% were on sub-5,000.

# The Impact on Win Rates

From our new dataset, let’s recreate the graph from the original article that illustrates the impact this Mastery has on win rates:

​

Mastery impact on Win Rates

What we can see is that for those players who played a Champion they had sub-10k Mastery on, the average win rate is around 44%. As soon as you go above 10k, the win rate hits 50% and above. After this sudden increase from 44% to 50%, the remaining gain is very slight for every additional 10k.

**NOTE:** If this doesn’t seem like it adds up, which to me it didn’t: 20% of the players games had a 44% win rate due to sub-10k mastery, the remaining 80% had a 51.5% win rate: (0.2 \* 0.44) + (0.8 \* 0.515) = 50%, as expected.

The point at which players moved from below to above 50% win rate was around the **12,000 Mastery** mark. This is very close to the point at which you get the flashable Level 4 (12,600). Whether Riot intended this or not, I am not sure. Using our broad estimate of 600 Mastery per game, that’s around 20 games of experience before you are no longer dragging down your win chance with the Champion.

Interestingly, players on Champion’s with **over 1M Mastery had a 51.73%** win rate, whilst those between **50K-1M had the ever-so-slightly higher value of 51.77%**. It’s far too small of a difference to be statistically significant, however it’s the lack of improvement that is interesting for these Champion aficionados. The obvious explanation is that these players play a majority of their games on a single Champion, and they also play a lot. What this means is that their elo has stabilised around it’s “true” value. If they played any other Champion they’d almost certainly lose a lot more, so the Mastery is more reflected in the _variance_ between Champion win rates, instead of the raw value.

# The variance between Champions

A common question I get asked about my work into Mastery is: how does this impact different Champions?

**Methodology**

First, let me explain the methodology for the rankings below. We need to account for the base win rate of a Champion, i.e. K’Sante top had a 44% win rate this patch, if someone had 100k Mastery and a 49% win rate we want to adjust from his base, not say “it’s still less than 50% therefore Mastery is useless”.

So, I bucketed Champion’s into three categories, chosen to allow for enough data for most Champions whilst also demonstrating a significant change:

-   Low: <10k
-   Medium: 10k-100k
-   High: 100k+

I then took their average win rates for each and calculated the ratio between Low and Medium, and High and Medium. For instance, if a Champion had a 45% win rate when sub-10k Mastery, and 50% for 10k-100k, the Low ratio will be 0.9 (0.45 / 0.50).

**NOTE:** This isn’t the only approach to this question, it’s just the one I chose that works fairly well.

From here, I ranked each by their Low Mastery and High Mastery ratios to create a leaderboard in each role. I then assigned the roles based on play rates.

Here is a full list of all the results: [https://docs.google.com/spreadsheets/d/1avgTSdh0eD39jGbni6ybGTcrlYeUrw7SsJA\_60j3fz4/edit?usp=sharing](https://docs.google.com/spreadsheets/d/1avgTSdh0eD39jGbni6ybGTcrlYeUrw7SsJA_60j3fz4/edit?usp=sharing)

**Champion Difficulty**

Let’s start with which Champion’s suffer the most when you have low Mastery. The other way to look at this is these are the Champion’s that are the **hardest** to pick-up the first time you play them.

Personally, I found a few of these obvious (K’Sante, Riven, Ivern) and a few of them surprising (Nunu, Yuumi & Senna).

HARDEST Champions to Win with LOW Mastery

Next, which Champion’s win rates are impacted **the least** when players are first timing (i.e. the **easiest** to pick-up). Again, some obvious ones but I was surprised to see Ryze, Vayne and Fiora here.

EASIEST Champions to Win with LOW Mastery

**Skill Ceiling**

Now, the same method except we’re looking at which Champion’s have the least increase in their win rate when going from 10k-100k to 100k+. In other words, the Champion’s with the **lowest skill ceiling**.

Interestingly, top is mostly tanks, whilst support was mostly enchanters. All the “low ceiling” mid-laners were AP, even when looking way past the top 5.

LOWEST Improvement with HIGH Mastery

We can then look at the highest improvement with 100k+ Mastery, which we could call the “high skill-ceiling” Champions. I agree entirely with the mid-lane, although again was surprised to see Nunu to be both #1 hardest to pick-up and #1 highest skill ceiling as a jungler.

HIGHEST Improvement with HIGH Mastery

Again, here are the full results:

[https://docs.google.com/spreadsheets/d/1avgTSdh0eD39jGbni6ybGTcrlYeUrw7SsJA\_60j3fz4/edit?usp=sharing](https://docs.google.com/spreadsheets/d/1avgTSdh0eD39jGbni6ybGTcrlYeUrw7SsJA_60j3fz4/edit?usp=sharing)

# Variances by Lane

Whilst creating these tables I noticed something odd. There were fairly major differences between the impacts depending on the lane. Some lanes were, on average, showing greater gains from Mastery than others.

Variance of Mastery impact on Win Rate by lane

What I found was that Jungle had both the lowest win rate when the player was on a low Mastery Champion AND had the highest win rate with high Mastery. ADC was the flipside to this, with far less impact seen in their win rate if Mastery was either very low, or very high. In other words, for Jungle it mattered significantly more than for ADCs how experienced the player was on the Champion.

I won’t argue whether this is reflective of the difficulty or impact of the respective roles, however it is a bizarre behaviour that could be looked into (just not by me, at least not today).

# Data Limitations

As with all data analysis, there are limitations to be aware of. Simply to be kept in mind, but also areas of future exploration. I list a few that came to mind here:

-   If certain Champions have a tendency to attract smurfs (1v5 penta-friendly Champions) then it can inflate low-Mastery win rates, since the player has likely put many more hours in on the Champion on another account.
-   The Mastery data we sourced is a static look at the player, since this is the easiest to get hold of. Some players may have 10k Mastery over 2 days (i.e. spammed 20 games in a row on the Champion), whilst others may have 10k over 5 years, playing the Champion a few times each season. The difference between these win rates, I expect, would be drastic.
-   Certain Champion’s may attract one-tricking more than others, which will change the make-up of the average player and their win rates. This could impact the win rates within the large buckets, such as 100k+, since some Champions may have lots of OTP’s with 1M+ Mastery (Yorick), whilst others may have mostly fairly average Mastery between 100k-150k and very few OTPs (Malphite).

(A special thank you to Collin ([Twitter](https://twitter.com/KingShmileyLoL)) for designing the table graphics for me!)

726

-   [permalink](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/)
-   [reddit](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/#popup)

97% Upvoted

296

[u/Diligent\_Deer6244](https://safereddit.com/user/Diligent_Deer6244) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy80g8/?context=3#jhy80g8 "Apr 27 2023, 18:19:08 UTC")

> A notorious Heimerdinger player (OP.GG) called “GeT CoN TRollED”, who apparently exclusively runs TP/Heal whilst manually clicking their abilities.

# what

129

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy9uhf/?context=3#jhy9uhf "Apr 27 2023, 18:31:03 UTC")

Legend

28

[u/Diligent\_Deer6244](https://safereddit.com/user/Diligent_Deer6244) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyanf4/?context=3#jhyanf4 "Apr 27 2023, 18:36:15 UTC")

how can you tell he's clicking his abilities btw?

85

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyazc7/?context=3#jhyazc7 "Apr 27 2023, 18:38:24 UTC")

No idea, I mentioned it on the itero discord and someone said he's notorious for it

81

[u/KislevNeverForgets](https://safereddit.com/user/KislevNeverForgets) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyowl2/?context=3#jhyowl2 "Apr 27 2023, 20:08:51 UTC")

My friend occasionally plays with this guy, he fucking loves him, he went like 4-19 in one of his games but he ended the game with like 140k dmg or something absurd.

He just non stop splits and won’t run away even if they send the whole team to him, my friends a jungler so he said he just gets free soul every time they play together because everyone’s top lane killing Heim constantly.

11

[u/ViraLCyclopes19](https://safereddit.com/user/ViraLCyclopes19) Vasectomized [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzy0dg/?context=3#jhzy0dg "Apr 28 2023, 01:28:58 UTC") edited Apr 28 '23

He's also a racist. I think I saw a clip of him saying a damn slur for Jews(Kyles little brother from South Park to give a clue). I saw it on a thread about him last time it was here. Gonna be hard to dig up however as it was like 2 years ago. I hope someone who reads this remembers that thread or clip source. Furthest I can find something about it again was a comment on my previous account from 2021 saying the exact same thing.

107

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji031vp/?context=3#ji031vp "Apr 28 2023, 02:04:27 UTC") edited Apr 28 '23

> He's also a racist.

that was already implied when they mentioned he mained Heimer.

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji031vp)

30

[u/CaptainBonsiI](https://safereddit.com/user/CaptainBonsiI) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji08gkf/?context=3#ji08gkf "Apr 28 2023, 02:44:24 UTC")

hes a 50-60 year old man living in europe, what did you expect?

20

[u/SignificantLacke](https://safereddit.com/user/SignificantLacke) Dont ff we scale [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0ip4h/?context=3#ji0ip4h "Apr 28 2023, 04:11:44 UTC") edited Apr 28 '23

I have met with many who are not racist

7

[u/ViraLCyclopes19](https://safereddit.com/user/ViraLCyclopes19) Vasectomized [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0gs8e/?context=3#ji0gs8e "Apr 28 2023, 03:53:26 UTC")

not be racist towards jewish people? Not like they got a war or something over it.

16

[u/CaptainBonsiI](https://safereddit.com/user/CaptainBonsiI) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0iodj/?context=3#ji0iodj "Apr 28 2023, 04:11:31 UTC")

im just saying, old people are brainrotted

8

[u/ViraLCyclopes19](https://safereddit.com/user/ViraLCyclopes19) Vasectomized [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0pxlz/?context=3#ji0pxlz "Apr 28 2023, 05:29:44 UTC")

fair

[→ More replies (4)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0iodj)

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzy0dg)

11

[u/omop](https://safereddit.com/user/omop) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhze96p/?context=3#jhze96p "Apr 27 2023, 23:03:10 UTC")

He streams and has vids of his game play under the channel DONGERSDOJO

2

[u/aTemeraz](https://safereddit.com/user/aTemeraz) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1iv59/?context=3#ji1iv59 "Apr 28 2023, 11:45:59 UTC")

Does he still stream? Last i checked he was banned on twitch

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyazc7)

27

[u/Bisounoursdestenebre](https://safereddit.com/user/Bisounoursdestenebre) EU HOPES AGAIN [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyczbr/?context=3#jhyczbr "Apr 27 2023, 18:51:26 UTC")

Because he streams. He's fairly well-known for his playstyle.

9

[u/RealHellcharm](https://safereddit.com/user/RealHellcharm) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyc6zr/?context=3#jhyc6zr "Apr 27 2023, 18:46:21 UTC")

He streams I think so u can see it there.

1

[u/FouteMakelaar](https://safereddit.com/user/FouteMakelaar) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0wll3/?context=3#ji0wll3 "Apr 28 2023, 06:53:51 UTC")

He streams (or at least used to)

4

[u/downvoteverythingxd](https://safereddit.com/user/downvoteverythingxd) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji34m6p/?context=3#ji34m6p "Apr 28 2023, 18:29:28 UTC")

Nah he’s also sexist and a terrible person. If you check out his streams it’s just a guy who’s calling everyone “soys” or “women” in a derogatory way. He also clearly got boosted to plat and banned anyone that brought it up in his chat lmao.

1

[u/NotYetPerfect](https://safereddit.com/user/NotYetPerfect) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyfc2h/?context=3#jhyfc2h "Apr 27 2023, 19:06:52 UTC")

He also got boosted so there's that

20

[u/ADistantFallenStar](https://safereddit.com/user/ADistantFallenStar) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyfk4d/?context=3#jhyfk4d "Apr 27 2023, 19:08:22 UTC")

He also refuses to buy boots

2

[u/Lisaurora](https://safereddit.com/user/Lisaurora) Magic [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzf1rb/?context=3#jhzf1rb "Apr 27 2023, 23:09:19 UTC")

Oh yea, I remember that name. I wonder how that started.

111

[u/irihS](https://safereddit.com/user/irihS) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy0gke/?context=3#jhy0gke "Apr 27 2023, 17:29:25 UTC")

Something about Fiora: Definitely influenced by the fact that many low-mid mastery Fiora players probably keep her in their back pocket as a specific counterpick to easy, if not impossible matchups to lose, which may influence her surprisingly high winrate on low mastery players. Higher mastery means more games, so you probably play her more often into matchups she isn't even that good, whereas if you're a serviceable level 5 Fiora who just picks her to bully the fuck out of K'sante and Mordekaiser, you'll have a very good winrate.

26

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy0y9m/?context=3#jhy0y9m "Apr 27 2023, 17:32:40 UTC")

That is a very good point, I wonder how many other Champions that applies to? And I wonder if we can track that effect in the data...

32

[u/tmb--](https://safereddit.com/user/tmb--) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzd645/?context=3#jhzd645 "Apr 27 2023, 22:54:36 UTC")

> I wonder how many other Champions that applies to?

It's pretty specific to top lane, where counter matchups matter the most. Countering someone in mid lane or support can easily be overcome by roams from the other lane and the jungler. And the current meta favors top-to-bot pathing as well, so counterpicks and thus pocket picks see much more use in top.

3

[u/snowflakepatrol99](https://safereddit.com/user/snowflakepatrol99) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji16p58/?context=3#ji16p58 "Apr 28 2023, 09:20:34 UTC")

How is it specific to top lane? A vayne main would easily have less win rate if he spam picks vzyne bli d compared to okay-ish vayne players that only oick it in games she'd be good.

10

[u/TechnoFTW](https://safereddit.com/user/TechnoFTW) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1v6ln/?context=3#ji1v6ln "Apr 28 2023, 13:29:43 UTC")

Top lane counterpicks are by far the most impactful as most of the matchups are borderline unplayable due to long lane and melee into melee.

Also Top lane can only really roam to help jungle or mid which is usually not that great.

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzd645)

6

[u/SuperWoodpecker95](https://safereddit.com/user/SuperWoodpecker95) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0crvt/?context=3#ji0crvt "Apr 28 2023, 03:18:48 UTC")

Definitly to Pantheon vs the windshiter bros & Zed. Probably also helps that Pantheon isnt exactly hard to play...

3

[u/Doorknob11](https://safereddit.com/user/Doorknob11) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0f8hx/?context=3#ji0f8hx "Apr 28 2023, 03:39:43 UTC")

Vex.

2

[u/DyslexicBrad](https://safereddit.com/user/DyslexicBrad) DlyxesicBdar? SylxeciDabr? [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0v7p9/?context=3#ji0v7p9 "Apr 28 2023, 06:35:35 UTC")

Maybe you could identify certain matchups with outlying occurrence rates, and then examine their effect on overall winrate (both positive and negative)?

E.g. fiora vs Sion has much higher occurrence than statistically likely, and also a much higher than average winrate.

137

[u/MysticExile](https://safereddit.com/user/MysticExile) Finally people are playing her [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxybo2/?context=3#jhxybo2 "Apr 27 2023, 17:15:24 UTC")

Rell is not surprising, she feels really overtuned once you know how to play her and really weak/bad when you play her for the first time.

79

[u/Apollosyk](https://safereddit.com/user/Apollosyk) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy0a9z/?context=3#jhy0a9z "Apr 27 2023, 17:28:16 UTC")

who?

270

[u/Serene\_Skies](https://safereddit.com/user/Serene_Skies) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy3pgr/?context=3#jhy3pgr "Apr 27 2023, 17:50:50 UTC")

horse leona

31

[u/Zygalo](https://safereddit.com/user/Zygalo) true damage lover [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy2tyf/?context=3#jhy2tyf "Apr 27 2023, 17:45:05 UTC")

new champ

46

[u/Kurkaroff](https://safereddit.com/user/Kurkaroff) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyjacw/?context=3#jhyjacw "Apr 27 2023, 19:32:51 UTC")

Next week she'll be 5 years old.

Feel old now?

30

[u/42069420\_](https://safereddit.com/user/42069420_) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhykcmb/?context=3#jhykcmb "Apr 27 2023, 19:39:43 UTC")

I hate you.

Kaisa is still a new champ to me.

7

[u/ryan\_wastaken](https://safereddit.com/user/ryan_wastaken) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhze8go/?context=3#jhze8go "Apr 27 2023, 23:03:01 UTC")

I remember when fizz was a new champ and I found him so much fun. That was 12 years ago :(

9

[u/42069420\_](https://safereddit.com/user/42069420_) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhznj2a/?context=3#jhznj2a "Apr 28 2023, 00:14:00 UTC")

Fizz will be able to drive in a few years 😭😭

2

[u/RheingoldRiver](https://safereddit.com/user/RheingoldRiver) Leaguepedia [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji11fv3/?context=3#ji11fv3 "Apr 28 2023, 08:02:52 UTC")

WHAT

2

[u/Omnilatent](https://safereddit.com/user/Omnilatent) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhytdhc/?context=3#jhytdhc "Apr 27 2023, 20:35:39 UTC")

Jhin is a new one to me lmao

16

[u/RocketHops](https://safereddit.com/user/RocketHops) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhykqw3/?context=3#jhykqw3 "Apr 27 2023, 19:42:16 UTC")

Rell was released at the end of 2020 bro, shes not even 3 years old.

21

[u/Kurkaroff](https://safereddit.com/user/Kurkaroff) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhylbqx/?context=3#jhylbqx "Apr 27 2023, 19:46:02 UTC")

No, I was wrong. She was released in beta. Almost 14 now

12

[u/Random\_Stealth\_Ward](https://safereddit.com/user/Random_Stealth_Ward) 💤 Release VattleVunny Viego with black tights😻 [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhykxsu/?context=3#jhykxsu "Apr 27 2023, 19:43:31 UTC")

Yeah, people really underestimate how strong AoE hard CC can be. She gets compared to Leona but Leona is more of a pick 1 target and focus them type of deal.

15

[u/truthordairs](https://safereddit.com/user/truthordairs) Flairs are limited to 2 emotes. [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhygedg/?context=3#jhygedg "Apr 27 2023, 19:13:52 UTC")

Yeah she’s a pretty insane champion once you put in some games on her, and I really don’t find her that clunky overall. She has the best aoe lockdown in the game along with unmounted w being insanely strong, but people don’t give her a chance due to stigma/not knowing how to combo so she’s more fluid

35

[u/Jinxzy](https://safereddit.com/user/Jinxzy) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhynpq5/?context=3#jhynpq5 "Apr 27 2023, 20:01:20 UTC")

No amount of mastery is going to make that Q feel any less clunky and useless to use. On top of how miserable it feels to do one suboptimal engage and then just being stranded on wheelchair island.

Similar champs like Alistar & Leona has ult & W to survive. Rell gets a pitiful 10% resistance steroid and a self-slow

She may very well be _strong_, especially when mastered. But that doesn't change how awful she _feels_ to play.

6

[u/Koroioz-LoL](https://safereddit.com/user/Koroioz-LoL) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz7ldm/?context=3#jhz7ldm "Apr 27 2023, 22:11:13 UTC")

true, that q just feels soooooo useless but 4 forms of hard cc is just so good when utilized well

2

[u/fat\_dick\_jones](https://safereddit.com/user/fat_dick_jones) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzrerz/?context=3#jhzrerz "Apr 28 2023, 00:42:27 UTC")

Gotta use that Q as a heal for your ADC or to delete shields

1

[u/tmb--](https://safereddit.com/user/tmb--) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzcth5/?context=3#jhzcth5 "Apr 27 2023, 22:51:54 UTC")

Another thing is that it's very easy to tell when Leona or Alistar want to engage. But when a Rell wants to Flash R W E, the animations are actually fairly... subdued? And teams are not quick to immediately pounce on it.

[→ More replies (2)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhynpq5)

1

[u/CarrysonCrusoe](https://safereddit.com/user/CarrysonCrusoe) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1amd3/?context=3#ji1amd3 "Apr 28 2023, 10:14:52 UTC")

I like to play her too, but you can't first pick her sadly. Janna and thresh are unplayable, there are a lot more abilities that easily cancel her w

6

[u/WolfMafiaArise](https://safereddit.com/user/WolfMafiaArise) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz1moe/?context=3#jhz1moe "Apr 27 2023, 21:29:01 UTC")

I mean idk. She's extremely punishable no matter how much mastery you have. One wrong W and you're dead

0

[u/Koroioz-LoL](https://safereddit.com/user/Koroioz-LoL) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz7u2o/?context=3#jhz7u2o "Apr 27 2023, 22:13:00 UTC")

true, counterpoint that when you have a lot of comfort on her poor use of W lessens, all that cc is just juicy if you're playing well which i suppose could be said of any champ (aka when your playing well you win more lmao)

2

[u/WolfMafiaArise](https://safereddit.com/user/WolfMafiaArise) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz844q/?context=3#jhz844q "Apr 27 2023, 22:15:05 UTC")

Yea but no amount of mastery can prevent a bad W towards something like a Shaco hiding in a bush, Janna completely screwing everything up, or someone using Zhonyas

2

[u/Koroioz-LoL](https://safereddit.com/user/Koroioz-LoL) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz90fn/?context=3#jhz90fn "Apr 27 2023, 22:21:49 UTC")

i feel that covers "playing a good rell" though. If your in a shaco support matchup, don't engage uncleared bushes, if your in a janna matchup, just take the lane L and work teamfight's best you can (though thats def a bad matchup) and if someone has zhonyas, knowing when to use your abilities to bait zhonya's being worth it in a fight versus blindly w'ing a zhonyas champ and being like "oh shit"

Again, i generally agree with you and my point is pretty pedantic or /koreanadvice (play better than your opponent and you win)lmao

1

[u/Halbaras](https://safereddit.com/user/Halbaras) Convicted tank Karma enjoyer [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji12tqs/?context=3#ji12tqs "Apr 28 2023, 08:23:04 UTC")

In bad lanes or vs champions with a lot of mobility, you can always just engage with W2 instead. It's single target, but flash + W2 isn't really dodgeable and afterwards you don't have the slow. The shield also helps with taking poke beforehand.

47

[u/katsuatis](https://safereddit.com/user/katsuatis) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy4jp7/?context=3#jhy4jp7 "Apr 27 2023, 17:56:21 UTC")

So Ryze is easy to pick and broken when mastered? Clearly, another nerf is coming.

9

[u/Droughtbringer](https://safereddit.com/user/Droughtbringer) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz9swo/?context=3#jhz9swo "Apr 27 2023, 22:27:55 UTC")

No. Please.

1

[u/maiden\_des\_mondes](https://safereddit.com/user/maiden_des_mondes) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1oy7z/?context=3#ji1oy7z "Apr 28 2023, 12:40:49 UTC")

Both Ryze and Leblanc surprised me a lot. I wonder how much their low pickrates and tendencies of finding much more success in the M+ elo bracket matter/create bias. Both are staples for highly skilled players that profit from extremely good mechanics and game knowledge...

Then again the same would be true for Azir whom we find on the other end of the spectrum. Really interesting.

3

[u/DoorHingesKill](https://safereddit.com/user/DoorHingesKill) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji27nrn/?context=3#ji27nrn "Apr 28 2023, 14:54:57 UTC")

I mean there are a lot of cases of low sample size fucking things up here.

For example [Nautilus](https://i.imgur.com/zQaN1Bn.png), literally the fourth least steep skill curve in the entire roster at the time of releasing that graph (probably didn't change considering Riot doesn't release too many simplistic champs these days), is rated as harder to learn than [Yasuo](https://i.imgur.com/u2BjbDO.png).

Or how [Taliyah](https://i.imgur.com/InYGcEG.png) is easier to learn than [Malphite](https://i.imgur.com/SxJUWhW.png). I mean they have the same ratio of 0.9 so maybe I should say "same learning difficulty" but according to Riot these champions aren't even in the same ballpark. Like, Malphite you play 10 games you quite literally peaked in win rate. Taliyah you play 10 games you'll still be accused of first timing.

Then on the other page, you got a bunch of champs who perform better in the hands of "Medium Mastery" players than they do in the hands of "High Mastery" players which is even more troll.

179

[u/Adventurous\_File\_798](https://safereddit.com/user/Adventurous_File_798) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxuc9z/?context=3#jhxuc9z "Apr 27 2023, 16:49:37 UTC")

I feel like Nunu data might be skewed due to Disco Nunu, as most Disco Nunus will have low mastery and extremally low winrate.

64

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxv35o/?context=3#jhxv35o "Apr 27 2023, 16:54:20 UTC")

That could be it for sure. I think next time I'll look to remove accounts lower than level 100 or so as a quick & dirty fix for smurfs etc...

6

[u/SuperWoodpecker95](https://safereddit.com/user/SuperWoodpecker95) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0dh47/?context=3#ji0dh47 "Apr 28 2023, 03:24:37 UTC")

I think his data might also be skewed by the fact that hes the go to pick for autofilled junglers across all elos. Im a jungle main myself and Nunu is braindead easy IF you already know what a jungler is supposed to be doing but kinda dog if you cant read the map and dont know to play around objective timings and your laners pushing

1

[u/oroora6](https://safereddit.com/user/oroora6) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji2n67e/?context=3#ji2n67e "Apr 28 2023, 16:35:23 UTC")

Let us know the results! Love your posts man

44

[u/FoxxiestAhriNA](https://safereddit.com/user/FoxxiestAhriNA) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy3o98/?context=3#jhy3o98 "Apr 27 2023, 17:50:37 UTC")

I would be surprised if there is enough people strictly locking in nunu to run it down to cause the data to skew in any meaningful way. I don’t have hard numbers but my guess would be sub 0.1% nunu lock-ins are disco Nunus. It’s far more likely champions with 1-2% AFK rates would impact the stats (master yi, Yasuo, Katarina etc.)

1

[u/Lachainone](https://safereddit.com/user/Lachainone) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0xb6l/?context=3#ji0xb6l "Apr 28 2023, 07:03:35 UTC")

Yeah but AFK rate isn't correlated with mastery, troll picking is

9

[u/Mathemuse](https://safereddit.com/user/Mathemuse) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy3job/?context=3#jhy3job "Apr 27 2023, 17:49:46 UTC")

Bad unranked player here, but I sorta main Nunu mid and he's my highest mastery (I think it's around 130k). From my group of friends that also play League, it seems like each person either is pretty decent on Nunu or falls flat on their face when trying with no in between. I even struggle playing tank Nunu because I have a lot more time on AP. Disco Nunu most likely skews it especially in Gold+, but I'm not too surprised to see a disparity overall. My guess is that he's easy to understand on paper but difficult to execute well without knowing his limits such as how close to cut corners with his W, the timing on his Q animation, and the radius and timing on his E and R. Given that he's also played as a jungler makes little things like that a lot more important.

6

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhynv3w/?context=3#jhynv3w "Apr 27 2023, 20:02:18 UTC")

\[deleted\]

1

[u/PapaTahm](https://safereddit.com/user/PapaTahm) WardenSupportAsshole [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzsr5m/?context=3#jhzsr5m "Apr 28 2023, 00:51:53 UTC") edited Apr 28 '23

Issue with Tahm Kench is that Devour is the most complicated ability in the game to use properly.

Specially given how many interactions it has, and how flexible it is.

That combined with the restrictions TK has in his kit, it makes him a nightmare to play, specially on low elo.

That's why most people play him on Top which is his easier role, which removes his interactions with other players.

1

[u/SebJenSeb](https://safereddit.com/user/SebJenSeb) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0gbuf/?context=3#ji0gbuf "Apr 28 2023, 03:49:19 UTC")

Well this looks like the answer...

27

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyg5yl/?context=3#jhyg5yl "Apr 27 2023, 19:12:21 UTC")

interesting tidbit I noticed: the more mastery a Zyra has, the worse she plays

7

[u/not\_yes\_lad](https://safereddit.com/user/not_yes_lad) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz2dgu/?context=3#jhz2dgu "Apr 27 2023, 21:34:15 UTC")

why is this true tho? I rarely see zyras below 250k but when I do they are always better than the onetricks I see all the time

17

[u/Amblypygi12](https://safereddit.com/user/Amblypygi12) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzq65f/?context=3#jhzq65f "Apr 28 2023, 00:33:34 UTC")

Zyra onetrick know 1 thing Camp in bush and hope s1 facecheaks

3

[u/Hans\_H0rst](https://safereddit.com/user/Hans_H0rst) Toxicity should be punished harder [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji2jq0r/?context=3#ji2jq0r "Apr 28 2023, 16:12:56 UTC")

because onetricks play zyra no matter the matchup, and have bad habits that more casual zyras might not have.

I'm honestly surprised we dont see this effect more often in the chart, only 11 times.

1

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0so6n/?context=3#ji0so6n "Apr 28 2023, 06:02:38 UTC")

No idea, I just know that if I see 100k+ mastery on a Zyra I know shes gonna sprint it

58

[u/Vorcia](https://safereddit.com/user/Vorcia) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxz4p1/?context=3#jhxz4p1 "Apr 27 2023, 17:20:41 UTC")

> ADC was the flipside to this, with far less impact seen in their win rate if Mastery was either very low, or very high.

I used to main ADC but roleswapped to top, my experience was a lot of ADCs are really similar, outside of certain weird ones like Kalista and Draven, skillsets between ADCs transfer over really well. There's also a lot fewer matchups to learn in bot than other roles, and it was easier to learn those matchups in my experience.

28

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxzg5u/?context=3#jhxzg5u "Apr 27 2023, 17:22:47 UTC")

Yeah, there's also less ADC Champion's in general which may be impacting it? Or it could be a reflection of which roles are the most impactful!

7

[u/fr0z3nph03n1x](https://safereddit.com/user/fr0z3nph03n1x) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyg8dp/?context=3#jhyg8dp "Apr 27 2023, 19:12:48 UTC")

At minimum there is less in meta ADCs at any one time.

3

[u/IcyPanda123](https://safereddit.com/user/IcyPanda123) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyqxv9/?context=3#jhyqxv9 "Apr 27 2023, 20:21:27 UTC")

ADCs rotate in and out of the meta and there are usually only like 3-4 good ADCs at a time that every ADC player rotates through until the next meta. This means even if theres an ADC that I have a lot of mastery on, if left out the meta long enough I could become pretty rusty with and would have to then somewhat "relearn" them when they come back into the meta.

19

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy4n5f/?context=3#jhy4n5f "Apr 27 2023, 17:56:59 UTC")

\[deleted\]

3

[u/NextReference3248](https://safereddit.com/user/NextReference3248) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji196av/?context=3#ji196av "Apr 28 2023, 09:55:34 UTC")

This definitely matters a lot, considering ADC/Support are the two least affected by individual mastery.

3

[u/ui2332](https://safereddit.com/user/ui2332) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhys2x7/?context=3#jhys2x7 "Apr 27 2023, 20:28:04 UTC")

just low impact role in soloq, heavy team reliant, prob weakest role in most elos. You dont solo lose many games but dont solo win them either.

77

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxxw5y/?context=3#jhxxw5y "Apr 27 2023, 17:12:32 UTC")

In my games it feels like if enemy has >500k mastery then the more mastery they have the worse they play. I'm more interested in knowing if this is true. People with 20k mastery unironically play better than 500k mastery in low elo

62

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxz1xe/?context=3#jhxz1xe "Apr 27 2023, 17:20:12 UTC")

That (almost) exact stat is in the article

2

[u/onlyHest](https://safereddit.com/user/onlyHest) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1w6sv/?context=3#ji1w6sv "Apr 28 2023, 13:37:02 UTC")

Logically, in this context, it makes sense. The dataset scope is limited to just one rank. When a player increases their mastery, they increase their game experience proportionally, as mastery is related to the number of games, and thus climb ranks. Those who don't climb and stay in the same rank have other issues not captured here. So it's more like "people who play more and don't climb" than just "people who play more".

43

[u/Blastuch\_v2](https://safereddit.com/user/Blastuch_v2) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy45qi/?context=3#jhy45qi "Apr 27 2023, 17:53:47 UTC")

They got to their peak elo by knowing their champion not by understanding the game.

\-15

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz4qz3/?context=3#jhz4qz3 "Apr 27 2023, 21:50:49 UTC")

\[deleted\]

6

[u/pongobuff](https://safereddit.com/user/pongobuff) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzouz2/?context=3#jhzouz2 "Apr 28 2023, 00:23:55 UTC")

Ekko definitely isn't one of those picks

13

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyjkju/?context=3#jhyjkju "Apr 27 2023, 19:34:42 UTC")

\[deleted\]

11

[u/TehPharaoh](https://safereddit.com/user/TehPharaoh) (NA) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyxryo/?context=3#jhyxryo "Apr 27 2023, 21:03:17 UTC")

The idea that you can just learn by playing is completely shattered by 1mil mastery gold and below people. You have to WANT to learn. These people don't

4

[u/mootland](https://safereddit.com/user/mootland) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji15wdt/?context=3#ji15wdt "Apr 28 2023, 09:08:40 UTC")

Imo it's not about wanting to learn, it's about what to learn. OTPs are good mechanically because thats what they learn, the limits and mechanics of the champion.

But macro doesn't come naturally to most people like limit testing and mechanics come, and quite honestly LoL has nothing in it to point out to ignorant players that lane management is a crucial tool as well as playing around objectives, they don't understand they can draw pressure from objectives by splitting when TP is up and that saving your 5min flash instead of flashing for a solo kill on support just 2 minutes before drake is the correct play because of macro.

TL;DR The game teaches you champion mechanics and limit testing, it does not teach you a single thing about wave/lane management and objective centered playing.

[→ More replies (2)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji15wdt)

7

[u/werrcat](https://safereddit.com/user/werrcat) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhygbxk/?context=3#jhygbxk "Apr 27 2023, 19:13:27 UTC")

I think the 500k is usually running it most of the game, but once or twice they get caught but suddenly turn around and get a 1v3 triple kill or something, so it balances out.

2

[u/Koroioz-LoL](https://safereddit.com/user/Koroioz-LoL) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz84j4/?context=3#jhz84j4 "Apr 27 2023, 22:15:10 UTC")

anecdotally, when i see a huge mastery number and im playing low elo with friends, i generally see it as someone loves the champ but doesnt know how to play the game and so they may be good at certain champion-specific mechanics but not good at league as a game outside of champion proficiency

2

[u/muktheduck](https://safereddit.com/user/muktheduck) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz85xk/?context=3#jhz85xk "Apr 27 2023, 22:15:29 UTC")

It seems like it would be true. Imagine if instead of 600K mastery on one champ, they had 100K on six different champs in different roles. They'd know a hell of a lot more about the game.

Also in some sense, OTPs like that are guaranteed to be "worse" than their elo, as their proficiency on that champ makes up for weaknesses that would otherwise prevent them from being at that MMR.

\-1

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzoebh/?context=3#jhzoebh "Apr 28 2023, 00:20:31 UTC")

OTPs off their main champ would almost certainly be "worse" than their elo but I don't think that's the full story. If you have someone who is trying to learn the game and they play 500 games of one champion they WILL climb further than someone who plays 100 games of five different champions. The former will probably have worse macro than others in their elo but still be better at macro than the person trying different champions. If you are trying to improve then it's better to be playing something you know really well so you can focus on other things.

3

[u/jenso2k](https://safereddit.com/user/jenso2k) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz3igc/?context=3#jhz3igc "Apr 27 2023, 21:42:11 UTC")

it’s because they’re in whatever rating you’re in because of their champion knowledge, not their game knowledge. if you have 500k mastery or 1mil or whatever on a champion, and you’re not high elo, you’re bad at the game (sounds harsh but it’s true). see what happens when you ban Kat (most elo inflating champ in the game) from a Kat main. it’s insane how far champion knowledge and mechanics can take you on the right champs

\-5

[u/EiEsDiEf](https://safereddit.com/user/EiEsDiEf) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyjgon/?context=3#jhyjgon "Apr 27 2023, 19:34:02 UTC")

This 100%. When you find someone with 500k+ mastery below at least mid diamond you know they're a complete idiot at the game.

1

[u/ICanCrossMyPinkyToe](https://safereddit.com/user/ICanCrossMyPinkyToe) smoothbrained top and support [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji132tn/?context=3#ji132tn "Apr 28 2023, 08:26:48 UTC")

I swear some high mastery players are mostly one or two tricks who play the game mostly on autopilot and trying to go for gigaflashy plays. I know some one tricks who play just like that

I see the same thing here in mid-low gold MMR (I mostly play normal games with friends, but the occasional ranked match feel no different).

14

[u/egonoelo](https://safereddit.com/user/egonoelo) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyxt2z/?context=3#jhyxt2z "Apr 27 2023, 21:03:29 UTC")

Is it not a huge mistake to look specifically at one elo bracket? Like it ruins the entire data set and causes a lot of the unintuitive results that we see. All of the high mastery lee sins that got good at their champions climbed out of gold, but they aren't included in your data because of that very reason. So you end up comparing new lee sin players (who don't win a lot) to bad lee sin mains (who also don't win a lot) and incorrectly coming to the conclusion that lee sin is low mastery curve which is absolutely not true.

80

[u/KanskiForce](https://safereddit.com/user/KanskiForce) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxs7bf/?context=3#jhxs7bf "Apr 27 2023, 16:36:03 UTC") edited Apr 27 '23

Turns out... Yuumi is one of the hardest champions to master and her skill ceiling is higher than other champions

I'm also surprised that Ezreal's winrate doesn't grow along with amount of mastery

15

[u/Sykil](https://safereddit.com/user/Sykil) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyc7ce/?context=3#jhyc7ce "Apr 27 2023, 18:46:25 UTC") edited Apr 27 '23

I think for most people with some experience of the game, Ezreal is pretty easy to pick up and contribute even if you’re not skilled with him. Getting better with him lets you flirt with disaster more, but maybe it makes sense that there’s no big improvement compared to ADCs like Draven and Zeri who have more unique mechanics. I’ve played mostly AD since season 1 and just catching axes took a long time for me to get comfortable with.

38

[u/F0RGERY](https://safereddit.com/user/F0RGERY) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxv707/?context=3#jhxv707 "Apr 27 2023, 16:54:58 UTC")

I wonder if Yuumi bots have any influence on the data, or if that sample size is too small.

30

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxw6k1/?context=3#jhxw6k1 "Apr 27 2023, 17:01:14 UTC")

the sample size is pretty big (i think Yuumi was at least 5,000 games in each part), but potentially could be influenced my smurfs/bots and the likes. I think when I launch the stats on the website ([itero.gg](https://itero.gg/)) I'll add some extra controls like a minimum account level, maybe account win rate over 20% etc...

17

[u/Random\_Stealth\_Ward](https://safereddit.com/user/Random_Stealth_Ward) 💤 Release VattleVunny Viego with black tights😻 [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhylm97/?context=3#jhylm97 "Apr 27 2023, 19:47:57 UTC")

It wouldn't be unless the bots were a VERY significant portion of her players. On top of this, you would need to apply this sort of logic to Sona, Lulu, Taric and other champions who are well-known to also have bots

\-4

[u/tmb--](https://safereddit.com/user/tmb--) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzdlpt/?context=3#jhzdlpt "Apr 27 2023, 22:58:00 UTC")

> unless the bots were a VERY significant portion of her players

Should we tell him?

> who are well-known to also have bots

Really only when Yuumi is pick-ban. Ever since Yuumi has came out, she's the go-to pick for Bronze/Iron bots.

20

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzokxe/?context=3#jhzokxe "Apr 28 2023, 00:21:51 UTC")

This data was collected from gold games so unless there are bots out climbing 50% of the league player base I think bots are out of the picture.

\-10

[u/Vorcia](https://safereddit.com/user/Vorcia) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxykmv/?context=3#jhxykmv "Apr 27 2023, 17:17:03 UTC")

It 100% is, I remember Riot making that article implying Yuumi was as hard as Akali using a similar metric, they've since walked that back and put Yuumi at 450 BE because she was among the easiest champions to play, so they figured out the obvious conclusion that the bots or whatever were skewing their data super hard.

31

[u/pedja13](https://safereddit.com/user/pedja13) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy2cwd/?context=3#jhy2cwd "Apr 27 2023, 17:41:58 UTC")

Except if you look at this post this is about Gold games,and there are no bots there really.

\-10

[u/Vorcia](https://safereddit.com/user/Vorcia) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy659g/?context=3#jhy659g "Apr 27 2023, 18:07:00 UTC")

If it says Gold-ish, that catch some of the lucky yuumi bots that got carried on their first game, no?

17

[u/Jinxzy](https://safereddit.com/user/Jinxzy) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyhq8v/?context=3#jhyhq8v "Apr 27 2023, 19:22:35 UTC")

Lol no bots ever realistically make it anywhere near gold, even if their team somehow 4v6'd the first game.

\-7

[u/KislevNeverForgets](https://safereddit.com/user/KislevNeverForgets) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhypsbs/?context=3#jhypsbs "Apr 27 2023, 20:14:24 UTC")

I’ve seen Yumi bots in high silver which can get into gold lobbies.

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyhq8v)

21

[u/nanadin](https://safereddit.com/user/nanadin) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy3d0q/?context=3#jhy3d0q "Apr 27 2023, 17:48:33 UTC") edited Apr 27 '23

M7 on all enchanters here:

Yuumi is not “hard” but she is hard to win with. It’s not like you’re getting that much better at hitting Q and pressing E the more you play. The champ has a get carried playstyle and you as an individual don’t have the same tools to contribute to swaying the match. You’re always gonna lose to a support pick that is doing more, so you really have to know everything to have enough influence on the match.

It’s also why it’s so frustrating to lose against, precisely because Yuumi doesn’t have the tools to contribute to swaying the match. When I first started, it always felt like enemy yuumi was freeloading and getting carried while my teams were horrid and I could never do enough. I had to learn to use pings smarter, communicate to my team in a nice way what we should do, itemize, when to hop off my adc and let them feed by themselves, when to ward because it’s very risky, etc just to actually contribute in a game.

4

[u/jamie1414](https://safereddit.com/user/jamie1414) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz7ymy/?context=3#jhz7ymy "Apr 27 2023, 22:13:56 UTC")

It's more like knowing how to not lose as yuumi instead of knowing how to win/carry as yuumi.

17

[u/hclarke15](https://safereddit.com/user/hclarke15) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyss1w/?context=3#jhyss1w "Apr 27 2023, 20:32:05 UTC")

Riot published data last year that yuumi has one of the steepest learning curves in the game but everyone just ignored it because it didn’t fit the narrative

I think it’s because she’s just so bad at warding and needs coordination with the team to get map control

7

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz0n6d/?context=3#jhz0n6d "Apr 27 2023, 21:22:20 UTC") edited Apr 27 '23

It's more that their arguments weren't defensible with the data they provided. The analysis was so superficial and poorly thought out that anyone who is data-literate is easily able to point out the fundamental flaws in their reasoning.

5

[u/jamie1414](https://safereddit.com/user/jamie1414) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz7u0m/?context=3#jhz7u0m "Apr 27 2023, 22:12:59 UTC")

Well the data listed in this post seems to go against the standard mantra of yuumi being completely brain dead.

11

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz9qrw/?context=3#jhz9qrw "Apr 27 2023, 22:27:27 UTC")

No, it doesn't. It shows that yuumi plays differently to other champions. Look at the champions listed under hardest to win with low mastery, there are effectively two groups of champions: mechanically difficult champions and champions with non-standard gameplay.

Yuumi is not hard. She simply plays a different game than every other champion. Having player success tied to unintuitive gameplay design doesn't make a champion difficult.

Which of the following is harder to operate: a motorcycle or a tricycle with inverted handlebars? The motorcycle, obviously. But if you take someone who can ride a bike and had them learn these things, they'll take roughly the same amount of time to learn. But if you teach someone with no experience how to ride a tricycle with inverted handlebars, theyll pick it up quickly. However, if you then take that person and try to teach them how to ride a normal bike or motorcycle, theyll have a significantly more difficult time simultaneously unlearning 'turn left = go right' _and_ learning balance, how to shift weight, how to shift gears, braking, etc.

The tricycle may be unintuitive _for people who have already learned how to ride_, but that is not the same thing as difficult. Further, saying 'x champion is hard and has a graph that looks like this. Y champion has a graph that looks similar, therefor they are the same.' Is the fastest way to enrage... really anyone who has taken statistics after highschool.

5

[u/Esarael](https://safereddit.com/user/Esarael) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzlhuq/?context=3#jhzlhuq "Apr 27 2023, 23:58:30 UTC")

Unsaid in this post is that you have _some_ definition of "hard", which you did not share, and I'm willing to bet it's subjective and not measurable.

0

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji00621/?context=3#ji00621 "Apr 28 2023, 01:44:05 UTC")

Riot themselves consider yuumi a champion for brand new players. Look under ["Staying True To Yuumi"](https://www.leagueoflegends.com/en-gb/news/dev/dev-yuumi-s-rework/).

"We believe that Yuumi has a key spot on the League roster when she’s positioned as a champion like Garen, Annie, and Sona who were designed to help introduce players to Summoner’s Rift."

Did you think you were adding something to the conversation? Because you weren't...

8

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji165wk/?context=3#ji165wk "Apr 28 2023, 09:12:37 UTC") edited Jul 11 '23

\[removed\] — [view removed comment](https://undelete.pullpush.io/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji165wk)

2

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1oz63/?context=3#ji1oz63 "Apr 28 2023, 12:41:02 UTC")

I didnt say I had a problem with the _quality_ of the data. I stated that their analysis did nothing to support their argument that yuumi is a difficult champion. Doubly so when they compared her level of difficulty to akali.

Name one thing that yuumi does that is hard to pull off.

[→ More replies (3)](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1oz63)

3

[u/Halbaras](https://safereddit.com/user/Halbaras) Convicted tank Karma enjoyer [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji13h7k/?context=3#ji13h7k "Apr 28 2023, 08:32:43 UTC")

It's pretty bad for the Reddit narrative that 'anyone can just play Yuumi and win games for free'. Obviously there's not much depth to her kit, but having a Yuumi player who doesn't know what they're doing is bad news.

Some people actually seem to think that picking Yuumi is a free ticket to high elo, when she's often an extremely weak champion because of pro and a bad Yuumi player is going to get their adc dived repeatedly.

4

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxw3lr/?context=3#jhxw3lr "Apr 27 2023, 17:00:41 UTC")

Is it because she's a hard champion or because people to autopilot on not think too much about it when playing her / don't bother learning ?

19

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhxxx0d/?context=3#jhxxx0d "Apr 27 2023, 17:12:42 UTC")

i'm not sure, but i'd guess that it's because people assume her skill-ceiling is low and then play the AFK, always-inside style, which clearly doesn't perform well at all

2

[u/werrcat](https://safereddit.com/user/werrcat) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyh11n/?context=3#jhyh11n "Apr 27 2023, 19:18:01 UTC")

It's also possible that it's related to / inverse of the super high mastery phenomenon you mentioned -- yuumi has a high banrate, so if someone is only good at yuumi and bad at other champs then their yuumi wr will be inflated because they lose and lose mmr every time they get banned out.

(That said, I do think most players greatly underrate the laning potential of a good yuumi player, at least with old yuumi, no opinion on the new one.)

11

[u/tankmanlol](https://safereddit.com/user/tankmanlol) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy82xv/?context=3#jhy82xv "Apr 27 2023, 18:19:35 UTC")

Imo it's because yuumi really is hard _for league players_ to learn, in the same way a chess player would learn a checkers strategy less easily than a chess one - the champ tests stuff other than positioning, which is very new for league players. Riot [said this a while ago](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-delete-yuumi/) which should always be linked to note 1) new yuumi players lose a lot and 2) probably because choosing who to attach to and when you can unattach are not as transferable from other champs as what you have to learn for a typical champion.

Also, the image in this post make her look harder to master than she really is in the spreadsheet just because supports generally have low skill ceilings, since the image shows her at #2 for the role but of all champions she's #41 hardest to master. She's also #4 hardest to learn (after nunu, ivern, and ksante), so the skill floor is much more dramatic - whatever the reason when people first play yuumi they do really poorly.

\-1

[u/PlacatedPlatypus](https://safereddit.com/user/PlacatedPlatypus) Taller than you IRL [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy8s3n/?context=3#jhy8s3n "Apr 27 2023, 18:24:07 UTC")

Maybe people with a lot of Yuumi games played her before she got gutted?

1

[u/Lethal-Sloth](https://safereddit.com/user/Lethal-Sloth) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz4kma/?context=3#jhz4kma "Apr 27 2023, 21:49:36 UTC")

Could just be because she doesn't have as many transferable skills as other champions. Makes sense when you consider a lot of the 'unique' champions (Singed, Ivern) are in the top 5 for their respective roles.

11

[u/KataKataBijaksana](https://safereddit.com/user/KataKataBijaksana) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy7z3n/?context=3#jhy7z3n "Apr 27 2023, 18:18:54 UTC")

Anyone else notice the Vanye label in the easiest to win with low mastery screenshot? Is that Vanye West?

6

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy9y32/?context=3#jhy9y32 "Apr 27 2023, 18:31:41 UTC")

Haha lmao its an easter egg

\-1

[u/Hide\_on\_bush](https://safereddit.com/user/Hide_on_bush) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji04ezt/?context=3#ji04ezt "Apr 28 2023, 02:14:19 UTC")

I think it’s because vayne used to be the pick for Smurfs

10

[u/TheGawringSame](https://safereddit.com/user/TheGawringSame) I'm not a fan of any one region, I flame everyone equally [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy1exn/?context=3#jhy1exn "Apr 27 2023, 17:35:48 UTC")

I play a bunch of Zyra and Sona and can definitely confirm that past a certain point fairly early on it does feel like there's nothing you can improve on when piloting the champ mechanically. Both champs are just so simple. I've heard them called: "old man champs", because of how little mechanicaly proficiency is needed.

Though personally I feel like there's a lot to optimize with item builds and match-ups. But I'm not sure if one can ever properly analyse data for that. Because funnily enough, I've noticed that the people with the highest masteries also tend to auto-pilot the most and get absolutely locked into their preferred item builds even when they're super obviously suboptimal. Maybe in like Master+ elo you'll see people actively adjust runes/builds every game, but that likely further hits the sample size to the point where it's hard to draw conclusions. Hell, we even see terrible item builds in Pro play all the time because people are used to building champs a certain way.

So it's a bit hard to analyse. Understanding optimal builds requires high mastery, but when high mastery is more likely to lead to comfort builds, they might even out and you can't really tell how much ceiling there is left to push.

2

[u/SahiroHere](https://safereddit.com/user/SahiroHere) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0cyha/?context=3#ji0cyha "Apr 28 2023, 03:20:18 UTC")

The only thing that you continuely can improve as a Zyra main is blocking/baiting important skill shots (mostly hooks) with your pants imo

But yeah, most Zyra mains are in it for unga bunga dmg

7

u/\[deleted\] [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhznlan/?context=3#jhznlan "Apr 28 2023, 00:14:28 UTC")

Nunu and Yuumi seem like victims of misperception, if you ask the community who the easiest jungler and support is then you would probably have those two near the top of a poll. While they are probably middle of the pack difficulty champions, players who are off role will look at them and first time them thinking that they are really easy.

​

On the other hand the top two junglers for easy of winning with low mastery are well known as smurf/booster champions. Graves isn't very difficult but Lee Sin definitely isn't getting picked up randomly. For these it might be interesting if games were filtered to only have accounts with relatively reasonable overall winrates (even just 35%-65%) or only accounts with 60+ games in ranked.

15

[u/CuatroBoy](https://safereddit.com/user/CuatroBoy) Twisted Tea Fate [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy936e/?context=3#jhy936e "Apr 27 2023, 18:26:08 UTC")

This further proves my point that champions with simple kits can have high skill-floors and high skill-ceilings.

Twisted Fate is near the bottom on "easy to learn" but near the top on "best to master"

But this also proves that champions with more sophisticated kits can have lower skill-floors. Just take a look at the top 20 in "easiest to learn" and you'd be surprised who ends up there.

8

[u/muktheduck](https://safereddit.com/user/muktheduck) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz9pb0/?context=3#jhz9pb0 "Apr 27 2023, 22:27:08 UTC")

It's because those kits don't exist in a vacuum. Sometimes a simple kit can be very difficult to play against certain aspects of complex kits that are easy to utilize.

Singed has always had an extremely simple kit, but has always been one of the hardest champs to learn. Lane phase just isn't easy for a champ with no range, no sustain and a primary ability that auto pushes the wave if used incorrectly. Getting through that lane phase requires a lot of skill in matchups and wave control.

For the opposite case, look at Akali on those lists. Learning her Q range is about all you need to be proficient, but execution in teamfights is extremely difficult and needs a lot more practice.

\-1

[u/Quazz](https://safereddit.com/user/Quazz) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0wx0v/?context=3#ji0wx0v "Apr 28 2023, 06:58:13 UTC")

The simpler the kit, the more important it is that you properly understand how to pilot your champion since you don't get "get out of jail free" abilities.

10

[u/FYININJA](https://safereddit.com/user/FYININJA) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy19vs/?context=3#jhy19vs "Apr 27 2023, 17:34:52 UTC")

I think people might underestimate Nunu a bit. He's a great jungler to learn if you are learning jungle, but he has one big issue that makes it so he's pretty hard to play when he's not oppresively OP.

He's horrific at playing from behind. Due to the nature of his kit, his two most impactful abilities in teamfight (W and R) are very easy for the enemy team to play around. If he builds AP, he has to land his W on an important target without getting CC'd, first (as if he gets CC'd he's just dead) and he has to basically cheese an ult or combo it to get a decent channel off without dying. If he's going tank, playing from behind is insanely difficult because you will always die if you W into a teamfight, and your ult isn't threatening enough when the enemy team can burst you down.

I used to think Nunu was easy, but honestly I've reached a point where I barely play him because I struggle to catch up too bad. If I don't get an early kill or two (which is admittedly easier for Nunu than basically anybody else), I reach a point where my W is basically a suicide button.

Idk if he's the HARDEST jungler to learn, but I do think people think he's braindead easy because when he's doing well he is braindead easy, but being able to consistently win even from behind as Nunu is rough.

Even non-disco nunu's can die an absurd amount in a game.

4

[u/Shprut](https://safereddit.com/user/Shprut) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy4hg0/?context=3#jhy4hg0 "Apr 27 2023, 17:55:57 UTC")

Solid work as always. Impressive! Good job.

1

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhya0ga/?context=3#jhya0ga "Apr 27 2023, 18:32:07 UTC")

Thanksss

3

[u/patmax17](https://safereddit.com/user/patmax17) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0qvep/?context=3#ji0qvep "Apr 28 2023, 05:40:42 UTC")

"mastery is the best indication of a game's outcome"

Nice to see data backing up what curtis and Nathan have been saying for years. Very interesting data and thread, thank you!

6

[u/gzhskwbd](https://safereddit.com/user/gzhskwbd) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy0kod/?context=3#jhy0kod "Apr 27 2023, 17:30:10 UTC")

I hate how Riot basically forced Fiora to build Grasp Divine, it's so braindead and boring. Remove DS already.

3

[u/BrainrottedYuumiMain](https://safereddit.com/user/BrainrottedYuumiMain) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz01ns/?context=3#jhz01ns "Apr 27 2023, 21:18:18 UTC")

It turns out Yuumi is a high skill champion. Don't know why people complain when she's dominant in pro play. It's always a joy seeing high skill players pilot the most difficult champion in the game, and now look what the community has done to her.

2

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzg416/?context=3#jhzg416 "Apr 27 2023, 23:17:30 UTC")

Holy based.

2

[u/Nihilatyk](https://safereddit.com/user/Nihilatyk) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy8hr6/?context=3#jhy8hr6 "Apr 27 2023, 18:22:16 UTC")

Wtf Jack... very well-crafted statistics!

3

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy9sx8/?context=3#jhy9sx8 "Apr 27 2023, 18:30:46 UTC")

Thanks!

1

[u/Nihilatyk](https://safereddit.com/user/Nihilatyk) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhype6f/?context=3#jhype6f "Apr 27 2023, 20:11:50 UTC")

This is what I expected from Katarina, which proves many factors regarding this champion's community, which to this day remains impressive, as it is also related to why she is not seen in the hands of professional players!

2

[u/Therozorg](https://safereddit.com/user/Therozorg) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyqw5x/?context=3#jhyqw5x "Apr 27 2023, 20:21:10 UTC") edited Apr 27 '23

xerathbros...

actually, i dont see mid xerath in your list at all, only support

2

[u/Similar\_Recover\_3864](https://safereddit.com/user/Similar_Recover_3864) moon rises inferno begins [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzlcaj/?context=3#jhzlcaj "Apr 27 2023, 23:57:18 UTC")

love posts like these, thank you for putting this together! im also shocked by nunu but thinking about it... it makes sense how the more you play him, the better you get with snowball timing/positioning and ganking

2

[u/Xayzu](https://safereddit.com/user/Xayzu) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1csrc/?context=3#ji1csrc "Apr 28 2023, 10:41:56 UTC")

Despite all this data, I often dislike having players with millions of mastery points on a champion on my team (in gold/plat) because IMO, if you are one tricking that much to get that many points, I think you should have at least climbed higher, and it's more a game issue vs champ issue at that point.

2

[u/Boudynasr](https://safereddit.com/user/Boudynasr) I like junglers whose name starts with B [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1phhr/?context=3#ji1phhr "Apr 28 2023, 12:45:15 UTC")

so much work seems to have been put for this analysis, Thanks alot Jack94, would recommend anyone who like this man's work to check out his discord and his socials!

4

[u/LargestPerson](https://safereddit.com/user/LargestPerson) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz08cm/?context=3#jhz08cm "Apr 27 2023, 21:19:33 UTC")

yummi mains rise up

5

[u/ADeadMansName](https://safereddit.com/user/ADeadMansName) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy0pkh/?context=3#jhy0pkh "Apr 27 2023, 17:31:03 UTC")

Darius in there with the high mastery champs makes me happy. I don't like his current style but I disagree that he is OP or easy to play, which seems to be a common thing to say on Reddit.

Also Fiora and Vayne on the easy to win with on low mastery. Easy to pick up.

11

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy11wo/?context=3#jhy11wo "Apr 27 2023, 17:33:22 UTC")

if it helps, whenever I take Darius because he's an apparent counter - I end up 0/7/0

2

[u/Random\_Stealth\_Ward](https://safereddit.com/user/Random_Stealth_Ward) 💤 Release VattleVunny Viego with black tights😻 [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhym826/?context=3#jhym826 "Apr 27 2023, 19:51:52 UTC")

Enemy scripting smh

1

[u/42069420\_](https://safereddit.com/user/42069420_) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyl8l3/?context=3#jhyl8l3 "Apr 27 2023, 19:45:28 UTC")

You should play him more. You have to play around incredibly specific spikes (mainly 5stacks), and once you hit them you gain around an item in stats on your opponent. Keeping the bleed stacks alive while trading is a big thing too (ie get them to 3, back off for a bit, then pull combo and execute).

0

[u/SahiroHere](https://safereddit.com/user/SahiroHere) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0d8dj/?context=3#ji0d8dj "Apr 28 2023, 03:22:36 UTC")

Also, you gotta learn to have some BALLS with the dude. Oftenly it looks like Darius is loosing a trade, but more often than not he can turn it around

3

[u/SignificantLacke](https://safereddit.com/user/SignificantLacke) Dont ff we scale [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0ji0q/?context=3#ji0ji0q "Apr 28 2023, 04:19:48 UTC") edited Apr 28 '23

Yeah that "BALLS" is q healing and 230 extra ad you get from the passive and the true damage it gives when it is proced.

I heard that people also call that "BALLS" statchecking.

2

[u/EliteTeutonicNight](https://safereddit.com/user/EliteTeutonicNight) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyisd3/?context=3#jhyisd3 "Apr 27 2023, 19:29:34 UTC")

Definitely an interesting and high-quality read.

Regarding the variance by lane, I think I might have some interplay to how often one plays the role itself, because chances are the person is off role if they’re picking a low mastery champion. Wonder if there’ll be some way to have a joint mastery on different roles for each player and see if the effect sustains.

2

[u/warfail](https://safereddit.com/user/warfail) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz7b4u/?context=3#jhz7b4u "Apr 27 2023, 22:09:06 UTC")

Do you know why Irelia is not at the top of "winrate is increasing with mastery increase"? You play her a ton, and then a ton more, but you are still unable to play her 20% correctly after hundreds of hours (and even best players on her fail mechanically sometimes, other players? meh, we can't even scratch it)

1

[u/PlacatedPlatypus](https://safereddit.com/user/PlacatedPlatypus) Taller than you IRL [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy942q/?context=3#jhy942q "Apr 27 2023, 18:26:17 UTC")

How were patches handled? Yorick is actually quite a hard champ to "master" but has a very low mastery ratio which may be because of his constant nerfs (players who play a lot of Yorick will stick with him as he becomes worse and worse).

5

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhy9oy2/?context=3#jhy9oy2 "Apr 27 2023, 18:30:03 UTC")

It's all one patch but that's an interesting effect to keep in mind

1

[u/pongobuff](https://safereddit.com/user/pongobuff) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzq8zk/?context=3#jhzq8zk "Apr 28 2023, 00:34:08 UTC")

I gave up, i dont want to play lethality, i want to enjoy shovel bonk

1

[u/nightlesscurse](https://safereddit.com/user/nightlesscurse) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyo143/?context=3#jhyo143 "Apr 27 2023, 20:03:23 UTC")

as a riven main this put smile of my face

0

[u/Alakdae](https://safereddit.com/user/Alakdae) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyvnvr/?context=3#jhyvnvr "Apr 27 2023, 20:49:40 UTC")

> What I found was that Jungle had both the lowest win rate when the player was on a low Mastery Champion AND had the highest win rate with high Mastery.

Well yes, the average winrate is always 50%, so, the lower it goes one group the higher it goes for the other group, as long as the universe is divided into this two groups.

0

[u/draggerHAHA](https://safereddit.com/user/draggerHAHA) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0czed/?context=3#ji0czed "Apr 28 2023, 03:20:30 UTC")

As a darius/Pyke player that skill ceiling graph pleases me

0

[u/averageyurikoenjoyer](https://safereddit.com/user/averageyurikoenjoyer) wewuzkangs [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0no9o/?context=3#ji0no9o "Apr 28 2023, 05:03:49 UTC")

I don't care how many mastery points you have on gp, if you're gold that shit is not getting through ban phase

\-1

[u/Sox2417](https://safereddit.com/user/Sox2417) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyop66/?context=3#jhyop66 "Apr 27 2023, 20:07:34 UTC")

As a riven main with 250k mastery . I always have around a 55% win rate with her in ranked over the seasons it’s scary sometimes what you can do on champions and people don’t expect it.

\-2

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyd7kx/?context=3#jhyd7kx "Apr 27 2023, 18:52:56 UTC")

Idiots are always going to try what their fav streamer played or what their apps (porofessor, op.gg, mobafire) tell them to. They have no minds of their own and then will want to ff after 4 minutes because they’re getting their butts kicked

\-2

[u/SnooSprouts4802](https://safereddit.com/user/SnooSprouts4802) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz5xow/?context=3#jhz5xow "Apr 27 2023, 21:59:05 UTC")

I dont like this because it doesnt take in consideration of players like me that only play on an account until it hits below a 50% wr. Currently 80 games in a hand leveled account and im 120 lp away from Plat 4 and every champ i have with 5 games or less i have a 80% wr or higher. I just played Milio for the first time last week and have an 80% wr over 9 games.

\-7

[u/Makyura](https://safereddit.com/user/Makyura) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyqckn/?context=3#jhyqckn "Apr 27 2023, 20:17:51 UTC")

Isn't this just a cheap clone of the same post that was made 1/2 months ago. Why do we need the same info recycled?

1

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyc3co/?context=3#jhyc3co "Apr 27 2023, 18:45:41 UTC")

good work on the stats, these are some interesting insights I never actually thought about outside of high mastery equalling higher win, would be cool if riot readjusted champ skill floor ceiling numbers based on this.

1

[u/doglop](https://safereddit.com/user/doglop) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyecc7/?context=3#jhyecc7 "Apr 27 2023, 19:00:16 UTC")

Wow, im surprised about panth supp tbh, he is defo more than the haha w 1 shot adc champ he may look at first but 5th?

1

[u/Sinnum](https://safereddit.com/user/Sinnum) Girl Dad [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhyw0ts/?context=3#jhyw0ts "Apr 27 2023, 20:51:59 UTC")

I remember your post from a few months ago about this, i think it was towards the end of 2022. I had actually decided to try it myself AGAIN and unsurprisingly, yeah, it's soooo true. I did 100 solo q games of Udyr and my early stats were abysmal, as I was also learning jungle in low gold. Starting in February, I finished the 100th game last week and it was like night and day. ALL of my stats were way better in the last 50 games, but the main thing was that it FELT better to play.

1

[u/\_ziyou\_](https://safereddit.com/user/_ziyou_) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz8ici/?context=3#jhz8ici "Apr 27 2023, 22:18:02 UTC")

Even if it's not a smurf, many people have more than one account, so champion mastery does not necessarily have to be accurate. Simple example: on my main account I have rarely played champion X, but I have played him a lot on my second account, so when I now play him on my main account it seems that I almost first-time him, but in reality I have plenty of mastery points on him.

In addition, it does not say when the champion mastery was collected. Simple example: my most mastery points on my main account are on a champion that I have not played properly in like 5 years by now. So when I play that champion now I am surely not as proficient on him as I used to be 5 years ago, yet I do still have that high champ mastery on him.

1

u/\[deleted\] [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz92aj/?context=3#jhz92aj "Apr 27 2023, 22:22:12 UTC")

\[removed\] — [view removed comment](https://undelete.pullpush.io/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhz92aj)

2

[u/CanadianNoobGuy](https://safereddit.com/user/CanadianNoobGuy) hee hee hoo hoo poison man [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzrkon/?context=3#jhzrkon "Apr 28 2023, 00:43:37 UTC")

I think there's actually some sort of mistake here, because singed actually has a good winrate (in high elo at least), and according to Blaustoise, [singed has one of the highest improvements over time among all champs](https://twitter.com/blaustoise/status/1075515580570980352)

1

[u/Lethal-Sloth](https://safereddit.com/user/Lethal-Sloth) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzdjsg/?context=3#jhzdjsg "Apr 27 2023, 22:57:34 UTC")

This is so interesting, do you have any more posts planned like this?

2

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0nlxr/?context=3#ji0nlxr "Apr 28 2023, 05:03:05 UTC")

Of course, and there's a load of my old articles on itero.gg - the first one was in 2018!

1

[u/ggLokiTricks](https://safereddit.com/user/ggLokiTricks) [Apr 27 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzf1bt/?context=3#jhzf1bt "Apr 27 2023, 23:09:13 UTC")

Ryze: one of the easiest champions to win with (with low mastery) and ALSO high wr improvement with higher mastery. REWORK INCOMING

1

[u/Arachex](https://safereddit.com/user/Arachex) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzn9lh/?context=3#jhzn9lh "Apr 28 2023, 00:11:59 UTC")

Senna having a low wr on inexperienced players is because most of them stay to collect the soul after leashing and lose out on the lv2 advantage in lane

1

[u/iwalkwounded](https://safereddit.com/user/iwalkwounded) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzoaot/?context=3#jhzoaot "Apr 28 2023, 00:19:47 UTC")

out of curiosity, why did you define medium as 10k - 100k?

while I would agree that 10k is a good starting point and that 100k is certainly high, I almost feel like the end of "medium" could be even lower.

some thoughts:

-   if we use your champion mastery points average defined as 600pts, a player would need to play roughly 166 games to finally reach "high mastery" on the champion
    -   I remember posts in this sub over the seasons saying that, to really master a champion, you should play that champion and only that champion for 100 games
-   If we say the average game in silver-gold takes about 30min. then that person will have spent a little over 80hrs on the champion
    -   a modern take on the time to develop a new skill (josh kaufman) says it takes 20hrs of focused / dedicated practice to reasonably develop a skill
        -   I'm willing to concede that a league game isn't a fantastic learning environment, but 4x that seems a bit much
    -   conversely, the historical take on **mastery** of a skill says it should take 10k hours
        -   which would be a whole lot of games lol

​

In the end, I'm just curious and / or wanting to chat with you about it lol. I enjoyed your articles and book marked your site :P you've gained a new user

1

[u/JackWills94](https://safereddit.com/user/JackWills94) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji1k5ju/?context=3#ji1k5ju "Apr 28 2023, 11:58:07 UTC")

Hey, this is really interesting information. Please do join the itero discord, exactly the sort of interesting information I want to hear about.

As far as why I chose those points, it was more to do with # of accounts in each, looking to get roughly 20% in low and high mastery then 40% in the middle

1

[u/iwalkwounded](https://safereddit.com/user/iwalkwounded) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji46imh/?context=3#ji46imh "Apr 28 2023, 22:57:34 UTC")

Ah i see, that makes sense.

joined!

1

[u/GoatRocketeer](https://safereddit.com/user/GoatRocketeer) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzqk3o/?context=3#jhzqk3o "Apr 28 2023, 00:36:20 UTC")

I would argue that the term "skill ceiling" should apply exclusively to their winrate when mastered, and ignore their winrate at low mastery.

If, in theory, azir caps out at a 51.5% winrate when mastered then you dont actually get that much from playing him and his ceiling is really low. It's just that his floor is really high so he's hard, but going by these numbers alone he doesn't become very strong if you use him to his maximum (maximum in gold) potential.

IMO, difference between winrate when unmastered and mastered is skill floor. I'd argue "easy" and "high skill ceiling" are not mutually exclusive - specifically when a champ is OP you both get a lot out of them if youre good and also get a lot out of them if they're bad.

1

[u/TunaSafari25](https://safereddit.com/user/TunaSafari25) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/jhzz4mz/?context=3#jhzz4mz "Apr 28 2023, 01:37:00 UTC")

Curious how much getting filled impacts this as I imagine it’s significant. I.e. a selected champ with low mastery could also mean they are auto filled and also don’t know the role well(looking at jungle). This would make their win rate even worse.

1

[u/SebJenSeb](https://safereddit.com/user/SebJenSeb) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0g92i/?context=3#ji0g92i "Apr 28 2023, 03:48:38 UTC")

Very good work. Kind of surprised at how hard nunu is...

1

[u/\_Jetto\_](https://safereddit.com/user/_Jetto_) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0jsop/?context=3#ji0jsop "Apr 28 2023, 04:22:42 UTC")

Interesting read thanks for post

1

[u/xfm0](https://safereddit.com/user/xfm0) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0nsvh/?context=3#ji0nsvh "Apr 28 2023, 05:05:16 UTC")

I wish things like urf didn't skew champion mastery points. I'll admit I have like a 500k+ on ezreal because I only played him in urf (before their stealth nerf to Q) over several urfs and that alone gave like 300k points.

1

[u/syrboy](https://safereddit.com/user/syrboy) W GOT BUFF!! [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji0sjnh/?context=3#ji0sjnh "Apr 28 2023, 06:01:01 UTC")

the jarvan stat makes me laugh because i feel like im on of the few people in the elo range you looked at with 1m+ mastery on him and my winrate is just around his regular winrate.

1

[u/StJe1637](https://safereddit.com/user/StJe1637) [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji2k2xv/?context=3#ji2k2xv "Apr 28 2023, 16:15:17 UTC")

aphelios is actually not that hard though reddit said so

1

[u/claptrap23](https://safereddit.com/user/claptrap23) Frozen Mallet enjoyer [Apr 28 '23](https://safereddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/ji2kxfr/?context=3#ji2kxfr "Apr 28 2023, 16:20:46 UTC")

I'm surprised vayne is that high in low mastery ratio
