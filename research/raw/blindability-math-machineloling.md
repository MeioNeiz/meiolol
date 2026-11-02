# The math behind champion blindability

- url: https://www.youtube.com/watch?v=3t5dEYyLua0
- channel: MachineLoLing (@MachineLoLing, 9,110 subscribers)
- uploaded: 2026-10-30; length 17:48
- views 356,522, likes 8,697 (as of 2026-11-02)
- transcript: auto-generated captions (en-orig); [m:ss] is where each paragraph starts
- frames: 81, each where the picture settles; the one at m:ss is raw/blindability-math-machineloling/frames/m-ss.jpg (listed under each paragraph); contact sheets under Frames

## Description

The math behind champion blindability: how safely can you lock in a champion before you know who you are facing?

This video builds the idea from the ground up using two Mid laners, Ahri and Yasuo, as an example. You will learn the math behind who is blindable, who gets counterpicked, and what pro teams blind pick.

Blog, old posts and the Champion Pool Designer: machineloling.com
Website: coming once Riot approves it
X: x.com/machineloling
Reddit: reddit.com/u/machineLoLing
Ko-fi: ko-fi.com/machineloling

Chapters
0:00 Intro
0:48 What is blindability?
1:29 Ahri's matchups as a bell curve
3:03 How odds work
3:23 Expected win rate: Ahri vs Mel
4:50 The problem with game counts
5:40 Spread, noise and true spread
6:48 Yasuo's spread
7:36 Ahri's counters
7:57 How likely is a counterpick?
9:14 Mastery and pool size
10:15 Spread against the chance of a counter
10:33 Matchups beyond your own lane
11:42 Which roles matter
12:59 The Mid map
13:40 Who gets counterpicked
14:36 Blindability against counterpicks
15:25 Blindability by rank, and what the pros blind pick
16:56 Wrap-up

#LeagueOfLegends #LoL #Ahri #Yasuo #MidLane #MLoL #MachineLoLing

## Chapters

- 0:00 Intro
- 0:48 What is blindability?
- 1:29 Ahri's matchups as a bell curve
- 3:03 How odds work
- 3:23 Expected win rate: Ahri vs Mel
- 4:50 The problem with game counts
- 5:40 Spread, noise and true spread
- 6:48 Yasuo's spread
- 7:36 Ahri's counters
- 7:57 How likely is a counterpick?
- 9:14 Mastery and pool size
- 10:15 Spread against the chance of a counter
- 10:33 Matchups beyond your own lane
- 11:42 Which roles matter
- 12:59 The Mid map
- 13:40 Who gets counterpicked
- 14:36 Blindability against counterpicks
- 15:25 Blindability by rank, and what the pros blind pick
- 16:56 Wrap-up

## Frames

Contact sheets of up to 16, left to right then down:

- raw/blindability-math-machineloling/sheets/01.jpg: 0:01 0:11 0:22 0:57 1:05 1:11 1:18 1:28 1:38 1:43 1:59 2:40 3:02 3:13 3:15 3:22
- raw/blindability-math-machineloling/sheets/02.jpg: 3:29 3:32 3:43 3:46 3:54 3:59 4:14 4:36 4:49 4:53 5:08 5:13 5:16 5:40 5:51 6:20
- raw/blindability-math-machineloling/sheets/03.jpg: 6:25 6:35 6:44 7:01 7:20 7:22 7:36 7:43 7:48 7:51 7:57 8:16 8:22 8:25 8:28 9:14
- raw/blindability-math-machineloling/sheets/04.jpg: 9:31 9:38 9:41 9:49 9:54 10:02 10:08 10:14 10:22 10:32 10:44 10:49 11:42 11:55 12:05 12:20
- raw/blindability-math-machineloling/sheets/05.jpg: 12:40 12:45 12:58 13:01 13:05 13:40 14:36 14:41 14:45 15:01 15:24 15:40 16:07 16:14 16:56 17:31
- raw/blindability-math-machineloling/sheets/06.jpg: 17:45

## Transcript

