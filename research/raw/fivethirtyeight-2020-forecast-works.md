# How FiveThirtyEight’s 2020 Presidential Forecast Works — And What’s Different Because Of COVID-19 | FiveThirtyEight

<https://web.archive.org/web/20201101001559/https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/>

[Skip to main content](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#content)

## [FiveThirtyEight](https://fivethirtyeight.com/)

Search

 

-   [Politics](https://fivethirtyeight.com/politics/)
-   [Sports](https://fivethirtyeight.com/sports/)
-   [Science](https://fivethirtyeight.com/science/)
-   [Podcasts](https://fivethirtyeight.com/podcasts/)
-   [Video](https://fivethirtyeight.com/videos/)

[

Live Updates: The State Of Election Law In The Lead-Up To The Election

](https://fivethirtyeight.com/live-blog/trump-biden-votes/)

Aug. 12, 2020, at 6:30 AM

# How FiveThirtyEight’s 2020 Presidential Forecast Works — And What’s Different Because Of COVID-19

By [Nate Silver](https://fivethirtyeight.com/contributors/nate-silver/)

Filed under [2020 Election](https://fivethirtyeight.com/tag/2020-election/)

-   
-   
-   

Our [presidential forecast](https://projects.fivethirtyeight.com/2020-election-forecast/), which launched today, is not the first election forecast that FiveThirtyEight has published since 2016. There was our [midterms forecast in 2018](https://projects.fivethirtyeight.com/2018-midterm-election-forecast/house/), which was pretty accurate in predicting the makeup of the House and the Senate. And there was our [presidential primaries model](https://projects.fivethirtyeight.com/2020-primary-forecast/) earlier this year, which was a bit of an adventure but mostly notable for being bullish (correctly) on Joe Biden and (incorrectly) on Bernie Sanders. But we’re aware that the publication of our first presidential forecast since 2016 is liable to be fraught.

We’d like to address one thing upfront, though: We think our model did a good job in 2016. Although [it had Hillary Clinton favored](https://projects.fivethirtyeight.com/2016-election-forecast/), it gave Donald Trump around a 30 percent chance of winning on Election Day,[1](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-1) which was considerably higher than [other models](https://www.nytimes.com/interactive/2016/upshot/presidential-polls-forecast.html#other-forecasts), [prediction markets](https://phys.org/news/2016-11-polls-trump-victory-economist.html) and the [conventional wisdom about the race](https://fivethirtyeight.com/features/the-real-story-of-2016/). Moreover, the [reasons the model was more bullish on Trump](https://fivethirtyeight.com/features/why-fivethirtyeight-gave-trump-a-better-chance-than-almost-anyone-else/) than other forecasts — such as [detecting a potential overperformance for Trump](https://fivethirtyeight.com/features/the-odds-of-an-electoral-college-popular-vote-split-are-increasing/) in the Electoral College — proved to be important to the outcome.

Also, we’ve found that FiveThirtyEight’s models — including our election forecasts since they were first published in 2008 — have been [well calibrated over time](https://projects.fivethirtyeight.com/checking-our-work/). Candidates who our models claim have a 30 percent chance of winning really do win their races about 30 percent of the time, for example.

So if this were an ordinary election, we’d probably just say screw it, take the 2016 version of our model, make some modest improvements, and press “go.” We’d [certainly devote more attention to how the model was _presented_](https://twitter.com/wiederkehra/status/1287872080474603521), but the underlying math behind it would be about the same.

We are not so sure that this is an ordinary election, though. Rather, it is being contested amid the most serious pandemic to hit the United States since 1918. So we’ve been doing a lot of thinking about how COVID-19 and other news developments could affect various aspects of the race, ranging from its impact on the economy to how it could alter the actual process of voting.

Put another way, while we think “ZOMG 2016!!!” is not a good reason to rethink a model that tended to be pretty cautious in the first place, we think COVID-19 might be.

## **What’s different from 2016**

In the end, our model still isn’t _that_ different from 2016’s, but let’s run through the list of changes. After that, we’ll provide a front-to-back description of how our model works.

First, a number of changes in the model are related to COVID-19:

-   In forecasting how much the polls could change, we now account for more components related to uncertainty. Two of these components include estimating i) economic uncertainty and ii) the overall volume of important news, both of which are very high under COVID-19. These offset other trends — such as greater polarization — that would lead to less uncertainty.
-   We’ve put a lot more work into our economic index: i) extending it back to 1880 to capture a fuller range of economic conditions, ii) adjusting it for increased partisanship and iii) developing an economic forecasting component to reflect potential changes in the economy between now and November. This is important because most projections [forecast substantial improvement in the economy before November](https://www.wsj.com/graphics/econsurvey/).
-   We attempt to account for additional uncertainty in Election Day results because turnout will potentially be less predictable given the pandemic.
-   We allow COVID-19 to be a factor in determining [covariance](https://en.wikipedia.org/wiki/Covariance). That is to say, states that have had high rates of COVID deaths and cases (such as Arizona and New York, which otherwise don’t have that much in common politically) could have correlated outcomes. Likewise, we also consider covariance based on a state’s anticipated rate of mail voting.
-   With the party conventions being [substantially scaled down](https://deadline.com/2020/08/democratic-national-convention-tv-networks-fox-news-cnn-nbc-1203000862/) and largely held virtually, we’re applying only half of the usual “convention bounce adjustment” (see below for more on the convention bounce adjustment).

Other changes fall more into the category of continual improvements we’re making to our models that aren’t directly related to COVID-19:

-   Since 2016, we’ve made various changes to how our polling averages are calculated, as described [here](https://fivethirtyeight.com/features/our-new-polling-averages-show-biden-leads-trump-by-9-points-nationally/).
-   We now account for changes in how [easy it is to vote](https://www.liebertpub.com/doi/full/10.1089/elj.2017.0478) in each state, as empirically, this yields higher turnout and a higher share of Democratic votes.
-   The model is now more careful around major events such as presidential debates that can have an outsize impact on candidates’ polling averages. If candidates gain ground in the polls following these events, they will have to sustain that movement for a week or two to get full credit for it.
-   We’re running only one version of the presidential model this year. Things are complicated enough in an election held during a pandemic without getting into “polls-only” and “polls-plus” forecasts. Nor is there a “now-cast.” Our [polling averages](https://projects.fivethirtyeight.com/polls/president-general/national/) are the best way to reflect the current snapshot of the race, but the snapshot is not the same as the projected Election Day outcome.

The rest of how our model works involves three major steps. What follows is a pretty detailed walk-through, but I’ll be more circumspect when discussing steps described at more length elsewhere, such as in our [2016 methodology guide](https://fivethirtyeight.com/features/a-users-guide-to-fivethirtyeights-2016-general-election-forecast/).

## **Step 1: Collect, analyze and adjust polls**

Our [national](https://projects.fivethirtyeight.com/polls/president-general/national/) and [state](https://projects.fivethirtyeight.com/polls/president-general/pennsylvania/) polling averages, which we began publishing in June, are the first steps we take in building our election forecast. We [detailed our process for constructing those polling averages](https://fivethirtyeight.com/features/our-new-polling-averages-show-biden-leads-trump-by-9-points-nationally/) when we released them, so I’ll just review the highlights here.

-   Our polling averages are intended to be as inclusive as possible. We don’t want to have to make a lot of arbitrary decisions on which polls to include. But please [review our polls policy for some exceptions](https://fivethirtyeight.com/features/polls-policy-and-faqs/) on when we can’t use a poll in our forecast. Sometimes there are also delays in adding a poll until we can get more information about it.
-   Polls are weighted based on their sample size and their [pollster rating](https://projects.fivethirtyeight.com/pollster-ratings/), so higher-quality polls have more influence on the forecast. And if there are a large number of polls from one polling firm, the weight applied to each individual poll is discounted so no one pollster dominates the average.
-   Our polling averages reflect a blend of two methods. The first is a relatively simple weighted average, and the second is a more complicated method based on calculating a trend line. Of the two, the trend line method tends to be more aggressive. So early on in the campaign, we rely mostly on the more conservative weighted average method, while in the final few weeks, we mostly use the trend line method — that means our polling averages become more aggressive as Election Day nears.
-   The polling averages are subject to three types of adjustments:
    -   The **likely voter adjustment**, which reflects that polls of likely voters and registered voters differ in predictable ways, adjusts polls of registered voters[2](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-2) to make them more comparable to likely voter polls. Generally speaking, this means that Republicans (such as Trump) gain ground relative to Democrats when applying a likely voter screen, although this effect is mitigated when the Republican is an incumbent. Indeed, polls this year that have both a registered voter and likely voter version usually show Trump doing slightly better in the likely voter version. However, he does only modestly better, gaining around 1 percentage point on average.
    -   The **house effects adjustment**, which detects polls that consistently lean toward one party or that consistently have more (or fewer) undecided voters than other polls of the same states, and adjusts them to correct for this. For example, Rasmussen Reports polls typically have very Republican-leaning results. So this adjustment would account for that. However, polls are allowed to retain at least some of their house effect, since an apparent house effect over a small number of polls could reflect statistical noise. In calculating house effects, the model mostly uses polls from the same state, so a polling firm could theoretically have a Trump-leaning house effect in one state and a Biden-leaning house effect in another.
    -   Finally, we apply a **timeline adjustment**, which is based on a poll’s recency, and adjusts “old” polls for shifts in the overall race since it was conducted. For instance, say a poll of Arizona last month showed Biden up 3 points there, but there’s been a strong shift toward Trump since then in national polls and polls of similar states such as Nevada. This adjustment would shift that older Arizona poll toward Trump.

As we noted, the calculation of the polling averages is the first step in calculating our forecast. But they are not the same thing.

One time when this distinction is particularly relevant is following major events such as the debates and party conventions. These events sometimes produce big swings in the polls, and our polling averages are designed to be aggressive following these events and reflect the changed state of the race. However, these shifts are not necessarily long-lasting, and after a couple of weeks, the polls sometimes revert to where they were before.

Therefore, the model relies only partly on the polling average of the race after one of these events happens. For instance, say there is a debate on Oct. 1 and you’re looking at the model on, for example, Oct. 5. It will use a blend of the post-debate polling average from Oct. 5 _and_ the pre-debate polling average from Oct. 1. After a week or two (depending on the event) though, the model will fully use the post-event polling average because it no longer necessarily expects a reversion to the mean.

In addition, our presidential model has traditionally applied a [convention bounce adjustment](https://fivethirtyeight.com/features/measuring-a-convention-bounce/) that reflects the predictable boost in the polls that a party tends to get following its convention. Clinton [surged to some of her biggest leads of the cycle](https://projects.fivethirtyeight.com/2016-election-forecast/national-polls/) following the Democratic Convention in 2016, for example. However, three factors could mitigate the convention bounce this year.

-   First, convention bounces have become smaller over time, likely reflecting a reduced number of swing voters because of greater partisanship. Based on current levels of polarization, for instance, we would expect a party to poll about 5 percentage points better at the peak of its convention bounce on the day just after the conclusion of its convention, with the effects fading fairly quickly thereafter. This is down from past convention bounces that could sometimes be measured in the double digits.
-   Second, as mentioned before, we are applying only half of the usual convention bounce adjustment this year because due to COVID-19, the conventions are being scaled back.
-   Third, because this year’s Republican National Convention occurs the week immediately following the Demoratic National Convention, the effects could largely cancel each other out — Biden’s bounce could be derailed by Trump’s bounce, in other words. Because Trump’s convention occurs second, the effects of it might linger for slightly longer, but the model expects the net effect to be small given that the Democratic convention will also be fairly fresh in voters’ minds.

Thus, the convention bounce adjustments will be small this year. Polls conducted in the period between the Democratic convention and the Republican convention will be adjusted toward Trump by around 2 or 2.5 percentage points, depending on the precise dates of the polls. And polls in the two to three weeks after the Republican convention will be adjusted toward Biden but only very slightly so (by less than 1 full percentage point).

## **Step 2: Combine polls with “fundamentals,” such as demographic and economic data**

As compared with [other models](https://projects.economist.com/us-2020-forecast/president), FiveThirtyEight’s forecast relies heavily on polls. We do, however, incorporate other data in two main ways:

-   First, the polling average in each state is combined with a modeled estimate of the vote based on demographics and past voting patterns to create what we call an “enhanced snapshot” of current conditions. This is especially important in states where there is little or no polling.
-   Second, that _snapshot_ is then combined with our priors, based on incumbency and economic conditions, to create a _forecast_ of the Election Day outcome.

#### _Enhancing our polling averages_

At the core of the modeled estimate is FiveThirtyEight’s partisan lean index, which reflects how the state voted in the past two presidential elections as compared with the national average. In our partisan lean index, 75 percent of the weight is assigned to 2016 and 25 percent to 2012. So note, for example, that Ohio (which turned much redder between 2012 and 2016) is not necessarily expected to continue to become redder. Instead, it might revert somewhat to the mean and become more purple again.

The partisan lean index also contains a number of other adjustments:

-   We adjust for the home states of the presidential and vice presidential candidates. The size of the home-state adjustment is much larger for presidential candidates than for their running mates. The size of the state is also a factor: Home-state advantages are larger in states with smaller populations. We also allow candidates to be associated with more than one state, in which case the home-state bonus is divided. For Biden, for instance, his primary home state is Delaware (where he lives now), and his secondary state is Pennsylvania (where he was born). And for Trump, his primary home state is New York (where he was born), and his secondary state is Florida (where he [officially claims residence](https://www.nytimes.com/2019/10/31/us/politics/trump-new-york-florida-primary-residence.html)).[3](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-3)
-   We also adjust for what we call a state’s _elasticity_. Some states such as New Hampshire [“swing” more than others in response to national trends](https://fivethirtyeight.com/features/swing-voters-and-elastic-states/) because they have a higher proportion of swing voters, which can cause wider fluctuations from cycle to cycle. The [elasticity scores we’re using for 2020](https://twitter.com/NateSilver538/status/1272618296571985920?s=20) are based on a blend of each state’s elasticity in 2008, 2012 and 2016.
-   And finally, we account for changes in [how easy it is to vote](https://www.liebertpub.com/doi/full/10.1089/elj.2017.0478) in each state based on the [Cost of Voting Index](https://www.liebertpub.com/doi/full/10.1089/elj.2017.0478), as researchers have found that states with higher barriers to voting tend to produce better results for Republican candidates and states with lower barriers tend to lean more Democratic.[4](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-4)

We then apply the partisan lean index in three slightly different ways to create a modeled estimate of the vote in each state.

-   First is what we call the “rigid method” because it rigidly follows the partisan lean index. In this technique, we first impute where the race stands nationally based on a blend of state and national polls. (Most of the weight in this calculation actually goes to state polls, though. National polls play relatively little role in the FiveThirtyEight forecast, other than to calculate the trend line adjustment in Step 1.) Then we add a state’s partisan lean index to it. For instance, if we estimate that Biden is ahead by 5 points nationally, and that a state’s partisan lean index is D+10 — meaning it votes 10 points more Democratic than the country as a whole — the rigid method would project that Biden is currently ahead by 15 points there.[5](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-5)
-   Second is the demographic regression method. Basically, the goal of this technique is to infer what the polls would say in a state based on the polls of other states that have more polling. In this method, [adopted from a similar process we applied in our primary model](https://fivethirtyeight.com/features/how-fivethirtyeight-2020-primary-model-works/), we use a state’s partisan lean index plus some combination of other variables in a series of regression analyses to try to fit to the current polling in each state. The variables considered include race (specified in several different ways), income, education, [urbanization](https://fivethirtyeight.com/features/how-urban-or-rural-is-your-state-and-what-does-that-mean-for-the-2020-election/), religiosity[6](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-6) and an index indicating the severity of the COVID-19 situation in each state, based on the number of cases and deaths per capita [as recorded by the COVID Tracking Project](https://covidtracking.com/data). (Technically speaking, the model runs as many as 180 different regressions based on various combinations of these variables, but there are limits on which variables may appear in the regressions together in order to avoid [collinearity](http://www.stat.tamu.edu/~hart/652/collinear.pdf), as well as how many variables can be included.) We then take a weighted average of all the regressions, where regression specifications with a [higher adjusted R2](https://blog.minitab.com/blog/adventures-in-statistics-2/multiple-regession-analysis-use-adjusted-r-squared-and-predicted-r-squared-to-include-the-correct-number-of-variables#:~:text=The%20adjusted%20R%2Dsquared%20is,less%20than%20expected%20by%20chance.) receive more weight but all regressions receive at least some weight.
-   Third is the regional regression method. This is much simpler: It consists of a single regression analysis where the dependent variables are a state’s partisan lean index, plus dummy variables indicating which of the four major regions (Northeast, Midwest, South, West) the state is in.[7](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-7)

We then combine these three estimates to create an [ensemble forecast](https://en.wikipedia.org/wiki/Ensemble_forecasting#:~:text=Ensemble%20forecasting%20is%20a%20method,future%20states%20of%20the%20atmosphere.) for each state. The rigid method, which is the most accurate historically, receives the majority of the weight, followed by the demographic regression and then the regional regression.

Then, we combine the ensemble forecast with a state’s polling average to create an enhanced snapshot of the current conditions in each state. The weight given to the polling average depends on the volume of polling in each state and how recently the last poll of the state was conducted. As of the forecast launch (Aug. 12), around 55 percent of the weight goes to the polling average rather than to the ensemble in the average state. However, in well-polled states toward the end of the campaign, as much as 97 or 98 percent of the weight could go toward the polling average. Conversely, states that have few polls rely mostly on the ensemble technique (and states that have no polls use the ensemble in lieu of a polling average).

Next, we combine the enhanced snapshots in each state to create a _national_ snapshot, which is essentially our prediction of the national popular vote margin in an election held today. The national snapshot accounts for projected voter turnout in each state based on population growth since 2016, changes in how easy it is to vote since 2016, and how close the race is in that state currently — closer-polling states tend to have higher turnout. National polls are _not_ used in the national snapshot; it’s simply a summation of the snapshots in the 50 states and Washington, D.C.

We know this is starting to get pretty involved — we’re really in the guts of the model now — but there is another important step. Our national snapshot is not the same thing as our prediction of the Election Day outcome. Instead, our prediction blends the polling-driven snapshot with a “fundamentals forecast” based on economic conditions and whether an incumbent is seeking reelection.

#### _Polls vs. Fundamentals_

I’m [on the record](https://fivethirtyeight.com/features/models-based-on-fundamentals-have-failed-at-predicting-presidential-elections/) as saying that I think presidential forecasting models based strictly on “fundamental” factors like economic conditions are overrated. Without getting _too_ deep into the weeds, it’s easy to [“p-hack” your way to glory](https://projects.fivethirtyeight.com/p-hacking/) with these models because there are so many ways to measure “the economy” but only a small sample size of elections for which we have reliable economic data. The telltale sign of these problems is that models claiming to predict past elections extremely well often produce inaccurate — or even ridiculous — answers when applied to elections in which the result is unknown ahead of time. One popular model based on [second-quarter GDP](https://www.nytimes.com/2020/07/30/business/economy/q2-gdp-coronavirus-economy.html), for example, implies that Biden is currently on track to win [nearly 1,000 electoral votes](https://twitter.com/NateSilver538/status/1290762834285035520?s=20) — a bit of a problem since the maximum number theoretically achievable is 538.[8](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-8)

At the same time, that doesn’t mean the fundamentals are of no use at all. They can provide value and gently nudge your forecast in the right direction — if you use them carefully (although they’re hard to use carefully amidst something like the pandemic).

So, since 2012, we have used an [index of economic conditions](https://fivethirtyeight.com/features/measuring-the-effect-of-the-economy-on-elections/) in our presidential forecast. In its current incarnation, it includes six variables:

-   **Jobs**, as indicated by [nonfarm payrolls](https://fred.stlouisfed.org/series/PAYEMS).
-   **Spending**, as indicated by [real personal consumption expenditures](https://fred.stlouisfed.org/series/PCEC96).
-   **Income, as measured by [real disposable personal income](https://fred.stlouisfed.org/series/DSPIC96).**
-   **Manufacturing**, as measured by [industrial production](https://fred.stlouisfed.org/series/INDPRO).
-   **Inflation**, based on the [consumer price index](https://fred.stlouisfed.org/series/CPIAUCSL).[9](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-9)
-   And the **stock market**, based on the [S&P 500](https://finance.yahoo.com/quote/%5EGSPC/).

All variables are [standardized](https://en.wikipedia.org/wiki/Standard_score) so that they have roughly the same mean and standard deviation — and, therefore, have roughly equal influence on the index — for economic data since 1946. The index is then based on readings of these variables in the two years leading up to the election (e.g., from November 2018 through November 2020 for this election) but with a considerably heavier weight placed on the more recent data, in particular, the data roughly six months preceding the election. Where possible, the index is calibrated based on “vintage” economic data — that is, [data as it was published in real time](https://alfred.stlouisfed.org/series/downloaddata?seid=PAYEMS) — rather than on data as later revised.

Although the quality of economic data is more questionable prior to the 1948 election, we have also attempted to create an approximate version of the index for elections going back to 1880 based on the [data that we could find](https://www2.census.gov/prod2/statcomp/documents/HistoricalStatisticsoftheUnitedStates1789-1945.pdf). (It’s extremely important, in our view, to expand the sample size for this sort of analysis, even if we have to rely on slightly less reliable data to do so.) Our economic index for elections dating to 1880 (see below) is expressed as a [Z-score](https://www.investopedia.com/terms/z/zscore.asp), where a score of zero reflects an average economy. And, as you can see, extremely negative economic conditions tend to predict doom for the incumbent party (as in 1932, 1980 and 2008).

##### The economy is a noisy predictor of presidential success

FiveThirtyEight’s economic index as of Election Day, since 1880,\* where a score of zero reflects an average economy, a positive score a strong economy and a negative score a weak one

| Year | Economic Index |  | Year | Economic Index |
| --- | --- | --- | --- | --- |
| 1880 | +1.37 |  | 1948 | \-0.29 |
| 1884 | \-0.18 |  | 1952 | +0.21 |
| 1888 | \-0.25 |  | 1956 | +0.07 |
| 1892 | +0.71 |  | 1960 | \-0.01 |
| 1896 | \-0.15 |  | 1964 | +0.70 |
| 1900 | +0.56 |  | 1968 | +0.23 |
| 1904 | \-0.23 |  | 1972 | +0.46 |
| 1908 | \-1.03 |  | 1976 | +0.26 |
| 1912 | +0.13 |  | 1980 | \-1.71 |
| 1916 | +0.75 |  | 1984 | +0.86 |
| 1920 | \-1.52 |  | 1988 | +0.09 |
| 1924 | +0.44 |  | 1992 | \-0.29 |
| 1928 | +0.15 |  | 1996 | +0.36 |
| 1932 | \-2.34 |  | 2000 | +0.36 |
| 1936 | +1.55 |  | 2004 | +0.01 |
| 1940 | +0.77 |  | 2008 | \-1.34 |
| 1944 | +1.01 |  | 2012 | \-0.10 |
|  |  |  | 2016 | +0.08 |

\*Values prior to the 1948 election are based on more limited data and should be considered rough estimates.

But, overall, the relationship between economic conditions and the incumbent party’s performance is fairly noisy. In fact, we found that the economy explains only around 30 percent of the variation in the incumbent party’s performance, meaning that other factors explain the other 70 percent.

We do try to account for some of those “other” factors, although we’ve found they make only a modest difference. For instance, we also account for whether the president is an elected incumbent (like Trump this year or Barack Obama in 2012), an incumbent who followed the line of succession into office (like Gerald Ford in 1976) or if there is no incumbent at all (as in 2008 or 2016). We also account for polarization based on [how far apart the parties are in roll call votes cast in the U.S. House](https://voteview.com/articles/party_polarization). Periods of greater polarization (such as today in the U.S.) are associated with closer electoral margins and also smaller impacts of economic conditions and incumbency.

One additional complication is that the condition of the economy at any given moment prior to the election may not resemble what it eventually looks like in November, which is what our model tries to predict. Thus, the model makes a simple forecast for each of the six economic variables, which accounts for some mean-reversion, but is also based on the recent performance of the stock market (yes, it [has some predictive power](https://digitalcommons.iwu.edu/cgi/viewcontent.cgi?article=1000&context=uauje)) and surveys of professional economists.[10](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-10)

Although we’ll discuss this at more length in [the feature that accompanies our forecast launch](https://fivethirtyeight.com/features/its-way-too-soon-to-count-trump-out/), the fundamentals forecast is not necessarily as bad as you might think for Trump, despite awful numbers in categories such as GDP. One of the economic components that the model considers (income) has been strong thanks to government subsidies in the form of the [CARES Act](https://home.treasury.gov/policy-issues/cares), for instance, and two others (inflation and the stock market) have been reasonably favorable, too.

In addition, Trump is an elected incumbent, the economy is expected to improve between the forecast launch (Aug. 12) and November, and the polarized nature of the electorate limits the damage to him to some degree. Thus, one shouldn’t conclude that Trump is a huge underdog on the basis of the economy alone, although he’s also not a favorite to win reelection as elected incumbents typically are.

##### The closer to Election Day, the more our model relies on polls

Share of the weight assigned to polls and the “fundamentals,” by number of days until the election

| Days until election | Polls | Fundamentals |
| --- | --- | --- |
| 0 | 100% | 0% |
| 5 | 97 | 3 |
| 10 | 94 | 6 |
| 25 | 89 | 11 |
| 50 | 84 | 16 |
| 75 | 79 | 21 |
| 100 | 74 | 26 |
| 150 | 65 | 35 |
| 200 | 57 | 43 |
| 250 | 47 | 53 |

However, our model assigns relatively little weight to the fundamentals forecast, and the weight will eventually decline to zero by Election Day. (Although the fundamentals forecast does do a good job of forecasting most recent elections, there are a lot more misses once you extend the analysis before 1948. So keep that in mind in the table, as the assigned weight is based on the entire data set.) Nonetheless, here is how much the model weights the fundamentals up until the election.

As of forecast launch in mid-August, for instance, the model assigns 77 percent of the weight to the polling-based snapshot and 23 percent of the weight to the fundamentals. In fact, the fundamentals actually help Trump at the margin (they aren’t good for him, but they’re better than his polls), so the model shifts the snapshot in each state slightly toward Trump in the forecast of the Election Day outcome. States with higher elasticity scores are shifted slightly more in this process.

## **Step 3: Account for uncertainty, and simulate the election thousands of times**

As complicated though it may seem, everything I’ve described up until this point is, in some sense, the easy part of developing our model. There’s no doubt that Biden is comfortably ahead as of the forecast launch in mid-August, for example, and the choices one makes in using different methods to average polls or combine them with other data isn’t likely to change that conclusion.

What’s trickier is figuring out how that translates into a probability of Biden or Trump winning the election. That’s what this section is about.

Before we proceed further, one disclaimer about the scope of the model: It seeks to reflect the vote as cast on Election Day, assuming that there are reasonable efforts to allow eligible citizens to vote and to count all legal ballots, and that electors are awarded to the popular-vote winner in each state. It does _not_ account for the possibility of extraconstitutional shenanigans by Trump or by anyone else, such as trying to prevent mail ballots from being counted.

That does _not_ mean it’s safe to assume these rules and norms will be respected. (If we were sure they would be respected, there wouldn’t be any need for this disclaimer!) But it’s just not in the purview of the sort of statistical analysis we conduct in our model to determine the likelihood they will or won’t be respected.

We do think, however, that well-constructed polls and models can provide a useful benchmark if any attempts to manipulate the election do occur. For instance, a candidate (in a state with incomplete results because mail ballots have yet to be counted) declaring themselves the winner in a state where the model had given them an 0.4 percent chance of winning would need to be regarded with more suspicion than one where they’d had a 40 percent chance going in (although a 40 percent chance of winning is by no means a sure thing either, obviously).

With that disclaimer out of the way, here are the four types of uncertainty that the model tries to account for:

1.  **National drift**, or how much the overall national forecast could change between now and Election Day.
2.  **National Election Day error**, or how much our final forecast of the national popular vote could be off on Election Day itself.
3.  **Correlated state error**, which reflects errors that could occur across multiple states along geographic or regional lines — for instance, as was relevant in 2016, a systematic underperformance relative to polls for the Democratic candidate in the Midwest.
4.  **State-specific error**, an error relative to our forecast that affects only one state.

The first type of error, **national drift**, is probably the most important one as of the launch — that is, the biggest reason Biden might not win despite currently enjoying a fairly wide lead in the polls is that the race could change between now and November.

National drift is calculated as follows:

_Constant x (Days Until Election)^⅓ x Uncertainty Index_

That is, it is a function of the cube root of the number of days until the election[11](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-11) times the FiveThirtyEight Uncertainty Index, which I’ll describe in a moment. (Note that the use of the cube root implies that polls do not become more accurate at a linear rate, but rather that there is a sharp increase in accuracy toward the end of an election. Put another way, August is still early as far as polling goes.)

The uncertainty index is a new feature this year, although it reflects a number of things we did previously, such as accounting for the number of undecided voters. In the spirit of [our economic index](https://fivethirtyeight.com/features/measuring-the-effect-of-the-economy-on-elections/), it also contains a number of measures that are historically correlated with greater (or lesser) uncertainty but are also correlated with one another in complicated ways. And under circumstances like these (not to mention the small sample size of presidential elections), we think it is better to use an equally-weighted blend of all reasonable metrics rather than picking and choosing just one or two metrics.

The components of our uncertainty index are as follows:

1.  The number of undecided voters in national polls. More undecided voters means more uncertainty.
2.  The number of undecided plus third-party voters in national polls. More third-party voters means more uncertainty.
3.  Polarization, as measured elsewhere in the model, is based on [how far apart the parties are in roll call votes cast in the U.S. House](https://voteview.com/articles/party_polarization). More polarization means less uncertainty since there are fewer swing voters.
4.  The volatility of the national polling average. Volatility tends to predict itself, so a stable polling average tends to remain stable.
5.  The overall volume of national polling. More polling means less uncertainty.
6.  The magnitude of the difference between the polling-based national snapshot and the fundamentals forecast. A wider gap means more uncertainty.
7.  The standard deviation of the component variables used in the FiveThirtyEight economic index. More economic volatility means more overall uncertainty in the forecast.
8.  The volume of major news, as measured by the [number of full-width New York Times headlines](https://twitter.com/NateSilver538/status/1273294432394190849?s=20) in the past 500 days, with more recent days weighted more heavily. More news means more uncertainty.

In 2020, measures No. 1 through 5 all imply below-average uncertainty. There aren’t many undecided voters, there are no major third-party candidates, polarization has been high and polls have been stable. Measure No. 6 suggests average uncertainty. But metrics No. 7 and 8 imply extremely high uncertainty; there has been a _ton_ of news related to COVID-19 and other major stories, like the protests advocating for police reform in response to the death of George Floyd — not to mention the impeachment trial of Trump earlier this year. Likewise, there has been as much volatility in economic data as at any time since the Great Depression.

On the one hand, the sheer number of uncertainties unique to 2020 indicate the possibility of a volatile election, but on the other hand, there are also a number of measures that signal lower uncertainty, like a very stable polling average. So when we calculate the overall degree of uncertainty for 2020, our model’s best guess is that it is about average relative to elections since 1972. That average, of course, includes a number of volatile elections such as 1980, 1988 and 1992, where there were [huge swings in the polls over the final few months of the campaign](https://twitter.com/baseballot/status/1292809396439982082?s=20), along with elections such as 2004 and 2012 where polls were pretty stable. As voters consume even more economic- and pandemic-related news — and then experience events like the conventions and the debates — it’s not yet clear whether the polls will remain stable or begin to swing around more.

It’s also not entirely clear how this might all translate into the **national Election Day error** — that is, how far off the mark our final polling averages are — either. In calculating Election Day error, we use a different version of the uncertainty index that de-emphasizes components No. 6, 7 and 8, since those components pertain mostly to how much we expect the polls to change between now and the election, rather than the possibility of an Election Day misfire.

Still, our approach to calculating Election Day error is fairly conservative. In order to have a larger sample size, the calculation is based on the error in final polls in [elections since 1936](https://news.gallup.com/poll/110548/gallup-presidential-election-trial-heat-trends.aspx), rather than solely on more recent elections. While polls [weren’t as far off the mark in 2016](https://fivethirtyeight.com/features/the-polls-are-all-right/) as is generally reputed (national polls were fairly accurate, in fact), it’s also not clear that the extremely precise polls in the final weeks of 2004, 2008 and 2012 will be easy to replicate given the [challenges in polling today](https://fivethirtyeight.com/features/how-to-read-2020-polls-like-a-pro/). Given the small sample sizes, we also use a [fat-tailed distribution](https://en.wikipedia.org/wiki/Fat-tailed_distribution) for many of the error components, including the national Election Day error, to reflect the small — but not zero — possibility of a larger error than what we’ve seen historically.

There could also be some challenges related to polling during COVID-19. In primary elections conducted during the pandemic, for instance, [turnout was hard to predict](https://fivethirtyeight.com/features/there-have-been-38-statewide-elections-during-the-pandemic-heres-how-they-went/). In some ways, the pandemic makes voting easier (expanded options to vote by mail in many states), but it also makes it harder in other ways (it’s difficult to socially distance if you must vote in person).

This is a rough estimate because there are a lot of confounding variables — including the end of the competitive portion of the Democratic presidential primary — but we estimate that the variability in turnout was about 50 percent higher in primary elections conducted after the pandemic began in the U.S. than those conducted beforehand. Empirically, we know that states that experience a sharp change in turnout from one cycle to the next are harder to forecast, too. So we estimate that a 50 percent increase in error when predicting turnout will result in a 20 percent increase in error when predicting the share of the vote each party receives.

Therefore, we increase national Election Day error, correlated state error and state-specific error by 20 percent relative to their usual values because of how the coronavirus could affect turnout and the process of voting. Note that this still won’t be enough to cover extraordinary developments such as mail ballots being impounded. But it should help to reflect some of the additional challenges in polling and holding an election amidst a pandemic.

When it comes to simulating the election — we’re running 40,000 simulations each time the model is updated — the model first picks two random numbers to reflect national drift (how much the national forecast could change) and national Election Day error (how off our final forecast of the national popular vote could be) that are applied more or less uniformly[12](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-12) to all states. However, even if you somehow magically knew what the final national popular vote would be, there would still be additional error at the state level. A uniform national swing would not have been enough to cost Clinton the Electoral College in 2016, for example. But underperformance relative to the polls concentrated in the Midwestern swing states did.

In fact, we estimate that at the end of the campaign, most of the error associated with state polling is likely to be correlated with errors in other states. That is to say, it is improbable that there would be a major polling error in Michigan that wouldn’t also be reflected in similar states such as Wisconsin and Ohio.

Therefore, to calculate correlated polling error, the model creates random permutations based on different demographic and geographic characteristics. In one simulation, for instance, Trump would do surprisingly well with Hispanic voters and thus overperform in states with large numbers of Hispanics. In another simulation, Biden would overperform his polls in states with large numbers of Catholics. The variables used in the simulations are as follows:

-   Race (white, Black, Hispanic, Asian)
-   Religion (evangelical Christians, mainline protestants, Catholic, Mormon, other religions, atheist/nonreligious)
-   A state’s partisan lean index in 2016 and in 2012
-   Latitude and longitude
-   Region (North, South, Midwest, West)
-   Urbanization
-   Median household income
-   Median age
-   Gender
-   Education (the share of the population with a bachelor’s degree or higher)
-   Immigration (the share of a state that is part of its [voting-eligible population](http://www.electproject.org/home/voter-turnout/faq/sold))
-   The COVID-19 severity index (see Step 2)
-   The share of a state’s vote that is [expected to be cast by mail](https://covidstates.net/COVID19%20CONSORTIUM%20REPORT%207%20VBM%20JULY%202020.pdf)

One mathematical property of correlated polling errors is that states with demographics that resemble those of the country as a whole tend to have less polling error than those that don’t. Underestimating Biden’s standing among Mormons wouldn’t cause too many problems in a national poll, or in a poll of Florida, for example. But it could lead to a huge polling error in Utah. Put another way, states that are outliers based on some combination of the variables listed above tend to be harder to predict.

Finally, the model randomly applies some residual, **state-specific error** in each state. This tends to be relatively small, and is primarily a function of the volume of polling in each state, especially in states that have had no polling at all. If you’re wondering why Trump’s chances are higher than you might expect in Oregon, for example, it’s partly because there have been no polls there as of forecast launch.

## **Odds and ends**

Whew — that’s pretty much it! But a few random bullet points that don’t fit neatly into the categories above.

-   The model accounts for the fact that Maine and Nebraska award one electoral vote each to the winner of each congressional district. In fact, these congressional districts have their own [forecast pages](https://projects.fivethirtyeight.com/2020-election-forecast/nebraska-2/), just as the states do. For the most part, though, the statewide forecasts in Maine and Nebraska just reflect the sum of the district forecasts. However, because not all polls provide district-level breakdowns in these states, the model also makes inferences from statewide polls of Maine and Nebraska. In total, the model calculates a forecast in 54 jurisdictions: the two congressional districts in Maine, the three in Nebraska, the other 48 states and Washington, D.C.
-   In 2016, as well as in backtesting the model in certain past years (i.e., 1980, 1992), we designated “major” third-party candidates such as Gary Johnson and Ross Perot. We defined major as (i) a candidate who is on the ballot almost everywhere, (ii) who is included in most polls and (iii) who usually polls in at least the mid-to-high single digits. There is no such candidate in 2020.
-   However, we _do_ predict votes for “other” candidates in each state. The predictions are based on how many third-party candidates appear on the ballot in the state,[13](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/#fn-13) whether write-in votes are permitted, how much of the vote a state has historically given to third-party candidates and how competitive the state is (third-party candidates historically receive fewer votes in swing states).
-   Electoral College ties (269-269) are listed as such in the model output. This is a change from past years, where we used various methods to break the ties. We do not account for the [possibility of faithless electors](https://en.wikipedia.org/wiki/Faithless_elector) or candidates other than Trump and Biden winning electoral votes.

Got any other questions or see anything that looks wrong? Please [drop us a line](mailto:polls@fivethirtyeight.com).

Nate Silver is the founder and editor in chief of FiveThirtyEight. [@natesilver538](https://twitter.com/natesilver538)

### Comments

Filed under

[Donald Trump (1422 posts)](https://fivethirtyeight.com/tag/donald-trump/) [2020 Election (1079)](https://fivethirtyeight.com/tag/2020-election/) [Joe Biden (453)](https://fivethirtyeight.com/tag/joe-biden/) [Polls (435)](https://fivethirtyeight.com/tag/polls/) [Coronavirus (289)](https://fivethirtyeight.com/tag/coronavirus/) [COVID-19 (265)](https://fivethirtyeight.com/tag/covid-19/) [Economy (143)](https://fivethirtyeight.com/tag/economy-2/) [Methodology (116)](https://fivethirtyeight.com/tag/methodology/) [National Polls (61)](https://fivethirtyeight.com/tag/national-polls/) [Protests (29)](https://fivethirtyeight.com/tag/protests/) [Voter Turnout (29)](https://fivethirtyeight.com/tag/voter-turnout/) [2020 Presidential Election (28)](https://fivethirtyeight.com/tag/2020-presidential-election/) [2020 Presidential Forecast (27)](https://fivethirtyeight.com/tag/2020-presidential-forecast/) [General Election (17)](https://fivethirtyeight.com/tag/general-election/) [State Polls (13)](https://fivethirtyeight.com/tag/state-polls/) [Police Protests (11)](https://fivethirtyeight.com/tag/police-protests/) [Polling Averages (9)](https://fivethirtyeight.com/tag/polling-averages/) [Economic Index (6)](https://fivethirtyeight.com/tag/economic-index/) [General Election Forecast (5)](https://fivethirtyeight.com/tag/general-election-forecast/) [Uncertainty Index (3)](https://fivethirtyeight.com/tag/uncertainty-index/) [Fundamentals (2)](https://fivethirtyeight.com/tag/fundamentals/) [Partisan Lean (2)](https://fivethirtyeight.com/tag/partisan-lean/) [National Drift (1)](https://fivethirtyeight.com/tag/national-drift/) [National Election Day Error (1)](https://fivethirtyeight.com/tag/national-election-day-error/)

## Newsletter

#### Want more FiveThirtyEight? Get our weekly most popular stories newsletter.

 

Get more FiveThirtyEight

-   [Store](https://cottonbureau.com/stores/fivethirtyeight#/shop)
-   [Newsletter](https://fivethirtyeight.com/newsletter/)
-   [Twitter](https://twitter.com/fivethirtyeight)
-   [Facebook](https://www.facebook.com/fivethirtyeight)
-   [Data](https://data.fivethirtyeight.com/)
-   [RSS](https://fivethirtyeight.com/features/fear-not-readers-we-have-rss-feeds/)

-   [Follow @FiveThirtyEight](https://twitter.com/FiveThirtyEight)

-   [Contact](https://fivethirtyeight.com/contact/)
-   [Jobs](https://fivethirtyeight.com/tag/fivethirtyeight-jobs/)
-   [Masthead](https://fivethirtyeight.com/masthead/)
-   [About Nielsen Measurement](http://priv-policy.imrworldwide.com/priv/browser/us/en/optout.html)
-   [Advertise With Us](https://disneyadsales.com/our-brands/abc-news/)

Powered by [WordPress.com VIP](https://wpvip.com/?utm_source=vip_powered_wpcom&utm_medium=web&utm_campaign=VIP%20Footer%20Credit&utm_term=fivethirtyeight.com)

-   [Terms of Use](https://disneytermsofuse.com/)
-   [Privacy Policy](https://disneyprivacycenter.com/)
-   [Do Not Sell My Info](https://privacy.thewaltdisneycompany.com/en/dnsmi/)
-   [Your California Privacy Rights](https://disneyprivacycenter.com/notice-to-california-residents/)
-   [Children's Online Privacy Policy](https://disneyprivacycenter.com/kids-privacy-policy/english/)
-   [Interest-Based Ads](https://preferences-mgr.truste.com/?type=abcnews&affiliateId=11&cid=clicksource_4380645_footer_interestbasedads)

© 2020 ABC News Internet Ventures. All rights reserved.
