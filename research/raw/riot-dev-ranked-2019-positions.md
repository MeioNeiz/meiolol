# /dev: Addressing Your Feedback on Ranked for 2019 – League of Legends

<https://web.archive.org/web/20191103223223/https://nexus.leagueoflegends.com/en-us/2018/06/dev-addressing-your-feedback-on-ranked-for-2019/>

[Explore  
League](https://na.leagueoflegends.com/en/)

League of Legends

[Home Explore League of Legends](https://na.leagueoflegends.com/en/) [News Catch up on League news](https://na.leagueoflegends.com/en/news/) [Game Learn about League](https://na.leagueoflegends.com/en/game-info/) [Universe Explore the League universe](https://universe.leagueoflegends.com/en_US/)

[Nexus Look behind the scenes of League](https://nexus.leagueoflegends.com/) [Esports See pros battle for glory](https://www.lolesports.com/en_US/) [Community Connect & Contribute](https://boards.na.leagueoflegends.com/en/) [Support Get the help you need](https://support.riotgames.com/hc/en-us)

Riot Games

[Merchandise Equip yourself IRL](https://na.merch.riotgames.com/en/)

Nexus [Overview](https://nexus.leagueoflegends.com/en-us/) [Champions](https://nexus.leagueoflegends.com/en-us/search/champions/) [Ask Riot](https://nexus.leagueoflegends.com/en-us/search/ask-prcnt-20riot/) [/dev](https://nexus.leagueoflegends.com/en-us/search/-prcnt-2Fdev/)

[Play Now](https://signup.na.leagueoflegends.com/en) Login

North America (English)

# Ask Riot

Ask a question about League or Riot, and we’ll try to answer it. Answers go live every other Thursday at 1:30 pm (PT)

Thank you for submitting a question!

Next Article

[Gameplay](https://nexus.leagueoflegends.com/en-us/search/gameplay/)

# /dev: Addressing Your Feedback on Ranked for 2019

We’re back to address your questions about competitive integrity, matchmaking, and grindiness.

By [Riot SapMagic](https://nexus.leagueoflegends.com/en-us/search/riot-prcnt-20sapmagic/)

a year ago

Hey everyone! Ed “SapMagic” Altorfer, the lead for Ranked, back again. A couple weeks ago **[we recapped the feedback we heard from you](https://boards.na.leagueoflegends.com/en/c/developer-corner/QTXRJ9fj-what-we-heard-on-ranked-2019)** on our initial announcement about **[updates we’re making to Ranked next year](https://nexus.leagueoflegends.com/en-us/2018/04/dev-updates-to-ranked-for-2019/)**. Since then, we’ve been hard at work refining solutions to mitigate the biggest concerns you—and frankly, we—have about the experience.

We believe positional matchmaking and ranks can give you fairer games and meaningful ways to challenge yourself. At the same time, we heard an important piece of feedback from you that we agree with: Win or lose, every game reflects your skill and _needs to matter_ regardless of the position or champion you’re playing. The changes we’re discussing today are aimed at making sure the system reflects **both** of these goals.

## **You’re worried other players won’t take games seriously.**

### **Solution: Wins and losses in Ranked will splash LP to all other positions. Splashing starts moderate (around +6/-3) and can become stronger when you win Autofill games or if it looks like you’re not taking off-position games seriously.**

  
Position ranks and positional matchmaking promise to let you challenge yourself with fair games in off-positions without hurting the accuracy of your main. We’ve been worried for a while that completely separate ranks make the system more grindy and create concerns about competitive intent—which is to say, some players won’t try as hard in off-position games.

We’re adding a mechanic called **splashing**, which reinforces how every game reflects your skill while preventing abusers from ruining off-position games. It works like it sounds: At the end of each game, you’ll splash some LP to your other positions based on your normal gains and losses for the position being splashed to. Bear in mind, we’ll likely tune these numbers over time, but let’s talk about a couple examples of how this works:

### **Example — Getting autofilled**

Let’s say you’re a Silver mid main and you’re usually earning around 20 LP for a win. You queue up for a game and get autofilled to support. Winning that game will net you around 6 LP for top and jungle and 10 LP for your main since you didn’t get to play it.

### **Example — Getting unlucky (or trolling)**  

On the other hand, maybe you’re that same mid player and you’re on a losing streak trying to climb in top. The strength of splashing is determined by the number of losses out of the last X games. At first you’ll splash around -3 to your other positions, and that splashing scales up to around -15 if you’re supremely unlucky—or trolling, but we know you wouldn’t do that.

## **You’re worried positional matchmaking can be abused.**

### **Solution: The MMRs for all your positions are linked together. Occasional position swapping doesn’t have any effect, but repeated trading tightens the link, meaning you’ll get matched in harder games when playing off-positions.**

  
Positional matchmaking can help us make huge improvements to how fair games feel when you get autofilled or decide to challenge yourself in new ways. Having said that, there are clearly some big problems to solve—players could consistently trade positions with a duo partner or queue up in new positions and stomp lower-skill players.

Similar to splashing, we can mitigate these problems by **linking** **the MMRs** for all your positions. To start, that link has some slack, but we tighten it if we’re less confident about the position you’re playing.

### **Example — Playing a New Position**

Imagine you’re a Gold mid main. If you decide to go play a new position like top, matchmaking will look at your MMR in mid and other positions to estimate your initial skill. That means instead of getting put into a Bronze game, you’ll likely play a Silver game.

### **Example — Frequent Trading**

Let’s say you’re the same player and your duo hits you up. They play top and suggest you queue up for each other’s positions and trade so you can get easier games. It takes a game or two for us to see a pattern of trades, but for those games we’ll detect that you traded positions and adjust accordingly—you’ll have decreased LP gains and increased losses since your team was favored to win. After that, the link between your MMRs will tighten and you’ll get matched in Gold games regardless of the position you’re playing.

While it _does_ take a couple games to tighten the MMR link and stop abuse, those games should be about the same quality as today because we don’t currently consider position skill in matchmaking.

## **You’re worried we’re making Ranked too grindy.**

### **Solution: We’re softening the season reset so most players will have a higher initial rank. When playing off-positions, you’ll have LP splashing, increased LP gains and decreased losses, and Promo Helper for every series, which means you’ll get promoted more quickly.**

  
Position ranks let players branch out and challenge themselves in new ways, but that might not feel rewarding if it takes twice as many games to reach your rank across two positions, let alone three, four, or all five. Alienating fill players would be a pretty clear failure to meet one of our goals: to give_better_ recognition for breadth of skill.

We believe we can address this concern using several mechanics we’ve already built into Ranked. We want players to be able to climb to their peak skill in two or three positions without playing significantly more games. True fill players will have to play more games if they want to max out their rank in every position, but nowhere near five times as many. Let’s talk specifics:

### **One Position**

Starting next season, we’re going to soften the season reset, which means most players will have a higher initial rank. With other placement changes, it should take you less time to climb than today, even after considering Autofill games. This will make Ranked explicitly _less_ grindy than today.

### **Two to Three Positions**

You’ll have larger LP gains when playing off-positions and we’re extending **[Promotion Helper](https://support.riotgames.com/hc/en-us/articles/204010760-Ranked-Play-FAQ#h2q3)** to all series for off-positions below your main rank. LP splashing will help considerably when playing off-positions as well since it translates some of your gains to other positions.

### **Four to Five Positions**

Generalists will benefit from all the features above. We’re also making a small adjustment to splashing: When you queue as Fill, your LP splashing is stronger, which means you’ll be eligible for promotion series more quickly.

We plan to tune how some of these work to find the right balance, but we believe they make sense in the context of the other changes we’re making and help reinforce the value of every game you play. We’ll also consider ways to recognize versatile players through Ranked rewards.

## **Up Next**

Hopefully you’re starting to get a feel for how we’re planning to handle most of your big questions and concerns. We’ll continue the regular updates and check-ins over the next several months, with the next blog focusing on details about tier and division changes. Stay tuned!

This is the third one of these we’ve done, so by now you probably know the drill: Thanks for all the conversation so far, let us know what you think of the changes, and we’ll be on the lookout for your suggestions and feedback!

Oh—and if you want all the latest info on the Ranked changes for next year, check out our other blogs below:

Post 1: **[/dev: Updates to Ranked for 2019](https://nexus.leagueoflegends.com/en-us/2018/04/dev-updates-to-ranked-for-2019/)**

Post 2: **[What We Heard on Ranked 2019](https://boards.na.leagueoflegends.com/en/c/developer-corner/QTXRJ9fj-what-we-heard-on-ranked-2019)**

Post 3: /dev: Addressing Your Feedback on Ranked for 2019

[Riot SapMagic](https://nexus.leagueoflegends.com/en-us/search/riot-prcnt-20sapmagic/)

UX Lead for Teamfight Tactics

Ed Altorfer

SapMagic heads up the team working on Ranked. His favorite type of shirt (and meta) is tank tops.

-   
-   
-   
-   

[Next Article

# 2018 Mid-Season Invitational By the Numbers

](https://nexus.leagueoflegends.com/en-us/2018/06/2018-mid-season-invitational-by-the-numbers/)

-   [About League Of Legends](http://gameinfo.na.leagueoflegends.com/en/game-info/get-started/what-is-lol/)
-   [Prepaid Cards](http://na.leagueoflegends.com/en/page/league-legends-prepaid-game-cards/)
-   [Help Us Improve](http://leagueoflegends.na-surveyen2.sgizmo.com/s3/)
-   [Service Status](http://status.leagueoflegends.com/?en_US#na)
-   [Support](https://support.riotgames.com/hc/en-us)
-   [Esports Pro Site](http://www.lolesports.com/en_US)

© 2019 Riot Games, Inc. All rights reserved. Riot Games, League of Legends and PvP.net are trademarks, services marks, or registered trademarks of Riot Games, Inc.