[0:00] We all know the feeling. You've got the first pick, no one will trade, you lock in your favorite champion, and bam, it gets countered. But what were the odds that that was going to happen? If you'd picked a different champion, could it have been avoided? Hi, I'm Joseph, the data scientist behind Machine Lolling. I have a PhD and over 10 years of experience in bioinformatics, and today I'm going to show you the math behind blindability. >> [music] [music] [music]
frames: 0:01 0:11 0:22

[0:48] >> I'm sure you've heard people say that such and such champion is blindable, and for most, [music] that just means that you could pick it early in the draft and it probably won't get countered. But I'd like to offer us a more concrete definition. >> [music] >> In simple terms, blindability is the variability of a champion win rate based on the opponents and teammates that are in the game. If a champion is really blindable, it doesn't care about what other champions are in the game, it's still going to perform its function. But if it's not blindable, it's going to care a lot. Different champions are going to lead to very different outcomes. To help us work through this, I'm going to do a mid lane case study between Ahri and Yasuo. Both are top three picks, but Ahri is blindable and Yasuo is not. I think it's pretty well known in this case, but I want to show you why it's the case.
frames: 0:57 1:05 1:11 1:18 1:28

[1:29] If you go to any League of Legends statistic sites these days, you can probably find what a champion is good into and what they're bad into. But what you probably haven't seen is what happens if you stack all of those matchups onto a histogram. This is just a one-dimensional display we'll be using to compare the win rates. When we drop Ahri's into place, we can see that she's really good against Azir >> [music] >> and really bad against Annie. She wins more games than she loses, so her average is around 50.8%. But the big thing I want you to focus on here is what happens when we fit a bell curve to her champion pool. This will allow us to get a measurement of spread. >> [music] >> Spread is going to be our statistical way of distinguishing how far her good match-ups are from her bad match-ups. >> [music] >> In this case, we're going to use the standard deviation as our unit of spread. And for Ahri, she has a standard deviation of about 1.8%. This means if this actually was a normal curve, which I won't get into, but assuming it is, a spread of 1.8% would mean that about 68% of her match-ups are going to fall plus or minus 1.8% of her average win rate.
frames: 1:38 1:43 1:59

[2:25] That's pretty good. I mean, I can tell you it's pretty good, but you don't know that it's pretty good [music] yet, but it is in fact pretty good. And we'll see that when we compare it to Yasuo later. But before we do that, we need to take care of a few things. First of all, I think this makes more sense to look at a champion's blind ability irrespective of their overall win rate. For reasons we'll definitely get into in another video, win rates are not necessarily great at telling us just how powerful a champion is. And the shifts can obscure which champions Ahri loses to because they're her counters, and which champions she loses to because they're just really strong right now. To wash away the overall win rate of both champions, we're going to need to understand how odds work. >> [music] >> For example, if
frames: 2:40 3:02

[3:03] Ahri wins 2/3 of her games, we would say she has 2:1 odds to win any game that she's going to play. That means she's going to get about 66.7 wins for every 100 games that she plays. And the odds ratio is just the win rate, 66.7 over 100 minus the win rate, >> [music] >> which ends up being 33.3, and that comes out to two, which is the odds,
frames: 3:13 3:15 3:22

[3:23] 2:1. >> [music] >> Now, to compare two champions, let's look at Ahri and Mel. Ahri is very strong and Mel is very weak. Ahri wins about 50.9 games per 100, where Mel only wins 45.5. Ahri's odd ratio is 1.04, and Mel's odd ratio is only 0.83. If we want to see what the expected outcome of these two facing each other should be, we just take the ratio of their odds ratios. We would take Ahri's 1.04 over Mel's 0.83, [music] and that would give us an odds ratio of 1.25 for Ahri facing Mel. [music] If we want to convert back to win rate, we just use our odds equation once again. And that gives us about a 55.6% expected win rate for Ahri facing off against Mel. Because [snorts] again, Ahri is strong and Mel is weak. But when we look at the actual win rates between Ahri and Mel, it's 51.5% about 4.1% lower than we would expect based on the champion win rates.
frames: 3:29 3:32 3:43 3:46 3:54 3:59 4:14

