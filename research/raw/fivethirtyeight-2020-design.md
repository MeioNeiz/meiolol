# How We Designed The Look Of Our 2020 Forecast | FiveThirtyEight

<https://web.archive.org/web/20201101005657/https://fivethirtyeight.com/features/how-we-designed-the-look-of-our-2020-forecast/>

[Skip to main content](https://fivethirtyeight.com/features/how-we-designed-the-look-of-our-2020-forecast/#content)

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

# How We Designed The Look Of Our 2020 Forecast

By [Anna Wiederkehr](https://fivethirtyeight.com/contributors/anna-wiederkehr/)

Filed under [2020 Election](https://fivethirtyeight.com/tag/2020-election/)

Published Aug. 13, 2020

-   
-   
-   

  

ILLUSTRATION BY FIVETHIRTYEIGHT

An election year in the FiveThirtyEight newsroom is unlike any other year. We started off by launching [our Democratic primary forecast](https://projects.fivethirtyeight.com/2020-primary-forecast/) in January, and once Joe Biden had effectively clinched the nomination in April, we were ready to hit the gas on our general election forecast. But 2020 has its own agenda: a [global pandemic](https://coronavirus.jhu.edu/map.html), a crashing [U.S. economy](https://fivethirtyeight.com/features/the-terrible-jobs-report-gets-worse-the-more-you-read-it/), changes to [the way we conduct elections](https://fivethirtyeight.com/features/there-have-been-38-statewide-elections-during-the-pandemic-heres-how-they-went/), and a reckoning with [systemic racism](https://fivethirtyeight.com/features/white-neighborhoods-have-more-access-to-covid-19-testing-sites/) and [police brutality](https://fivethirtyeight.com/features/why-statistics-dont-capture-the-full-extent-of-the-systemic-bias-in-policing/).

This week, however, we kicked off our main event: We launched our [2020 presidential election forecast](https://projects.fivethirtyeight.com/2020-election-forecast/) on Wednesday. We put a lot of thought into [how to forecast an election](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19) amid world-altering events, and into how to design and let users interact with that forecast. How do you present a forecast that communicates what we know but also what we don’t know and what might change? That question became especially pressing given the added uncertainty introduced by COVID-19, but we’ve been thinking about it for years, especially after the 2016 election.

Our impression was that people who [read a lot of our coverage in the lead-up to 2016](https://fivethirtyeight.com/tag/election-update/page/13/) and spent a good amount of time with [our forecast](https://projects.fivethirtyeight.com/2016-election-forecast/) thought we gave a [pretty accurate picture](https://www.washingtonpost.com/news/politics/wp/2017/09/27/your-critique-that-fivethirtyeight-misfired-on-the-2016-race-is-wrong/) of the election — polls showed Clinton leading, but [not by much](https://fivethirtyeight.com/features/trump-is-just-a-normal-polling-error-behind-clinton/), and President Trump had [a clear chance of winning](https://fivethirtyeight.com/features/election-update-yes-donald-trump-has-a-path-to-victory/) given his [advantage in crucial battleground states](https://fivethirtyeight.com/features/election-update-why-clintons-position-is-worse-than-obamas/). People who were looking only at our top-line forecast numbers, on the other hand, thought we bungled it. Given the brouhaha after the 2016 election, we knew we had to thoughtfully approach _how_ we delivered the forecast. When readers came looking to see who was favored to win the election, we needed to make sure that information lived in a well-designed structure that helped people understand where those numbers are coming from and what circumstances were affecting them.

## **Building the foundation**

We started by putting some major goals for the design on paper. We aimed to:

-   Construct a clear narrative that helps readers better understand how the election actually works.
-   Focus almost exclusively on the model and put related information into other projects.
-   Help users find our other content, like video, podcasts and stories, to give the model context.
-   Design for desktop and mobile devices so readers can have a great experience no matter how they access the forecast.
-   Use art to let that weird visual quality that FiveThirtyEight is known for shine.

In the [2016](https://projects.fivethirtyeight.com/2016-election-forecast/?ex_cid=2016-forecast) and [2018](https://projects.fivethirtyeight.com/2018-midterm-election-forecast/house/#deluxe), we built straightforward interfaces: a sidebar and a series of modules that weren’t really linked by a narrative flow.

One of our goals this time was to form a narrative, so we figured, why not rethink how the user explores the election? This time around, we considered a number of experimental experiences, including interfaces where readers could shuffle the House, Senate and presidential forecasts like a deck of cards, or ones where users could sort of choose their own adventure.

Sketches of potential user experience flows we considered during the concept phase.

Ultimately, we chose a fairly simple structure for displaying the presidential forecast, leaving behind some of the more complicated user experiences. The final version is modular and [the pieces of the forecast are visualized on cards](https://dreamy-liskov-70ea5e.netlify.app/#/structure). Each card gives the reader a different lens on the election. Some also offer a chance to explore deeper by switching tabs or hovering on elements like dots or lines. This structure also helped us nail our goal of designing for flexibility. Adapting for smaller screen sizes and other platforms (like social media, TV and video) was much easier because each piece of content was designed to stand alone.

A few early versions of what became the final design, with placeholder data and annotations.

## **Designing the floor plan**

Now that we had a sound foundation, we needed great data visualizations to build on it. To iron out what we wanted to show in this year’s forecast, we sifted through all the work we’ve done before. We surveyed past forecasts and documented what every chart aimed to accomplish and how successful we felt it was.

The list of visualizations from 2016 that we used to decide which might be good candidates to carry into the most recent forecast.

This approach helped us prioritize visualizations that effectively communicate what is most valuable to readers. We divvied up the design of the individual graphics across our team of visual journalists. To ensure some consistency in the results, we asked each person to consider [a standard set of questions](https://dreamy-liskov-70ea5e.netlify.app/#/designquestions) about their design.

## **Choosing the most expensive couch**

No visualization in this forecast received more design attention than the top line, which is what we call the chart that shows the overall chances of a candidate or party winning the election.

Whether we show the chances in percentages or odds, this is the portion of an election forecast that is most anticipated — and has the most potential to be misunderstood. In 2016, we aimed for simplicity, both visually and conceptually. In 2018, we leaned into the complexity of the forecast. For 2020, we wanted to land somewhere in between. We also knew we wanted to try to lift the curtain a little on how that top-line chart comes to exist in the first place.

To _really_ oversimplify things: Each candidate’s odds of winning at least 270 electoral votes come from their chances of winning in each state[1](https://fivethirtyeight.com/features/how-we-designed-the-look-of-our-2020-forecast/#fn-1) and D.C. To get from polling averages to probabilities, we simulate the election thousands of times to account for a whole bunch of uncertainties: How accurate will the polls be overall? What if they’re off in only certain states? What if Trump beats his polls, but only in the Midwest? What if Biden overperforms in the states hit hardest by the pandemic? What if the economy improves a ton between now and Election Day? What if it gets worse? What if the coronavirus or vote-by-mail laws affect turnout? I could go on, but let’s stop there.

Those simulations give us a universe of possibilities, and focusing on the scope of that universe is eventually how we chose the design for the top-line chart.

We came up with dozens of concepts, from dead-simple bar charts and conventional visualization types to [universes within universes](https://www.youtube.com/watch?v=OKnpPCQyUec).

A selection of the top-line charts we experimented with to evoke the “universe of possibility” concept we wanted to convey.

In each iteration we tried to add a visual twist to the design. Some were relatively undemanding. Others were … pretty bizarre! We tried to get creative rather than boxing ourselves into things we knew would work. Ultimately, we landed on two elements to lead off the forecast.

First — before we get to any numbers — we give the reader the headline and a sense of the range of possible electoral outcomes in the form of a grid of maps:

There are a number of ways a candidate can win, depending on which states they put in their column. Each of these maps represents one simulated scenario. We want to prime readers to focus on the states as the drivers of the overall odds, and we want to tease the idea of multiple possible outcomes.

Second, we follow the maps with a chart that we affectionately call “the ball swarm,” a reference to a type of chart sometimes called a [bee swarm](https://www.rhoworld.com/i-swarm-you-swarm-we-all-swarm-for-beeswarm-plots-0/):

Similar to the grid of maps, the ball swarm shows readers 100 representative electoral outcomes from our model. The dots huddle on an x-axis showing how many votes a candidate wins the Electoral College by in each scenario. Hover over each of the dots to see how the map shook out in that simulation.

Those maps — some of which you’ve already seen at the top of the forecast — are intended to hammer home how the states power the overall probabilities and show the huge range of potential outcomes that would be consistent with the data currently being input into the model. Forecasting an election is more like predicting the weather than predicting whether a coin will land on heads or tails; it’s complicated, and one of the chief benefits of building a model is to measure the real-world uncertainty about the outcome. We hope the ball swarm’s universe of 2020 outcomes communicates that uncertainty.

Our guess is that you won’t see something like the ball swarm in other publications’ election coverage and we hope that you think it’s as weird and informative as we do. As for the rest of our presidential forecast, let our forecast mascot Fivey Fox guide you through it. There’s more to come from the forecast and no doubt from 2020, so buckle up and [give it a scroll](https://projects.fivethirtyeight.com/2020-election-forecast/)!

Anna Wiederkehr is a senior visual journalist for FiveThirtyEight. [@wiederkehra](https://twitter.com/wiederkehra)

### Comments

Filed under

[Donald Trump (1422 posts)](https://fivethirtyeight.com/tag/donald-trump/) [2020 Election (1079)](https://fivethirtyeight.com/tag/2020-election/) [Joe Biden (453)](https://fivethirtyeight.com/tag/joe-biden/) [Housekeeping (82)](https://fivethirtyeight.com/tag/housekeeping/) [Data Visualization (7)](https://fivethirtyeight.com/tag/data-visualization/) [Forecast (1)](https://fivethirtyeight.com/tag/forecast/)

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
