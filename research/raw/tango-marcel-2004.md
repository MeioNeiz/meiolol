# Tango on Baseball

<https://tangotiger.net/archives/stud0346.shtml>

# Tango on Baseball Archives

© [Tangotiger](mailto:tangotiger@yahoo.com)

[Archive List](https://tangotiger.net/archives/studies.html)

****[The 2004 Marcels](http://www.tangotiger.net/marcel/)** (March 10, 2004)**

Here you go.

You will find the data for all batters for 2001 through 2003. This is simply an extract of the data you can get from the Lahman DB or baseball-databank.org. I removed all pitchers from the list of batters.

I also have the 2004 Marcels. They were calculated using the following process:  
1 - Weight each season as 5/4/3. 2003 counts as "5" and 2001 counts as "3".

2 - Determine each player's league average. I removed all pitchers' hitting totals from the league average. I lumped in AL and NL together. I weighted the player's league average using the 5/4/3 process and that's player's PA for that season. I then forced in that player's league average to come in at a total of 1200 PA for each player (2 weights x 600 PA). This is the regression towards the mean component.

3 - Add the above two.

4 - Determine the projected PA = 0.5 \* 2004PA + 0.1 \* 2003PA + 200. I take the result of #3, and prorate it to this projected PA.

5 - Determine an age adjustment. Age = 2004 - yearofbirth. If over 29, AgeAdj = (age - 29) \* .003. If under 29, AgeAdj = (age - 29) \* .006. Apply this age adjustment to the result of #4.

6 - Rebaseline the results against an assumed league average of 2003.

I have \*not\* verified my numbers. If you want to compare it to ZiPS and PECOTA, feel free. Any 2004 rookie with no MLB experience will project at the league average.

Please, only make a comment that the numbers are wrong if you have either:  
a - gone through this process step-by-step and have verified a problem  
b - compared the results of Marcel against those of ZiPS, PECOTA, DMB, etc and that the Marcel numbers are systematically off

  
Any error I would have done would be apparent on all players.

I might be able to do the pitchers next week.

Note: I do not stand behind these forecasts. These forecasts are the minimum level of competence that you should expect from any forecaster. Do not attach my name to these forecasts in any kind of evaluation experiment. They should only be referred to as Marcel The Monkey Forecasting System, or simply The Marcels.  
_\--posted by [TangoTiger](mailto:tom@tangotiger.net) at 02:27 PM EDT_

* * *

**Posted 2:39 p.m., March 10, 2004 (#1) -** **[Charles Saeger](https://tangotiger.net/archives/posters/Charles%20Saeger/index.shtml)([e-mail](mailto:rasputin@visi.com))**  
  Didn't Alfonzo Soriano age a few years? You still have him as 26.

**Posted 2:52 p.m., March 10, 2004 (#2) -** **[Rob S](https://tangotiger.net/archives/posters/Rob%20S/index.shtml)([e-mail](mailto:robls@adelphia.net))**  
  Thanks Tango.

**Posted 2:52 p.m., March 10, 2004 (#3) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  I forgot about that. I used the BDB. I'll update that one. I'll post a revised file on Friday in case there are other changes needed.

**Posted 2:56 p.m., March 10, 2004 (#4) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Hmmm... thanks Charlie. I see that I've got a bug in my age adjustments. I divided where I should have multiplied, and multiplied where I should have divided. This applies to all players.

Give me 5 minutes, and I'll reupload the whole thing.

**Posted 3:02 p.m., March 10, 2004 (#5) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Ok, the latest version is up. You know you've got the latest version if Sori is shown with an age of 28. I aged Soriano from a YOB of 1978 to 1976. If someone has the correct year of birth, let me know.

**Posted 3:35 p.m., March 10, 2004 (#6) -** **[bob mong](https://tangotiger.net/archives/posters/bob%20mong/index.shtml)**  
  Just to clarify: You have not made any park adjustments at any point in the calculations, correct?

**Posted 3:42 p.m., March 10, 2004 (#7) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Correct. I did only and exactly what I listed above. It should be possible for someone to independently verify my results using only the 2001-2003 data from the Batting table, and the Master table (from BDB or Lahman).

Consider this to be a good exercise to those who want to improve their Access/Query/SQL skills.

\*\*\*

I agree that park adjustments, "profile" adjustments (like strong, fast, smart, tall, skinny, athletic, etc) would be necessary to improve reliability.

**Posted 4:22 p.m., March 10, 2004 (#8) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  I added another column called "reliability". That shows how much of the forecast is based on his performance, and how much was regression towards the mean.

Bobby Abreu shows a .87. That means that I regressed towards the mean 13%. Using that, it should be easy enough to figure out a confidence interval for each of the stats. If I show a reliability of .00, this means that it is an absolute pure guess on my part.

**Posted 4:45 p.m., March 10, 2004 (#9) -** **[Stephen](https://tangotiger.net/archives/posters/Stephen/index.shtml)**  
  Thanks, Tango! I'd love to put these in Excel, but I'm not sure how to format them correctly. Something about text to columns...

Any help would be greatly appreciated.

**Posted 4:54 p.m., March 10, 2004 (#10) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Hmmmm.... since these are csv files, Excel should automatically parse it for you properly. When you see the link of the file, do a "right-click" and "save target as". Then, open up Excel, and from Excel, open this csv file. Excel should automatically parse it for you.

If Excel doesn't, then do the following:  
\- Data / Text to Columns  
\- select Delimited  
\- click Comma and set the Text qualifier to none  
\- click Finish

**Posted 5:11 p.m., March 10, 2004 (#11) -** **[Stephen](https://tangotiger.net/archives/posters/Stephen/index.shtml)**  
  Awesome, thanks again, Tango. Worked perfectly.

**Posted 5:32 p.m., March 10, 2004 (#12) -** **[Big Series](https://tangotiger.net/archives/posters/Big%20Series/index.shtml)**  
  I agree great work - I've already got hitting rankings by team out to the ol' league. Yeah.

**Posted 9:43 a.m., March 11, 2004 (#13) -** **[Rob S](https://tangotiger.net/archives/posters/Rob%20S/index.shtml)([e-mail](mailto:robls@adelphia.net))**  
  Does Marcel do hitting projections only?  
Or is there another friendly critter that does pitching quesstimates?

**Posted 11:39 a.m., March 11, 2004 (#14) -** **[bob mong](https://tangotiger.net/archives/posters/bob%20mong/index.shtml) ([homepage](http://vdub_bobby.blogspot.com/))**  
  _Posted 3:35 p.m., March 10, 2004 (#6) - bob mong  
Just to clarify: You have not made any park adjustments at any point in the calculations, correct?_

_Posted 3:42 p.m., March 10, 2004 (#7) - tangotiger  
Correct. I did only and exactly what I listed above._

I just brought this up because it will affect projections for some players more than others - namely, players who are going from pitchers' parks to hitters' parks or vice versa. Like Alex Rodriguez, Alfonso Soriano, anybody coming or going to Colorado, etc. Just something to keep in mind.

**Posted 12:57 p.m., March 11, 2004 (#15) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Agreed.

My intent is only to do what a monkey would do: the simplest forecasts possible: uses last 3 years of data weighted, regression, and age.

(Feel free to quibble that this monkey is too smart for a monkey.)

**Posted 5:29 p.m., March 11, 2004 (#16) -** **[David Smyth](https://tangotiger.net/archives/posters/David%20Smyth/index.shtml)**  
  ---"(Feel free to quibble that this monkey is too smart for a monkey.)"

Well, you make this point in mild jest, and my middle name is quibble, but...

yes. The monkey designation carries the popular implication of "randomness". It would be silly to make random baseball predictions, so the next step up would be last year's performance. Using age, multiple years, weighting, and especially regression is not really so basic. In fact, I expect that some published forecasters do less...

Nothing wrong with what you're doing--just a poor terminology choice.

**Posted 6:36 p.m., March 11, 2004 (#17) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  No, it's just like the stock market. The stock price is based on all known information. What the price will be in 1 year is, for all intents and purposes, random. A monkey picking a stock to improve is like a monkey picking a player to perform better than his Marcel forecast.

**Posted 7:39 p.m., March 11, 2004 (#18) -** **[David Smyth](https://tangotiger.net/archives/posters/David%20Smyth/index.shtml)**  
  Alright then, Tango, I take it all back. :-)

**Posted 10:09 a.m., March 12, 2004 (#19) -** **[Nod Narb](https://tangotiger.net/archives/posters/Nod%20Narb/index.shtml)**  
  _5 - Determine an age adjustment. Age = 2004 - yearofbirth. If over 29, AgeAdj = (age - 29) \* .003. If under 29, AgeAdj = (age - 29) \* .006. Apply this age adjustment to the result of #4._

Am I reading this right? Those over 29 are expected to improve and those under 29 are expected to decline? Shouldn't it be (29 - age)?

**Posted 10:23 a.m., March 12, 2004 (#20) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Yup, it should be 29 - age. That was the bug I reported in post #4.

\[an error occurred while processing this directive\] **Posted 12:51 p.m., March 13, 2004 (#22) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)([e-mail](mailto:tom@tangotiger.net))**  
  If you are asking if there's anything of the mundane things that I do that I'd like to take off my plate (like updating the Team Previews file, or my Primate Index file, or formatting MGL's superLWTS file \[I don't have time for that one\], etc), sure! If that's what you'd like to do, then email me.

**Posted 4:20 p.m., March 13, 2004 (#23) -** **[Snowboy](https://tangotiger.net/archives/posters/Snowboy/index.shtml)**  
  Thanks for the work, Tango.  
I'm sorry to focus on one player out of 839, because I know that's not what you want to hear. But what's going on with Carlos Beltran?  
    3YrAvg     Marcel  
Runs   107        91  
HR      26        22  
RBI   102        87  
SB      35         27

580 PA is not a problem. I can't find an error (ie other Royals look okay, his numbers are all there in the 01-03 file, Adrian Beltre's numbers look reasonable). But something doesn't look right? What does Marcel see that I can't? Is Marcel scared of only 14 doubles in 2003?

**Posted 4:22 p.m., March 13, 2004 (#24) -** **[Snowboy](https://tangotiger.net/archives/posters/Snowboy/index.shtml)**  
  Oh, and reason #281 to use your own brain, and not just live by Marcel alone: Predicted HR by Jason Tyner = 3.

But again, thanks Tango.

**Posted 4:14 p.m., March 15, 2004 (#25) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Ok, let's look at Carlos Beltran's HR forecast.

From 01 to 03:  
HR: 24, 29, 26  
PA: 680, 722, 602

lgHR/PA: .0300, .0279, .0285

\*\*\*  
Weighting his numbers on a 3/4/5 level, and we have:  
HR: 318  
PA: 7938

The league numbers would be:  
.0300x680x3, .0279x722x4, .0285x602x5 = 228. That's the league mean HR for Beltran's 7938 PAs. Set this to 1200 PAs, and we have 34.4 league HR.

\*\*\*  
HR: 318 + 34.4 = 352.4  
PA: 7938 + 1200 = 9138

Or, HR/PA = 352.4/9138 = .0386

Those are Beltran's expected rates

\*\*\*

We are projecting Beltran at:

PA = 602\*.5 + 722\*.1 + 200 = 573 PA

\*\*\*

573 PA x .0386 HR / PA = 22 HR

\*\*\*

Beltran is 27, so the age adjustment has almost no impact.

\*\*\*

See, the thing with Beltran is that he had an ENORMOUS number of PAs in 2001/2002. The projected PA for 2004 is HEAVILY influenced by his PAs in 2003 (rightly or wrongly).

His simple average number of PAs in 2001-2003 is 668 PAs, or almost 100 more PAs than I'm projecting him for. Give him 4 HR in those number of PAs, and you get to 26. And that's matches his average.

**Posted 1:10 a.m., March 16, 2004 (#26) -** **[Miko](https://tangotiger.net/archives/posters/Miko/index.shtml)**  
  I have a question about the age adjustments in the scheme.

If one applies the age adjustment to all components (prorated to the projected PA), doesn't this result in nudging the counting stats up or down, leaving the resulting rate stats unchanged?

If this is the case, then are improvements/declines due to age more or less taken care of by the weighted averaging? Or is it just that the system as is is accurate enough given the relative ease of calculating results?

**Posted 11:44 a.m., March 16, 2004 (#27) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  To everything, except PA and AB.

I actually have to fix that... it should be RATIOs relative to batting outs (AB-H), and not per PA.

**Posted 12:33 p.m., March 22, 2004 (#28) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Ok, I have completed the 2004 Marcels for pitching. FTP is currently down, so I'll have to wait until that opens up.

It follows the exact same process as the Marcels for batting. Here are the particulars that are different (which you can line up with the top of this thread).

1 - Weights are 3/2/1.  
2 - Removed nonpitchers pitching totals (i.e. Wade Boggs as a pitcher.)  
3 - same  
4 - used IP instead of PA. Change "200" to 25 for relievers and 60 for starters (or something in between for part-time starters based on GS/G).  
5 - Same  
6 - Same

Now, I need to make one final modification. Pitchers in the NL have a .2 or .3 ERA advantage (and big-time K advantage) over their counterparts in the AL (because of the DH). To make better forecasts, I need to know whether the pitcher is currently in the AL or NL. Right now, I have lumped everyone into the same league.

If someone wants to help me out, download the files (after I post them), and send me a csv file of all pitcherid and their leagues.

If I get no takers for this, I will repost the files with my own markings of a player's current league: last league pitched in. I'm not keen of going through each pitcher manually afterwards, like Clemens and Vazquez. Marcels will just have to be a little off on those.

As well, I added a category called bsrER, which is the "component" ER, based on BaseRuns. The ERA column is a 50/50 split between the mER column and bsrER columns.

That's it...

**Posted 4:44 p.m., March 22, 2004 (#29) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Ok, they are all there now! For pitchers, I used "last league pitched in" as the baseline. So, for guys like Vazquez and Clemens, you'll have to mentally adjust them slightly. Over the last 3 years, the ERA in the AL was 0.25 higher than in the NL.

Per 9 IP, the HR rates are similar. 0.5 more K and 0.2 more BB in the NL. That's kind of weird. I'd expect more K because: pitchers batting and more HR allowed. I'd expect more BB because: more K and HR. I'd expect fewer BB because: pitchers batting. I'm surprised that the BB rate increased as much as it did.

If I make any changes, it will be before Opening Day. After that, that's it.

**Posted 4:45 p.m., March 22, 2004 (#30) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Btw, for W/L, be careful! You need to look no further than Javier Vazquez to see how useless it is.

**Posted 5:45 p.m., March 22, 2004 (#31) -** **[studes](https://tangotiger.net/archives/posters/studes/index.shtml) ([homepage](http://www.baseballgraphs.com/))**  
  Great job, Tango. Question: did you think of taking a FIP/DIPs approach to the pitching stats? Or would regression to the mean take care of that, in theory?

**Posted 3:23 p.m., March 23, 2004 (#32) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  Since we are after the pitcher's ERA, that includes the hits allowed by his fielders. FIP/DIPS wouldn't apply here.

\*\*\*

I have added a file called: jtoMarcel.zip. This contains an Access 2000 database for the Marcel for 2001 to 2003. My program is now setup to generate the Marcels for any year in history. (It takes about 2 minutes to generate the data for each year.) Not now, but eventually, I might generate them for every year. It might be useful as a way for other forecasters to improve their engines.

**Posted 7:13 a.m., March 25, 2004 (#33) -** **[studes](https://tangotiger.net/archives/posters/studes/index.shtml) ([homepage](http://www.baseballgraphs.com/))**  
  I was thinking that a FIP/DIPS approach is a better way to predict ERA than using the previous three year's ERA. Take out the BABIP over the last three years, average and regress your result, and then add them back in.

**Posted 9:52 a.m., March 25, 2004 (#34) -** **[tangotiger](https://tangotiger.net/archives/posters/tangotiger/index.shtml)**  
  The best way would be some combination of:  
\- past ERA  
\- component ERA (BaseRuns)  
\- DIPS/FIP

Tom

* * *

* * *
