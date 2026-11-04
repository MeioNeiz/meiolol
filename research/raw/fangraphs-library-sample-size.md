# Sample Size | Sabermetrics Library

<https://library.fangraphs.com/principles/sample-size/>

​

-   Support Us
    
-   Fantasy
    
-   Blogs
    
-   Projections
    
-   Scores
    
-   Standings
    
-   Leaders
    
-   Teams
    
-   RosterResource
    
-   Prospects
    
-   Lab
    
-   Glossary
    

-   [
    
    Sign In
    
    
    
    ](https://blogs.fangraphs.com/wp-login.php?redirect_to=https%3A%2F%2Flibrary.fangraphs.com%2Fprinciples%2Fsample-size%2F)

-   [Intro](https://library.fangraphs.com/getting-started/)
-   [Features](https://library.fangraphs.com/features/)
-   [Offense](https://library.fangraphs.com/offense/)
-   [Defense](https://library.fangraphs.com/defense/)
-   [Pitching](https://library.fangraphs.com/pitching/)
-   [WE/RE/LI](https://library.fangraphs.com/misc/)
-   [Principles](https://library.fangraphs.com/principles/)
-   [WAR](https://library.fangraphs.com/war/)
-   [Business](https://library.fangraphs.com/business/)

# [Sample Size](https://library.fangraphs.com/principles/sample-size/ "Permanent link to Sample Size")

by [Piper Slowinski](https://library.fangraphs.com/author/steve-slow/)

February 18, 2010

A baseball season is the amalgamation of a lot of little events. Each pitch fits into a plate appearance which fits into an inning which fits into a game which fits into a series which fits into a season. That’s a lot of little data points flowing into an overall end result. We care a lot about which players will have good seasons and careers. It matters to us that we can distinguish between good players and bad players, but doing so requires that we understand which chunks of data are meaningful and which aren’t.

Enter _sample size_. You’ve heard this phrase plenty over the  years when talking about baseball statistics and it’s usually a conversation ender rather than a conversation starter. Someone cites a stat and then another person says it doesn’t matter because the sample size is too small. What does that mean and how should we properly think about sample size in baseball?

_If you’re just looking for the numbers, skip ahead by clicking [here](https://library.fangraphs.com/principles/sample-size/#1) ._

**Overview:**

Each little moment in baseball is essentially random. Not random in the sense that all outcomes are equally likely and subject completely to chance, but random in the sense that the most likely outcome doesn’t happen every time. If the best hitter in baseball faced the worst pitcher 100 times, he would very likely strike out a couple of times and hit into a double play or two. He wouldn’t always hit a home run even if it was Coors Field and the pitcher was throwing meatballs. Think about the home run derby. MLB players can’t simply hit home runs on demand even when the pitcher is trying to help.

When dealing with pitches flying 90+ miles per hour and split second movements, a whole bunch of randomness gets thrown into the pot. This means that any one plate appearance might have a funky result, meaning that you need to see lots of events to get a clear picture of what is going on. You know this. One time [Don Kelly](http://www.fangraphs.com/statss.aspx?playerid=2216&position=OF) took [Yu Darvish](http://www.fangraphs.com/statss.aspx?playerid=13074&position=P) deep.

So of course, we know that a single plate appearance isn’t a convincing amount of data. Even the least sabermetrically-minded person agrees with that concept. That single plate appearance is a valid data point, but it’s not enough information to inform your opinion very fully. Instead, you need more and more data points until you have enough for them to “_stabilize_.” Remember that word because the way we’re going to come back to it in a very specific way in a moment.

Essentially, we want to make sure we have enough observations that the random noise gets cancelled out. Don Kelly hit a home run against Yu Darvish one time, but how many Kelly versus Davrish at bats do we need before we can accurately access their abilities? It’s more than one for sure, but the actual number you need depends on the skill you’re trying to analyze. For example, strikeout rate starts to communicate useful information in fewer than 100 PA while BABIP for a pitcher can take three years. The difference is the nature of the skill and the number of factors that influence the outcome of the play. With respect to strikeout rate, we’re only talking about the batter and pitcher’s ability to make or allow contact (or let strikes go by). When you’re talking about BABIP, you’re adding in quality of contact, direction, weather, defensive ability, luck, etc. That means there’s more room for noise and things with less noise in the actual data generating process stabilize more quickly. There are also diminishing returns. Having 20 PA is better than five PA, but having 520 PA is only a little better than having 505 PA.

**Stabilization? Reliability?**

So let’s go back to this idea of _stabilization_. This is the word you hear a lot in conversation about baseball statistics. Conceptually, it’s an ironclad idea. You want to know how many data points it takes for the current information to provide an accurate assessment of the player in question. However, there is no one point at which something stabilizes. Things become stable over time, at a given speed. So after five PA, you know more about a hitter’s walk rate than after one PA, but you don’t know as much as you do after 150 PA or 600 PA. A statistic doesn’t stabilize, _it becomes more stable._

The word “stabilize” got into the baseball lexicon after [some work by Russell Carleton](http://web.archive.org/web/20080102094412/http:/mvn.com/mlb-stats/2007/11/14/525600-minutes-how-do-you-measure-a-player-in-a-year/) (aka Pizza Cutter), who looked to see how many PA you need for a given statistic to reach the point where the correlation between that sample and another sample of the same size is 0.7 (i.e. R^2 of .49). That’s the colloquial definition of stabilize and despite Carleton’s constant warnings, most of us picked up the word “stabilize” and ran with it even if it’s not the most useful term. He has done updated work [here](http://www.baseballprospectus.com/article.php?articleid=20516) and [here](http://www.baseballprospectus.com/article.php?articleid=17659), and has some thoughts about how we talk about stabilization and reliability [here](http://www.baseballprospectus.com/article.php?articleid=31626).

Regardless, the key is that 100 PA is better than 50 PA no matter the statistic, but smaller samples are more useful for some statistics than others. It’s always better to have more data, but the rate at which the data becomes useful varies based on the statistic. A good way to think about this is by visualizing a curve.

This is from [work by Sean Dolinar and Jonah Pemstein](http://www.fangraphs.com/blogs/a-new-way-to-look-at-sample-size/) which takes a methodology similar to Carleton’s but doesn’t focus on the .49 R^2 (technically Cronbach’s Alpha for the technically inclined). Instead, they plot the reliability measure for each 10 PA increment to better show the nature of stabilization. As you can see, K% crosses the .49 threshold much more quickly that the other statistics, which is consistent with our common understanding, but this also shows that the first 200 PA are much more important than the second 200 PA for understanding K%, something you wouldn’t necessarily see in the Carleton studies. Here is a [link](http://www.fangraphs.com/blogs/a-long-needed-update-on-reliability/) to their update work which allows you to visualize many different statistics using this method. The same tool is available below.

**Practical Use:**

For practical purposes, you really want to know the difference between a sample that’s meaningful and one that isn’t. There isn’t a point at which it becomes useful data all of a sudden, but there are quantities that are clearly one or the other. For example, 400 PA is enough to tell you a lot about strikeout rate and 30 PA is not enough to tell you much about HR rate. The real trick is how you update your beliefs between those two extremes.

Every April, at least one previously bad hitter has an awesome month. They have a .380 wOBA over three weeks and lots of people rush to suggest they are a breakout candidate who did something during the offseason to improve. It’s important to note that this may be true or it may not be true. All we know is that they hit .380 wOBA over three weeks, let’s call it 85 PA.

Are those 85 PA enough to lead us to totally change our opinion about this bad hitter to the point where we now think they are fundamentally different in the box? Using our sample size rules of thumb, the answer is no. A bad hitter can easily have a .380 wOBA over 85 PA without actually being a different hitter, just due to random chance. A couple lucky bounces and a well timed cluster of hits and his numbers look great even if he’s no different than he was before.

Those 85 PA give you some idea that he might be improving, but they are not sufficient to change your mind completely. A true .380 wOBA hitter should hit .380 over more stretches than a .310 wOBA hitter, but a .310 wOBA hitter can hit .380 over a month no problem.

The goal of these “stabilization” or “reliability” numbers is to prevent you from reacting to data that is still highly susceptible to random chance. Good hitters can have bad results in small samples even when their process is fine. The larger the sample gets, the more we can discount this random noise component and zero in on factors that are within the player’s control. That’s the point of sample size; preventing us from ascribing too much meaning to small chunks of data.

  
**Rules of Thumb:**

Here is a tool that allows you to explore those reliability graphs mentioned earlier. If it’s not loading on this page for you, here is a [link](http://www.fangraphs.com/blogs/a-long-needed-update-on-reliability/) you can use to find it.

If you’re only looking for Carleton’s .49 cut points, they are listed below.

[_“Stabilization”_ _Points for Offense Statistics:_](http://www.baseballprospectus.com/article.php?articleid=17659)

-   _60 PA:_ Strikeout rate
    
-   _120 PA:_ Walk rate
    
-   _240 PA:_ HBP rate
    
-   _290 PA:_ Single rate
    
-   _1610 PA:_ XBH rate
    
-   _170 PA:_ HR rate
    

-   _910 AB:_ AVG
    
-   _460 PA:_ OBP
    
-   _320 AB:_ SLG
    
-   _160 AB:_ ISO
    

-   _80 BIP:_ GB rate
    
-   _80 BIP:_ FB rate
    
-   _600 BIP:_ LD rate
    
-   _50 FBs:_ HR per FB
    
-   _820 BIP:_ BABIP
    

[__“Stabilization”__ _Points for_ Pitching Statistics:](http://www.baseballprospectus.com/article.php?articleid=20516)

-   _70 BF:_ Strikeout rate
-   _170 BF:_ Walk rate
-   _640 BF:_ HBP rate
-   _670 BF:_ Single rate
-   _1450 BF:_ XBH rate
-   _1320 BF:_ HR rate

-   _630 BF:_ AVG
-   _540 BF:_ OBP
-   _550 AB:_ SLG
-   _630 AB:_ ISO

-   _70 BIP:_ GB rate
-   _70 BIP:_ FB rate
-   _650 BIP:_ LD rate
-   _400 FB:_ HR per FB
-   _2000 BIP:_ BABIP

**Links to Further Reading:**

[525,600 Minutes: How Do You Measure a Player in a Year? – Statistically Speaking / Pizza Cutter](http://web.archive.org/web/20080102094412/http:/mvn.com/mlb-stats/2007/11/14/525600-minutes-how-do-you-measure-a-player-in-a-year/)

[On the Reliability of Pitching Stats – Statistically Speaking / Pizza Cutter](http://web.archive.org/web/20080112135748/mvn.com/mlb-stats/2008/01/06/on-the-reliability-of-pitching-stats/)

[When Samples Become Reliable – FanGraphs](http://www.fangraphs.com/blogs/when-samples-become-reliable/)

[The Beginner’s Guide to Sample Size – FanGraphs](http://www.fangraphs.com/library/the-beginners-guide-to-sample-size/)

[A New Way to Look at Sample Size – FanGraphs](http://www.fangraphs.com/blogs/a-new-way-to-look-at-sample-size/)

[A Long-Needed Update on Reliability – FanGraphs](http://www.fangraphs.com/blogs/a-long-needed-update-on-reliability/)

[Should I Worry About My Favorite Pitcher – Baseball Propsectus](http://www.baseballprospectus.com/article.php?articleid=20516)

[It’s A Small Sample Size After All – Baseball Prospectus](http://www.baseballprospectus.com/article.php?articleid=17659)

[Reliably Stable (You Keep Using That Word) – Baseball Propsectus](http://www.baseballprospectus.com/article.php?articleid=31626)

_\-Neil Weinberg, Updated August 2017_

  
  
  

[What is PITCHF/x?](https://library.fangraphs.com/misc/pitch-fx/)

[Pitch Type Linear Weights](https://library.fangraphs.com/pitching/linear-weights/)

Piper was the editor-in-chief of [DRaysBay](http://www.draysbay.com/) and the keeper of the [FanGraphs Library](http://saberlibrary.com/).

[Login](https://library.fangraphs.com/wp-login.php?redirect_to=https%3A%2F%2Flibrary.fangraphs.com%2Fprinciples%2Fsample-size%2F)

Please login to comment

5 Comments

Oldest

theperfectgame

15 years ago

Steve,  
If GB rate and GB/FB are reliable at 200 PA, doesn’t that imply that FB rate is also reliable at 200 PA? I only ask because you have it listed at 250 PA. Sorry if this was nitpicking. I think the whole library is fantastic. Thanks!

0

theperfectgame

15 years ago

Reply to  [theperfectgame](https://library.fangraphs.com/principles/sample-size/#comment-405)

In the same vein, isn’t BB/PA implicitly reliable at 500 BF? Thanks again.

0

Piper Slowinski

15 years ago

Reply to  [theperfectgame](https://library.fangraphs.com/principles/sample-size/#comment-405)

Good point….I’m just quoting word for word from the research that was done. I can double-check all that, but otherwise I’d go with what is listed. Sometimes individual stats can be reliable in one context, but once you start mixing them together, the results aren’t always the same.

Also, geez, the formatting on this page did not transfer well. Time to fix that.

1

James

15 years ago

This came up in the original thread, here is Pizza Cutter’s answer:

“Those numbers are per PA, not per ball in play. So, for one player who always puts the ball in play LD + GB + FB may account for 95% of his plate appearances. For another guy who strikes out and walks a lot (we’ll call him “Adam Dunn” just to give him a name), LD + GB + FB might only cover 70% of his PA’s.”

0

Jake

14 years ago

I’m confused about split-half methodology and how the results can be interpreted.

When you say that measure X stabilizes at 200 PAs, for example, how is that reflected in your methodology?

If I understand correctly, you took 400 PAs and compared the 200 odd PAs to the 200 even PAs and looked for correlation.

But that doesn’t tell you that an individuals’ **first** 200 PAs correlate to his next 200 PAs, yet it’s being advertised as such. Instead, it means that it takes 200 PAs consisting of every other PA over 400 PAs for measure X to stabilize. That’s not exactly useful information.

Am I wrong in making this criticism?

0

-   [Hey, Where Did All the Runs Go?](https://blogs.fangraphs.com/hey-where-did-all-the-runs-go/)
    
    11/4 – [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)
    
-   [The 2026 Pitching Superlatives, Part 2: Movement](https://blogs.fangraphs.com/the-2026-pitching-superlatives-part-2-movement/)
    
    11/3 – [Davy Andrews](https://www.fangraphs.com/blog-roll?author=198584)[3](https://blogs.fangraphs.com/the-2026-pitching-superlatives-part-2-movement/#comments)
    
-   [Brendan Gawlowski Prospects Chat 11/3/2026](https://blogs.fangraphs.com/brendan-gawlowski-prospects-chat-11-3-2026/)
    
    11/3 – [Brendan Gawlowski](https://www.fangraphs.com/blog-roll?author=173407)
    
-   [Dusty Baker and Bruce Bochy Headline the Strongest Contemporary Era Ballot in Recent Memory](https://blogs.fangraphs.com/dusty-baker-and-bruce-bochy-headline-the-strongest-contemporary-era-ballot-in-recent-memory/)
    
    11/3 – [Jay Jaffe](https://www.fangraphs.com/blog-roll?author=169789)[14](https://blogs.fangraphs.com/dusty-baker-and-bruce-bochy-headline-the-strongest-contemporary-era-ballot-in-recent-memory/#comments)
    
-   [Tai Peete Changed For the Better, Without Really Changing, After Becoming a Cardinal](https://blogs.fangraphs.com/tai-peete-changed-for-the-better-without-really-changing-after-becoming-a-cardinal/)
    
    11/3 – [David Laurila](https://www.fangraphs.com/blog-roll?author=25048)[2](https://blogs.fangraphs.com/tai-peete-changed-for-the-better-without-really-changing-after-becoming-a-cardinal/#comments)
    
-   [Effectively Wild Episode 2552: The Best Things in Life Are Free Agents](https://blogs.fangraphs.com/effectively-wild-episode-2552-the-best-things-in-life-are-free-agents/)
    
    11/3 – [Ben Lindbergh](https://www.fangraphs.com/blog-roll?author=38267)[1](https://blogs.fangraphs.com/effectively-wild-episode-2552-the-best-things-in-life-are-free-agents/#comments)
    
-   [The 2026 Pitching Superlatives, Part 1: Velocity](https://blogs.fangraphs.com/the-2026-pitching-superlatives-part-1-velocity/)
    
    11/2 – [Davy Andrews](https://www.fangraphs.com/blog-roll?author=198584)
    
-   [Ben Clemens Top 50 Free Agents Chat - 11/2/26](https://blogs.fangraphs.com/ben-clemens-top-50-free-agents-chat-11-2-26/)
    
    11/2 – [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)[15](https://blogs.fangraphs.com/ben-clemens-top-50-free-agents-chat-11-2-26/#comments)
    
-   [2027 Top 50 Free Agents](https://blogs.fangraphs.com/2027-top-50-free-agents/)
    
    11/2 – [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)[128](https://blogs.fangraphs.com/2027-top-50-free-agents/#comments)
    
-   [Job Posting: Colorado Rockies - Senior or Lead Analyst (Forecasting)](https://blogs.fangraphs.com/job-posting-colorado-rockies-senior-or-lead-analyst-forecasting/)
    
    11/2 – [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
-   [Job Posting: Colorado Rockies - Affiliated Technology Data Fellow](https://blogs.fangraphs.com/job-posting-colorado-rockies-affiliated-technology-data-fellow/)
    
    11/2 – [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
-   [Sunday Notes: Matthew Wood Caught Jacob Misiorowski in the Minors](https://blogs.fangraphs.com/sunday-notes-matthew-wood-caught-jacob-misiorowski-in-the-minors/)
    
    11/1 – [David Laurila](https://www.fangraphs.com/blog-roll?author=25048)[21](https://blogs.fangraphs.com/sunday-notes-matthew-wood-caught-jacob-misiorowski-in-the-minors/#comments)
    

  

Updated: Monday, November 2, 2026 3:46 AM ET

[@fangraphs](https://twitter.com/fangraphs) - [Contact Us](https://blogs.fangraphs.com/contact/) - [Advertise](https://blogs.fangraphs.com/advertise/) - [Terms of Service](https://www.fangraphs.com/about/terms-of-service) - [Privacy Policy](https://www.fangraphs.com/about/privacy-policy)

All major league baseball data including pitch type, velocity, batted ball location, and play-by-play data provided by Sports Info Solutions.

Major League and Minor League Baseball data provided by Major League Baseball.

Mitchel Lichtman

All UZR (ultimate zone rating) calculations are provided courtesy of Mitchel Lichtman.

[TangoTiger.com](http://www.tangotiger.com/)

All Win Expectancy, Leverage Index, Run Expectancy, and Fans Scouting Report data licenced from TangoTiger.com

[Retrosheet.org](http://www.retrosheet.org/)

Play-by-play data prior to 2002 was obtained free of charge from and is copyrighted by Retrosheet.
