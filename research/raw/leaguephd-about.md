# Blog | About League PhD

<https://leaguephd.com/en/blog/about-us/>

-   [Champions](https://leaguephd.com/en/stats/)
-   [Pick Now](https://leaguephd.com/en/stats/pick-now/)
-   [Desktop App](https://leaguephd.com/en/stats/app/)
-   [Blog](https://leaguephd.com/en/blog/)

Patch: 15.12

-   

# About League PhD

A quick introduction to our counter and synergy metrics

Feb. 18, 2021

League PhD provides statistical analysis of counter and synergy relationships between League of Legends champions. By using a machine learning model to predict a match outcome based on team comps, we aim to produce metrics that are more accurate and easier to interpret than matchup win rates. Our team comp builder helps you pick the right champion and maximize your chance of winning even before the match starts.

#### Data

League PhD collects and analyzes millions of Platinum+ solo queue games in multiple regions (currently North America, EU West, EU Nordic & East, and Korea). For every new patch, it usually takes 3-4 days for our first batch of analysis to be released.

Data are automatically updated a few times a day. Please note, however, that the website/app is not actively managed.

#### Our counter and synergy metrics: why they are better than matchup win rates

Matchup win rates are one of the most commonly used statistics to identify champion counters and synergies. They are easy to calculate, but when it comes to actually deciding which champion to pick, there are a number of issues with matchup win rates that you should be aware of.

First, matchup win rates are difficult to interpret. Suppose Champion A has an overall win rate of 50%, and has a matchup win rate of 45% against Champion B. Does this mean Champion A is countered by Champion B because it’s sub 50%? Well, it depends on Champion B’s overall win rate.

-   B has a win rate of 50%: We may conclude Champion B counters Champion A. Both champions seem to be performing at an average level, so without any countering relationship between them, it’s reasonable to expect the matchup win rate to be close to 50%. But Champion B is winning more often than expected, so it’s likely Champion B counters Champion A.
-   B has a win rate of 60%: Unfortunately, in this case, we cannot draw any conclusion. On average, a 50% WR champion should win less than half of her games against a 60% WR champion. But is 45% **too low, about right, or too high**?

This problem arises because matchup win rates reflect not only counter and synergy relationships between champions, but also each champion’s overall performance. OP champions often have over 50% matchup win rates across the board, but it shouldn’t mean they don’t have any counters. With matchup win rates, it’s hard to disentangle counters and synergies from overall performance. There are some methods to construct the expected win rate, including the elo rating system in chess or the Log 5 formula in baseball. But they’re more of a numerical exercise, and can’t be easily generalized into the 5v5 setting (more on this below).

Second, matchup win rates suffer from correlations between champion picks. For example, Xayah and Rakan are played together so often that Xayah usually accounts for more than 25% of Rakan’s games. In this case, Rakan’s matchup win rate against another champion is likely to reflect not only his own, but also Xayah’s countering relationship against that champion. In other words, when Rakan has a high matchup win rate against a certain champion, there’s a possibility that it’s not Rakan but actually Xayah who counters that champion. Matchup win rates can’t tell you anything about this possibility.

Third, and most importantly, **it isn’t straightforward how to use matchup win rates in the 5v5 setting**. If League were a 1v1 game, you’d just need to pick a champion with the highest matchup win rate against your opponent. But as we all know, League is a 5v5 game, and there’s no proper way to generalize pairwise win rates into a 5v5 setting. Just using one matchup isn’t optimal; according to our analysis, your lane matchup explains only a small portion of the variations in champion performance.

League PhD attempts to address the issues by employing a machine learning model and performing more in-depth analysis. **Our metrics are performance-neutral, so you can directly compare a number with another.** They are not perfect, in the sense that they are still estimates of true relationships, but many of the issues with matchup win rates are at least partly addressed.

#### Pick Now

As mentioned above, our metrics are designed to be interpreted in the 5v5 setting. Therefore, they can be directly used to help you decide which champion to pick, based on your ally and enemy team comps. Our team comp builder, Pick Now, considers not only the champions that are already selected, but also all possible combinations of upcoming picks. It calculates how likely a champion will be picked into your champion and makes recommendations based on not only how well your champion will perform on average, but also how likely your champion will be countered by your enemies or poorly synergize with your teammates.

Our desktop app provides the same experience of Pick Now but without the hassle of manual typing and clicking.

#### For Technical Audience

The analysis uses a regularized logistic regression to predict a match outcome solely based on team compositions, taking account of champion strengths as well as synergy and counter relationships with other champions. Measuring the performance of the model turned out to be tricky. Log loss is often used to gauge the quality of a classifier estimating probabilistic outcomes, but with very balanced data, log loss is naturally not much different from 0.693. Indeed, data show that most common team compositions have 45-55% winning percentage. After tuning the hyperparameter, my model scored log loss of around 0.68, indicating that it has some predictive power. On a more positive note, cross-validation results suggested that coefficients are quite stable across folds.

#### Who built this?

I am a Platinum ADC/support main who has played League of Legends since Season 2. For any suggestion and question, please contact me at leaguephd.com@gmail.com

League PhD isn’t endorsed by Riot Games and doesn’t reflect the views or opinions of Riot Games or anyone officially involved in producing or managing League of Legends. League of Legends and Riot Games are trademarks or registered trademarks of Riot Games, Inc. League of Legends © Riot Games, Inc.

[Return to blog](https://leaguephd.com/en/blog/)

© 2021 League PhD

[About](https://leaguephd.com/en/blog/about-us/) [Privacy Policy](https://g.ezoic.net/privacy/leaguephd.com) [Contact Us](mailto:leaguephd.com@gmail.com)

## Privacy & Transparency

leaguephd.com and our partners ask for your consent to use your personal data, and to store and/or access information on your device. This includes using your personal data for personalised advertising and content, advertising and content measurement, audience research and services development. An example of data being processed may be a unique identifier stored in a cookie. Your personal data may be stored by, accessed by, and shared with 1214 partners, or used specifically by this site. You can change your settings or withdraw consent at any time, the link to do so is in our privacy policy at the bottom of this page. Some vendors may process your personal data on the basis of legitimate interest, which you can object to by managing your settings below.

 

[Vendor List](javascript:void\(0\);) | [Privacy Policy](https://g.ezoic.net/privacy/leaguephd.com)