[4:16] When we apply this correction to all of Ahri's match-ups, we can see just how bad that Mel match-up really is. It's the one true counter, if we define counters as being anything more than 2% below a champion's expected win rate, which is arbitrary and you can do it another way. But for now, I just want you to appreciate that Mel is the one real counter. >> [music] >> And I'd also like you to note that Ahri's spread has now fallen to 1.3%. We're going to do one last small adjustment where we factor in the play rate of each champion in the meta. It's going to shrink the curve a little bit more, but the spread will still round to 1.3%. And you might be thinking, "Mission accomplished. We have measured Ahri's spread."
frames: 4:36 4:49

[4:50] But we still have a problem. And that problem is that the number of games we have recorded for Ahri affects what her spread is going to be. Here's where I have to introduce you to a concept you're probably not familiar with. Spread is affected by sample size. What that means for us is that champions that get played more look like they have lower spreads than champions that [music] don't. As a visual example, I'll sub-sample the Ahri games that I'm using in this video. When I only take 3% of them, or 9,000, Ahri's spread becomes enormous. >> [music] >> As I sample more and more of her games, her spread tightens, eventually condensing to that 1.3% we saw before. That leaves us with the question, would the spread keep getting smaller if I kept sampling more games? And moreover, how do I compare Ahri, who's played a lot, to Yasuo, who's played less?
frames: 4:53 5:08 5:13 5:16

[5:35] The answer lies in understanding the nature of the noise that's introduced in these low sample sizes.

[5:40] You can think of the spread we observe as a combination of the true variability that Ahri has combined with the noise. What we're after is true spread, and what we have is the observed spread. [music] So, if we had some estimate for the noise, we'd be able to calculate the true spread. Fortunately, every one of Ahri's match-ups is a binomial distribution. This is because every one of her match-ups only has two outcomes. [music] Fortunately, the noise for a binomial distribution depends only on the N. So, if we have the number of samples, we know exactly what the noise is going to look like. This allows us to perfectly estimate the noise for every one of her match-ups. And that means once we know what the noise is, we can simply subtract the noise from the observed spread to find the true spread. Here's a plot of what the correction looks like as we increase the number of games we sample for Ahri. >> [music] >> You can see that even at low sample rates, it's already honed in on what the ultimate convergence point is going to be.
frames: 5:40 5:51 6:20 6:25

[6:31] As we approach many hundreds of thousands of games, the observed spread and the noise corrected spread do converge. That leaves Ahri with a true spread of 1.1%. But, we still have no idea what that means. First, let's start out by comparing it to other mid laners. A typical mid laner has a spread of 1.8%.
frames: 6:35 6:44

[6:48] If we look at Yasuo, things get even worse. Yasuo has a spread of 2.2% with his best match-up being Akshan and his worst match-up being Azir. That means Yasuo's spread is higher and he's less blindable. But, I feel like this term is still too abstract. The realistic question is, when you queue up, how much more likely are you to be countered if you're playing Yasuo than if you're playing Ahri? Let's dig into that question. If we define being countered as playing into a match-up that a champion wins 2% less than we would expect, only 3.8% of Ahri's match-ups would fall into that range. Conversely, Yasuo would have 17.8% of his match-ups in that range. But, match-ups in League of Legends are not smooth curves. They're discrete, which is a fancy word for saying they're made up of individuals.
frames: 7:01 7:20 7:22

[7:36] So, how many match-ups actually fall below 2% for Ahri versus Yasuo? Ahri has just one, Mal. For Yasuo, there's a whole bunch. Mal accounts for 1.4% of the meta at the moment, where Yasuo's counters account for a whopping 24% of all mids picked. But, we can go even further.
frames: 7:36 7:43 7:48 7:51

