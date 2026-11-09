# A letter to our users. Hey Everyone! | by Mobalytics | Mobalytics | Medium

<https://medium.com/mobalytics/a-letter-to-our-users-425f0520f1b7>

[

Write

](https://medium.com/m/signin?operation=register&redirect=https%3A%2F%2Fmedium.com%2Fnew-story&source=---top_nav_layout_nav-----------------------new_post_topnav--------------------)

[Sign in](https://medium.com/m/signin?operation=login&redirect=https%3A%2F%2Fmedium.com%2Fmobalytics%2Fa-letter-to-our-users-425f0520f1b7&source=post_page---top_nav_layout_nav-----------------------global_nav--------------------)

[

## 

Mobalytics

](https://medium.com/mobalytics?source=post_page---publication_nav-4fe7c16c3a87-425f0520f1b7-----------------------------------------)

1.  [Here’s our TL;DR for the 11 topics we’ll be covering:](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#ee6a "Here’s our TL;DR for the 11 topics we’ll be covering:")
2.  [Topic 1: We need Ekko and Zilean…](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#7b04 "Topic 1: We need Ekko and Zilean…")
3.  [Topic 2: Resources and priorities…](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#f645 "Topic 2: Resources and priorities…")
4.  [Topic 3: Why haven’t we added Normal and Flex games yet?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#bf2d "Topic 3: Why haven’t we added Normal and Flex games yet?")
5.  [Topic 4: What about the problems with the GPI? Why aren’t my scores accurate?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#12d5 "Topic 4: What about the problems with the GPI? Why aren’t my scores accurate?")
6.  [Topic 5: Aggression (probably our biggest culprit)](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#b51e "Topic 5: Aggression (probably our biggest culprit)")
7.  [Topic 6: Fighting (probably our second biggest offender)](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#182c "Topic 6: Fighting (probably our second biggest offender)")
8.  [7\. What’s the deal with Kill Stealing?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#ec19 "7. What’s the deal with Kill Stealing?")
9.  [Topic 8: What’s the deal with Build?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#feae "Topic 8: What’s the deal with Build?")
10.  [Topic 9: What’s up with the advice being so…hit or miss?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#2c27 "Topic 9: What’s up with the advice being so…hit or miss?")
11.  [10\. Why isn’t the Post Game more accurate?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#e01a "10. Why isn’t the Post Game more accurate?")
12.  [11\. Why can’t I get more info in the Dashboard?](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#c275 "11. Why can’t I get more info in the Dashboard?")
13.  [Closing Thoughts](https://medium.com/?source=post_page-----425f0520f1b7-----------------------------------------#cd5f "Closing Thoughts")

Mobalytics is the first personal performance analytics for competitive gamers.

# A letter to our users

[Mobalytics](https://medium.com/@Mobalytics?source=post_page---byline--425f0520f1b7-----------------------------------------)

13 min read

·

Oct 9, 2017

Hey Everyone!

It’s been a wild ride since we opened our beta to all our users. We’ve had a tremendous amount of people join, and are approaching the 300k mark! The feedback has been overwhelmingly positive, but we don’t want you to think that we’ve been [blinded by the hearts.](https://youtu.be/DdPmqNRNsbs?t=21s)

On the contrary, we’ve seen and heard all the the criticism, constructive feedback, and negative feedback. Our vision is crystal clear!

We talk about it every day, EVERY hour. It’s in our Slack, it’s in our League games, and it’s in my sleep. The purpose of this letter, should you decide to read through it (I won’t be sad if you decide to go play League instead), is to tell you what we’ve been up to and why things sometimes take so long.

For those of you that like it short and sweet…

## **Here’s our TL;DR for the 11 topics we’ll be covering:**

**1.** **Things take a while to fix** because we have so many things to work on and our team is small.

**2.** **Our resources are limited** so we really have to choose our battles wisely.

**3.** **Normal and Flex games** are more complex to add than you think, but they’re right around the corner!

**4.** Remember that the **GPI** primarily **illustrates your play style** and what you can improve. Scores don’t necessarily mean you’re a “good” or “bad” player.

**5.** **Aggression** is too swingy and isn’t fulfilling our original intent, it will be going through a revamp to make it more accurate and “feel” better overall.

**6.** **Fighting** is also swingy, we will be making changes to make it better incorporate all types of fights and lean less towards team fighting.

**7.** Our intent for **Kill Stealing** isn’t being fulfilled — we will be renaming and re-purposing it to make it more understandable for our users.

**8.** We failed in properly conceptualizing our **Build metric** and we’ve realized that it doesn’t yield effective actionable advice. We’ll be making tweaks to it but in the future, we’ll be leaning more toward measuring metrics that can be actionable.

**9.** We know our **advice** can be much better and we know that one bad assigning of one can make you question the whole system. We’re constantly working hard to make our advice more relevant and specific so please bear with us as we go through our beta growing pains.

**10.** We know our **Post Game** can be better and we are figuring out how to best improve it.

**11.** Our **Dashboard** is still far from its final form, more stuff will be added soon! Those 0’s in **Consistency** and **Versatility** are a bug that we are working on fixing. We also need to find a way to represent single game performances more accurately.

If you want a deeper dive into the [inner machinations of our minds](https://youtu.be/KNZSXnrbs_k), adventure on! Feel free to jump around to the topics you care about — I will be technical, but not too technical (probably because I’m not a developer). We’ll be covering a few big issues and some answers to questions that we frequently receive.

## **Topic 1: We need Ekko and Zilean…**

Let’s start with the obvious, why does it take _so long_ for us to fix seemingly small bugs like the wrong CS number for Junglers showing in the Post Game, or Consistency and Versatility being 0 in some Dashboard games, or our terrible log-in bugs!? Before I was in Mobalytics, I could also never understand why it took companies like Riot and Blizzard seemingly forever to fix small bugs on champs.

Press enter or click to view image in full size

These damn zeros have haunted us since the birth of the Dashboard

Yes, I am not a developer, so although I could comprehend that sometimes things are more complex than they seem, I couldn’t quite grasp the extent of it. Like playing against a good Fiora for the first time, you can’t understand it till you experience it. Let’s just say I have a new respect for the companies that make these games (and Fiora!), and make sure that for the most part, everyone is able to log in, play, and enjoy crisp gameplay every day. Hats off.

## **Topic 2: Resources and priorities…**

As a small company, we have limited resources. We can’t research every tech tree possible and we have to really focus on what’s in front of us. If we want to fix some bug that really isn’t that simple, we have to delay our new features… so we find ourselves in constant conversations of, _how important is it really_? Is it more important than adding ranked and normal games? Is it more important than reviewing and fixing Aggression? Is it more important than a desktop app? Can I just play league and farm my jungle all day as Shyvanna instead? Please?

## **Topic 3: _Why haven’t we added Normal and Flex games yet_**_?_

For you, using this feature would be really simple. You would select the type of game you want through a filter, and view your GPI in that game mode. You’d be able to compare and combine games from multiple game types.

The reality is…for us, this is a lot more complex. Our databases and server load increased at a tremendous rate as our users grew rapidly. The way different parts of our product interact with each other and Riot’s servers required that we segment appropriately to continue to pull and store a ton of data in anticipation for Normal and Flex games.

Making sure everything works together cohesively and allows us to continue to grow is no easy feat, and this not accounting for random bugs that may appear.

That being said, know that it is right around the corner! It is definitely on the top of our list of features requested by our users. What’s important to you is important to us.

## **Topic 4_: What about the problems with the GPI? Why aren’t my scores accurate?_**

I’m going to go through all of the major parts that we aren’t happy with, and what we are doing about it. Obviously these are also the parts that you are the least happy with too.

Before I go into each metric specifically, something I want to make very clear is that the GPI was NOT designed for someone to get a 100 in everything to be a great player. It was designed to identify your play style and what you are good or bad at. You do not have to be an aggressive player if you don’t want to - we want you to understand that you _could be_ though if you wanted to.

I can’t stress this enough. We have realized that this message is not clear throughout different parts of our platform so we are reworking different parts of the product to make sure that message is clear.

With that in mind, let’s go through some of the biggest questions marks in our following topics…

## **Topic 5: Aggression (probably our biggest culprit)**

**Original Intent:** The design philosophy behind aggression was to understand what players are being aggressive on average throughout their games

-   How often do they get First Blood or First Turret?
-   How much damage do they put out for their role?
-   How often do they successfully take solo engagements?
-   How much pressure do they exert on the map if they get an early lead?
-   Do they zone well when they are ahead?
-   How aggressively do they build?

**What went wrong?**

The Post game really exposed some of the flaws with the way we were calculating and weighing our scores.

On a single game basis, our scores were way too binary, and people were getting an aggression score of 0 far too often. This was due to our focus on early plays and First Blood.

On average, you will get a good score if you are more aggressive than players on a regular basis. However, in a single game, being compared to an average standard, a binary score like First Blood or being ahead is going to result in a zero.

## Get Mobalytics’s stories in your inbox

Join Medium for free to get updates from this writer.

Remember me for faster sign in

**How do we plan to fix this?**

-   First Blood is a bad metric to gauge Aggression, especially in Solo Queue since players don’t always have control over how this goes down.
-   Now we look at your time to kill. Players who kill earlier are more aggressive and look for opportunities sooner.
-   We are using better inference algorithms to look at your position during the game and specifically your kills to understand how aggressively you are playing/diving
-   We have improved how we assess whether someone is ahead. Rather than a single point at 10 or 15, we look at the cumulative to see if you really had a lead.
-   We use a coefficient to account for champion biases in damage, so that we can look at how aggressively you play more accurately rather than how much damage does your champ kit put out.
-   We reworked build and mitigated the influence it had. More on build later.

Press enter or click to view image in full size

Aggression and Fighting were too swingy, it could seem almost impossible to impact them sometimes

## **Topic 6: Fighting (probably our second biggest offender)**

Original Intent: The design philosophy behind Fighting was to understand how often and how well you fight, specifically team fights.

-   What is your kill and assist participation?
-   What is your team fight participation?
-   How much do you contribute in team fights, doing damage or taking damage depending on your role?
-   Most importantly, how often do you die and how early into the fights do you die, your team fight survivability?

**What went wrong?**

-   Again, the Post Game really exposed some of the flaws with the way we were calculating and weighing our scores.
-   Again, on a single game basis, our scores were way too binary, getting super low Fighting scores way too often, although for entirely different reasons than Aggression.
-   We were assessing your ability to fight in team fights, but some games don’t have team fights (5+ players from both teams with 2+ deaths), and that really hurt the factors we can draw from for your score
-   On average, you will get a good score if you fought often and well, but there are games you are losing badly and it’s really hard to get any type of Fighting score.
-   There are also games where you take only one team fight and you do poorly, giving you one hell of a shitty score.

**How do we plan to fix this?**

-   We haven’t worked this out as well as Aggression yet but our major focus is to shift the scoring towards specifically how well you fight in all types of fights, not just team fights.
-   How well do you fight when behind and ahead? Looking at conditions around each fight will help us figure this out and move away from binary scores with not enough information.

Worst-named score NA

## **7\. What’s the deal with Kill Stealing?**

Kill Stealing is probably the most inappropriately named metric of all time. I don’t know what we were thinking in hindsight, but we wanted to choose something…familiar to players. Our intent was to measure if you are doing enough damage throughout the game to warrant the number of kills you are getting.

What we did learn from this skill is that very few people hover over our metrics to read the descriptions (feelsbadman). Choosing something with a familiar name, but making it something else will lead to a disaster… even if you specifically say that, “This is not getting the last hit to steal the kill”, in the description. Any suggestions on how to rename it? “Kill to Damage Ratio” seemed a little… meh.

There is also another problem with the metric. When you get a crazy game with like 20 kills, the denominator standards placed in the formula don’t quite catch up as easily so it is very hard to have enough damage to justify your kills. This is something we will fix soon, now that we have identified it.

Most importantly, this is not a critical score for your overall teamplay score, so please don’t think it’s holding you back in any way. We put a lot more weight on your participation in objectives and other map activities.

## **Topic 8: What’s the deal with Build?**

The original design behind build was to tell people how often they build spec and choose champions in a specific way. Are you, or the person you are researching, an all out aggro player whose most defensive item is a phantom dancer? OR are you looking at a player who always plays tough tanky champs and buys all tank items? Most likely you are on a scale somewhere in between.

In that goal we succeeded reasonably well. Where we failed miserably is realizing although this property might be cool to measure, it is not suitable for giving people actionable advice. This is quickly apparent when you play similar champs in their optimal way; your score will always look the same! No one know this pain more than me, I play Shyvanna every game with the same build practically (slight variations). The Item Build score in Versatility was intended to talk about these variations, BUT although it works as intended, and it gives a reasonably correct score, again it is not actionable.

In the future what we will be doing is moving away from giving advice for build and pushing more actionable metrics to the front end. We will still gather and calculate this data BUT we will not be using it to advise people on how to improve, not right now anyways.

## **Topic 9: What’s up with the advice being so…hit or miss?**

The above categories tell part of the story why we were unable to give you advice successfully, but there’s more to it than that. Our system is complicated and tries to give advice to everyone and someone all at once. You can read more about how we craft our pieces [in this article.](https://mobalytics.gg/blog/how-mobalytics-gpi-advice-is-created-and-given-to-you/)

Advice is a tricky thing because players will read one inappropriate tip and then quickly dismiss the entire system and website as shit. What are the problems that can lead to poorly-given assignments?

-   Bugs in data acquisition path and system mismatches were very common when we were switching our servers and upgrading our infrastructure. Most of these have been cleaned up, but we are still finding some.
-   Most of the real problems arise when players play in a very specific style, and the insights are not applicable to them. _I play Shaco Top every game and I split push, why are you telling me I don’t help my team enough?_ To that guy, we say sorry! Our algorithms aren’t good enough yet to reliably detect that is his play style and give him the correct advice.
-   The worst problems arise when the information is too general for the user. This is inversely correlated to their skill. Getting more specific advice into the system will be a long process, especially for the higher level players.

What do we plan to do? Make more and more advice. Make them smarter and more specific. Since the GPI is the lifeblood of our system, it’s also the hardest part to get right, so this will be a lifelong journey. The system will always evolve and get better.

How can you help? Make sure to thumbs up and thumbs down advice you see. Reach out to us and tell us when you think a piece is bad (thanks for doing this already). If you thumbs up and down enough advice, we will definitely reach out to you for additional feedback!

## 10\. **Why isn’t the Post Game more accurate?**

We love the Post game, and think it’s a vital part of our tool. It’s so important to know how well you did in that specific game. Most good players can look at the stats in the client and walk away with a strong idea of the game. We wanted to paint a more clear picture and make it even easier to see what happened. It’s also incredibly satisfying to see how you stacked up compared to your lane opponent, and your usual self.

What went wrong? A lot of the scoring standards we created for our GPI were based off how well people do on average. We touched on this when talking about aggression and fighting, but it affects all the stats.This makes a lot of single games more spiky than they should be.

We also have a lot of conditional scores that work out on average. For example, we can’t tell you how well you play ahead from behind if you are never behind. We can’t tell you how you aggressively you zone if you’re never ahead to zone! This creates problems for evaluating specific aspects of some scores in individual games. Not to mention that Consistency and Versatility are not something evaluated on a single game basis.

What are we doing to fix this? We haven’t fully decided, but we want to create more accurate single game standards to judge performance by. We also want to be able to show you your mistakes more clearly and allow you to review them whenever you want.

## **11\. Why can’t I get more info in the Dashboard?**

The real answer to this question is the time that we have to work on it. The original goal with the Dashboard was to provide you with a home or match history to look at every single one of your games in more detail, and more importantly to see how you have progressed over time.

Press enter or click to view image in full size

Nowhere near its FINAL FORM

Right now the graph feature is not as fleshed out as we would like. We want people to be able to manipulate multiple time windows and compare their performance in those windows. We recently added the ability to see your Pre Game in addition to the Post Game, and as we add more features to the Pre Game, you can review the prep for the game in addition to the breakdown.

Most importantly, once we solve the issue with how to approach Consistency and Versatility on a single game basis, we will be able to get rid of the glaring bug that makes them zero in every game.

## **Closing Thoughts**

Every decision we make (or don’t make) has gone through a process of brainstorming/showerthinking, arguing about whether or not it’s worthwhile (especially our RnD team), and an attempt to implement and execute it. Between these three major steps, things can and do go wrong. Sometimes our ability to argue why an idea is good may be better than the idea is. Our idea may be there, but we may not have the resources to accomplish it according to the original concept, or without the amount of polish that we hold ourselves to. The feedback and testing from our community is really what ties it all together.

We really, really want everyone to get the most use out of our platform, and enjoy their time on it. Rather than be frustrated by what each metric means, we want to be able to present the information in a concise and uncluttered way for people to better understand and digest. We also want to be able to provide precise details for those who want them. In the future we will be publishing detailed descriptions of all our scores and how we approach them. I think if we can come up with a format similar to how Blizzard did their advanced tooltips for Diablo 3, we’ll be much closer to where we want to be.

_Sincerely,_

Uthgar, Mobalytics Warchief of Science

[

## Written by Mobalytics

](https://medium.com/@Mobalytics?source=post_page---post_author_info--425f0520f1b7-----------------------------------------)

[220 followers](https://medium.com/@Mobalytics/followers?source=post_page---post_author_info--425f0520f1b7-----------------------------------------)

·[142 following](https://medium.com/@Mobalytics/following?source=post_page---post_author_info--425f0520f1b7-----------------------------------------)

Personal performance analytics and improvement tools for competitive #MOBA gamers.

[

## Published in Mobalytics

](https://medium.com/mobalytics?source=post_page---post_publication_info--425f0520f1b7-----------------------------------------)

[100 followers](https://medium.com/mobalytics/followers?source=post_page---post_publication_info--425f0520f1b7-----------------------------------------)

·[Last published Jan 22, 2019](https://medium.com/mobalytics/lessons-learned-from-2018-a-mobalytics-retrospective-56a112a85572?source=post_page---post_publication_info--425f0520f1b7-----------------------------------------)

Mobalytics is the first personal performance analytics for competitive gamers.

## No responses yet

Write a response

[

What are your thoughts?

](https://medium.com/m/signin?operation=register&redirect=https%3A%2F%2Fmedium.com%2Fmobalytics%2Fa-letter-to-our-users-425f0520f1b7&source=---post_responses--425f0520f1b7---------------------respond_sidebar--------------------)

[

Help

](https://help.medium.com/hc/en-us?source=post_page-----425f0520f1b7-----------------------------------------)

[

Status

](https://status.medium.com/?source=post_page-----425f0520f1b7-----------------------------------------)

[

About

](https://medium.com/about?autoplay=1&source=post_page-----425f0520f1b7-----------------------------------------)

[

Careers

](https://medium.com/jobs-at-medium/work-at-medium-959d1a85284e?source=post_page-----425f0520f1b7-----------------------------------------)

[

Press

](mailto:pressinquiries@medium.com)

[

Blog

](https://blog.medium.com/?source=post_page-----425f0520f1b7-----------------------------------------)

[

Store

](https://medium.com/store)

[

Privacy

](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=post_page-----425f0520f1b7-----------------------------------------)

[

Rules

](https://policy.medium.com/medium-rules-30e5502c4eb4?source=post_page-----425f0520f1b7-----------------------------------------)

[

Terms

](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=post_page-----425f0520f1b7-----------------------------------------)

[

Text to speech

](https://speechify.com/medium?source=post_page-----425f0520f1b7-----------------------------------------)

## Be the first to hear about new stories from Mobalytics

#### Join Medium for free to get updates from Mobalytics sent right to your inbox.

Your email

Remember me for faster sign in

Already have an account? 

By clicking "Create Account", you accept Medium's [Terms of Service](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=register-----425f0520f1b7-----------------ea3ddcb4cc65----subscribe_to_author--------------------) and [Privacy Policy](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=register-----425f0520f1b7-----------------ea3ddcb4cc65----subscribe_to_author--------------------).

This site uses reCaptcha and the Google [Privacy Policy](https://policies.google.com/privacy?source=register-----425f0520f1b7-----------------ea3ddcb4cc65----subscribe_to_author--------------------) and [Terms of Service](https://policies.google.com/terms?source=register-----425f0520f1b7-----------------ea3ddcb4cc65----subscribe_to_author--------------------) apply.
