# How Good Are FiveThirtyEight Forecasts? | FiveThirtyEight

<https://web.archive.org/web/20220105161212/https://projects.fivethirtyeight.com/checking-our-work/>

UPDATED Jun. 7, 2021, at 4:00 PM

[

# How Good Are FiveThirtyEight Forecasts?

](https://projects.fivethirtyeight.com/checking-our-work/)

##### Recent forecasts

[

###### Presidential elections

](https://projects.fivethirtyeight.com/checking-our-work/presidential-elections/)[

###### March Madness

](https://projects.fivethirtyeight.com/checking-our-work/march-madness-men/)

Forecasts have always been a core part of FiveThirtyEight’s mission. They force us (and you) to think about the world probabilistically, rather than in absolutes. And making predictions, whether we’re modeling a candidate’s chance of being elected or a team’s odds of making the playoffs, improves our understanding of the world by testing our knowledge of how it works — what makes a team or a candidate win.

But are those forecasts any good?

This project seeks to answer that question. Using the dropdown menu above, you can check out how all our major forecasts, going back to 2008, fared. (We’ll add new forecasts once they can be evaluated.) These tools reveal where our forecasts need some tweaking. But we also think they show that FiveThirtyEight’s models have performed strongly. All of our forecasts have proved to be more valuable than an unskilled guess, and things we say will happen only rarely … tend to happen only rarely.

##### Politics

##### Sports

##### Everything

## How do you judge a forecast?

There are many ways to judge a forecast. Here, we’re looking at two main things: the calibration of a forecast — that is, whether events that we said would happen 30 percent of the time actually happened about 30 percent of the time — and how our forecast compared with an unskilled estimate that relies solely on historical averages. We can answer those questions using calibration plots and skill scores, respectively. To show you how they work, we’ll use our MLB game predictions, which span the last five seasons.

### Calibration plots

Calibration plots compare what we predicted with what actually happened — in this case, every MLB team’s chance of winning each game on the day it was played and the actual outcome of each of those games. Let’s start by looking at only games from September 2018 (so that there aren’t thousands of dots on the chart below). Every matchup gets two dots, one for the team that won and another for the team that lost.

Actual win percentage

Looking at the chart, you might think we were pretty lousy at picking winners. Our forecast gives most teams close to a 50 percent chance of winning and seems to be wrong almost as often as it is right. We’re not trying to pick winners, though; we’re trying to model the games, which means including in our predictions all of the randomness inherent in baseball. And baseball games are [among the most random events we forecast](https://fivethirtyeight.com/features/the-imperfect-pursuit-of-a-perfect-baseball-forecast/) — even the best teams lose about a third of their matchups every season.

Indeed, single predictions are hard to judge on their own. So let’s group every MLB game prediction (not just those from September 2018) into bins — for example, we’ll throw every prediction that gave a team between a 37.5 percent and 42.5 percent chance of winning into the same “40 percent” group — and then plot the averages of each bin’s forecasted chances of winning against their actual win percentage. If our forecast is _well-calibrated_ — that is, if events happened roughly as often as we predicted over the long run — then all the bins on the calibration plot will be close to the 45-degree line; if our forecast was _poorly calibrated_, the bins will be further away.

#### MLB games, 2016-20

The plot of our MLB game predictions shows that our estimates were very well-calibrated. But it also shows that we rarely went out on a limb and gave any team a high chance of winning. Our second tool, skill scores, lets us evaluate our forecasts even further, combining accuracy and an appetite for risk into a single number.

### Skill scores

##### Popular

[

###### Presidential elections

](https://projects.fivethirtyeight.com/checking-our-work/presidential-elections/)[

###### U.S. House elections

](https://projects.fivethirtyeight.com/checking-our-work/us-house-elections/)

Brier [skill scores](https://en.wikipedia.org/wiki/Forecast_skill) — an extension to the more commonly known Brier score — tell us how much more valuable our forecasts are than an unskilled estimate, one that is informed by historical averages — e.g., a guess that every baseball game is roughly 50-50. Here’s how our MLB games forecast compares with all our other forecasts, based on their Brier skill scores.

Sports forecastsPolitics

More value

More value

Less value

Less value

You can see that all our forecasts performed better than an unskilled forecast. Our MLB games forecast, however, has a lower skill score than all of our other forecasts. That’s primarily because there’s a lot of uncertainty in baseball, so finding an edge over the unskilled estimate — which is essentially a coin flip in this case — is difficult. Other arenas lend themselves to more confident predictions. Compared with MLB games, U.S. House elections are easier to predict, in part because there’s less randomness involved and we have a better sense of what affects outcomes — for example, incumbents almost always keep their seats. So our forecasts of those elections have higher certainty that a candidate will win, and they perform far better than an unskilled estimate that assumes each candidate has an equal shot.

Two reasons FiveThirtyEight exists are to act as a counterweight to the influence of [punditry](https://journals.sagepub.com/doi/abs/10.1177/1081180x96001001004) and to help create a news environment in which readers demand accountability. Until we published this project, [we](https://fivethirtyeight.com/features/how-fivethirtyeights-2018-midterm-forecasts-did/) [were](https://fivethirtyeight.com/features/how-fivethirtyeights-ncaa-tournament-forecasts-did/) [spotty](https://fivethirtyeight.com/features/politics-podcast-how-to-judge-our-forecasts/) about letting you know whether our predictions were any good, sometimes leaving that task to [other](https://www.buzzfeednews.com/article/jsvine/2016-election-forecast-grades) [publications](https://decisiondeskhq.com/midterm-forecasting-model-analysis/). But now, we’ve created a single place where we hope you’ll come back as we add future forecasts and help keep us honest.

All probabilities were published by FiveThirtyEight before the corresponding events occurred. We have removed all 100 percent and 0 percent forecasts for events that were guaranteed or impossible from this analysis; for example, any forecasts made after a team was eliminated from a postseason race. When projects are aggregated across multiple years and multiple model types, only FiveThirtyEight's default model type from each year is evaluated. The unskilled estimates for sports games incorporate home-field advantage by using each sport's historical home team winning percentage in its forecasts, rather than assuming that each team has an equal chance of winning. The “biggest surprises” for sports forecasts exclude the chance of a team finishing the regular season in a specific position or with a specific playoff seed.

When calculating the calibration and skill scores for forecasts that we updated over time, such as election forecasts that we updated every day, we weighted each update by the inverse of the number of updates issued. That way, we counted each forecasted event equally, regardless of how many updates we issued to the forecast. We applied the same weights when calculating the confidence intervals.

[Download this data](https://github.com/fivethirtyeight/checking-our-work-data).

By [Jay Boice](https://fivethirtyeight.com/contributors/jay-boice/) and [Gus Wezerek](https://fivethirtyeight.com/contributors/gus-wezerek/). Additional contributions by [Laura Bronner](https://fivethirtyeight.com/contributors/laura-bronner/) and [Aaron Bycoffe](https://fivethirtyeight.com/contributors/aaron-bycoffe/).

### Related Stories

## [Biden’s Vaccine Mandates Could Be In Trouble At The Supreme Court](http://fivethirtyeight.com/features/bidens-vaccine-mandates-could-be-in-trouble-at-the-supreme-court/)

## [Why Republicans Take Jan. 6 Less Seriously Than Other Americans](http://fivethirtyeight.com/features/why-republicans-take-jan-6-less-seriously-than-other-americans/)

## [Why More Republicans Aren’t Outraged By Jan. 6](http://fivethirtyeight.com/features/why-more-republicans-arent-outraged-by-jan-6/)

## [We’re Misunderstanding What Caused Jan. 6](http://fivethirtyeight.com/features/were-misunderstanding-what-caused-jan-6/)

## [How Jan. 6 Enabled Greater Interference In Our Elections](http://fivethirtyeight.com/features/how-jan-6-enabled-greater-interference-in-our-elections/)

### Comments

Get more FiveThirtyEight

-   [Newsletter](https://fivethirtyeight.com/newsletter/)
-   [Videos](https://fivethirtyeight.com/videos/)
-   [Podcasts](https://fivethirtyeight.com/tag/fivethirtyeight-podcasts/)
-   [Twitter](https://twitter.com/fivethirtyeight)
-   [Facebook](https://www.facebook.com/fivethirtyeight)
-   [Data](https://data.fivethirtyeight.com/)
-   [RSS](https://fivethirtyeight.com/datalab/fear-not-readers-we-have-rss-feeds/)

-   [Contact](https://fivethirtyeight.com/contact/)
-   [Jobs](https://fivethirtyeight.com/jobs/)
-   [Masthead](https://fivethirtyeight.com/masthead/)
-   [About Nielsen Measurement](http://priv-policy.imrworldwide.com/priv/browser/us/en/optout.html)

-   [Terms of Use](https://disneytermsofuse.com/)
-   [Privacy Policy](https://disneyprivacycenter.com/)
-   [Do Not Sell My Info](https://privacy.thewaltdisneycompany.com/en/dnsmi/)
-   [Your California Privacy Rights](https://disneyprivacycenter.com/notice-to-california-residents/)
-   [Children's Online Privacy Policy](https://disneyprivacycenter.com/kids-privacy-policy/english/)
-   [Interest-Based Ads](https://preferences-mgr.truste.com/?type=abcnews&affiliateId=11&cid=clicksource_4380645_footer_interestbasedads)

© 2018 ABC News Internet Ventures. All rights reserved.