[7:57] We can estimate exactly how likely Yasuo is to be countered with some basic probability [music] theory. Let's assume that pools are an assembly of random champions, which as I know, a bit of a bad assumption, but I think it's good enough for this back-of-the-envelope calculation. [music] If this assumption hold, each opponent's champion pool can be represented by a number of pulls from a random champion bag, where the odds of drawing a champion from that bag are the current play rates in the meta. In this case, the probability of being countered would be 1 minus the probability of not drawing a counter >> [music] >> to the power of n. N is the number of draws each opponent gets from the bag, our metaphorical proxy for champion pool size. But, to complete this calculation, we do need an estimate for n, the average person's champion pool size in the mid lane. Unfortunately, this is a place where my current access to Riot's API is going to limit my answer.
frames: 7:57 8:16 8:22 8:25 8:28

[8:45] If and when Riot decides to give me greater access, I can bring you greater stats, and I'll be able to answer this question directly. But, for now, I'm going to have to get creative and estimate. I'm going to make another assumption, that a player's distribution of mastery points is indicative of their pool size. Now, this is certainly imperfect. Players can simply cycle what they play and have small pools at any given time. But, I think it's reasonable to assume that a one trick will have a lot of mastery stacked on one champion, where someone who plays a lot more in their pool will have lots of mastery on many

[9:14] champions. >> [music] >> This plot shows the share of mastery that's covered by a person's top X champions. So, if your most played champion has 50% of your mastery points, then at one, you would be at 50%. If your next champion had 25%, then at two, you'd be at 75%. We're going to arbitrarily draw the line at 80%. We'll consider pool size to be however many champions it takes for a player to reach 80% of their total mastery. >> [music] >> If we plot the number of champions that it takes to cover 80% of a player's mastery on its own plot, the mean number of champions is seven. On average, mid laners have 80% of their mastery on just seven champions. When we plug that estimate for pool size back into our probability equation, we can see that if you're blinding Yasuo, you're probably getting countered 85% of the time.
frames: 9:14 9:31 9:38 9:41 9:49 9:54

[9:59] But, if you're blinding Ahri, then probability is only about 10%. We can even look at the individual breakdown of champions to see what Yasuo is most likely facing when he gets countered. If we look at Viktor and Yone alone, there's a 30% chance that your opponent plays one of those two.
frames: 10:02 10:08 10:14

[10:15] If we do the same calculation for all mid laners, we can see that for every 0.1% spread that a mid laner's matchups has, it adds approximately 4.7% chance that they will be countered when they lock it in blind. Because of the discrete nature of this calculation, there's some deviation from that line, but all in all, it fits pretty well.
frames: 10:22 10:32

[10:33] So far, we've only been focusing on in lane matchups, and moreover, we haven't even talked about synergies. I think many players using stats websites put a lot of emphasis into countering their own lane, but don't think enough about the other lanes and synergies they should consider. When we plot the spread of Ahri's matchups against each other opponent's role, a very interesting thing happens. Her spread versus mid lane is by far the largest, where her spread versus bot lane is the lowest. >> [music] >> Let's recall again our definition for blind ability. Blind ability was a measure of how much champion cares if other champions are in the game with them. We've shown that spread is a really good measure for that, >> [music] >> and now we see that most of Ahri's spread is concentrated in the mid lane. That means she cares a lot more about what she's matching up with mid than she cares about what she's matching up with at the ADC position.
frames: 10:44 10:49

[11:21] If we look at her synergy spreads, it tells us the same thing, except about her teammates. This is useful information for Ahri, for sure, but I bet some of you see where I'm going with this. If we were to not just look at Ahri, but her entire role, and then look at the spread interactions versus other roles, we can tell which roles care the most about which other roles on the rift, both for opponents and for teammates.

[11:42] Here, I'm showing that in heat map form. Greener shades indicate that champions care relatively more about that matchup or synergy, where red cares they mean relatively less. The left heat map is matchups, and the right heat map is synergies. >> [music] >> Mid lane cares predominantly about its matchup in lane, but it also cares a lot about the enemy jungler. Synergy-wise, it cares most about its own jungler and a bit about the bot lane. Top lane always kind of makes me laugh. I've been checking in on this for years, and it's always shown the exact same thing, which is that top laners really only care about top lane and pretty much nothing else. I think the stereotype is that top lane is on an island, but it's actually absolutely correct. Jungle is interesting because for both matchups and synergies, it cares holistically about the entire team that it's facing or with more than any other position.
frames: 11:42 11:55 12:05 12:20

