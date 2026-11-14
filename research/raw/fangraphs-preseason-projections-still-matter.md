# Yes, Preseason Projections Still Matter | FanGraphs Baseball

<https://blogs.fangraphs.com/yes-preseason-projections-still-matter/>

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
    
    
    
    ](https://blogs.fangraphs.com/wp-login.php?redirect_to=https%3A%2F%2Fblogs.fangraphs.com%2Fyes-preseason-projections-still-matter%2F)

# [Yes, Preseason Projections Still Matter](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/ "Permanent link to Yes, Preseason Projections Still Matter")

by [Dan Szymborski](https://blogs.fangraphs.com/author/dszymborski/)

September 2, 2026

Pablo Robles-Imagn Images

Baseball fans are often unhappy with projections, and they seem to enjoy sharing that unhappiness with me. That’s hardly surprising, of course — projections have large error bars (which we try to express when discussing them), and on some level, they represent a computer saying mean things about players you might like. You probably aren’t shocked by this, though you might be surprised to learn that the time of year I get the most complaints is during the stretch run rather than the preseason. And while some of the complaints I hear are about projections that missed the mark, the majority are about how little the in-season projections have changed since the start of the year. It can be frustrating when a player who is slugging .500 despite a preseason SLG projection of .350 only has a rest-of-season SLG projection of .400. Clearly, the conventional wisdom says, the projections are too slow to change.

Ben Clemens has written a [number](https://blogs.fangraphs.com/a-fangraphs-playoff-odds-performance-update/) of [pieces](https://blogs.fangraphs.com/how-well-do-our-odds-work/) [auditing](https://blogs.fangraphs.com/a-bayesian-check-in-on-our-playoff-odds-at-the-quarter-season-mark/) our playoff odds, and while they aren’t as meticulously perfected as a [1996 Lexus](https://lexusenthusiast.com/2019/02/22/matt-farahs-lexus-ls-400-reaches-1000000-miles/), they’re pretty darn good. These calculations rely heavily on our in-season projections, which at their gooey, caramel center are an attempt to combine what we knew about a player or team before the season (in the form of preseason projections) with what we’ve learned since.

The relevant question then becomes how much a few months of performance should change what we thought about a player in March. And as it turns out, it’s less than the folks who find projections frustrating might think. When it comes to ZiPS, the preseason projections, both for teams and individual players, are more predictive of rest-of-season performance than season-to-date numbers. That holds true even very late in the season, when there’s been a lot of cumulative in-season performance to look at. I’ve tested preseason projections versus in-season performance as late as September 10 each year, and the preseason projections never clearly do worse than the in-season stats. Since we’re right at the start of September, I thought this would be a good opportunity to look at how the ZiPS preseason projections stack up against March-through-August performance when it comes to projecting what happens in the final month of the season.

And to be clear, I don’t think this preseason edge is exclusive to ZiPS; I expect that Steamer and PECOTA perform similarly well. It’s just that I have a rather unique level of access to ZiPS. But data is more important than a simple claim, so let’s dig in.

Let’s start with the team projections. Teams are where you might expect the season-to-date numbers to perform the absolute best compared to preseason projections. In addition to performance data, team seasonal numbers also include information about roster construction and injuries that a preseason projection can’t possibly have.

ZiPS has run team projections since 2005. If we eliminate 2020 and 2026 from the mix (2020 due to its shortened slate, this season because it’s not yet over), we have 600 projected team winning percentages, ranging from a high of .611/99 wins (the 2021 Dodgers) to .321/52 wins (the 2025 White Sox). I then compared the preseason projected winning percentages to the actual team winning percentages through August 31, and pitted them against each other head-to-head to see which set of numbers did better when it came to actual September results.

In a “what did better” matchup, the preseason ZiPS projections were closer than the season-to-date projections to the actual September results 309 times out of 600, or 51.5% of the time. While ZiPS wins this round, the season-to-date numbers win when you look at the magnitude of misses. The preseason projections had a mean absolute error of 87 points of winning percentage and an RMSE of 110 points of winning percentage, while the season-to-date numbers had a MAE of 85 points and an RMSE of 107 points.

If you look at the following season, however, the ZiPS projections claw back a lead, both against the season-to-date results through the end of August and the full-season results. What this means is that if you were projecting the 2027 season and all you had were the 2026 ZiPS preseason projected standings (with no updated information about the construction of the roster) and the actual 2026 results, the ZiPS projected standings would, if history holds, do a better job. Preseason ZiPS wins 52.8% of the next-year battles, with a slightly lower MAE and RMSE than the full-season data.

Let’s shift over to hitters. From 2004 to 2025, there have been 2,196 players who had at least 100 plate appearances in September and at least 300 plate appearances for the full season, and who also had a preseason ZiPS projection (a few players have fallen through the cracks over the years, especially in ZiPS’ early going). Going by wRC+, the preseason ZiPS projections win the head-to-head battle versus season-to-date numbers (50.4%), if only slightly, and have both a lower MAE (28 points vs. 30 points of wRC+) and RMSE (35 points vs. 38 points). If you modeled September wRC+ based only on preseason ZiPS wRC+ and March-August wRC+, the ideal mix from 2004 to 2025 would be 62% ZiPS/38% season-to-date.

The same basic effect exists for pitchers. I included pitchers with at least 20 innings pitched in September and at least 120 innings for the full season. ZiPS does quite a bit better against season-to-date numbers in ERA+, as a pitcher’s actual numbers have a lot of noise in them. ZiPS wins 55.3% of the head-to-head matchups (1,166 of 2,107), and beats the season-to-date numbers in both MAE (48 points of ERA+ vs. 51 points) and RMSE (85 points vs. 95 points). If you modeled September ERA+ based on just preseason ZiPS ERA+ and March-August ERA+, the ideal mix from 2004 to 2025 would be 69% ZiPS/31% season-to-date.

We’re getting into even smaller sample sizes here, but I also looked at players age 25 and younger and age 35 and older to see if the season-to-date numbers had an additional edge, as recent performance would be expected to be more volatile for players of these ages. They come closer, but the preseason projections still win, with an ideal mix of preseason and season-to-date numbers being 57% preseason/43% season-to-date for the hitters and 60%/40% for the pitchers.

Now, if the conclusion that you draw from all of this is that what happens during the season doesn’t matter, you would be sorely mistaken. When September rolls around, we know quite a bit more about who a player is, whether he’s is healthy, and which teams are good than we did back in March. All in-season projection systems incorporate this information, and the projections definitely move. They just don’t move as much as our brains want them to.

Recency bias tends to have a powerful effect on us because the recent stuff is the stuff we just watched. Seeing [Otto Lopez](https://www.fangraphs.com/players/otto-lopez/19608/stats/batting) hit .305/.340/.442 over most of a season feels like overwhelming evidence of how good he is in a way that a projection generated in March simply doesn’t. [Jordan Walker](https://www.fangraphs.com/players/jordan-walker/27475/stats/batting) is having a wonderful 2026, the sort of season I had given up on as a reasonable possibility for him. Given that, Cardinals fans may be disappointed that despite his breakout and his relative youth, the array of public projection systems mostly peg him in the 105-110 wRC+ range going forward. Still, as tempting as it might be, just saying “OK, Walker is a borderline star from now on” goes beyond properly evaluating the near-present and chucks out everything that tells a different story.

The same goes for teams. The Mets, Orioles, Blue Jays, and Tigers have all underperformed relative to our preseason expectations, and all moved key players at the trade deadline. Since August 3, those teams have combined to go 55-47 (through Monday’s games), good for an 87-75 seasonal pace. Perhaps the original story — that these clubs were pretty talented — was actually the right one, and they simply played poorly for four months. After all, those preseason projections represent years of information about players, their development, and their ups-and-downs, and that doesn’t just evaporate into meaninglessness. The actual season determines who wins each game, who plays in October, and which team gets to pop champagne at the end, and each one gives us an enormous trove of new information about players. But that new information doesn’t magically transform several hundred plate appearances or 100 innings into a comprehensive description of a player’s ability. With that in mind, you may want to think twice before treating the “Season to Date” projection mode on our [playoff odds page](https://www.fangraphs.com/standings/playoff-odds/fg/div) as more than an interesting amusement.

Baseball seasons are important because they’ve actually happened, while projections are useful because the next game hasn’t. When looking at what’s to come in the next game, week, month, or season, the past is more than mere prologue.

  
  
  
  

[Ben Clemens FanGraphs Chat – 9/1/26](https://blogs.fangraphs.com/ben-clemens-fangraphs-chat-9-1-26/)

[Introducing FanGraphs MVP](https://blogs.fangraphs.com/introducing-fangraphs-mvp/)

Dan Szymborski is a senior writer for FanGraphs and the developer of the ZiPS projection system. He was a writer for ESPN.com from 2010-2018, a regular guest on a number of radio shows and podcasts, and a voting BBWAA member. He also maintains a terrible Twitter account at @DSzymborski.

29 Comments

Oldest

Cave Dameron

2 months ago

Yes, Dan is still very cool. Thank you!

14

trixmcgeeMember since 2026

2 months ago

Dan – as someone new to Fangraphs, and relatively unaccustomed to projections / statistics, I find these types of posts fascinating and enlightening .. never want them to end haha.  
Keep them coming in time — they are the best! Thank you.

16

MikeSMember since 2020

2 months ago

People are very subject to recency bias and don’t appreciate (or understand) regression to the mean enough.

13

Jason BMember since 2017

2 months ago

Reply to  [MikeS](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532449)

It crosses season-ending boundaries, too; last year the Jays’ bats got hot in the postseason and it almost carried them to a World Series title. Ownership mistakenly thought “hey this is who we are now” and didn’t do much of anything to address their hitting in the offseason. Totally forgetting that the prior season, they couldn’t hit their way out of a wet paper bag.

Guess what happened this season? They’re back to being the team that can’t hit their way out of a wet paper bag. Last in wOBA, 28th in wRC+, 29th in runs scored.

(Vlad Guerrero now hitting like a prime-age Doug Mientkiewicz isn’t helping matters any, of course)

14

Fun-Hating DorkMember since 2019

2 months ago

Reply to  [Jason B](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532462)

I think it’d be easier to hit yourself out of a dry paper bag if it was large enough to fit you inside of it. A wet paper bag would just stick to everything.

8

KeithMember since 2024

2 months ago

Reply to  [Jason B](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532462)

Don’t you be knocking down Doug. Us Red Sox fans have fond memories of 2004. Even if he was rubbish with the wood, he could still pick it at 1B.

1

Jason BMember since 2017

2 months ago

Reply to  [Keith](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532632)

Sorry, I just had to go find the worst-hitting 1B of the 2000-10s with at least 1000 AB’s. He had a fine glove, but he was the winner of that particular query!

2

david k

2 months ago

Reply to  [MikeS](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532449)

And I think anyone who has played fantasy baseball and is any good at it knows both of these pretty well. It DOESN’T mean that a .300 hitter that’s batting .200 in April is going to hit .320 for the rest of the year (or whatever that would be to turn out to be .300 over the entire year – don’t feel like doing the math), but it does mean he’s more likely to hit closer to his .300 career average the rest of the way, so if someone is panicking and is willing to sell low (or outright waive the player, then unless there’s some significant nagging injury causing the low average, go get him!

3

warpath

2 months ago

What I’m struck by when reading this is that baseball is really a team game, where it’s difficult for any one player to have an outsized impact.

Projections systems can be off by a fair amount for individual players, this happens all the time. Guys improve more than expected, guys decline more than expected, guys get injured, guys get hot or cold for a long stretch and have career high or career low years. But for a projection system to be drastically wrong about a whole team, it probably involves a fair amount of players either under or overperforming their median projections all at once.

Now, that does happen, and the Mets this year are a prime example of that. They’ve had injuries (Lindor, Soto, Robert Jr., Polanco) and underperformance (Bichette, Senga, Semien, Vientos, Baty, also Robert Jr., also Polanco) galore.

But things looked extremely dire earlier in the season when Benge and Ewing struggled to start off, and guys like Baty and Vientos had absolutely dismal starts. A lot of things have gone wrong for the Mets, and early on, basically everything was going wrong at once to the max.

That was unlikely to continue, that basically every guy would play way worse than predicted, and a lot of those guys have played a lot better in recent months. So their end-of-season record will probably be closer to the initial projects than we may have thought back in May.

Last edited 2 months ago by warpath

10

David Klein

2 months ago

Reply to  [warpath](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532454)

Is Baty and Vientos underperformance or pretty close to who they really are? Ewing had a pretty good first few months but hasn’t hit a lick the last few months. Semien looks cooked and Polanco’s body might be. That said, I agree with the rest of your comment. The Mets were underperforming their base runs record by a good bit last I checked.

2

warpath

2 months ago

Reply to  [David Klein](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532463)

Baty and Vientos have definitely underperformed projections this year, I think ZiPS had each down for about 2 WAR preseason. Baty sits at 0.1, Vientos sits at -1.1. Now this might be who they really are, but if so, the projections were wrong about them.

I brought up Baty, Vientos, Ewing, and Benge moreso because they all started very slow, but then hit better after a month or two, if only relatively better. Although I don’t think I realized how badly Ewing has cratered recently, my goodness, those August numbers are ghastly.

I remember back in April, basically every Met seemed to play as apocalyptically bad as possible (or got hurt). Even if they haven’t been “good” since, they’ve been better, and inched towards the projection. I wrote this in an comment on an article on the Mets published on May 1st:

“But between injuries and underperformance, this is a team with a single hitter with a wRC+ of 100 or better (Francisco Alvarez at 104) in over 70 PAs (which is even well below the cutoff for being qualified). Just about every position player to receive significant playing time except for Soto and Alvarez have dug a deep hole well below projections/expectations, not just a little below.”

For reference: [https://www.fangraphs.com/leaders/major-league?pos=all&stats=bat&lg=all&type=8&season=2026&month=1000&season1=2026&ind=0&team=25&qual=1&startdate=2026-03-01&enddate=2026-04-30](https://www.fangraphs.com/leaders/major-league?pos=all&stats=bat&lg=all&type=8&season=2026&month=1000&season1=2026&ind=0&team=25&qual=1&startdate=2026-03-01&enddate=2026-04-30)

2

Mike Green

2 months ago

I’m curious about the pre-season and current ZiPS projection for Sean Keys. Pre-season, the projection was .188/.285/.334. The current projection is .187/.281/.331. After Keys’ great season at double and triple A this year, a decline in his projected performance does not make sense to me. Perhaps ZiPS places great weight on his struggles in 37 MLB PAs this year, but that would surprise me. Any thoughts?

5

Dan SzymborskiFanGraphs Staff

2 months ago

Reply to  [Mike Green](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532455)

This is one of those instances where it normally wouldn’t show an ROS for ZiPS since he was in the minors so long (and we don’t have the site set up to do minor league translations, which is something I’m definitely hoping to address during the lockout). He’d actually be 214/309/403 now.

10

Mike Green

2 months ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532468)

Thanks, Dan. Good to know!

1

asb123Member since 2020

2 months ago

Reply to  [Mike Green](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532455)

\~~~

Last edited 2 months ago by asb123

0

Ivan\_GrushenkoMember since 2016

2 months ago

Silly humans

4

jdbolickMember since 2016

2 months ago

I made a similar comment recently about prospects. It’s common for unexpectedly strong performances to result in an improved ranking, Future Value, and tools grades during a season. We have to be careful to assess how much of the deviation from expected performance represents a genuine breakout or collapse. I need to do some statistical analysis of midseason rankings versus preseason ones, as I would expect preseason ones to be substantially more accurate over the long-term.

3

A Salty ScientistMember since 2024

2 months ago

Reply to  [jdbolick](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532464)

Yes, and why scouting is still important. So much SSS and recency bias in prospect performance evaluations. I would also bet that your hypothesis on the relative accuracy of midseason vs preseason rankings is correct. In part because mid-season rankings are more rushed and less deliberate. That said, if you’re overly conservative, you’ll miss true breakouts. It’s a tough balancing act.

8

fanofthemanMember since 2020

2 months ago

Reply to  [A Salty Scientist](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532470)

This reminds me of a story Brendan told somewhere, where an older scout told him “If you just slap an “org filled” grade on every prospect, you’ll be the most accurate and least helpful scout”. You have to be wrong sometimes and find the guys with a path forward, even if they never get there.

2

jdbolickMember since 2016

2 months ago

Reply to  [fanoftheman](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532619)

That’s a completely different situation. Taking strong stances on a player after extensive review is great even if they end up being wrong. The issue I’m talking about is overreacting to small samples during a season.

0

Runaway ToasterMember since 2016 MVP

2 months ago

Reply to  [jdbolick](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532464)

How dare you?! Jesus Montero and Brett Lawrie will be the best hitters in the league for years to come! Forget anything we’ve seen up to this point, these guys rake!

– Me in the fall of 2011

12

Marc KartmanMember since 2021

2 months ago

My guess is if you eliminate the Brewers data ZIPs preseason projections do even better! (Dan actually did a great job this year trying to come up with a rational way to evaluate the Brewers’ tendency to over perform their ZIPs projections).

8

bluestragglerMember since 2016

2 months ago

People are gonna get mad about the variance of individual human performance predictions no matter how spectacular those projections are in aggregate.

1

LouisMember since 2024

2 months ago

Interesting. I think a useful analysis would be to throw out those situations in which the pre-season projection was relatively similar to the through-August performance, and just measure whether “surprising” \[statistically significant different\] performace was more or less predictive of September performance. There may not be a sufficient sample size. But it’s not surprising to me that the entire mass of data shows very little difference in September performance between prediction and performance when so much of the data includes instances where the pre-September performance closely matches the prediction. To put it in individual terms, it’s not all that useful to project whether Yandy Diaz’ September will look more like his projection or his performance, when so far the two have been close to the same. It would, however, be more interesting to know whether Raleigh or Vladi’s September will look like the projection or the prior performance.

4

dodgersfansteveMember since 2024

2 months ago

Interesting choice of pictures. Lindor and Bichette have been mostly horrid this season and won’t come near their individual projections.

1

Roger McDowell Hot Foot

2 months ago

Reply to  [dodgersfansteve](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532509)

I was going to make a joke about how Jared Young, on the other hand, has been a pleasant surprise… but it turns out he _also_ dramatically underperformed his preseason ZIPS on a rate basis.

1

David Klein

2 months ago

Reply to  [dodgersfansteve](https://blogs.fangraphs.com/yes-preseason-projections-still-matter/#comment-5532509)

Lindor hasn’t performed to his usual standards but I would not say he’s been horrid. He’s missed a big chunk of the season due to the calf injury yet has put up nearly two war in like half a season again not to his standards but not horrid.

Last edited 2 months ago by David Klein

0

TrigauxMember since 2016

2 months ago

Is there survivor bias in these calculations? For example, if a pitcher dramatically underperformed, they won’t meet those IP thresholds and will be an outline on performance, but won’t show up in the data.

2

HubKidMember since 2020

2 months ago

At the end, all of the meaning of the article is somehow contained in one beautiful sentence,

“Baseball seasons are important because they’ve actually happened, while projections are useful because the next game hasn’t”.

I know we need Dan’s analysis (because it’s great), but it’s a good thing he didn’t lead with that because that’s pretty much the last word. Done, dusted, i don’t need to think about the merits etc. of projections ever again.

0

-   [Eric Longenhagen Prospects Chat: 11/13/26](https://blogs.fangraphs.com/eric-longenhagen-prospects-chat-11-13-26/)
    
    11/13 – [Eric Longenhagen](https://www.fangraphs.com/blog-roll?author=81295)[3](https://blogs.fangraphs.com/eric-longenhagen-prospects-chat-11-13-26/#comments)
    
-   [Evan Phillips and Atlanta Get Free Agency Moving With Multi-Year Pact](https://blogs.fangraphs.com/evan-phillips-and-atlanta-get-free-agency-moving-with-multi-year-pact/)
    
    11/13 – [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)[3](https://blogs.fangraphs.com/evan-phillips-and-atlanta-get-free-agency-moving-with-multi-year-pact/#comments)
    
-   [Where Do the Yankees Go From Here?](https://blogs.fangraphs.com/where-do-the-yankees-go-from-here/)
    
    11/13 – [Matthew Roberson](https://www.fangraphs.com/blog-roll?author=212969)[54](https://blogs.fangraphs.com/where-do-the-yankees-go-from-here/#comments)
    
-   [2027 ZiPS Projections: Pittsburgh Pirates](https://blogs.fangraphs.com/2027-zips-projections-pittsburgh-pirates/)
    
    11/13 – [Dan Szymborski](https://www.fangraphs.com/blog-roll?author=30942)[33](https://blogs.fangraphs.com/2027-zips-projections-pittsburgh-pirates/#comments)
    
-   [Job Posting: Cincinnati Reds - Baseball Operations Trainee](https://blogs.fangraphs.com/job-posting-cincinnati-reds-baseball-operations-trainee/)
    
    11/13 – [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
-   [Job Posting: Cleveland Guardians - 2027 Minor League Hitting Coach](https://blogs.fangraphs.com/job-posting-cleveland-guardians-2027-minor-league-hitting-coach/)
    
    11/13 – [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
-   [RosterResource Chat: November 12, 2026](https://blogs.fangraphs.com/rosterresource-chat-november-12-2026/)
    
    11/12 – [Jon Becker](https://www.fangraphs.com/blog-roll?author=82328)[3](https://blogs.fangraphs.com/rosterresource-chat-november-12-2026/#comments)
    
-   [Dan Szymborski FanGraphs Chat - 11/12/26](https://blogs.fangraphs.com/dan-szymborski-fangraphs-chat-11-12-26/)
    
    11/12 – [Dan Szymborski](https://www.fangraphs.com/blog-roll?author=30942)[12](https://blogs.fangraphs.com/dan-szymborski-fangraphs-chat-11-12-26/#comments)
    
-   [Back Healthy, Blue Jays Prospect Jake Bloss Is Looking To Regain His Top-100 Form](https://blogs.fangraphs.com/back-healthy-blue-jays-prospect-jake-bloss-is-looking-to-regain-his-top-100-form/)
    
    11/12 – [David Laurila](https://www.fangraphs.com/blog-roll?author=25048)
    
-   [Welcome to We Tried Season](https://blogs.fangraphs.com/welcome-to-we-tried-season/)
    
    11/12 – [Davy Andrews](https://www.fangraphs.com/blog-roll?author=198584)[20](https://blogs.fangraphs.com/welcome-to-we-tried-season/#comments)
    
-   [2027 Contemporary Baseball Era Committee Candidate: Dusty Baker](https://blogs.fangraphs.com/2027-contemporary-baseball-era-committee-candidate-dusty-baker/)
    
    11/12 – [Jay Jaffe](https://www.fangraphs.com/blog-roll?author=169789)[26](https://blogs.fangraphs.com/2027-contemporary-baseball-era-committee-candidate-dusty-baker/#comments)
    
-   [Effectively Wild Episode 2556: Benge, Don't Break](https://blogs.fangraphs.com/effectively-wild-episode-2556-benge-dont-break/)
    
    11/11 – [Ben Lindbergh](https://www.fangraphs.com/blog-roll?author=38267)[1](https://blogs.fangraphs.com/effectively-wild-episode-2556-benge-dont-break/#comments)
    

-   [Alan Nathan](https://www.fangraphs.com/blog-roll?author=19001)
    
    Post Count: 5
    
-   [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)
    
    Post Count: 1652
    
-   [Ben Lindbergh](https://www.fangraphs.com/blog-roll?author=38267)
    
    Post Count: 2532
    
-   [Brendan Gawlowski](https://www.fangraphs.com/blog-roll?author=173407)
    
    Post Count: 165
    
-   [Brendan Gawlowski and Eric Longenhagen](https://www.fangraphs.com/blog-roll?author=224541)
    
    Post Count: 5
    
-   [Dan Szymborski](https://www.fangraphs.com/blog-roll?author=30942)
    
    Post Count: 1300
    
-   [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
    Post Count: 1000
    
-   [David Laurila](https://www.fangraphs.com/blog-roll?author=25048)
    
    Post Count: 2274
    
-   [Davy Andrews](https://www.fangraphs.com/blog-roll?author=198584)
    
    Post Count: 502
    
-   [Eric Longenhagen](https://www.fangraphs.com/blog-roll?author=81295)
    
    Post Count: 1054
    
-   [Eric Longenhagen and Brendan Gawlowski](https://www.fangraphs.com/blog-roll?author=286038)
    
    Post Count: 12
    
-   [Eric Longenhagen and James Fegan](https://www.fangraphs.com/blog-roll?author=270663)
    
    Post Count: 12
    
-   [Esteban Rivera](https://www.fangraphs.com/blog-roll?author=167339)
    
    Post Count: 122
    
-   [FanGraphs Staff](https://www.fangraphs.com/blog-roll?author=180253)
    
    Post Count: 33
    
-   [Jake Mailhot](https://www.fangraphs.com/blog-roll?author=10708)
    
    Post Count: 382
    
-   [James Fegan](https://www.fangraphs.com/blog-roll?author=31563)
    
    Post Count: 7
    
-   [Jason Martinez](https://www.fangraphs.com/blog-roll?author=151408)
    
    Post Count: 159
    
-   [Jay Jaffe](https://www.fangraphs.com/blog-roll?author=169789)
    
    Post Count: 1956
    
-   [Jon Becker](https://www.fangraphs.com/blog-roll?author=82328)
    
    Post Count: 119
    
-   [Jordan Rosenblum](https://www.fangraphs.com/blog-roll?author=11712)
    
    Post Count: 6
    
-   [Kiri Oler](https://www.fangraphs.com/blog-roll?author=166180)
    
    Post Count: 92
    
-   [Leo Morgenstern](https://www.fangraphs.com/blog-roll?author=209902)
    
    Post Count: 146
    
-   [Matt Martell](https://www.fangraphs.com/blog-roll?author=153421)
    
    Post Count: 96
    
-   [Matthew Roberson](https://www.fangraphs.com/blog-roll?author=212969)
    
    Post Count: 25
    
-   [Meg Rowley](https://www.fangraphs.com/blog-roll?author=95174)
    
    Post Count: 727
    
-   [Michael Baumann](https://www.fangraphs.com/blog-roll?author=198829)
    
    Post Count: 739
    
-   [Michael Rosen](https://www.fangraphs.com/blog-roll?author=34149)
    
    Post Count: 72
    
-   [Paul Sporer](https://www.fangraphs.com/blog-roll?author=11752)
    
    Post Count: 14
    
-   [Ryan Blake](https://www.fangraphs.com/blog-roll?author=200227)
    
    Post Count: 41
    
-   [Sean Dolinar](https://www.fangraphs.com/blog-roll?author=76277)
    
    Post Count: 144
    

-   [2026 BBWAA Ballot](https://www.fangraphs.com/blog-roll?category=2026%20BBWAA%20Ballot)
-   [2026 MLB Draft](https://www.fangraphs.com/blog-roll?category=2026%20MLB%20Draft)
-   [2026 Pitching Superlatives](https://www.fangraphs.com/blog-roll?category=2026%20Pitching%20Superlatives)
-   [2026 Positional Power Rankings](https://www.fangraphs.com/blog-roll?category=2026%20Positional%20Power%20Rankings)
-   [2026 Postseason](https://www.fangraphs.com/blog-roll?category=2026%20Postseason)
-   [2026 Replacement-Level Killers](https://www.fangraphs.com/blog-roll?category=2026%20Replacement-Level%20Killers)
-   [2026 Trade Deadline](https://www.fangraphs.com/blog-roll?category=2026%20Trade%20Deadline)
-   [2026 Trade Deadline Prospects Guide](https://www.fangraphs.com/blog-roll?category=2026%20Trade%20Deadline%20Prospects%20Guide)
-   [2026 Trade Value](https://www.fangraphs.com/blog-roll?category=2026%20Trade%20Value)
-   [2026 WBC](https://www.fangraphs.com/blog-roll?category=2026%20WBC)
-   [2026 ZiPS Projections](https://www.fangraphs.com/blog-roll?category=2026%20ZiPS%20Projections)
-   [2027 Contemporary Baseball Ballot](https://www.fangraphs.com/blog-roll?category=2027%20Contemporary%20Baseball%20Ballot)
-   [Arizona Fall League](https://www.fangraphs.com/blog-roll?category=Arizona%20Fall%20League)
-   [Challenging Career Quiz](https://www.fangraphs.com/blog-roll?category=Challenging%20Career%20Quiz)
-   [Chat](https://www.fangraphs.com/blog-roll?category=Chat)
-   [College](https://www.fangraphs.com/blog-roll?category=College)
-   [Contract Crowdsourcing 2026-27](https://www.fangraphs.com/blog-roll?category=Contract%20Crowdsourcing%202026-27)
-   [Economics](https://www.fangraphs.com/blog-roll?category=Economics)
-   [Effectively Wild](https://www.fangraphs.com/blog-roll?category=Effectively%20Wild)
-   [Effectively Wild 2026 Season Preview](https://www.fangraphs.com/blog-roll?category=Effectively%20Wild%202026%20Season%20Preview)
-   [Extension](https://www.fangraphs.com/blog-roll?category=Extension)
-   [FanGraphs Feature Focus](https://www.fangraphs.com/blog-roll?category=FanGraphs%20Feature%20Focus)
-   [FanGraphs Lab](https://www.fangraphs.com/blog-roll?category=FanGraphs%20Lab)
-   [Featured](https://www.fangraphs.com/blog-roll?category=Featured)
-   [Featured Prospects](https://www.fangraphs.com/blog-roll?category=Featured%20Prospects)
-   [Five Things](https://www.fangraphs.com/blog-roll?category=Five%20Things)
-   [Free Agent Signing](https://www.fangraphs.com/blog-roll?category=Free%20Agent%20Signing)
-   [Free To Read](https://www.fangraphs.com/blog-roll?category=Free%20To%20Read)
-   [Game Thread](https://www.fangraphs.com/blog-roll?category=Game%20Thread)
-   [Hall of Fame](https://www.fangraphs.com/blog-roll?category=Hall%20of%20Fame)
-   [JAWS](https://www.fangraphs.com/blog-roll?category=JAWS)
-   [Job Postings](https://www.fangraphs.com/blog-roll?category=Job%20Postings)
-   [Mailbag](https://www.fangraphs.com/blog-roll?category=Mailbag)
-   [Mathemadage](https://www.fangraphs.com/blog-roll?category=Mathemadage)
-   [Matrix Reloaded](https://www.fangraphs.com/blog-roll?category=Matrix%20Reloaded)
-   [Minor Leagues](https://www.fangraphs.com/blog-roll?category=Minor%20Leagues)
-   [MLB Draft 2026](https://www.fangraphs.com/blog-roll?category=MLB%20Draft%202026)
-   [Power Rankings](https://www.fangraphs.com/blog-roll?category=Power%20Rankings)
-   [Projections](https://www.fangraphs.com/blog-roll?category=Projections)
-   [Prospect List](https://www.fangraphs.com/blog-roll?category=Prospect%20List)
-   [Prospect Week 2026](https://www.fangraphs.com/blog-roll?category=Prospect%20Week%202026)
-   [Prospects](https://www.fangraphs.com/blog-roll?category=Prospects)
-   [Prospects Report 2026](https://www.fangraphs.com/blog-roll?category=Prospects%20Report%202026)
-   [Q&As](https://www.fangraphs.com/blog-roll?category=Q&amp;As)
-   [Research](https://www.fangraphs.com/blog-roll?category=Research)
-   [Site News](https://www.fangraphs.com/blog-roll?category=Site%20News)
-   [Talks Hitting](https://www.fangraphs.com/blog-roll?category=Talks%20Hitting)
-   [Angels](https://www.fangraphs.com/blog-roll?category=Angels)
-   [Astros](https://www.fangraphs.com/blog-roll?category=Astros)
-   [Athletics](https://www.fangraphs.com/blog-roll?category=Athletics)
-   [Blue Jays](https://www.fangraphs.com/blog-roll?category=Blue%20Jays)
-   [Braves](https://www.fangraphs.com/blog-roll?category=Braves)
-   [Brewers](https://www.fangraphs.com/blog-roll?category=Brewers)
-   [Cardinals](https://www.fangraphs.com/blog-roll?category=Cardinals)
-   [Cubs](https://www.fangraphs.com/blog-roll?category=Cubs)
-   [Diamondbacks](https://www.fangraphs.com/blog-roll?category=Diamondbacks)
-   [Dodgers](https://www.fangraphs.com/blog-roll?category=Dodgers)
-   [Giants](https://www.fangraphs.com/blog-roll?category=Giants)
-   [Guardians](https://www.fangraphs.com/blog-roll?category=Guardians)
-   [Mariners](https://www.fangraphs.com/blog-roll?category=Mariners)
-   [Marlins](https://www.fangraphs.com/blog-roll?category=Marlins)
-   [Mets](https://www.fangraphs.com/blog-roll?category=Mets)
-   [Nationals](https://www.fangraphs.com/blog-roll?category=Nationals)
-   [Orioles](https://www.fangraphs.com/blog-roll?category=Orioles)
-   [Padres](https://www.fangraphs.com/blog-roll?category=Padres)
-   [Phillies](https://www.fangraphs.com/blog-roll?category=Phillies)
-   [Pirates](https://www.fangraphs.com/blog-roll?category=Pirates)
-   [Rangers](https://www.fangraphs.com/blog-roll?category=Rangers)
-   [Rays](https://www.fangraphs.com/blog-roll?category=Rays)
-   [Red Sox](https://www.fangraphs.com/blog-roll?category=Red%20Sox)
-   [Reds](https://www.fangraphs.com/blog-roll?category=Reds)
-   [Rockies](https://www.fangraphs.com/blog-roll?category=Rockies)
-   [Royals](https://www.fangraphs.com/blog-roll?category=Royals)
-   [Tigers](https://www.fangraphs.com/blog-roll?category=Tigers)
-   [Twins](https://www.fangraphs.com/blog-roll?category=Twins)
-   [White Sox](https://www.fangraphs.com/blog-roll?category=White%20Sox)
-   [Yankees](https://www.fangraphs.com/blog-roll?category=Yankees)
-   [The Early Shift](https://www.fangraphs.com/blog-roll?category=The%20Early%20Shift)
-   [Trade](https://www.fangraphs.com/blog-roll?category=Trade)
-   [We Tried](https://www.fangraphs.com/blog-roll?category=We%20Tried)
-   [Women’s Baseball](https://www.fangraphs.com/blog-roll?category=Women%E2%80%99s%20Baseball)
-   [World Baseball Classic](https://www.fangraphs.com/blog-roll?category=World%20Baseball%20Classic)
-   [WPBL](https://www.fangraphs.com/blog-roll?category=WPBL)

  

Updated: Friday, November 13, 2026 5:38 AM ET

[@fangraphs.com](https://bsky.app/profile/fangraphs.com) - [Contact Us](https://blogs.fangraphs.com/contact/) - [Advertise](https://blogs.fangraphs.com/advertise/)\- [Terms of Service](https://www.fangraphs.com/about/terms-of-service) - [Privacy Policy](https://www.fangraphs.com/about/privacy-policy)

All major league baseball data including pitch type, velocity, batted ball location, and play-by-play data provided by Sports Info Solutions.

Major League and Minor League Baseball data provided by Major League Baseball.

Mitchel Lichtman

All UZR (ultimate zone rating) calculations are provided courtesy of Mitchel Lichtman.

[TangoTiger.com](http://www.tangotiger.com/)

All Win Expectancy, Leverage Index, Run Expectancy, and Fans Scouting Report data licenced from TangoTiger.com

[Retrosheet.org](https://www.retrosheet.org/)

Play-by-play data prior to 2002 was obtained free of charge from and is copyrighted by Retrosheet.
