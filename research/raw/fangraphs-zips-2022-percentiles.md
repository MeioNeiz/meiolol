# The 2022 ZiPS Projections Are Coming! | FanGraphs Baseball

<https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/>

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
    
    
    
    ](https://blogs.fangraphs.com/wp-login.php?redirect_to=https%3A%2F%2Fblogs.fangraphs.com%2Fthe-2022-zips-projections-are-coming%2F)

FanGraphs is now being presented ad free for international visitors!  
  
International users make up about 15% of FanGraphs’ traffic, and with the addition of advanced statistics for NPB and the KBO, that number continues to grow. Unfortunately, international advertising rates are just a fraction of those in the United States. In total, international advertising accounts for about 3% of our total advertising revenue.  
  
If you’re a frequent FanGraphs user, we ask that you consider becoming a **[FanGraphs Member](https://plus.fangraphs.com/product/fangraphs-membership/?ifgc=international_adfree)**. While you are already receiving one benefit of Membership as an international user, being a Member comes with **[so much more](https://blogs.fangraphs.com/instagraphs/introducing-new-steamer-split-projections-and-more/)** than an ad-free experience. Plus, your support helps us continue to improve the site and expand our international coverage of the game of baseball.

# [The 2022 ZiPS Projections Are Coming!](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/ "Permanent link to The 2022 ZiPS Projections Are Coming!")

by [Dan Szymborski](https://blogs.fangraphs.com/author/dszymborski/)

November 18, 2021

The first ZiPS team projections will hit the site this coming Monday, and as I typically do, I’m going to use this space to talk a little bit about my philosophy behind ZiPS, my goals, and the new things I’ve worked on before they go live.

ZiPS is a computer projection system I initially developed in 2002–04 and which officially went live for the ’04 season. The origin of ZiPS is similar to Tom Tango’s Marcel the Monkey, coming from discussions I had with Chris Dial, one of my best friends (my first interaction with Chris involved me being called an expletive!) and a fellow stat nerd, in the late 1990s. ZiPS moved quickly from its original inception as a reasonably simple projection system, and now does a lot more and uses a lot more data than I ever envisioned 20 years ago. At its core, however, it’s still doing two primary tasks: estimating what the baseline expectation for a player is at the moment I hit the button, and then estimating where that player may be going using large cohorts of relatively similar players.

ZiPS uses multi-year statistics, with more recent seasons weighted more heavily; in the beginning, all the statistics received the same yearly weighting, but eventually, this became more varied based on additional research. And research is a big part of ZiPS. Every year, I run hundreds of studies on various aspects of the system to determine their predictive value and better calibrate the player baselines. What started with the data available in 2002 has expanded considerably: Basic hit, velocity, and pitch data began playing a larger role starting in ’13, while data derived from StatCast has been included in recent years as I’ve gotten a handle on the predictive value and impact of those numbers on existing models. I believe in cautious, conservative design, so data is only included once I have confidence in improved accuracy; there are always builds of ZiPS that are still a couple of years away. Additional internal ZiPS tools like zBABIP, zHR, zBB, and zSO are used to better establish baseline expectations for players. These stats work similarly to the various flavors of “x” stats, with the z standing for something I’d wager you’ve already figured out.

One change since last year is greater incorporation of these zStats for minor league hitters and pitchers. These have been in future versions of ZiPS for a few years now, and my hope, as of December 2019, had been to implement them for the 2021 projections. I wanted one more season of data that had no part of the original dataset from which these numbers were derived, but as we all know, there was no minor league season in 2020.

Now, we don’t have the full catalog of data to work with, but we do have _some_ data for minor leaguers that helps makes these stats possible. One of those things is the probabilistic estimates of defense that I’ve been using for minor league defense for a few years. This has helped ZiPS better identify solid defense for inexperienced players like [Luis Robert](https://www.fangraphs.com/players/luis-robert/20043/stats) and [Mike Yastrzemski](https://www.fangraphs.com/players/mike-yastrzemski/14854/stats) before they reach the majors:

I could do better with more robust data than is available, but just knowing _where_ a ball is hit is helpful. For example, a grounder hit directly over second base has been a single 49% of the time in the minors, while one that hugs the foul lines is a double 52% of the time at third and 66% of the time on the first base side. I’ve now been able to integrate this data not just with defensive projections, but in creating more accurate zBABIP estimates for pitchers and hitters.

You Aren't a FanGraphs Member

It looks like you aren't yet a FanGraphs Member (or aren't logged in). We aren't mad, just disappointed. We get it. You want to read this article. But before we let you get back to it, we'd like to point out a few of the good reasons why you should become a Member. 1. Ad Free viewing! We won't bug you with this ad, or any other. 2. Unlimited articles! Non-Members only get to read 10 free articles a month. Members never get cut off. 3. Dark mode and Classic mode! 4. Custom player page dashboards! Choose the player cards you want, in the order you want them. 5. One-click data exports! Export our projections and leaderboards for your personal projects. 6. Remove the photos on the home page! (Honestly, this doesn't sound so great to us, but some people wanted it, and we like to give our Members what they want.) 7. Even more Steamer projections! We have handedness, percentile, and context neutral projections available for Members only. 8. Get FanGraphs Walk-Off, a customized year end review! Find out exactly how you used FanGraphs this year, and how that compares to other Members. Don't be a victim of FOMO. 9. A weekly mailbag column, exclusively for Members. 10. Help support FanGraphs and our entire staff! Our Members provide us with critical resources to improve the site and deliver new features! We hope you'll consider a Membership today, for yourself or as a gift! And we realize this has been an awfully long sales pitch, so we've also removed all the other ads in this article. We didn't want to overdo it. **In case you didn't read all that, here's the short version. Membership includes:**

✓Ad-free browsing

✓Unlimited FanGraphs & RotoGraphs articles

✓Historical & platoon projections

✓Leaderboard & player-page stat heatmaps

✓One-click data exports

✓Customizable player-page dashboards

✓Dark & Classic site modes

✓Weekly Members-only mailbag

✓FanGraphs Walk-Off, your year in review

✓Optional homepage photo removal

✓Gift articles to non-Members

✓Full postseason coverage

[Become a Member](https://plus.fangraphs.com/product/fangraphs-membership/?ifgc=article_middle_long)

[Already a Member? Log in](https://blogs.fangraphs.com/wp-login.php?redirect_to=https%3A%2F%2Fblogs.fangraphs.com%2Fthe-2022-zips-projections-are-coming%2F)

When estimating a player’s future production, ZiPS compares their baseline performance, both in quality and shape, to the baseline of every player in its database at every point in their career. This database consists of every major leaguer since the Deadball era — the game was so different prior to then that I’ve found pre-Deadball comps make projections less accurate — and every minor league translation since the early 1960s. Using cluster analysis techniques (Mahalanobis distance is one of my favorite tools), ZiPS assembles a cohort of fairly similar players across history for player comparisons, something you see in the “No. 1 Comp” column of the player tables that accompany each team projection piece. Non-statistical factors include age, position, handedness, and, to a lesser extent, height and weight compared to the average height and weight of the era (unfortunately, this data is not very good). ZiPS then generates a probable aging curve — both midpoint projections and range — on the fly for each player. This method was used by PECOTA and by the Elias Baseball Analyst in the late 1980s, and I think it is the best approach. After all, there is little experimental data in baseball; the only way we know how plodding sluggers age is from observing how plodding sluggers age.

One of the tenets of projections I follow is that no matter what the projection says, that’s the ZiPS projection. Even if inserting my opinion would improve a specific projection, I’m philosophically opposed to doing so. ZiPS is most useful when people know that it’s purely data-based, not some unknown mix of data and my opinion. Over the years, I like to think I’ve taken a clever approach to turning more things into data — for example, ZiPS’ use of basic injury information — but some things just aren’t in the model. ZiPS doesn’t know if a pitcher wasn’t allowed to throw his slider coming back from injury, or if a left fielder suffered a family tragedy in July. I consider these things outside a projection system’s purview, even though they can affect on-field performance.

It’s also important to remember that the bottom-line projection is, in layman’s terms, only a midpoint. You don’t expect every player to hit that midpoint; 10% of players are “supposed” to fail to meet their 10th percentile projection and 10% of players are supposed to pass the 90th percentile forecast. This point can create a surprising amount of confusion. ZiPS gave .300 BA projections to three players in 2020: [Luis Arraez](https://www.fangraphs.com/players/luis-arraez/18568/stats), [DJ LeMahieu](https://www.fangraphs.com/players/dj-lemahieu/9874/stats) (yikes!), and [Juan Soto](https://www.fangraphs.com/players/juan-soto/20123/stats?position=OF). But that’s not the same thing as ZiPS thinking there would only be three .300 hitters. ZiPS thought there would, on average, be 34 hitters with at least 100 plate appearances to eclipse .300, not three. In the end, there were 25; the league BA environment turned out to be five points less than ZiPS expected, catching the projection system flat-footed.

Speaking of catching ZiPS breaking in the wrong direction, 2020 turned out to be just as difficult as a dataset as I expected. The approach I took for dealing with 2020 was to consider it the first 60 games of a season, use the rest-of-season projections to “finish” the season, and then project normally from there. That’s basically the same approach I would take when projecting a player’s 2022 season on June 1, 2021. This worked out a bit better than I expected for hitters but significantly worse for pitchers. As with batting average, ZiPS was caught sneaking the wrong way on the walk rates and strikeout rates for pitchers.

Another crucial thing to bear in mind is that the basic ZiPS projections are not playing-time predictors. By design, ZiPS has no idea who will actually play in the majors in 2022. ZiPS is essentially projecting equivalent production; a batter with a .240 projection may “actually” have a .260 Triple-A projection or a .290 Double-A projection. But how a [Julio Rodríguez](https://www.fangraphs.com/players/julio-rodriguez/sa3005720/stats?position=OF) would hit in the majors full-time in 2022 is a far more interesting use of a projection system than it telling me that he won’t play in the majors, or at least play only a little bit. For the depth charts that go live in every article, I use the FanGraphs Depth Charts to determine the playing time for individual players. Since we’re talking about team construction, I can’t leave ZiPS to its own devices for an application like this. It’s the same reason I use modified depth charts for team projections in-season. There’s a probabilistic element in the ZiPS depth charts: sometimes Joe Schmo will play a full season, sometimes he’ll miss playing time, and Buck Schmuck has to step in. But the basic concept is very straightforward.

The to-do list never shrinks. One of the things not complete, but in the works, is better run/RBI projections. ZiPS wasn’t originally designed as a fantasy baseball tool — fantasy baseball analysts have been making fantasy-targeted projections for a long time — but given that ZiPS is frequently used by fantasy players, more sophisticated models are in the works. Saves, on the other hand, are a particularly difficult issue. As of now, the only thing I tell ZiPS about a player’s role is if it is going to change, which determines if ZiPS sees future [Mike Moustakas](https://www.fangraphs.com/players/mike-moustakas/4892/stats) as a second or third baseman. I’ve tried a lot of shortcuts, like trying to model the manager’s decision about who the closer would be using both statistics and things like age, salary, and history. While it generally does a good job projecting who will be the closer, the misses are gigantic and render save projections ineffective; a managerial decision can turn a 35-save pitcher into a five-save pitcher. I’m still figuring out how to approach this problem.

What else is new for 2022? On a general level, there’s greater integration of Statcast data into establishing player baselines. I’m very sensitive towards making sure that new things I integrate into the chaotic mass of algorithms actually have predictive value. One example is increased use of sprint speed when calculating the speed component of players. Another use is a model of individual spin rate change to estimate a substance enforcement environment that lasted the whole 2021 season rather than one in which baseball awkwardly started more vigorously enforcing rules about grip substances halfway through.

One change that I’m particularly proud of, though one you won’t see for single-year projections, is an improved model for estimating when a player’s career will end. In the past, ZiPS has estimated a decline in late-career performances based mainly on the normal injury/decline risks, age, overall performance, and vicinity to milestones. I’ve refined this approach to also include things like salary and existing contract length. This would have improved career projections for [Albert Pujols](https://www.fangraphs.com/players/albert-pujols/1177/stats); ZiPS could just not understand, using the old model, why the Angels refused to stop playing him.

Have any questions, suggestions, or concerns about ZiPS? I’ll try to reply to as many as I can reasonably address in the comments below. If the projections have been valuable to you now or in the past, I would also urge you to [consider becoming](https://plus.fangraphs.com/product/fangraphs-membership/) a member of FanGraphs, should you have the ability to do so. It’s with your continued and much appreciated support that I have been able to keep so much of this work available to the public for free for so many years. Improving and maintaining ZiPS is a time-intensive endeavor and your contributions have enabled me to have the flexibility to put an obscene number of hours into its development. Hopefully, the projections and the things we have learned about baseball have provided you a return on your investment; it’s hard to believe that ZiPS is nearing the 20-year-old mark.

  
  
  
  

[Astros, Verlander Agree to Return Engagement](https://blogs.fangraphs.com/astros-verlander-agree-to-return-engagement/)

[2022 Golden Days Era Committee Candidate: Gil Hodges](https://blogs.fangraphs.com/2022-golden-days-era-committee-candidate-gil-hodges/)

Dan Szymborski is a senior writer for FanGraphs and the developer of the ZiPS projection system. He was a writer for ESPN.com from 2010-2018, a regular guest on a number of radio shows and podcasts, and a voting BBWAA member. He also maintains a terrible Twitter account at @DSzymborski.

58 Comments

Oldest

TonyMember since 2017

4 years ago

Yay! Bring them on.

15

John Elway

4 years ago

Reply to  [Tony](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362515)

YEIGHHHHH!!!!!!!!!!!!!!!!!!!!!!!!!!!

12

Ivan\_GrushenkoMember since 2016

4 years ago

Are the furnaces running on coal or renewables?

2

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [Ivan\_Grushenko](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362516)

Little Lisa Slurry, made from 100% recycled sea creatures.  

23

Ivan\_GrushenkoMember since 2016

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362520)

Biomass!

3

hky1425Member since 2017

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362520)

Needs more dog

1

LFC Mike

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362520)

Skyline Chili … nuclear gas powered

2

Smiling PolitelyMember since 2018

4 years ago

Projections for the cats?

2

scotth855Member since 2020

4 years ago

Do you use any sort of spin rate information for pitchers?

1

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [scotth855](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362519)

I do, but mostly \*changes\* and conservatively.

3

scotth855Member since 2020

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362521)

Makes sense. Thanks for the answer!

0

stratocaster

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362521)

How about catcher spin rate? I think this is the logical next step to catcher ERA and it will help replace lost value from pitch framing once the robot umps take over.

0

jrogersMember since 2017

4 years ago

Reply to  [stratocaster](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362562)

Not sure if this got a -1 because they thought you were serious, or they thought it was that bad of a joke.

0

BenZobrist4MVP

4 years ago

Thanks, Dan, your projections are amazing!

Looking at 2021 ZiPS projections vs. actual stats, I noticed that of the batters with over 300 plate appearances, 4 of the 7 who most outperformed their projected wOBA were Brandon Crawford, Darin Ruf, Buster Posey, and Brandon Belt. Do you think this was just a coincidence or that changing park factors, excellent coaching, or some other quantifiable or non-quantifiable issue led ZiPS (and everyone) to miss on the Giants in general?

2

mikejuntMember

4 years ago

Reply to  [BenZobrist4MVP](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362524)

Projection systems are built around historical comparisons and players’ established performance levels. It is not common for players to make sudden jumps in true talent. but we know it happens: Sometimes players just jump to new levels of performance and stay there because of a change (think Chris Taylor).

Historically, there’s been no way to identify these players as opposed to the ones who have a single career year and regress or who get lucky. This is what Dan refers to in his policy of not using his own judgment even when it might improve a projection: we knew in 2017, for instance, that Taylor had rebuilt his swing with Robert Van Scoyoc. His improvement was much more likely to continue than normal. But it took projection systems longer, well into 2018, to start to believe, because those kinds of performances are historically a minority of sudden performance jumps.

Now, when we look at the Giants, their performance was such an outlier to their projections that it’s clear there were factors the projection systems could not see. And for some of those players, Belt for instance, we know those were related to sudden and substantial changes in approach and swing. And with the addition of statcast batted ball data, it becomes easier for projection systems to identify which of these will ‘stick’, but it’s still an imprecise science. And it’s almost certainly the case that the Giants’ fantastic season was the result of both actual true-talent increases for some players and more typical single-year bumps that will not sustain for others. You don’t get your entire roster overperforming projections (or your entire roster except Mike Yazstremski, I guess) without a mixture.

I have compared the 2021 Giants a bit to the 2020 Padres: There were legitimate breakout players on the 2020 Padres. There were also players who it was hard to believe had transformed their performance. And, indeed, some of those players maintained at or near those new performance levels. Others, like Eric Hosmer, turned back into pumpkins.

The big challenge for projection systems, and indeed for the Giants front office, given how many free agents they have, is identifying which of those breakouts represents new, long-term changes in skill level and which are likely to regress. My guess is that both the Giants and the projection systems will miss a bit on some of these, but you should expect to see some of them. Before Posey retired, for instance, it was my view that you should expect 1 or 2 of the Belt/Posey/Crawford to not sustain that improvement long-term. Similarly, some of those breakout late-20s players like LaMonte Wade will be good for several years, and others will not. Figuring out which of those players are each will be a real challenge for the Giants. Projection systems, however, will traffic in probabilities and give you weighted mean projections, where one player may have a 30% chance of sustaining their improvement and another 15% and a third 45%. They will all have some failure rate built in due to that uncertainty, and their mean projections will come in low for the players who DO sustain, and probably high for the players who don’t. Most projection systems don’t show you their whole range of percentile outcomes, which is where you’d really be able to see those differences in the probability of maintaining the new performance level. Dan shares that information sometimes in posts, but one thing I wish FanGraphs offered was freely viewable percentile projection information the way Baseball Prospectus traditionally has provided with PECOTA. Relying primarily on the weighted mean projection is overly simplistic and makes it impossible to attempt to answer these questions yourself with any level of detail.

12

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [BenZobrist4MVP](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362524)

Ask me in five years! It’s hard to tell from one season if the Giants had the coin come up the right way several times or they had a magical coin flipping robot.

8

Ivan\_GrushenkoMember since 2016

4 years ago

Is it appropriate to modify replacement level for pitchers based on changing usage?

1) IP/G rather than Starter/Reliever  
2) Replacement Level Relievers can be substituted for Starters to some extent

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [Ivan\_Grushenko](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362532)

ZiPS does different replacement levels on an innings basis. I’m not sure how to take into account workloads or even if we \*should\*. If the starting pitchers are used less then they’re simply less valuable as a whole.

2

Ivan\_GrushenkoMember since 2016

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362583)

Thank you

0

kylerkelton

4 years ago

My favorite part of the offseason!

3

Sporter's Five HorsesMember since 2016

4 years ago

Looking forward to this Thanksgiving week treat to occupy my time while “working”

1

GopherballsMember since 2017

4 years ago

Why are all Reds players projected at -0.1 WAR or worse when you represent Cincinnati and the team?

6

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [Gopherballs](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362544)

\-2? Someone didn’t get the joke! lol

8

Baseball Analyzed

4 years ago

Oooooh yeahhhhh!!!

0

darren

4 years ago

What’s the order for this year? 

1

Psychic... Powerless...

4 years ago

Reply to  [darren](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362555)

Dan doesn’t announce the order. It’s a surprise.  

0

szakylMember since 2024

4 years ago

Reply to  [darren](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362555)

Dan promised “piping hot projections” on Monday, so that disqualifies the Rockies.

On the other hand, starting off with Colorado sounds like something Dan would do.

1

fanofthemanMember since 2020

4 years ago

Reply to  [szakyl](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362637)

Pile of hot, steaming…. Something

1

Mean Mr. Mustard

4 years ago

Say Dan…this purely a spitball question, and outside the purview of ZiPS (speaking strictly), but if data like reaction time on balls hit, etc is available, could the system be usable as a sort of forecast for where a position-uncertain player would best fit on the field?

Take, for instance, someone like Kevin Mitchell from back in the day. No one thought he was a third baseman and he got stuck in left because that’s what you did (and do) with power guys. I’m curious whether running him through projections would have predicted another position, barehanded catches be damned.

We all know of a lot of guys who didn’t get much of a chance because they were either blocked or no one knew what to do with them. Seems like a raw skills/talent system would be pretty beneficial.

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [Mean Mr. Mustard](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362556)

It could be. I do estimates for position moves from things, for example, speed data is helpful to estimate how someone will do in center without them playing in center. Whatever data I can find, I try to wring it like a sponge!

2

Mean Mr. Mustard

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362585)

For more modern examples, I was thinking specifically about Bellinger and Gallo when I wrote the question, and how their teams trying them at unconventional positions really worked out for everyone involved, which led to wondering whether you or anyone else had designed or were working on a kind of positional forecaster. Seems like it’d be more efficient than trying to shoehorn a guy in a bad positional fit to meet a team shortcoming, and it seems like it would absolutely open up draft flexibility if you can predict by traits.

0

techzero

4 years ago

Dan, in a FG chat a few months back, someone (Ben? Kevin? Your cat?) mentioned that there would be changes to the defensive component of ZiPS and that we would be pleased with them. Is the integration of probabilistic estimates of defense for minor leaguers the change that referenced? In addition, I assume that this change is only applicable to the minor leagues, as you have far more robust data to inform the major league DEF component. If this is not the change, could you talk a little bit about what possible changes to defense might be upcoming in future versions of ZiPS? OAA inclusion?

Also, do you have any thoughts on ZiPS’s use of positional adjustment (meaning, is it one of the pieces you test throughout the year and have you thought about changing it)? At least on the VEB discussion boards the last few months, there has been a lot of back and forth about how some positional adjustments may be too severe or that they may need to be updated.

Thank you for all the work you do! Love ZiPS Day!

0

Cave Dameron

4 years ago

Reply to  [techzero](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362557)

It was indeed his cat Mercutio that mentioned the defensive component of ZiPS would have some alterations.

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [Cave Dameron](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362569)

Mercutio is a quarter-wit and you should not consider anything he says as having any value. He’s a friendly, good-natured cat, but he’s dumber than a box of rocks.

2

Cave Dameron

4 years ago

Reply to  [Dan Szymborski](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362590)

Sounds like we have a lot in common.

2

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [techzero](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362557)

I think they meant WAR, not ZiPS!

3

hombremomento

4 years ago

Finally! I’ve been wanting something completely predictive and not guaranteed to spout to my father when we talk baseball!

1

ShauncoreMember since 2019

4 years ago

Is ZiPS (or I guess you, Dan) making adjustments for MiLB translations given the rise in offensive environment in the minors (particularly AA/AAA) compared to 2019?

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [Shauncore](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362570)

ZiPS automatically adjusts for levels of offense of different leagues!

1

szakylMember since 2024

4 years ago

I understand that ZiPS ignores a GM’s and manager’s effects on playing time. Does it also ignore the possibility of injury and assume perfect health for the season?

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [szakyl](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362580)

No. It assumes players will generally regress towards being mostly healthy, but injury does have a tendency to predict injury.

2

byronMember since 2016

4 years ago

Is there still a backup buried in a state park?

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [byron](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362594)

Yup.

2

MikeSMember since 2020

4 years ago

_For example, a grounder…that hugs the foul lines is a double 52% of the time at third and 66% of the time on the first base side._

This kinda fascinates me. Why the better result down the first base line? Is it because 3B are better defenders than 1B? Do they play closer to the line in general? Is it because more batters are right handed, so against them 3B are closer to the line and 1B are further off of it? Are balls to the right side hit harder or with more spin?

1

Mahoney

4 years ago

Reply to  [MikeS](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362614)

Also, if we assume that most balls hit down either line are pulled, than the extra step that a LHB gets out of the box may help stretch more singles into doubles.

2

jrogersMember since 2017

4 years ago

Reply to  [MikeS](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362614)

I’d actually think 1B play closer to the line on average, taking into account when they hold runners on, or when the shift is on. Hmm.

0

guyarrigoniMember since 2024

4 years ago

Has anyone ever tracked what players’ production are the most consistently over or under estimated by the various projection systems? Is there someone they all hate or love despite real world results?

1

kevinthecomic

4 years ago

Reply to  [guyarrigoni](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362620)

Not exactly what you are asking, but I believe that one of the Fantasy writers (Sporer or Cohen?) does a look back to see which of the projection systems did the best in any given year.

0

Jason BMember since 2017

4 years ago

“my first interaction with Chris involved me being called an expletive!”

That’s how all great friendships start, you \*\*\*\*\*\*\*\*\* 

1

jankees1991

4 years ago

Hey Dan, just wondering how much programming goes into developing your projection system? I am a software developer by trade and a hobbyist in baseball/statistics and I’m curious how much exposure you have to the programming/scripting side of things vs. if you have someone else helping you out.

0

blueboy714

4 years ago

I love the ZIPs – but I have one question. Is there a reason the batting PA and pitcher BF are typically 2.5 to 3 times greater than what teams are actually have during the season?

0

jrogersMember since 2017

4 years ago

Reply to  [blueboy714](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362657)

I think it’s explained in the 11th paragraph: “Another crucial thing to bear in mind is that the basic ZiPS projections are not playing-time predictors. By design, ZiPS has no idea who will actually play in the majors in 2022 … how a Julio Rodríguez would hit in the majors full-time in 2022 is a far more interesting use of a projection system than it telling me that he won’t play in the majors, or at least play only a little bit.”

0

kevinthecomic

4 years ago

I think I have a Buck Schmuck rookie card somewhere in my collection.

0

Greg SimonsMember since 2016

4 years ago

Thanks for new ZiPS every year, Dan. They’re much appreciated and one of the reasons I (and many others, I’m sure) are happy to support FanGraphs.

0

atomicdogMember since 2021

4 years ago

Yes! Can’t wait.

0

dukewinslowMember since 2020

4 years ago

I’m curious if you’ve tried penalized regression techniques to select parameters- if you don’t particularly care about gnarly debates, something like elastic net? If you do, the various partisans of LASSO and ridge have meaningful priors stuff under review. You’d get a very good idea of what to include versus not include in the model.

0

Dan SzymborskiFanGraphs Staff

4 years ago

Reply to  [dukewinslow](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#comment-5362683)

One constraint is the \*quality\* of the data. In the big picture, there just aren’t that many baseball players and the results are so noisy. While we have a ton of inputs, dimensionality reduction isn’t the big issue I have and I think I do a solid job at avoiding overfits. The λ would be so small that we may be making things more complicated than the data demand.

Now, someone more clever than I — and there are many — may reap dividends with this approach. Indirectly, I suspect this approach might be effective with minor league translations; I’ve been playing with ridge regression here.

0

RotoholicMember since 2016

4 years ago

Do you look at TTOP at all? For example, in 2021 the 1-2-3-4 hitters comprised only 50% of the hitters Zack Wheeler faced the third time through the order. For Julio Urias, it was 67%. 1-2-3-4 hitters had a .351 wOBA against a pitcher in his third time through the order, while 6-7-8-9 hitters only had a .288 wOBA in the same situations. If Wheeler and Urias had the same zERA or whatever, wouldn’t that mean Urias was the better pitcher since faced more difficult competition? Or would the fact that Urias might have the same tough competition in the future negate that effect?

0

-   [The 2026 Pitching Superlatives, Part 3: Location](https://blogs.fangraphs.com/the-2026-pitching-superlatives-part-3-location/)
    
    11/4 – [Davy Andrews](https://www.fangraphs.com/blog-roll?author=198584)
    
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
    
    11/2 – [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)[16](https://blogs.fangraphs.com/ben-clemens-top-50-free-agents-chat-11-2-26/#comments)
    
-   [2027 Top 50 Free Agents](https://blogs.fangraphs.com/2027-top-50-free-agents/)
    
    11/2 – [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)[129](https://blogs.fangraphs.com/2027-top-50-free-agents/#comments)
    
-   [Job Posting: Colorado Rockies - Senior or Lead Analyst (Forecasting)](https://blogs.fangraphs.com/job-posting-colorado-rockies-senior-or-lead-analyst-forecasting/)
    
    11/2 – [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
-   [Job Posting: Colorado Rockies - Affiliated Technology Data Fellow](https://blogs.fangraphs.com/job-posting-colorado-rockies-affiliated-technology-data-fellow/)
    
    11/2 – [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    

-   [Ben Clemens](https://www.fangraphs.com/blog-roll?author=164011)
    
    Post Count: 1648
    
-   [Ben Lindbergh](https://www.fangraphs.com/blog-roll?author=38267)
    
    Post Count: 2528
    
-   [Brendan Gawlowski](https://www.fangraphs.com/blog-roll?author=173407)
    
    Post Count: 163
    
-   [Brendan Gawlowski and Eric Longenhagen](https://www.fangraphs.com/blog-roll?author=224541)
    
    Post Count: 5
    
-   [Dan Szymborski](https://www.fangraphs.com/blog-roll?author=30942)
    
    Post Count: 1295
    
-   [David Appelman](https://www.fangraphs.com/blog-roll?author=1)
    
    Post Count: 998
    
-   [David Laurila](https://www.fangraphs.com/blog-roll?author=25048)
    
    Post Count: 2271
    
-   [Davy Andrews](https://www.fangraphs.com/blog-roll?author=198584)
    
    Post Count: 497
    
-   [Eric Longenhagen](https://www.fangraphs.com/blog-roll?author=81295)
    
    Post Count: 1051
    
-   [Eric Longenhagen and Brendan Gawlowski](https://www.fangraphs.com/blog-roll?author=286038)
    
    Post Count: 12
    
-   [Eric Longenhagen and James Fegan](https://www.fangraphs.com/blog-roll?author=270663)
    
    Post Count: 12
    
-   [Esteban Rivera](https://www.fangraphs.com/blog-roll?author=167339)
    
    Post Count: 122
    
-   [FanGraphs Staff](https://www.fangraphs.com/blog-roll?author=180253)
    
    Post Count: 33
    
-   [Jake Mailhot](https://www.fangraphs.com/blog-roll?author=10708)
    
    Post Count: 380
    
-   [James Fegan](https://www.fangraphs.com/blog-roll?author=31563)
    
    Post Count: 7
    
-   [Jason Martinez](https://www.fangraphs.com/blog-roll?author=151408)
    
    Post Count: 159
    
-   [Jay Jaffe](https://www.fangraphs.com/blog-roll?author=169789)
    
    Post Count: 1951
    
-   [Jon Becker](https://www.fangraphs.com/blog-roll?author=82328)
    
    Post Count: 117
    
-   [Jordan Rosenblum](https://www.fangraphs.com/blog-roll?author=11712)
    
    Post Count: 6
    
-   [Kiri Oler](https://www.fangraphs.com/blog-roll?author=166180)
    
    Post Count: 92
    
-   [Leo Morgenstern](https://www.fangraphs.com/blog-roll?author=209902)
    
    Post Count: 146
    
-   [Matt Martell](https://www.fangraphs.com/blog-roll?author=153421)
    
    Post Count: 95
    
-   [Matthew Roberson](https://www.fangraphs.com/blog-roll?author=212969)
    
    Post Count: 22
    
-   [Meg Rowley](https://www.fangraphs.com/blog-roll?author=95174)
    
    Post Count: 727
    
-   [Michael Baumann](https://www.fangraphs.com/blog-roll?author=198829)
    
    Post Count: 736
    
-   [Michael Rosen](https://www.fangraphs.com/blog-roll?author=34149)
    
    Post Count: 72
    
-   [Paul Sporer](https://www.fangraphs.com/blog-roll?author=11752)
    
    Post Count: 14
    
-   [Ryan Blake](https://www.fangraphs.com/blog-roll?author=200227)
    
    Post Count: 41
    
-   [Sean Dolinar](https://www.fangraphs.com/blog-roll?author=76277)
    
    Post Count: 144
    

-   [2026 BBWAA Ballot](https://www.fangraphs.com/blog-roll?category=2026%20BBWAA%20Ballot)
-   [2026 Contemporary Baseball Ballot](https://www.fangraphs.com/blog-roll?category=2026%20Contemporary%20Baseball%20Ballot)
-   [2026 MLB Draft](https://www.fangraphs.com/blog-roll?category=2026%20MLB%20Draft)
-   [2026 Positional Power Rankings](https://www.fangraphs.com/blog-roll?category=2026%20Positional%20Power%20Rankings)
-   [2026 Postseason](https://www.fangraphs.com/blog-roll?category=2026%20Postseason)
-   [2026 Replacement-Level Killers](https://www.fangraphs.com/blog-roll?category=2026%20Replacement-Level%20Killers)
-   [2026 Trade Deadline](https://www.fangraphs.com/blog-roll?category=2026%20Trade%20Deadline)
-   [2026 Trade Deadline Prospects Guide](https://www.fangraphs.com/blog-roll?category=2026%20Trade%20Deadline%20Prospects%20Guide)
-   [2026 Trade Value](https://www.fangraphs.com/blog-roll?category=2026%20Trade%20Value)
-   [2026 WBC](https://www.fangraphs.com/blog-roll?category=2026%20WBC)
-   [2026 ZiPS Projections](https://www.fangraphs.com/blog-roll?category=2026%20ZiPS%20Projections)
-   [Arizona Fall League](https://www.fangraphs.com/blog-roll?category=Arizona%20Fall%20League)
-   [Challenging Career Quiz](https://www.fangraphs.com/blog-roll?category=Challenging%20Career%20Quiz)
-   [Chat](https://www.fangraphs.com/blog-roll?category=Chat)
-   [College](https://www.fangraphs.com/blog-roll?category=College)
-   [Contract Crowdsourcing 2026-27](https://www.fangraphs.com/blog-roll?category=Contract%20Crowdsourcing%202026-27)
-   [Economics](https://www.fangraphs.com/blog-roll?category=Economics)
-   [Effectively Wild](https://www.fangraphs.com/blog-roll?category=Effectively%20Wild)
-   [Effectively Wild 2026 Season Preview](https://www.fangraphs.com/blog-roll?category=Effectively%20Wild%202026%20Season%20Preview)
-   [Essential](https://www.fangraphs.com/blog-roll?category=Essential)
-   [Essential Articles](https://www.fangraphs.com/blog-roll?category=Essential%20Articles)
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
-   [Idle Thoughts](https://www.fangraphs.com/blog-roll?category=Idle%20Thoughts)
-   [JAWS](https://www.fangraphs.com/blog-roll?category=JAWS)
-   [Job Postings](https://www.fangraphs.com/blog-roll?category=Job%20Postings)
-   [Mailbag](https://www.fangraphs.com/blog-roll?category=Mailbag)
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

Welcome to FanGraphs

# FanGraphs asks for your consent to use your personal data to:

-   Personalised advertising and content, advertising and content measurement, audience research and services development
-   Store and/or access information on a device

Your personal data will be processed and information from your device (cookies, unique identifiers, and other device data) may be stored by, accessed by and shared with 314 partners, or used specifically by this site. We and our partners may use precise geolocation data. [List of partners.](https://blogs.fangraphs.com/the-2022-zips-projections-are-coming/#)

Some vendors may process your personal data on the basis of legitimate interest, which you can object to by managing your options below. Look for a link at the bottom of this page or in the site menu to manage or withdraw consent in privacy and cookie settings.