[12:30] It does have a special interest in playing with its mid and against opposing mid, as well as a direct matchup against the opposing jungler, but it's by far the most balanced role in terms of what it cares about on the rift. Bot laners basically only care about their matchup in bot lane and the interaction they have with their support. And finally, supports care about their ADC, obviously, but they also have a special relationship with their own and the opposing jungler. Taken together, I think this gives us really good insight into which positions care about which other positions during the draft phase.
frames: 12:40 12:45 12:58

[12:59] Okay, let's circle back to mid lane. This time, I'm going to show you matchup spread and synergy spread for mid lane on the same plot. You'll notice that there is some correlation. Champions that tend to be good into any matchup also tend to be good with any teammate, but you'll notice that some champions do deviate. For example, Malzahar doesn't care so much about what teammates he's with, but he really cares about the matchups, which makes sense for what we know about Malzahar. He counters some champions very hard. So, I've shown you which champions are safe to blind and which are not safe to blind, but I'd also like to look at what people think is okay to blind. Now, Riot doesn't share pick order, but I do know who's in every game, and I do know when champions are facing counter matchups versus good matchups.
frames: 13:01 13:05

[13:40] If I plot how often champions face good versus bad laning matchups, we can see that Yasuo by far faces the most counter matchups of any champion in mid lane. There are a few reasons why this could be the case. One could be the Yasuo players don't care about picking blind, even though it's not really that healthy for them. Another could be that they're not picking blind, they simply pick into bad matchups not caring about what that matchup is going to be. Technically, we can't tell the difference here. Even so, I do find it interesting that the top champions that end up with favorable matchups are a lot of counter pick champions. Galio, Taliyah, Vex, Lissandra. These champions are generally locked in in response to something else. And this data suggests that's generally how they get used. Conversely, Ahri more often than not is in a negative match up, which means that she's probably getting blinded a lot.
frames: 13:40

[14:28] I think that makes a lot of sense. Ahri is a well-known blind, and honestly, if you're picking blind, you should probably be picking Ahri. To see how well this holds,

[14:36] let's add match up consistency as a second access to this plot. We now have a scatter plot, [music] where in the bottom right are counter picks that shouldn't be blinded and aren't, and in the top left are champions that can be blinded and are. We see that most champions are actually being used in ways that are appropriate. The counter pick champions are facing better match ups than they would otherwise face, and the blindable champions are facing slightly worse match ups. There are some exceptions, and Yasuo is again one of them. He shouldn't be blinded, but the data suggests that >> [music] >> likely Yasuo mains are blinding him all the time. All in all, this means that the community as a whole has a pretty decent idea about which champions are blindable. There are some exceptions like Yasuo, but certain player bases are we'll call it eccentric. I do also want to address rank and mastery. My data is a little thin here, and if I get faster access, I'll be able to do a better job later.
frames: 14:36 14:41 14:45 15:01

[15:24] But for
frames: 15:24

[15:25] now, I can say that Ahri tends to be mildly more blindable at higher elos, while Yasuo tends to get less blindable. I think both of these make sense. And at a later time, when I've accumulated more games, I'll try to circle back and talk about this in detail. Okay, before I leave you, I want to talk about one more thing. I pulled from Oracle Elixir all of the champions in the 2026 pro scene that had above a 1% play rate in mid. Essentially, I want to see if pros follow the same logic that solo players do. Now, obviously, the pro meta is going to be different than the solo queue meta. >> [music] >> The champions that are played are different, how they interact might be a little bit different, and I don't have enough pro data from Oracle Elixir alone to fully lock down all of those differences. But we can just take a gander and see if they match what our data would predict. First, let's identify all the champions above a 1% play rate.
frames: 15:40 16:07

[16:11] Then we can color them by how often they get blinded in the pro scene. I'll get rid of the synergy blindability access because I assume in comp play, teams will have an idea of how they want drafts to unfold and instead I'll replace it with our solo queue match up consistency. Overall, we can see there's some agreement. There are definitely champions like Orianna and Ryze that we think are blindable and pros do too, but there are some that pros don't think are blindable. Anivia, LeBlanc, and Twisted Fate are used more as counter picks where in solo queue they're considered to be blindable. Some of the champions we think are counter picks the pros do too like Galio, Sylas, and Lissandra and all in all I think there's reasonable correlation here. And of course we don't actually know if the pros are right or wrong about what they're blinding. We simply don't have the data, but in solo queue we do have the data and now you know how [music] to
frames: 16:14

[16:56] read it. I think this is a good place to end our first machine lulling educational series video. All of the data will be available for you to explore the moment that Riot signs off letting me make it public, but while I'm in that holding pattern I'll try to keep circling back and making videos to show more and more of it. I'll release the blindability data for each of the different positions in short form videos >> [music] >> and once Riot approves my website will appear here on the screen or in the description or something like that. >> [music] >> You can also continue to see all of my old blog posts as well as my champion pool designer at machinlolling.com. But for now, I hope you enjoyed the video and I wish you the best of luck on the rift. >> [music] [music]
frames: 16:56 17:31 17:45

## Top 20 comments

- @MachineLoLing (uploader), 103 likes: Thanks for all the love! Here is my blog: machineloling.com . It has a few years of posts if you like to read and of my champion pool builder (new version will be on the new site).
- @MIKAEL212345, 403 likes: came for the league content, stayed for the mini stats lesson taught in an environment I have a lot of background knowledge in. incredible video. please keep them coming.
- @THESANDMAN1, 871 likes: HELLO what do you mean this is a first video. I was about to binge watch
- @isthiselevatorgoingup, 216 likes: Man I love good visualizations! This is so cool. So funny that yasuo mains are probably masochists lmao
- @Kaiss1, 134 likes: Channel has great potential
- @JakobMusic, 10 likes: Pleeeease Riot, give this guy all the Data and API Access he wants. This is phenomenal
- @EmDrei1, 568 likes: Top 3 LoL creator incoming 🔥 You guys are the best. Very easy to follow along, looking forward to the published data and the next videos!!
- @oldmanbanjo, 37 likes: Dude this is so good. None of the usual Claude fueled data analysis by people like me who did 101 bayesian. This like, actual info. I love it! Keep making videos.
- @Joshizam, 31 likes: What a good video! Glad to be a day one of you, looking forward to more videos like this!
- @wake-digital, 5 likes: Ok, but there's one problem with this whole thing. When you take the winrate of a champion like Yasuo, which you're way less likely to blind, that winrate obviously consists of favorable matchups way more, than the bad ones. This inflates "expected winrate", and your graph therefore shows him as less blindable. So ironically, your approach will show the most blindability for champions that are being blinded the most. Or am I getting something wrong?
- @DrTenma-xj3on, 26 likes: This guy used every method in my statistics course and I loved it
- @khoinguyen4455, 42 likes: Sylas can flex 5 roles 😂
- @chilliammcwilliam, 24 likes: I read your blog about two weeks ago and thought you'd be great at making videos. I'm really glad you've started to do so, subbed!
- @pootisman7660, 20 likes: I love seeing when lol creators are nerdy (in a good way) and explaining the whys than the when
- @Yamagataxd, 11 likes: Top lane next, let's see those nightmarish matchups
- @BP-vk2yn, 10 likes: Not gonna lie, I didn't look at the thumbnail and thought this was going to be a Teemo guide. I'm still down to watch though, seems interesting even if all I pick is Teemo.
- @hannahshoenhard783, 8 likes: This is quality content right here. Can't wait for this channel to explode
- @hylexia, 0 likes: This and your website are both extremely satisfying and something I've wished existed for over 10 years. You are a blessing, please keep it up!
- @alexboissonnas3732, 16 likes: awesome analysis, more of this please! really appreciated the visual aids so I could pretend I understood data terms
- @Moz31, 1 likes: i dont know why i assumed this video would be about which champion is the easiest to blind, as in removing their eyes
