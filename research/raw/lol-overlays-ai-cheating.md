# League Overlays and AI: When Data Analysis becomes borderline Cheating? - r/leagueoflegends

<https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/>

[redlib.](https://safereddit.com/) Feeds

 in /r/leagueoflegends

[reddit](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/#popup) [settings](https://safereddit.com/settings)

[r/leagueoflegends](https://safereddit.com/r/leagueoflegends) • [u/nexuton](https://safereddit.com/user/nexuton) • Jun 03 '25

# [Discussion](https://safereddit.com/r/leagueoflegends/search?q=flair_name%3A%22Discussion%22&restrict_sr=on) League Overlays and AI: When Data Analysis becomes borderline Cheating?

**Yes, this is a long read, but it's important in my opinion.**

I wanted to kick off a discussion about something that's been on my mind for a long time regarding ingame overlays, the League API, and the ever increasing capabilities of AI.

Over the years, we've seen overlays that gave players significant advantages that felt pretty unfair. Some of them have been navigating a gray area for years, and with AI becoming more powerful, I'm wondering where the community and especially RITO thinks the line is or should be.

\-

# Lets start with two examples:

I won't talk about simple "Jungle timers" or "ultimate cooldowns" here which has been dicussed before, but something different you may haven't heard of yet.

**Gank Alerts:**  
For example, [senpai.gg](http://senpai.gg/) (went bankrupt iirc but was active until a year ago) had an integrated "gank alert" which was seemingly approved by Riot. If an enemy jungler was spotted on the map heading towards a lane, the overlay would pop up a clear alert like "Enemy jungler incoming!" For players with less map awareness. In my opinion, that's an enormous tactical advantage handed to them instantly

**Heatmaps:**  
Another one is "Trophy Hunter", an Overwolf in game overlay, which used to show heatmaps based on players' recent game data. You could click on an enemy player in the lobby and see where they went on the map in their last 10 games as a specific champion. Imagine the advantage for a jungler using this, knowing exactly where the enemy Warwick started his last several games, whether he tends to invade, which lane he prioritizes for early ganks, etc. This kind of intelligence normally comes from deep game knowledge, VOD reviewing, or active scouting, but the tool just gave it to you.

Actual Trophy Hunter SS

This isn't Trophy Hunter, but it has the same concept.

I'm just scratching the surface of what was and still is available within numerous League Overlays.

From what I remember, these tools, despite offering significant advantages derived from data, seemed to be allowed by Riot at the time (likely still to this day), as they were partnered with Riot and were within these Overlay apps for years. (Happy to be corrected if my memory is fuzzy)

\-

# What could be possible?

Now, let's fast forward to our current age of AI. Given the wealth of data available through the League API, the potential for AI driven tools goes far beyond what we've seen before.

**Champion Select:**  
An AI \*could\* analyze the entire lobby composition. Not just simple counters, but deep data on champion synergies, early/mid/late game power spikes, scaling differences, teamfighting capabilities, objective control, common ganking paths or strategies associated with those champions and more. It \*could\* then suggest not just a "good" pick, but the \*statistically optimal\* champion choice for that specific game based on millions of analyzed games, predicting which pick maximizes your win probability given the already other picked champions in the game. While I'm writing \*could\*, this is already a thing in several Overlays like Porofessor.

Is it fair that a player using an AI Overlay gets this level of sophisticated strategic insight automatically, while others rely solely on their own game knowledge? It's an open question, so think about it, if you want my opinion I'll give it at the end of this thread.

**In Game:**  
Leveraging API data and a bit of AI (not necessarily needed), anyone \*could\* generate real time heatmaps showing predicted enemy movements (based on enemies earlier games) or likely positions based on jungle timers, wave states, and typical pathing, similar to the old Trophy Hunter, but perhaps more dynamic.

An AI \*could\* even analyze realtime combat scenarios. Based on current champion levels, health, armor, magic resist, items, runes, and summoner spells, live calculating the probability of winning a specific 1v1 or 2v2 engagement. Imagine an overlay saying, "You have an 87% chance to win this fight against Garen with your current items/runes/stats" giving players precise data on when they are strongest relative to their opponent. While skilled players develop an instinct for these things, a precise, calculated probability is a different level of information.

This \*could\* extend to real time macro guidance. Based on training data from million game timelines, an AI \*could\* potentially analyze the live game state and suggest the play with the highest predicted win rate increase. "Take Dragon now (+10% Win Rate)," "Invade red side jungle (+7% Win Rate)," or "Gank top lane (+8% Win Rate)."

\-

# My Take:

Notice how I wrote \*could\* almost everywhere above? That's because we already have and had Riot approved Overlays that worked and still work like that, for example [Gosu.Ai](http://gosu.ai/), Senpai.gg, Itero.gg and Zar.gg. You could argue that even the new BackseatAI Overlay from Tyler1 is somewhat reaching a similar path to that.

Even I, myself as a single person, was able to code and experiment with all of those ideas as you can see below.

**Lobby champion recommendations:**

**ingame heatmap (credits** [DeMorrr](https://safereddit.com/r/leagueoflegends/comments/exo1mr/so_i_made_a_league_of_legends_heatmap_viewer/)**):**

**1v1 / 2v2 fight winrate prediction:**

**live ingame ai macro guidance:**

While I had to go through an approval to get a "Riot API Key" for it, I just did it as a Proof of Concept and just for fun (because I love data). I also did it to show that all of the above is actually possible, solely using Riots official API. The potential is significant, it actually works very well and is pretty damn reliable with enough game data scraped.

\-

# The issue with that:

Looking at those tools individually, it might be "okayish", but using all the tools together, the "small advantage" can now lead up to a "big advantage":

-   it provides you with the optimal champion to choose for the match
-   it gives you prior knowledge of when and whether an opposing jungler is invading or ganking
-   it tells you the exact level when to all-in an enemy to win the fight and your lane
-   it tells you the optimal item/macro recommendations based on the current live state of the game

Let's say, you are a player who never used any overlay or external help before, now discovering the possibilities of those apps, does this sound fair to you? For me, it does not! Seemingly based on Riot's approval, it is, or at least was at some point. If Riot says it's not, then there are several Apps that need investigations as they have similar behaviors.

Some might argue this only helps "bad" players who lack macro, but I say, think about chess. You could argue that League is somewhat similar. There are Chess websites, infested with people using AIs like "Stockfish" that can calculate dozens of moves ahead, identifying the statistically best possible move with accuracy far exceeding human capability. Even the best chess players in the world struggle against this level of analysis. In League, while execution is still key, having an AI identify the \*optimal\* strategic move for every step of the game (champion select, ingame macro, recommended items, jungle paths etc.) significantly lowers the barrier to playing high percentage League. If you're a decent player who can execute, but you're getting Stockfish level strategic guidance... that's a massive advantage in my opinion.

**So, my core question is:** With AI becoming more powerful and overlays capable of leveraging API data in increasingly sophisticated ways, where do we draw the line? When does using publicly available data via a tool cross over from providing helpful statistics into providing an unfair, almost automated, advantage that borders on cheating? What does "unfair" truly mean in this evolving landscape, when we already have overlays showing you the best picks, or the best moves ingame, which definitely can give you an ~("unfair")~ advantage?

1.0k Upvotes

-   [permalink](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/)
-   [reddit](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/#popup)

93% Upvoted

521

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvry9gw/?context=3#mvry9gw "Jun 03 2025, 14:30:40 UTC")

\[deleted\]

138

[u/Cryolyt3](https://safereddit.com/user/Cryolyt3) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsex0f/?context=3#mvsex0f "Jun 03 2025, 15:48:41 UTC")

Exactly. Player skill has nothing to do with the unfairness of overlays. It comes down to the fact that an overlay or 3rd party program is essentially taking off a massive mental load by removing the need for you to track lots of information in different places, and instead handing you the interpretation immediately in an accessible way. And this is especially game-breaking because a lot of this information _would not_ be obtained by players typically during their game, even if they could do it, but which they _can_ use if it's given straight to them with no effort on their part.

No, most players don't track flash timers accurately down to the second. No, they don't track jungle camps or ult timers. No, they aren't paying attention to their minimap and react 100% of the time as soon as a jungler appears near them. Overlays providing this information rapidly in an overt and easy to understand manner are removing the need for you to make any effort to track that information yourself, and making up for the fact that the overwhelming majority of players DON'T track that information consistently.

They are simply bullshit. I could definitely take advantage of information like flash timers if they were given to me, but they aren't something I can actively be bothered to track myself because I'm too lazy most of the time.

85

[u/basicxenocide](https://safereddit.com/user/basicxenocide) cosonavirus [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtie9j/?context=3#mvtie9j "Jun 03 2025, 18:55:06 UTC")

> No, most players don't track flash timers accurately down to the second.

I always make sure to flash as soon as the other guy does so I have an on-screen timer for when his flash is up.

2

[u/Havendelacorysg](https://safereddit.com/user/Havendelacorysg) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvyv2y3/?context=3#mvyv2y3 "Jun 04 2025, 15:35:03 UTC")

Cosmic Insight has entered the chat

1

[u/KlaasofBlood](https://safereddit.com/user/KlaasofBlood) [Jun 05 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mw44y7s/?context=3#mw44y7s "Jun 05 2025, 11:07:22 UTC")

I actually would love to see LEC with 6 Players. Where they have one observer Player. Who can only collect information and help the laners with that. Not Internet or API.

I think this may be able to bring the Games to new heights.

Just my opinion of that being super cool.

1.0k

[u/No\_maid](https://safereddit.com/user/No_maid) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvryt5j/?context=3#mvryt5j "Jun 03 2025, 14:33:18 UTC")

Frankly I think Riot should draw a hard line and outright ban the use of all third-party tools and overlays for live assistance in-game. Don't leave any grey areas open. The partial ban for certain features just doesn't work and will continue to cause problems in the future. A good benchmark should be if a tool isn't accessible or allowed in a professional match then it shouldn't be allowed on the competitive ladder.

158

[u/HACEKOMAE](https://safereddit.com/user/HACEKOMAE) ROCK HARD [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs59rk/?context=3#mvs59rk "Jun 03 2025, 15:03:53 UTC")

To add, in order for these tools to feel "fair" everybody would need to start using them and, more importantly, learn how to use them effectively. And it would take away so much from League itself, bringing on an arms race for whoever uses these tools most effectively.

In no world would the whole player base willingly participate in this shit. Banning all third-party helping tools is a tough but necessary decision they have to make rather sooner than later.

Integrate cool features into the game directly, like they did with timers, on League's terms, but that's it.

40

[u/TommaClock](https://safereddit.com/user/TommaClock) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvscbvj/?context=3#mvscbvj "Jun 03 2025, 15:36:46 UTC")

> In no world would the whole player base willingly participate in this shit.

In WoW don't you have to use weak auras or they kick you from high level raids? It's bullshit but it could happen to league.

55

[u/Saphirklaue](https://safereddit.com/user/Saphirklaue) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsidq8/?context=3#mvsidq8 "Jun 03 2025, 16:04:39 UTC")

The problem in WoW isn't that you use them because its an advantage, some fights in Mythic raids need such an absurd level of ad hoc coordination between 20 people that automating it in some way is sometimes borderline mandatory.

Blizzard stated they want to ban these addon functionalities and make fights easier to coordinate without them, but wether they actually achieve that when the ban happens is anyones guess.

13

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvssdtm/?context=3#mvssdtm "Jun 03 2025, 16:51:41 UTC")

This is specifically why FF14 has a strong ban on 3rd party tools and is so much better off for it - you can _technically_ use them, they don't tend to outright ban (I've used some tools in the past and gotten away with it), but they DO say they will ban you for it. iirc a team had a world-first raid taken away because they used tools as well.

WoW is basically unplayable with the way the UI looks with all the 3rd party tools. I could never play it in current state with the requirements of all the extra tools just to play the game.

23

[u/Kokaiinum](https://safereddit.com/user/Kokaiinum) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvszd87/?context=3#mvszd87 "Jun 03 2025, 17:23:21 UTC")

I think you are over-emphasising how strong the "ban" is. Square generally don't bother hitting plugins at all unless you are very overt about using them (i.e. pasting your DPS meter into the chat or, like you said, using plugins on a world-first seen by thousands of people). But a large percentage, if not an outright majority, of players on PC are using at least some plugins, even if it's just small QoL stuff or the unofficial launcher etc.

\-4

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt2s9g/?context=3#mvt2s9g "Jun 03 2025, 17:38:48 UTC")

I'm using Square's own stance on the matter when saying they have a strong ban - their EULA says 3rd party tools aren't allowed **AT ALL**. They just tend to let it go in a vast majority of instances as long as it doesn't harm the game / players.

21

[u/ElementaryMyDearWut](https://safereddit.com/user/ElementaryMyDearWut) bonk [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvteopa/?context=3#mvteopa "Jun 03 2025, 18:32:59 UTC")

This is a really misinformed take. All these service EULAs let the account owners i.e Riot, Square, Blizz ban your account for ANY reason, whenever they feel like it, regardless of whether you cheated.

Square doesn't ban because they don't have an anti-cheat, so they can't detect anything. Most plugins in FF14 are quite literally just cheats because they don't have an official plugin API like Blizzard does.

For SE to moderate plugins at all, it would require them to actually develop, maintain, and add an anti-cheat which they will probably never do. Both Riot and Blizzard already have one which is why they can be more granular. At present, if Square WANTED to enforce plugin bans they couldn't.

11

[u/RivenRise](https://safereddit.com/user/RivenRise) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtyerd/?context=3#mvtyerd "Jun 03 2025, 20:19:12 UTC")

I can confirm as a Ff14 player for years. All of the community uses plug-ins and the main dude himself has said that as long as people aren't being dicks or in your face about it they won't do anything. Their stance is mostly as harsh as it sounds so they can just ban whoever is being a dick without backlash. Can't complain if you get banned if literally all aspects of them have been telling you that you'll get banned for third party add-ons.

I've used some crazy automation add-ons too for yers and no ban. Just don't be a dick and don't say anything out loud, you'll be fine.

2

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt89pu/?context=3#mvt89pu "Jun 03 2025, 18:03:20 UTC")

\[deleted\]

1

[u/Puandro](https://safereddit.com/user/Puandro) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtfs9r/?context=3#mvtfs9r "Jun 03 2025, 18:38:56 UTC")

Not to mention if plugin breaks or stop being updated it sucks but it is what it is, if SE makes something it better continue working every patch and get updated.

1

[u/tholt212](https://safereddit.com/user/tholt212) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtojyz/?context=3#mvtojyz "Jun 03 2025, 19:31:23 UTC")

Gonna be honest the EULA can say whatever it wants if it's not enforced.

This is from someone who has played ff14 for about a decade. They simply do not ban for addons alone. You either have to show it off (World first kill vods) or you have to use it as a tool for harassing other players (dps meters).

A large amount of players on the game who still play only play entirely because of how much they don't enforce modding.

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtojyz)

4

[u/IncasEmpire](https://safereddit.com/user/IncasEmpire) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv8rv3/?context=3#mvv8rv3 "Jun 04 2025, 00:25:11 UTC")

the only reason world first groups often get bonked for this is because they are up there in front of everyone's faces, so someone will call them out

third party tool use is rampant in FFXIV, if anything, its getting as bad as wow is.  
maybe not on the raid assistance part of things ,but everything else is modified to unbelievable degrees. there is no part of the game without at least 5 plugins for it.

square barely even bothers. as long as you dont send some weird package to the server (sometimes) they will blast you with a warning/tempban. or if you get someone mad enough to report you and there is a gm available to potentially check on weird activity

1

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvydb39/?context=3#mvydb39 "Jun 04 2025, 14:09:58 UTC") edited Jun 04 '25

> third party tool use is rampant in FFXIV, if anything, its getting as bad as wow is. maybe not on the raid assistance part of things ,but everything else is modified to unbelievable degrees. there is no part of the game without at least 5 plugins for it.

I played through the entire game in endwalker up to savage raids without using a single add-on. I did use some macros for crafting classes (because that shit is boring), but didn't use add-ons at all throughout my entire playthrough of the story and raiding.

There ARE add-ons, they are not REQUIRED to play the game.

This is a vastly different experience from WoW where you basically won't even be allowed into a raiding party without 20 different add-ons just for the fight to function "correctly". This is only possible because Square has taken the stance that they have, even if they normally don't do shit about it.

1

[u/IncasEmpire](https://safereddit.com/user/IncasEmpire) [Jun 05 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mw6ltug/?context=3#mw6ltug "Jun 05 2025, 18:50:05 UTC")

does that imply you did not do savage? or am i misunderstanding

most if not all content in wow is doable without add ons unless its bugged, and you will rarely get kicked from somewhere unless the whole group is already running said add on and they want you to be on line with them

ultimate PF and AM in the meanwhile, at least DSR and TOP is obligatory, UWU half the time, and you see them in UCOB for some godsforsaken reason

2

[u/Thelorian](https://safereddit.com/user/Thelorian) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvstjhf/?context=3#mvstjhf "Jun 03 2025, 16:56:55 UTC")

> borderline mandatory

Star augur moment.

8

[u/Boredy0](https://safereddit.com/user/Boredy0) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt0rvb/?context=3#mvt0rvb "Jun 03 2025, 17:29:45 UTC")

They don't necessarily kick you, it's more that if you ever get invited to a high level raiding guild, chances are you have a shit ton of weak auras already because it is just straight up a huge advantage.

5

[u/\_Cava\_](https://safereddit.com/user/_Cava_) Graves top enjoyer [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuwb6l/?context=3#mvuwb6l "Jun 03 2025, 23:14:24 UTC")

You straight up can't do some of the bosses without weakauras. Ovinax needed 8 random people to split into 4 pairs in specific locations in 8 seconds 9 times throughout the whole fight, fail to do it once and it's a wipe. While theoretically possible, it's not happening without help.

3

[u/Cherrycho](https://safereddit.com/user/Cherrycho) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtj3su/?context=3#mvtj3su "Jun 03 2025, 18:59:35 UTC")

I haven't played in a few years, but back when I did it was only one fight where weakauras was truly mandatory, and that was the beams on mythic Archimonde. But they just make your life so much easier in general that pretty much all high end raiders are happy to have them

7

[u/Easyaeta](https://safereddit.com/user/Easyaeta) Pretty Boy Enthusiast [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtyme1/?context=3#mvtyme1 "Jun 03 2025, 20:20:12 UTC")

The beams on mythic archimonde forced blizzard to limit what add ons could do and how they would design fights in the future that's how necessary that shit was lmao

7

[u/asweknow](https://safereddit.com/user/asweknow) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuouae/?context=3#mvuouae "Jun 03 2025, 22:33:06 UTC")

Competitive games should never enter into third-party add on things

70

[u/timelessblur](https://safereddit.com/user/timelessblur) Cloud 9 [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs3qu5/?context=3#mvs3qu5 "Jun 03 2025, 14:56:44 UTC")

I think this is dead on. The tools allowed to run ingame should be completely based on that.

15

[u/lastdancerevolution](https://safereddit.com/user/lastdancerevolution) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt46ba/?context=3#mvt46ba "Jun 03 2025, 17:45:04 UTC")

MSI has monitors with AI chips designed for League that shows map alerts like jungle ganks. It exists on the monitor, so is impossible for even the strongest kernel anti-cheat to detect.

> According to MSI, SkySight works by analyzing the on-screen mini-map to see where enemies are coming from, which is something you can do with your own eyes. But having an AI assistant that watches the map for you and then puts an icon on the screen to show where the threats are coming from is probably a huge help.

[MSI's AI-powered gaming monitor helps you cheat at 'League of Legends,' looks great doing it](https://www.tomshardware.com/monitors/msis-ai-powered-gaming-monitor-helps-you-cheat-at-league-of-legends-looks-great-doing-it)

25

[u/Exldk](https://safereddit.com/user/Exldk) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtaxba/?context=3#mvtaxba "Jun 03 2025, 18:15:37 UTC") edited Jun 03 '25

This sounds like fearmongering.

Do you have a single clip from 2025 of anyone using it ? If it was actually possible, there would be outrage so large the subreddit would lag out.

All I could see using "msi monitor league of legends" and "msi skylight league of legends" were the year old videos from CES 2024, but nothing since.

I simply don't believe it's an actual thing until I see a video of someone playing on it and using the "skylight" feature in 2025.

Looking on every store page I can see no one is mentioning any mystical "skylight" features. It had to have been scrapped from the product for obvious reasons.

EDIT1: Amazon page for the monitor in question doesn't mention any skylight, or AI for that matter.

EDIT2: meg 321urx qd oled skylight if searched from 01.2025 to 06.2025 doesn't give any results, whereas it gets a crapton of results from last year. Safe to say the AI part of the monitor is not real.

4

[u/UntimelyMeditations](https://safereddit.com/user/UntimelyMeditations) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtfnsr/?context=3#mvtfnsr "Jun 03 2025, 18:38:13 UTC")

> If it was actually possible, there would be outrage so large the subreddit would lag out.

I think it'd be a lot less convenient to clip something like this, because screen recording software wouldn't be able to capture it. You'd have to take a cell phone video of the screen.

23

[u/Exldk](https://safereddit.com/user/Exldk) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtgpln/?context=3#mvtgpln "Jun 03 2025, 18:44:26 UTC")

It's 2025 and people still use phones to take screenshots of their monitors, I'm sure they would be able to record a 5 second TikTok clip.

It would go viral in minutes.

10

[u/MazrimReddit](https://safereddit.com/user/MazrimReddit) ADCs are the support's damage item [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt6ixz/?context=3#mvt6ixz "Jun 03 2025, 17:55:29 UTC")

It's such a popular opinion I don't know why they are not doing this.

Even people using overlays frequently say they don't want to but feel they need to for certain features or they feel at a disadvantage

2

[u/zack77070](https://safereddit.com/user/zack77070) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtswq7/?context=3#mvtswq7 "Jun 03 2025, 19:52:51 UTC")

They have to be careful about not completely wiping an industry that they built and sanctioned. TSM basically only exists because of Blitz, idk how much they invest in other games but surely the League part is a decent chunk of their revenue.

\-2

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtmd5c/?context=3#mvtmd5c "Jun 03 2025, 19:20:16 UTC")

\[removed\] — [view removed comment](https://undelete.pullpush.io/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtmd5c)

5

[u/PaleontologistEven24](https://safereddit.com/user/PaleontologistEven24) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu1wo3/?context=3#mvu1wo3 "Jun 03 2025, 20:35:52 UTC")

I’m a diamond jungler playing without overlays and I don’t time camps at all. You certainly do not have to do it as a jungler in lower elo.

3

[u/thinkbetterofu](https://safereddit.com/user/thinkbetterofu) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvvwsc2/?context=3#mvvwsc2 "Jun 04 2025, 02:48:28 UTC")

overlays cause most people to be very predictable because they then overprioritize going to spawning camps over using their brains

3

[u/UntimelyMeditations](https://safereddit.com/user/UntimelyMeditations) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtfgk6/?context=3#mvtfgk6 "Jun 03 2025, 18:37:07 UTC")

> outright ban the use of all third-party tools

Does Notepad count as a 3rd party tool?

4

[u/Oniichanplsstop](https://safereddit.com/user/Oniichanplsstop) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvthcju/?context=3#mvthcju "Jun 03 2025, 18:48:26 UTC")

Why would you even notepad, you just type timers/etc in game chat and copy paste as needed.

9

[u/valcron1000](https://safereddit.com/user/valcron1000) "Easy partner" [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsy213/?context=3#mvsy213 "Jun 03 2025, 17:17:25 UTC")

> Frankly I think Riot should draw a hard line and outright ban the use of all third-party tools and overlays for live assistance in-game. Don't leave any grey areas open.

Most of the examples in the post do not require any kind of "overlay" since a lot of data is available outside the game. Banning this tools would require deleting the Riot API, and that might not be enough.

As for in-game overlays, it's practically impossible. You can always have a program that records the game in real time and extract the relevant information, and then feeds some info to the user.

The only way for this to work would be to somehow make League use one of the DRM protection tools to avoid screen recording (which can be bypassed too but that gets a bit tricky), but that kills the entire streaming community.

So no, this will never happen.

6

[u/fainlol](https://safereddit.com/user/fainlol) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsa8t0/?context=3#mvsa8t0 "Jun 03 2025, 15:27:06 UTC") edited Jun 03 '25

its a can of worms thats already opened. Problem with shutting them all down is people will still find a program to use regardless its allowed or not. Only way to stop is to have riot implement every feature on these overlays and I have hard time seeing riot implement every feature esp the winrate related ones.

[edit: infact, have you guys seen the hardware related ones?](https://youtu.be/stXXpGNOMQA?t=94) its just going to end up like apex cronus cheat.

33

[u/manboat31415](https://safereddit.com/user/manboat31415) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsc00v/?context=3#mvsc00v "Jun 03 2025, 15:35:14 UTC")

At that point it’s just people cheating and should be dealt with as such. None of these programs are going to be more evasive than expensive scripts are. If they announced they were adding these overlays to what Vanguard is looking for the vast majority of their users would drop it. The people who refuse to drop and try and skirt around it can just get banned.

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsc00v)

3

[u/Medical\_Boss\_6247](https://safereddit.com/user/Medical_Boss_6247) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtj1r0/?context=3#mvtj1r0 "Jun 03 2025, 18:59:13 UTC")

I feel like they could allow specific overlays rather than banning specific ones.

Like jungle timers are fine. The pretty overlay that shows all available info in load screen on one panel instead of three separate ones is fine. Auto filling runes is fine. Ban the rest of the features

If your overlay does anything that’s not specifically listed, it’s banned

2

[u/RivenRise](https://safereddit.com/user/RivenRise) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtxk7h/?context=3#mvtxk7h "Jun 03 2025, 20:15:07 UTC")

I mostly agree with you, I just want to point out that in a professional match they DO have access to a lot of this sort of data, just in the form of coaches who can let them know all of it. Not quite the same but similar.

1

[u/rayschoon](https://safereddit.com/user/rayschoon) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvthfpa/?context=3#mvthfpa "Jun 03 2025, 18:48:59 UTC")

I totally agree. It should’ve all been banned ages ago but I think they should just allow the client

1

[u/IGetPaidInCoin](https://safereddit.com/user/IGetPaidInCoin) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvvz3h5/?context=3#mvvz3h5 "Jun 04 2025, 03:03:28 UTC")

It’s all banned for all forms of competition. Even the AT&T streamer tournament. But when it comes to normal league they care more about player retention than competitive fairness which makes sense. If it helps new players learn and enjoy league more let them have it even if it makes it unfair from a competitive viewpoint.

1

[u/PENZ\_12](https://safereddit.com/user/PENZ_12) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwpu39/?context=3#mvwpu39 "Jun 04 2025, 06:31:19 UTC")

Fully agree.

1

[u/Benbubbly1804](https://safereddit.com/user/Benbubbly1804) [Jun 05 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mw3woyx/?context=3#mw3woyx "Jun 05 2025, 09:57:46 UTC")

Based as fuck.

\-3

[u/oby100](https://safereddit.com/user/oby100) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt8xfv/?context=3#mvt8xfv "Jun 03 2025, 18:06:22 UTC")

No way. Riot is approving these add ons guy. If you don’t like them, blame Riot for reviewing them and deciding they’re acceptable.

I despise the purist mindset. Let people see stats and beg Riot to ban stuff that bugs you. I agree that the jungle pathing heat map is suspect and something like a gank alert is way too far.

More information is ok to me as long as it’s not instructing you on how to play the game. Specific instructions decided from analysis you never even look at is simply cheating. Giving you the numbers usually isn’t.

8

[u/UntimelyMeditations](https://safereddit.com/user/UntimelyMeditations) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtfz7l/?context=3#mvtfz7l "Jun 03 2025, 18:40:03 UTC")

> Giving you the numbers usually isn’t.

Depends on if 'knowing the numbers' is part of the skill of the game or not.

8

[u/Contrite17](https://safereddit.com/user/Contrite17) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuzyl9/?context=3#mvuzyl9 "Jun 03 2025, 23:34:29 UTC")

> If you don’t like them, blame Riot for reviewing them and deciding they’re acceptable.

I do blame Riot. They used to ban this kind of stuff completely, but they opened pandoras bow and now it is all just "normal" and that sucks. They need to go back to the old stance of 3rd party tools being against the rules.

0

[u/economic-salami](https://safereddit.com/user/economic-salami) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsflqv/?context=3#mvsflqv "Jun 03 2025, 15:51:51 UTC")

This is the way. In stock market seemingly insignificant advantages when stacked together create a significant alpha. Such is a life; small advantages combine into a big one. Whatever advantage that pertains to in-game, where people should be playing, is going to be unfair. It can be insignificantly unfair but it still is what it is.

But I would like to add that things that can be done outside the live game session should be open to analysis. Like optimal champion picks, item build winrate and recommendations, and yes, general and customized usual gank routes too. They are the 'practice/training' part of the cycle, and it's not like steriods where users are inflincting self harm in the long term. In fact I would go as far to say that use of 3rd party pre-and-post-match analyzers should be encouraged.

What should remain untouched by programmed assistance is the gameplay itself, and that part only.

\-7

[u/serialdumbass](https://safereddit.com/user/serialdumbass) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs8n1c/?context=3#mvs8n1c "Jun 03 2025, 15:19:40 UTC")

I disagree. Some overlays are valid, especially those that help with physical impairments. Two things should happen. Instead of approving overlays, it should be programs (like porofessor, u.gg), and it should be a whitelist on features. That way, if you aren’t using an approved program, you’re subject to be banned, and if that program that’s approved implements an unapproved feature, it could be removed from the whitelist, which would trigger bans. This way once you’re an approved program it’s extremely unlikely that you implement anything unapproved. I think the stuff in u.gg and porofessor are mostly fine and these other tools are really the problem.

5

[u/alebarco](https://safereddit.com/user/alebarco) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvse6wk/?context=3#mvse6wk "Jun 03 2025, 15:45:19 UTC")

This is a very fair petition, but I think they In fact Had a whitelist with stuff like blitz or whatever centuries ago.

It's like everything, if the competition is implementing cooler features you either try to include them in your product or you're left in the dust.

Accessibility is a Huge thing for a few players, but sadly is a non factor for the majority of the community , The people that really use and Vouch for these overlays should pitch them to rito to either Whitelist or Outright implement in the game, and not a loophole where if the overlay had X functionality for Ease of use and I add it I can opt for a spot, A Close monitor by rito to either help the few minds behinds the good tools or adding them to The game.

\-1

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvubb44/?context=3#mvubb44 "Jun 03 2025, 21:21:45 UTC")

I think a funny part people seem to overlook is what happens when people have AI tools to counter the enemies AI-tools?

People talk about how there's overlays/tools that will tell you when you're getting ganked and where the enemy jungler is pathing based on huge amounts of data and information from the players history, but what if said opposing player also has an AI-tool that says "the enemy toplaner will recieve a gank warning soon, consider ganking mid or invading" to throw them off?

at some point everyone is just following orders from AI and it comes down to who has the smarter AI lmao

(i don't actually think it will get this far, but it's a funny thought that in 2034 there are 10 players all following AI-tools that are trying to outmaneuver each other)

[→ More replies (2)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvryt5j)

167

[u/AdNidalee](https://safereddit.com/user/AdNidalee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvrygpd/?context=3#mvrygpd "Jun 03 2025, 14:31:39 UTC") edited Jun 03 '25

That Trophy hunter heatmap on where the particular player who is the enemy jungle is usually going level one or where he usually starts clearing based on his past games sounds insanely broken. Shocking Riot is ok with something like that

EDIT: Yeah the jungler heatmaps are crazy. Tracking the enemy jungler is a skill and such an important part in the satisfaction you get from jungling.

Riot removed the Clairvoyance summoner spell for this exact reason. How is this ok?

46

[u/WikY28](https://safereddit.com/user/WikY28) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsf5x2/?context=3#mvsf5x2 "Jun 03 2025, 15:49:50 UTC") edited Jun 03 '25

It's really powerful. I wasn't aware of it. Leveraged properly you could absolutely destroy you opponents first clear.

With 0 risk too because you could also check if the enemy laners are the hugging tower type or the guard entrances type.

13

[u/Cheetah\_05](https://safereddit.com/user/Cheetah_05) GUMAYUSI [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtqq67/?context=3#mvtqq67 "Jun 03 2025, 19:42:16 UTC")

Does it show where they usually guard entrances? Because if so, through pathing you can even negate that. This is just so broken.

\-5

[u/JanEric1](https://safereddit.com/user/JanEric1) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtdc1t/?context=3#mvtdc1t "Jun 03 2025, 18:26:48 UTC")

Even if you ban it as an overlay, i could just write a little program where i alt tab out during the loading screen, enter the junglers IGN and out comes that heatmap.

Same for the champ picks. Just have a script ready to tab to and enter the current picks and maybe even the player igns and out comes that data. Everything that is done in the pregame can equally be done without overlays and there is literally no way to ban it too.

10

[u/AdNidalee](https://safereddit.com/user/AdNidalee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtmtwy/?context=3#mvtmtwy "Jun 03 2025, 19:22:39 UTC")

You could block their access to the API and make games below grandmaster not have downloadable replays, unless they're your own. I can see that working

28

[u/WikY28](https://safereddit.com/user/WikY28) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtsbar/?context=3#mvtsbar "Jun 03 2025, 19:49:57 UTC")

Could also add a 5min delay to requests, would make it useless for these trackers but remain useful for everything else.

5

[u/JanEric1](https://safereddit.com/user/JanEric1) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtnpju/?context=3#mvtnpju "Jun 03 2025, 19:27:07 UTC")

Rank restriction feels weird and arbitrary to be honest.

Would also make proper data science projects impossible.

8

[u/AdNidalee](https://safereddit.com/user/AdNidalee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtpzan/?context=3#mvtpzan "Jun 03 2025, 19:38:33 UTC")

Why? It's because people in GM+ play against each other constantly, the same players, and they know their styles. Elite queues already have different rules, including decay.

1

[u/JanEric1](https://safereddit.com/user/JanEric1) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtqphn/?context=3#mvtqphn "Jun 03 2025, 19:42:10 UTC")

That is not necessarily Inherint, right? If the server is large enough the. Even at high tiers you can have it that GMs don't always know all the people they play against. It also introduces a weird asymmetry in game where some people are GM and others aren't or you have people change regions or newly make it into GM.

6

[u/AdNidalee](https://safereddit.com/user/AdNidalee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtr4oo/?context=3#mvtr4oo "Jun 03 2025, 19:44:14 UTC")

It does, but those are fringe cases and only a problem for the 0.06% of the playerbase or whatever the exact break point between master and grandmaster is nowadays. Better for the 99.95%

[→ More replies (30)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvrygpd)

55

[u/Vengeful111](https://safereddit.com/user/Vengeful111) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvrz1jj/?context=3#mvrz1jj "Jun 03 2025, 14:34:25 UTC")

Itero.gg already uses AI in champ select, you can turn on or off if you want your own champion mastery to be taken into account, and it even imports you a build thats good against the enemy team. Like it will give you armor items if the enemy is full ad and so on.

21

[u/JackWills94](https://safereddit.com/user/JackWills94) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvssnum/?context=3#mvssnum "Jun 03 2025, 16:52:57 UTC")

I run iTero, left my thoughts here:

[https://www.reddit.com/r/leagueoflegends/s/TrJgAYETNl](https://safereddit.com/r/leagueoflegends/s/TrJgAYETNl)

8

[u/Vengeful111](https://safereddit.com/user/Vengeful111) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsxee8/?context=3#mvsxee8 "Jun 03 2025, 17:14:28 UTC")

Used it myself for a long time since the champ suggestions are really nice and I didnt have to keep up with item changes to know what to build.

Now i play more active again so i dont really need it anymore, but its an amazing tool for casual gaming

2

[u/JPHero16](https://safereddit.com/user/JPHero16) [Jun 05 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mw41m6z/?context=3#mw41m6z "Jun 05 2025, 10:41:00 UTC") edited Apr 15 '26

airport slap lantern quickest price roof existence hunt pen north

2

[u/JackWills94](https://safereddit.com/user/JackWills94) [Jun 05 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mw4zie7/?context=3#mw4zie7 "Jun 05 2025, 14:13:31 UTC")

Thanks man, actually working on that as we speak

(if it's still allowed once I'm finished)

48

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvrxiqy/?context=3#mvrxiqy "Jun 03 2025, 14:27:03 UTC")

Impressive work

15

[u/nexuton](https://safereddit.com/user/nexuton) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvrye2h/?context=3#mvrye2h "Jun 03 2025, 14:31:17 UTC")

Thank you :)

15

[u/Arsenije723](https://safereddit.com/user/Arsenije723) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs95x1/?context=3#mvs95x1 "Jun 03 2025, 15:22:05 UTC")

I thought you were gonna talk about random stats like porofessor, but tbh i never knew about these gank alerts and analyzing where the enemy is located. That definetely sounds like cheating

29

[u/PridePurrah](https://safereddit.com/user/PridePurrah) HURRDURR [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsggye/?context=3#mvsggye "Jun 03 2025, 15:55:47 UTC")

I wasn't even aware that heat maps and gank alerts are a thing.

this...this explains a lot to me o\_o

This is straight up cheating.

8

[u/GornothDragnBonee](https://safereddit.com/user/GornothDragnBonee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsmsfc/?context=3#mvsmsfc "Jun 03 2025, 16:25:33 UTC")

The line should've been drawn long ago, overlays in competitive games shouldn't display info that isn't displayed in the game. People shouldn't have been able to when it tracked jungle timers when they weren't in the game. I don't understand how they ever let it get to this point tbh.

72

[u/lolyoda](https://safereddit.com/user/lolyoda) Riven Resembles Her Sword, Broken AF [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs13yq/?context=3#mvs13yq "Jun 03 2025, 14:44:19 UTC")

I have always had the opinion that all third party tools should be banned, and I don't mean ban people using them, I mean limit your API. This is a Riot problem.

The reason is that any small advantage a person may get from an overlay means the competitive integrity of the match is ruined for the person who doesn't want to use them or physically doesn't have a good enough computer for them (overwolf is an awful draw on resources).

If there are features that overlays offer that you like, then tell riot to implement them in the game so everyone has them, they can even make them opt-out, but you shouldn't force new players to figure out the perfect concoction of software to use in order to play the game lmao which is the future we are heading towards at a rapid pace.

21

[u/BakaMitaiXayah](https://safereddit.com/user/BakaMitaiXayah) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvscckz/?context=3#mvscckz "Jun 03 2025, 15:36:51 UTC")

I agree, disable all third party tools except building ones, but for the love of god, put fucking timers on inhib respawn and jungle camps...

11

[u/ApprehensiveTough148](https://safereddit.com/user/ApprehensiveTough148) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvse8ds/?context=3#mvse8ds "Jun 03 2025, 15:45:30 UTC")

nexus tower respawn as well. I did not know its 3 minutes for nexus tower respawn. Unironically cost us an official match lol

6

[u/BakaMitaiXayah](https://safereddit.com/user/BakaMitaiXayah) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsf0x9/?context=3#mvsf0x9 "Jun 03 2025, 15:49:10 UTC")

Nexus towers at least have a very visible circle around them unlike inhibitors, i'll never understand how they work but with certain graphic settings you can see the circle (still not very easy to see)

4

[u/lolyoda](https://safereddit.com/user/lolyoda) Riven Resembles Her Sword, Broken AF [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt7qo4/?context=3#mvt7qo4 "Jun 03 2025, 18:00:56 UTC")

Id say even the building ones. I think the building ones aren't very good unless they do the AI thing of comparing data across millions of games. I have used the overlays in the past and honestly their recommendations were correct 80% of the time. The best way to get to 100% is to just think about what you want to build for yourself, and it stops people from being toxic because they have more variables to consider about their own gameplay instead of having all this mental free time to criticize how their team is playing.

I guess my point is that everything that an overlay provides should either be part of the official game, or not allowed.

4

[u/noahloveshiscats](https://safereddit.com/user/noahloveshiscats) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvum04i/?context=3#mvum04i "Jun 03 2025, 22:17:29 UTC")

Removing building ones would solve nothing as people would just go to Mobafire or something similar and look at a guide for the champion.

[→ More replies (3)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvum04i)

1

[u/kon4m](https://safereddit.com/user/kon4m) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt1h38/?context=3#mvt1h38 "Jun 03 2025, 17:32:57 UTC")

riot limiting their API is NOT the way that would brick a ton of apps, they need to ban 3rd party apps and revoke their API key if they dont comply

12

[u/UntimelyMeditations](https://safereddit.com/user/UntimelyMeditations) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtgeeh/?context=3#mvtgeeh "Jun 03 2025, 18:42:33 UTC")

> that would brick a ton of apps

Yes, that is the goal.

3

[u/lolyoda](https://safereddit.com/user/lolyoda) Riven Resembles Her Sword, Broken AF [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt5f3p/?context=3#mvt5f3p "Jun 03 2025, 17:50:36 UTC")

I honestly don't care about the other apps, just look at what WoW became and what league is becoming, everyone is just a meta slave trying to copy the optimal thing instead of playing the damn game and figuring it out for themselves which in turn makes their ego go crazy since they know better than the rest of their team.

Limit the Riot API for live games and completely remove any plugin that attaches to the game, things like [op.gg](http://op.gg/) and what not can stay since i view them as more or less disconnected but they shouldn't have features that intentionally affect live games, they should only be allowed to present historical data and all conclusions reached should come from the player.

6

[u/kon4m](https://safereddit.com/user/kon4m) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtigus/?context=3#mvtigus "Jun 03 2025, 18:55:34 UTC")

The problem is that none of this info is from the live game, the AI analyzing previous games is not a live game feature

0

[u/OneCore\_](https://safereddit.com/user/OneCore_) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsf6d1/?context=3#mvsf6d1 "Jun 03 2025, 15:49:53 UTC")

i just use them for the ingame stat trackers lol

4

[u/lolyoda](https://safereddit.com/user/lolyoda) Riven Resembles Her Sword, Broken AF [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt791q/?context=3#mvt791q "Jun 03 2025, 17:58:44 UTC")

Look im the biggest stats whore you will meet, I love numbers, my job is being a software engineer while working with lots and lots of data and being able to draw conclusions in a code driven way. I get where you are coming from.

I am just saying that by not limiting these tools for other players they essentially force people into using these tools in order to stay competitive because they are powerful. You and I are at fault for enjoying the stats in a sense so now even those that don't enjoy them MUST actually learn to interpret them.

2

[u/OneCore\_](https://safereddit.com/user/OneCore_) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvta152/?context=3#mvta152 "Jun 03 2025, 18:11:29 UTC")

oh yeah of course. the software shit is getting out of hand, riot needs to either limit the API or implement their own stats/timers so an end can be put to the stuff detailed in the post, because that is just a clear-cut unfair advantage vs. people who don't have the perfect software (made even more evident by the fact that the most common overlay apps like [u.gg](http://u.gg/), [blitz.gg](http://blitz.gg/), facecheck, porofessor, etc. don't have these heatmaps/gank notifs).

2

[u/lolyoda](https://safereddit.com/user/lolyoda) Riven Resembles Her Sword, Broken AF [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtaoz7/?context=3#mvtaoz7 "Jun 03 2025, 18:14:33 UTC")

It also sucks that this is the most viable way forward in a way simply because numbers are cool but its essentially turning into a nuclear arm race lmao.

20

[u/ok\_dunmer](https://safereddit.com/user/ok_dunmer) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsx024/?context=3#mvsx024 "Jun 03 2025, 17:12:42 UTC") edited Jun 03 '25

The argument that this is fair because pro teams do data analysis is so bad lol. Solo queue is not a coordinated professional game, it's pick up basketball, if you are doing things like pulling up a heatmap of the enemy jungler you are killing the vibe and making the game less fun. Ranked solo queue is designed around all of us being strangers and is at its most unfun and cheesy when some people are not, and the game will be actively less fun when we all feel like we need a fucking data analytics program hogging resources to even compete

2

[u/Alive\_Program\_4776](https://safereddit.com/user/Alive_Program_4776) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvw8o1r/?context=3#mvw8o1r "Jun 04 2025, 04:10:02 UTC")

amen

16

[u/PM-ME-MEI-PICS](https://safereddit.com/user/PM-ME-MEI-PICS) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsau62/?context=3#mvsau62 "Jun 03 2025, 15:29:50 UTC")

If pros can't use these tools during live games, then no one should have access to them.

10

[u/SnareBears](https://safereddit.com/user/SnareBears) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs6d4e/?context=3#mvs6d4e "Jun 03 2025, 15:09:02 UTC")

All I want are timers on my camps

[→ More replies (3)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs6d4e)

38

[u/JackWills94](https://safereddit.com/user/JackWills94) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsjyd4/?context=3#mvsjyd4 "Jun 03 2025, 16:12:05 UTC")

I run [iTero.GG](http://itero.gg/), one of the AI overlays mentioned above

First off - thank you for the detailed post and posing it as a discussion (\*rather than "KILL APP DEVELOPERS")

TLDR: In-game bad, pre-game/post-game good

My personal opinion (which is exceptionally biased):

\- I think any in-game AI is on track to become extremely powerful and I'm in favour for ruling them out completely. Gank detection, which objective to do next, what lane to be in - it's too far.

\- I'm in favour for almost everything based on the "review" process (i.e. checking stats of games you've played, AI analysis, auto-VOD reviews). It will never replace human coaches, but it makes it more accessible for the 99% of players who can't justify paying for one. I see no issue with it.

\- Draft, which is where we specialise, is an interesting one. Our main userbase tend to be people who just don't have the time to keep up with meta and don't play enough to know EVERY match-up and counter. They previously went onto (insert data website), but appreciate that our AI considers more than just the lane match-up and saves them time. Same with builds/runes/summoners. A lot of people use it to try new Champions, but in drafts where they aren't completely int. I still think someone with innate knowledge of the game has the advantage in picking Champions, but now it doesn't require being constantly clued up on the meta, and players can be more confident trying out new things. If you want to get real free LP, you OTP, it's the OP strategy - it's just that most people don't want to and would rather learn and try different Champs.

\- My biggest fear is when Riot fully lose control. At the moment they can limit everything through API access, but it isn't long before video data can be processed cheaply enough for undetectable monitor plugins, and that means it doesn't matter where Riot draws the line if you can get away with anything through an external monitor.

Happy to take any questions and do my best to give unbiased views!

10

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt15bg/?context=3#mvt15bg "Jun 03 2025, 17:31:26 UTC")

> TLDR: In-game bad, pre-game/post-game good

Pre-game (i.e. draft) is not okay either in my opinion - the game starts in champ select. If it's taking any data from champion select to make determinations on a game's winrate or what picks you should take - that's an unfair advantage given to the player using the tool that a player without the tool cannot have. They now have a higher chance of winning simply by having said tool, even if they only play 3 champions they can still pick the "best" option of those 3.

I'm all for things like reviewing yourself, but things that give you an _in the moment_ competitive advantage is not okay. Even looking up champion counters/winrates in a browser is kinda not okay, but I don't see a way to prevent that realistically.

It's crazy to me as someone who's been ~Masters+ MMR since Season 3 to see how downhill player knowledge has gone because so many people rely on apps like these to just "tell them" what's good. That used to be a skill, just like jungle timing and tracking was a skill for such a long period of League's life.

* * *

Complete side note but IMO, and this is _somewhat_ hypocritical to my above statement as well, but I think OTP's should not be allowed to climb the way they do currently, and you should be allowed to see the players in the lobbies ~10 game match history. OTP'ing is strong because you get to learn at a much quicker rate than someone who doesn't OTP due to off-loading a lot of mental workload to muscle memory, but OTP's are genuinely between 2-4 divisions lower skill level off their OTP. With draft being such an important part of the game now, allowing 1-tricks without some way for the opponent to punish them is odd.

8

[u/JackWills94](https://safereddit.com/user/JackWills94) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt9oce/?context=3#mvt9oce "Jun 03 2025, 18:09:51 UTC")

Thanks for the response!

I agree that post-game is definite OK, in-game definitely Bad, then draft is the grey area.

What this really comes down to is what are we trying to maximise for:

If it's competitive integrity, then draft AI should also be blocked, alongside in-game tools.

However, if the objective is actually something like "increasing the player base" or "game enjoyment" then it's much tougher to decide. The vast majority of our users say they like the app because it encourages them to play more champs, whilst also not having to spend time speed-typing into a stats website to find a good counter pick or whatever.

3

u/\[deleted\] [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvx8246/?context=3#mvx8246 "Jun 04 2025, 09:31:12 UTC") edited Sep 17 '25

soup aspiring tart glorious cats squeeze shocking smart degree office

3

[u/JackWills94](https://safereddit.com/user/JackWills94) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxpbaf/?context=3#mvxpbaf "Jun 04 2025, 11:51:25 UTC")

Is looking at Champion Win Rates cheating, too?

1

u/\[deleted\] [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxpiu6/?context=3#mvxpiu6 "Jun 04 2025, 11:52:52 UTC") edited Sep 17 '25

reach march sharp plate snails beneficial paltry vegetable payment crowd

1

[u/JackWills94](https://safereddit.com/user/JackWills94) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxyz4j/?context=3#mvxyz4j "Jun 04 2025, 12:52:23 UTC")

A human _could_, but certainly not a new player (or someone not paying attention to the meta/new champs)

2

u/\[deleted\] [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxzd0a/?context=3#mvxzd0a "Jun 04 2025, 12:54:37 UTC") edited Sep 17 '25

aromatic vegetable toothbrush sulky outgoing exultant offer flag bike squeeze

[→ More replies (1)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxyz4j)

5

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtmdvk/?context=3#mvtmdvk "Jun 03 2025, 19:20:22 UTC")

While the argument for making it easier for casual players is fair, this data _is_ used to give a competitive advantage. At bare minimum it shouldn't be allowed in Ranked, and it should be possible with Riot's current tooling to determine if you have these tools running and prevent queuing for Ranked while allowing them in Draft.

If Riot is not willing to put it in the client, it should not be available outside of it.

1

[u/fabton12](https://safereddit.com/user/fabton12) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt4rpr/?context=3#mvt4rpr "Jun 03 2025, 17:47:44 UTC")

> \- I'm in favour for almost everything based on the "review" process (i.e. checking stats of games you've played, AI analysis, auto-VOD reviews). It will never replace human coaches, but it makes it more accessible for the 99% of players who can't justify paying for one. I see no issue with it.

post game stuff like that is fine since it lets people put in the effort to learn themselves with the tool issue is when things start to happen during the game since now people use it as a way to get higher without being better just by having the game tell them whats up. im glad your on the side of ruling out in-game AI since thats where its insane in general with how much it can cover for peoples mistakes and skill gap.

> \- Draft, which is where we specialise, is an interesting one. Our main userbase tend to be people who just don't have the time to keep up with meta and don't play enough to know EVERY match-up and counter. They previously went onto (insert data website), but appreciate that our AI considers more than just the lane match-up and saves them time. Same with builds/runes/summoners. A lot of people use it to try new Champions, but in drafts where they aren't completely int. I still think someone with innate knowledge of the game has the advantage in picking Champions, but now it doesn't require being constantly clued up on the meta, and players can be more confident trying out new things. If you want to get real free LP, you OTP, it's the OP strategy - it's just that most people don't want to and would rather learn and try different Champs.

This is where i heavily disagree during draft even people who keep up with the meta and play a ton at a high level won't be able to know what to draft around based on both team comps and lane matchups. as you said they would go to XYZ data website for counters but thats the thing its only counters for that one lane the info was bare bones but now with these overlays/apps with drafting AI's there getting info that adapts with the champ select to the point no human can do themselves.

The game is considered started once champ select is started that how riot sees it for punishments and other aspects and how it should be seen for apps etc a draft AI affects the outcome of the game alot more then any quick info on a data website and should be treated with the same as in-game AI/Tools is treated.

my main question is why should draft based AI/Tools be treated differently to in-game AI/Tools when both have a drasticly affected on the outcome of the game for the average player.

20

[u/JanEric1](https://safereddit.com/user/JanEric1) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtfcng/?context=3#mvtfcng "Jun 03 2025, 18:36:30 UTC")

> my main question is why should draft based AI/Tools be treated differently to in-game AI/Tools when both have a drasticly affected on the outcome of the game for the average player.

Because an draft overlay can trivially be replaced by a separate app/tool/website where you just manually enter the up to 18 (28) relevant pieces of information with exactly 0 ways to prevent that

6

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu16r7/?context=3#mvu16r7 "Jun 03 2025, 20:32:24 UTC")

no high elo player needs to be told what champion fits the draft, trust me on this

24

[u/DeirdreAnethoel](https://safereddit.com/user/DeirdreAnethoel) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs1idz/?context=3#mvs1idz "Jun 03 2025, 14:46:13 UTC")

> Gank Alerts:

Should be straight up cheating yeah.

> Heatmaps

Data analysis of _past_ games is kinda fair game in theory but Riot might want to consider fully anonymous ranked games (not just lobby) because the data on opponents is getting crazy.

> Champion Select:

The only input for the AI here is a list of champions, I can't see how you could ban this. Even if you ban capturing data from the lobby, you could easily manually imput that information in a third party software that isn't observing the game.

> In Game

AI would need access to a lot of game data to make that kind of prediction, which Riot could easily rule out to be forbidden and ban appropriately.

I feel like a combination of anonymous accounts (to avoid past games data harvesting) and limits on what data is allowed to access for thirdparty software (to avoid the game giving too detailed predictions/instructions) should solve most of those issues.

I can see the second part being a rule clarification riot does in the future if predictive/instructive AI takes over with the data currently available.

I'm not sure what Riot's stance on the current status of datamining _past_ games from opponents is, but I don't see that part getting fixed short of my proposed anonymity system, since otherwise you could always input the enemy ID in a non overlay thirdparty tool.

41

[u/AdNidalee](https://safereddit.com/user/AdNidalee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsjfba/?context=3#mvsjfba "Jun 03 2025, 16:09:35 UTC")

I don't think heatmaps are fair game. If I don't have the overlay, I would be expected to manually go through the enemy jungler's replays of their past 10 games and track their level one patterns and how often they lvl 3 gank or invade WHILE IN LOADING SCREEN. It's not humanly possible.

7

[u/DeirdreAnethoel](https://safereddit.com/user/DeirdreAnethoel) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsk3c7/?context=3#mvsk3c7 "Jun 03 2025, 16:12:45 UTC")

Well yes, but either riot makes people's games unaccessible or make it impossible to track who you're playing against, because none of this is an overlay problem per se. As I said, you could always manually input the ID of your opponent in a non-overlay third party tool.

9

[u/HibeePin](https://safereddit.com/user/HibeePin) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtf7n7/?context=3#mvtf7n7 "Jun 03 2025, 18:35:44 UTC")

Alternatively Riot can revoke the API key of any third-party tool giving a heatmap. But that makes the line a lot more blurry. Because what's the line between a plain match history and a heatmap?

5

[u/Cheetah\_05](https://safereddit.com/user/Cheetah_05) GUMAYUSI [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvts438/?context=3#mvts438 "Jun 03 2025, 19:48:59 UTC")

Valorant's main third party app (valotracker) has an opt-in feature, so everyone can decide for themselves if they want their match history public. That might help?

1

[u/DeirdreAnethoel](https://safereddit.com/user/DeirdreAnethoel) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwzbgy/?context=3#mvwzbgy "Jun 04 2025, 08:02:39 UTC")

Either that or giving us private API keys we can choose to share or revoke with apps to process our own data (I would like a heatmap of myself but not for it to be available to others).

5

[u/AdNidalee](https://safereddit.com/user/AdNidalee) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvstqty/?context=3#mvstqty "Jun 03 2025, 16:57:51 UTC")

I get what you're saying, great point. Just make them anonymous then

2

[u/DeirdreAnethoel](https://safereddit.com/user/DeirdreAnethoel) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwzq9t/?context=3#mvwzq9t "Jun 04 2025, 08:06:53 UTC")

Yep, making ranked games anonymous like the ranked lobbies would solve a lot of issues.

6

[u/fabton12](https://safereddit.com/user/fabton12) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt28sx/?context=3#mvt28sx "Jun 03 2025, 17:36:26 UTC")

> Riot might want to consider fully anonymous ranked games (not just lobby) because the data on opponents is getting crazy

they tried that ages ago and it pretty much backfired on them, players bitched that they couldnt look up there match history online anymore or look up teams in loading screen etc and how they could get stats they could before online. They could do it again now you can link your riot account to a third party giving yourself your own data on sites for ranked but not for other peoples info.

> Data analysis of _past_ games is kinda fair game in theory 

in theory its fine if its the same lot of people your facing but the fact you can grab any persons data means its no longer past games of yourself against them but now a map of there in general playstyle of a person you never faced before. its kinda nuts when it gets to that point really.

2

[u/Contrite17](https://safereddit.com/user/Contrite17) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv0neb/?context=3#mvv0neb "Jun 03 2025, 23:38:18 UTC")

I mean you could design the system where player data is anonymous in game, but still records full records post game so you get full histories of everyone but cannot pull what players are in your current game or lobby.

1

[u/DeirdreAnethoel](https://safereddit.com/user/DeirdreAnethoel) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwzocg/?context=3#mvwzocg "Jun 04 2025, 08:06:21 UTC")

> they tried that ages ago and it pretty much backfired on them, players bitched that they couldnt look up there match history online anymore or look up teams in loading screen etc and how they could get stats they could before online. They could do it again now you can link your riot account to a third party giving yourself your own data on sites for ranked but not for other peoples info.

The solution for this (from experience playing other games with it, like EVE online) is a system of private API keys you can choose to share or revoke with apps to process your own data, but no one else can access. And of course apps would still have anonymized data for more general statistics.

[→ More replies (5)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs1idz)

7

[u/t1000s1](https://safereddit.com/user/t1000s1) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs1bnx/?context=3#mvs1bnx "Jun 03 2025, 14:45:21 UTC")

Good post, hopefully this gets some discussion in this sub!

5

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs5w28/?context=3#mvs5w28 "Jun 03 2025, 15:06:48 UTC")

im open to some help for the game, especially for new players, like autorunes/etc, but when im in game it gets weird, at some point you're wondering how much the enemy player is reading your gameplay or straight up having a map hack, so there is def some tuning to do

4

[u/Gosuoru](https://safereddit.com/user/Gosuoru) i like silly lil dudes [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvth3je/?context=3#mvth3je "Jun 03 2025, 18:46:53 UTC")

Don't we already have auto-runes? Iirc you can pick from any 3 runepages based on most used runes for a champ now (this may not be in ranked but I know for a fact its in casual modes)

4

[u/Jealous\_Juggernaut](https://safereddit.com/user/Jealous_Juggernaut) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv86pg/?context=3#mvv86pg "Jun 04 2025, 00:21:42 UTC")

They 3 can differ in winrate by over 5% at times and some can have as little as 5k games per patch vs 100k on the standard rune page. And those ones can be the first, thus automatically chosen when you don't select anything, giving you a massive disadvantage.

2

[u/Gosuoru](https://safereddit.com/user/Gosuoru) i like silly lil dudes [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvvdnjg/?context=3#mvvdnjg "Jun 04 2025, 00:54:13 UTC")

Oh yea, I also hate some bugs that occur where it auto-chooses the runepage and its like, no please I have one for my champ :')

2

[u/Gosuoru](https://safereddit.com/user/Gosuoru) i like silly lil dudes [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvth40r/?context=3#mvth40r "Jun 03 2025, 18:46:58 UTC")

Don't we already have auto-runes? Iirc you can pick from any 3 runepages based on most used runes for a champ now (this may not be in ranked but I know for a fact its in casual modes)

3

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtp5za/?context=3#mvtp5za "Jun 03 2025, 19:34:28 UTC")

the ones given by the game are usually sub par

also you double commented

8

[u/HThrowaway457](https://safereddit.com/user/HThrowaway457) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu25de/?context=3#mvu25de "Jun 03 2025, 20:37:02 UTC")

for a new player or someone super casual they don't need the 100% optimal minor runes every game, the pages are fine for pure convenience.

1

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuh2su/?context=3#mvuh2su "Jun 03 2025, 21:51:11 UTC")

it is when sometimes the recommended runes are pure ass, especially depending on matchups

6

[u/HThrowaway457](https://safereddit.com/user/HThrowaway457) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuhkhz/?context=3#mvuhkhz "Jun 03 2025, 21:53:45 UTC")

Bad players are losing by a million degrees before they are by not having bone plating.

1

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvui9ig/?context=3#mvui9ig "Jun 03 2025, 21:57:23 UTC")

did i say bad players ?

i said new players

game mechanics are so many, its overwhelming, its a good way to mitigate, bad players gonna be bad no matter the runes, and usually the worse they are, the more they do their own runes

its not the same to discover the game with bad runes that forces you to have a bad gameplay, and being bad so that you get bad runes and play bad

the runes recommendations changes a matchup entire, i can go and first time akali and do fine with good runes, or go 0/10 with bad runes, thats how strong they are especially early

5

[u/HThrowaway457](https://safereddit.com/user/HThrowaway457) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuj9r8/?context=3#mvuj9r8 "Jun 03 2025, 22:02:43 UTC")

New players are bad, that's kind of the nature of being new in a game this hard. It's better to take a 90% optimal page every game and learn through the same lens every time rather than constantly swapping and trying to optimize when you don't understand those optimizations, their strengths and weaknesses.

The difference is simply not that stark, you can learn akali with conq or electro or fleet every game, the important part is that you learn her kit and her matchups, not which matchup you can take electro in to win level 2 specifically.

0

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuziuh/?context=3#mvuziuh "Jun 03 2025, 23:32:04 UTC")

> New players are bad

not necesseraly, thats my point, also its better to help people learn than to just say they are bad and should stay bad cause they shouldnt eb able to learn anything until they learn everything in order

> The difference is simply not that stark

i can assure you it is, for me thats the difference between 0/10 or going even, and im talking about matchups i know a bit

7

[u/HThrowaway457](https://safereddit.com/user/HThrowaway457) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv4zy4/?context=3#mvv4zy4 "Jun 04 2025, 00:02:54 UTC")

It's literally helping them learn to simplify all the extra pieces that aren't core to the gameplay.

[→ More replies (0)](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv4zy4)

2

[u/Gosuoru](https://safereddit.com/user/Gosuoru) i like silly lil dudes [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtqrnq/?context=3#mvtqrnq "Jun 03 2025, 19:42:28 UTC")

Ah sorry about double comment, first one gave me an error from reddit :')

1

[u/Cheetah\_05](https://safereddit.com/user/Cheetah_05) GUMAYUSI [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtshxk/?context=3#mvtshxk "Jun 03 2025, 19:50:52 UTC")

jinx's main runes is 100% one of the pages

1

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuh5xa/?context=3#mvuh5xa "Jun 03 2025, 21:51:38 UTC")

you know there is like 160+ champs ? not just jinx

1

[u/Cheetah\_05](https://safereddit.com/user/Cheetah_05) GUMAYUSI [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvx0x8i/?context=3#mvx0x8i "Jun 04 2025, 08:19:11 UTC")

yeah but jinx is your flair, how many other champs do you play regularly enough to know if their recommended runepages are optimal or not?

1

[u/kykyks](https://safereddit.com/user/kykyks) I'm crazy! Got a doctor's note. [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxgt68/?context=3#mvxgt68 "Jun 04 2025, 10:49:07 UTC")

my flair is old, but i play new champ regularly, not everyone is otp

especially when im filled

3

[u/PhoenixInvertigo](https://safereddit.com/user/PhoenixInvertigo) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs9z0j/?context=3#mvs9z0j "Jun 03 2025, 15:25:52 UTC")

Important that people become aware of these possibilities, how extremely likely development of these apps is, and that it will only continue to get worse as people think of more creative ways to assist the player in their decisionmaking

3

[u/DragoCrafterr](https://safereddit.com/user/DragoCrafterr) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwizm2/?context=3#mvwizm2 "Jun 04 2025, 05:31:18 UTC")

Highest effort textpost I’ve seen in a while here with the examples damnn

10

[u/kamparox](https://safereddit.com/user/kamparox) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs1ooh/?context=3#mvs1ooh "Jun 03 2025, 14:47:03 UTC")

It's only a matter of time before someone develops an overlay that is one degree removed from cheating and riot has to ban all of them. The draft AIs already have like 70%+ prediction rate regardless of elo.

24

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs74gz/?context=3#mvs74gz "Jun 03 2025, 15:12:37 UTC")

I've seen this be repeated a lot but every time the 'AI' model is just some insanely overfitted ML model that usually take into account player Elo/mastery and do not have this performance in real data. I would change my mind in the face of adequate evidence.

3

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsxnnb/?context=3#mvsxnnb "Jun 03 2025, 17:15:37 UTC")

I mean, all AI models are just ML models - but they just look at champion winrates with / against each other, they can't look at player mastery / elo really because all of that is hidden in champ select (except your own).

But it's still a huge advantage to go into a lobby and have a machine learning algorithm telling you that you have a 70% chance of winning the game just based on draft. You can now easily dodge any sub-70% chance of winning regardless of player skill. That's a huge advantage.

6

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt45vj/?context=3#mvt45vj "Jun 03 2025, 17:45:00 UTC")

I'm actively contesting this 70% figure

5

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtlhyv/?context=3#mvtlhyv "Jun 03 2025, 19:15:39 UTC")

I mean, 70% is clearly not a real stat - the point is that even if the advantage given by the algorithm is a +1% winrate, that's a clear competitive advantage no? Like there's no argument here, if you can gain even 1% winrate by dodging based on draft using an ML tool that's not okay, right?

4

u/\[deleted\] [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxbga4/?context=3#mvxbga4 "Jun 04 2025, 10:03:04 UTC") edited Sep 17 '25

head paltry absorbed fuel spark touch grandiose quack entertain station

3

[u/HThrowaway457](https://safereddit.com/user/HThrowaway457) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu2fgd/?context=3#mvu2fgd "Jun 03 2025, 20:38:23 UTC")

Draft prediction doesn't matter if they just come to your house and blow up your router for dodging as they should.

2

[u/MoreBookkeeper4729](https://safereddit.com/user/MoreBookkeeper4729) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvui3j5/?context=3#mvui3j5 "Jun 03 2025, 21:56:31 UTC")

Where is this 70% from? Genuinely curious

1

[u/linstr13](https://safereddit.com/user/linstr13) [Jun 05 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mw37r5d/?context=3#mw37r5d "Jun 05 2025, 05:55:47 UTC")

Probably [this](https://safereddit.com/r/leagueoflegends/comments/1k5hmlf/ai_can_predict_the_winner_of_767_of_your_games/) post, though it was removed. The model was heavily flawed since it didn't get fed the ranks of the players in the game, rather it got the current rank of the players, even for old games. Also, the model wasn't much better than guessing the team with the highest average rank, getting about 72% of matches correct.

5

[u/Vivid-Amphibian-5593](https://safereddit.com/user/Vivid-Amphibian-5593) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs7sdx/?context=3#mvs7sdx "Jun 03 2025, 15:15:45 UTC")

Just add proper jungle timers and overlay is useless for 50% of it users

2

[u/Excellent\_Sport\_967](https://safereddit.com/user/Excellent_Sport_967) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsz6bz/?context=3#mvsz6bz "Jun 03 2025, 17:22:29 UTC")

Ban them all

2

[u/JoshiKousei](https://safereddit.com/user/JoshiKousei) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtjmf3/?context=3#mvtjmf3 "Jun 03 2025, 19:02:51 UTC")

I think overlays or tools should be limited to importing builds and skill priorities.

2

[u/Kaydie](https://safereddit.com/user/Kaydie) goodest boy rework when [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvukoo7/?context=3#mvukoo7 "Jun 03 2025, 22:10:18 UTC")

the composition segment:

[https://loldraftai.com/draft](https://loldraftai.com/draft) this already exists for compositions and it has disturbingly good tested accuracy. it's right quite a bit more often than it's wrong

[https://www.reddit.com/r/leagueoflegends/comments/1joumtm/i\_made\_an\_ai\_model\_that\_predicts\_62\_of\_ranked/](https://safereddit.com/r/leagueoflegends/comments/1joumtm/i_made_an_ai_model_that_predicts_62_of_ranked/)

2

[u/Carter1599](https://safereddit.com/user/Carter1599) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv8ky1/?context=3#mvv8ky1 "Jun 04 2025, 00:24:03 UTC")

Another one I've noticed is I consistently get 2 manned when I ward specific parts of enemy jungle early even if I switch the location, could just be predictability. Usually I blame porofessor or one of those bullshit apps that tells you things no solo queue player should know

4

[u/Clbull](https://safereddit.com/user/Clbull) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvueawk/?context=3#mvueawk "Jun 03 2025, 21:36:57 UTC")

I avoid overlay apps like Porofessor, Mobalytics or Trophy Hunter simply because I do not trust Overwolf as a business (they're basically the Wikia/Fandom of addon/mod sites), nor their overlay app because it's bloatware and one of the worst resource hogs I've seen.

Also, my first experience with Overwolf was discovering it had been installed on my PC without my knowledge nor consent, due to it being stealthily bundled with the Teamspeak 3 installer over a decade ago.

A few years ago they acquired Curseforge from Twitch and in doing so locked down access to their API (flipping the middle finger to both the WoW addon and Minecraft modding communities) and pushed their overlay bloatware shit upon people who used their official downloaders. They're a very big reason why a good portion of the WoW community has switched to using Wago to download addons.

Given how much of an unfair advantage these apps give, I think there's a strong argument for Riot to ban these apps and to have Overwolf get flagged by Vanguard in general.

4

[u/mbr4life1](https://safereddit.com/user/mbr4life1) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsmyjj/?context=3#mvsmyjj "Jun 03 2025, 16:26:21 UTC")

Riot needs to put an end to this and include what they want in the game. People shouldn't be penalized because they don't want outside apps.

5

[u/n0ticeme\_senpai](https://safereddit.com/user/n0ticeme_senpai) Wood IV [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs9j75/?context=3#mvs9j75 "Jun 03 2025, 15:23:49 UTC")

The benchmark should be "Can the information reconnaissance be done with pen & paper while simulatenously playing?" And when your both hands are on QWER and the mouse, you can't do any of the info-collecting with pen&paper in-game. Riot should disallow pretty much prohibit every 3rd party data overlay and not turn this game into "who is using the better overlay". Maybe an exception for champ select analysis since your hands are not necessarily glued to QWER + mouse during champ select.

3

[u/TechnalityPulse](https://safereddit.com/user/TechnalityPulse) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt2g4m/?context=3#mvt2g4m "Jun 03 2025, 17:37:19 UTC")

> And when your both hands are on QWER and the mouse, you can't do any of the info-collecting with pen&paper in-game

That's not _entirely_ true, players at highest level have been known to use a notepad to track summoner timers and stuff alt-tabbing etc. which is essentially "pen&paper".

But still, allowing the offloading of that tracking to a 3rd party tool is unacceptable.

3

[u/HaganeLink0](https://safereddit.com/user/HaganeLink0) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtf0zz/?context=3#mvtf0zz "Jun 03 2025, 18:34:44 UTC")

> it provides you with the optimal champion to choose for the match.

Which is going to be useless 99% of the time. AI can't know your or your enemies' level of knowledge on those champs. Winning draft outside of pro-play means almost nothing.

> You could argue that League is somewhat similar (to chess).

With the exception that in League, a pawn can destroy your queen 12 times if you are first timing.

> With AI becoming more powerful and overlays capable of leveraging API data in increasingly sophisticated ways, where do we draw the line?

I highly doubt that we are close to getting any AI that would give a significant advantage.

1

[u/Straight\_Chip](https://safereddit.com/user/Straight_Chip) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsw0k8/?context=3#mvsw0k8 "Jun 03 2025, 17:08:11 UTC")

Well written thread and surprising that there's so much information out there. I personally never used things other than jungle timer overlay + manually scouring lolalytics.

> When does using publicly available data via a tool cross over from providing helpful statistics into providing an unfair, almost automated, advantage that borders on cheating?

I think a decent solution would be to disallow all forms of processing of API information during the game, whilst allowing all the pregame analysis shenanigans.

1

[u/Ilosesoothersmaywin](https://safereddit.com/user/Ilosesoothersmaywin) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsy9f1/?context=3#mvsy9f1 "Jun 03 2025, 17:18:19 UTC")

For champ select it doesn't really matter. AI doesn't have access to your opponents so it can't 'predict' that your enemy is going to pick X, Y, Z, champions based on their match histories or know that they like to invade so you need to pick a champion that can rotate fast, etc.

So the information it has is very limited for champion select. And with that limited information it can still give you best choices of what to pick. But that isn't a big deal since what matters most in any game is what champion you are comfortable playing with.

If an AI says the best pick is Ryze, but I don't play Ryze, I'm not going to play them. The human factor will always make it so that it's best to pick one of the few champions you know best, in which case most people will already know what champions they know go well against others.

1

[u/fabton12](https://safereddit.com/user/fabton12) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt0cc6/?context=3#mvt0cc6 "Jun 03 2025, 17:27:46 UTC")

> **Champion Select:**  
> An AI \*could\* analyze the entire lobby composition. Not just simple counters, but deep data on champion synergies, early/mid/late game power spikes, scaling differences, teamfighting capabilities, objective control, common ganking paths or strategies associated with those champions and more. It \*could\* then suggest not just a "good" pick, but the \*statistically optimal\* champion choice for that specific game based on millions of analyzed games, predicting which pick maximizes your win probability given the already other picked champions in the game. While I'm writing \*could\*, this is already a thing in several Overlays like Porofessor

already an app that does that Itero . GG does that an app made by the LEC team GiantX, it look at the champ select and tells you the best pick/picks based on all that data your suggestioning. kinda nuts actually when wanting the highest chance at winning.

it also has other massive AI features as well to the point it does feel like cheating.

Some other points to talk about is the new Rise of AI monitors, theres new monitors now with AI built into them with features such as giving a indicator when someone appears in vision and it can also change your cursor colour constantly to make it always visable or increased zoom etc etc, some of these features are better in other games but the shit they have is insane.

> **So, my core question is:** With AI becoming more powerful and overlays capable of leveraging API data in increasingly sophisticated ways, where do we draw the line? When does using publicly available data via a tool cross over from providing helpful statistics into providing an unfair, almost automated, advantage that borders on cheating? What does "unfair" truly mean in this evolving landscape, when we already have overlays showing you the best picks, or the best moves ingame, which definitely can give you an ~("unfair")~ advantage?

to answer your question overlays crossed the line the moment they were made pretty much, so many features from the get go gave people advantages they shouldnt have and made things possible that not even a pen and paper could let you do(which tends to be riots stance on overlays if you can do it with pen and paper its ok).

1

[u/Randomis11](https://safereddit.com/user/Randomis11) slithery snek [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt4otc/?context=3#mvt4otc "Jun 03 2025, 17:47:22 UTC")

If we are loud enough riot will take care of it, just dont be silent over what you want and things will shake out fine. As for China, their culture seems to normalize anything that improves winrate so they are going to use every AI tool under the sun

1

[u/LargestPerson](https://safereddit.com/user/LargestPerson) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvt7mub/?context=3#mvt7mub "Jun 03 2025, 18:00:27 UTC")

i believe the line is real time tips/notifications. anything in champ select is fair game imo, as well as heat maps but not in real time or too easily accessible/implemented.

1

[u/Lytri\_360](https://safereddit.com/user/Lytri_360) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtgko6/?context=3#mvtgko6 "Jun 03 2025, 18:43:35 UTC")

id set the line at "ingame data" anything that bappens in champselect during loading screen or after the game is fine. Any data that changes during the game should be banned (and riot really should implement a way to ping-track enemy summs other than "top1005")

1

[u/relaximnewaroundhere](https://safereddit.com/user/relaximnewaroundhere) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtpqs2/?context=3#mvtpqs2 "Jun 03 2025, 19:37:23 UTC")

You can't even innovate or come up with a unique start or playstyle anymore because AI will call you out.

1

[u/bedatboi](https://safereddit.com/user/bedatboi) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtqf3r/?context=3#mvtqf3r "Jun 03 2025, 19:40:45 UTC")

It’s wild to me that riot even approves of overlays

1

[u/reskk](https://safereddit.com/user/reskk) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvtqwl1/?context=3#mvtqwl1 "Jun 03 2025, 19:43:07 UTC")

I vaguely recall Curse Overlay being banned at some point in the early seasons, why did Riot stop banning them?

1

u/\[deleted\] [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu02jc/?context=3#mvu02jc "Jun 03 2025, 20:27:07 UTC")

man i just want camp timers and being able to click enemy summoner for a timer so i dont have to type that shit in chat, plz riot

1

[u/caveman767](https://safereddit.com/user/caveman767) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu4q0u/?context=3#mvu4q0u "Jun 03 2025, 20:49:20 UTC")

Honestly all i need are jungle timers, ability to ping summoner card is ok but not needed. Jungle timers is a must

1

[u/Dazzling-Affect1654](https://safereddit.com/user/Dazzling-Affect1654) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu4vfh/?context=3#mvu4vfh "Jun 03 2025, 20:50:03 UTC")

Said this before many times ALL overlays should be banned all of them. Even the ones that just randomly play music for you only. There should be 0 spots for grey areas

1

[u/R0nin\_23](https://safereddit.com/user/R0nin_23) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu82vb/?context=3#mvu82vb "Jun 03 2025, 21:05:27 UTC")

How did you code this app? It's a lot of calls from Riot API display a lot of different informations.

1

[u/Elvenstar32](https://safereddit.com/user/Elvenstar32) April Fools Day 2018 [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvu9hlg/?context=3#mvu9hlg "Jun 03 2025, 21:12:28 UTC") edited Jun 03 '25

Man I really hate how everything is "AI" now and how most people don't even know what they mean when they say "AI" nor have any idea about to implement it nor how it actually works and I say that as someone who only has a very passing understanding of it.

I don't doubt that you got some impressive looking data through your program but it's not AI in any way, none of what you did actually needs some big LLM, just a bit of fancy maths on the numbers you pulled from the API.

But hey congrats on using "AI" as the marketing term it is for your thread whilst also riding on the current subreddit meta of complaining about overlays.

\>This \*could\* extend to real time macro guidance. Based on training data from million game timelines, an AI \*could\* potentially analyze the live game state and suggest the play with the highest predicted win rate increase. "Take Dragon now (+10% Win Rate)," "Invade red side jungle (+7% Win Rate)," or "Gank top lane (+8% Win Rate)."

Also this is just not going to happen. An LLM capable of doing that would require a lot more work and skill than the people who are currently deploying tweaked chatGPT agents actually have. You're theorising a system that:

\- can detect stuff like "oh taking dragon is good" (no shit Sherlock)

\- based on that determine when teamfights will happen and how they will play out based on individual player skill which itself depends on how comfortable the player is on the champion (for which data might start getting quite sparse for an LLM to make any worthwhile conclusion)

\- will be able to make accurate predictions of outcomes based on the current patch's data. Like yeah there's a lot of League matches but really there's not that many once you take individual ranks and patches into account. It's pointless to give diamond+ level macro tips to a player in silver, there's bigger issues happening in those games like when you win a teamfight, the team might not actually cooperate to do baron or push a lane, or that the player using the tool mechanically simply isn't good enough to capitalise on a gold lead or that in a teamfight the yasuo decided to try for a cool play instead of waiting for a good engage.

It's not _impossible_ but it's not a small quick money project to deploy some shit on overwolf easy either. It'd take time, effort, some form of capital investment for hardware and honestly hiring a couple people who actually know what they're doing with this stuff and for someone out there to actually think "yeah there's gonna be a return on investment on selling subscriptions for this". There's a reason all the marketing AI overlay stuff is shit right now and it's not that the technology isn't there yet, it's that it's financially not worth it especially since Riot at any moment could pull the plug on it.

The jungle gank warning thing that looks at the minimap for you admittedly is pretty BS but that's got nothing to do with AI either.

1

[u/Lantzl](https://safereddit.com/user/Lantzl) Depressed Kindred Main [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuenng/?context=3#mvuenng "Jun 03 2025, 21:38:45 UTC")

I miss the time when you had to have chat timestamps so you can accurately call jungle/dragon/flash timings

1

[u/CloudClown24](https://safereddit.com/user/CloudClown24) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvutwbw/?context=3#mvutwbw "Jun 03 2025, 23:01:04 UTC")

AI is terrible for champ selects.

1

[u/Even\_Cardiologist810](https://safereddit.com/user/Even_Cardiologist810) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvv01iv/?context=3#mvv01iv "Jun 03 2025, 23:34:56 UTC")

To those wondering what an ingame ai could give you. Look up Rala.ai for valorant. You can ask it ingame for setup for Characters with traps for instance. It Will also predict where ennemies Will go based on their ressource avialable 

1

[u/someonesshadow](https://safereddit.com/user/someonesshadow) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvvuy0u/?context=3#mvvuy0u "Jun 04 2025, 02:36:53 UTC")

At this point Riot should just revamp their own overlays. We already get teammate ult CDs, camp CDs, etc. just make the official overlay display things you or your teammates see, for instance if mid blows a flash enemy flash timer shows up on everyone's overlay.

I used to be in the camp of not getting any info and keeping track of it all in your head, however, there are now almost 200 champs, the jungle changes heavily every year, the metal shifts sometimes drastically every two weeks, many new champs have 8+ abilities in their kits.. etc.

The games and information overload already, so give the players all the information they or their team gathers on the enemy, and allow the best players to leverage the info better. It also takes a load off the worst players or new players who are already struggling to deal with being almost 20 years late to a game that is mostly players who have half that or more in experience.

1

[u/enricojr](https://safereddit.com/user/enricojr) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvw1106/?context=3#mvw1106 "Jun 04 2025, 03:16:21 UTC")

I think the future of League and other online games is that they'll be "streamed" from servers that Riot owns, kind of like how you can stream games from a PC to a mobile device with Steam Link, or from one PC to another via Steam itself.

That way, your device becomes nothing more than a "video player" and nothing you install client-side can really mess with it

1

[u/avengers9](https://safereddit.com/user/avengers9) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwfhr5/?context=3#mvwfhr5 "Jun 04 2025, 05:02:43 UTC")

I feel like you’re overestimating the champ select ai tools. Anyone can just go on u.gg and sort their lane by winrates. Should u.gg be banned as well? Or any site that tells you what runes to take or items to build? Because thats a competitive advantage in the same sense. Should you be allowed to know if a champion is strong this patch?

1

[u/Crnogoraac](https://safereddit.com/user/Crnogoraac) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwstyj/?context=3#mvwstyj "Jun 04 2025, 06:58:38 UTC")

I ward A LOT as support, and those wards are very deep. I still die from ganks because i dont watch map that much, mostly when baited by low hp enemy botlaner. With gank alert, i would be every junglers nightmare.

1

[u/RaidBossPapi](https://safereddit.com/user/RaidBossPapi) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwtmvt/?context=3#mvwtmvt "Jun 04 2025, 07:06:05 UTC")

This shit ruined wow and if it gets solid macro, could turn league into a pure skill check game where the overlay tells you what to do all the time. Riot should just add jg timers on map, maybe some other QoL stuff and straight up prohibit all third party overlays inside the game.

1

[u/lichink](https://safereddit.com/user/lichink) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwz5ex/?context=3#mvwz5ex "Jun 04 2025, 08:00:56 UTC")

I use blitz to have autorunes.

I have access to half of this and disabled it cause it annoys my view.

I want to play ADC and dive lvl1. Leave me alone

1

[u/Patchoel4](https://safereddit.com/user/Patchoel4) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvxiqok/?context=3#mvxiqok "Jun 04 2025, 11:04:01 UTC")

I see a world where league is fully played by AI and the more expensive your AI cheat subscription is, the better the AI micro and macro. 

1

[u/OkQuote5](https://safereddit.com/user/OkQuote5) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvy3pnj/?context=3#mvy3pnj "Jun 04 2025, 13:19:26 UTC")

I don't see how vanguard can stop AI cheats. You could have the AI cheats running completely outside of the system running League directly reading the pixels of the display and out putting an overlay on the display itself.

1

[u/toxicliam](https://safereddit.com/user/toxicliam) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvyeo3m/?context=3#mvyeo3m "Jun 04 2025, 14:16:42 UTC")

What did you use to create the UI’s for these experiments? It looks great!

2

[u/nexuton](https://safereddit.com/user/nexuton) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvz4n6g/?context=3#mvz4n6g "Jun 04 2025, 16:20:16 UTC")

C# winforms

1

[u/fastestchair](https://safereddit.com/user/fastestchair) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvz1jkz/?context=3#mvz1jkz "Jun 04 2025, 16:05:35 UTC")

when it happens during the game. that's why it's not allowed in professional games.

1

[u/Bunny\_Saber](https://safereddit.com/user/Bunny_Saber) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvze2ul/?context=3#mvze2ul "Jun 04 2025, 17:04:25 UTC")

League is not a game of skill as much as it is about the right analysis and decision making vs a game like Val which is mostly about precise skills. If overlays are taking over the live analysis and decision making from you, then they are a super unfair advantage. You should be the one guessing if the enemy wants to sneak a baron or not

1

[u/timelessblur](https://safereddit.com/user/timelessblur) Cloud 9 [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvs4myj/?context=3#mvs4myj "Jun 03 2025, 15:00:55 UTC")

To me I agree tools should be limited to what can be run on pro games.

The analytical ones like heat map generations on a player Riot should update their API to say only give that info to the logged in player. It should not be possible to pull it for all players or limit it to challanger only players that you can pull all of it on a single player.

The other heat map info they should reduce it to champion and rank tear only level. It not as super deep dive to pull it to generated it. Basically stuff that is not lobby based but over all data I could look up. Like if it is a Kyan in the game chances are he is starting at his raptors or if he is on red side he likely to try to start on mine to steal them level of data. Basically a lot more private protection on a single player to look at this. Straight up the heat map stuff woudl screw me as a jungler as I do tend to do early invades and early deep wards as most players in my elo dont do that so if you know I try to often steal their raptors no matter what then you can set up to screw me.

1

[u/PolicyMean](https://safereddit.com/user/PolicyMean) #1 Keria Glazer [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsqur2/?context=3#mvsqur2 "Jun 03 2025, 16:44:38 UTC")

My personal take on it is anything outside of the game and I find genuinely useful in improving as a player, but there should be barely anything for overlays once the game actually starts: no heatmaps, no gank alerts, even the click a button for summ spell timers which are pretty harmless as a feature im kind of iffy on. Once the game is actually starting and youve bought your starter item and left fountain, the only deciders should be your personal skill and game knowledge. I'm definitely biased as I've personally never used an overlay, but I honestly don't like it that much. If you watch pro-play, once the match starts the coaches leave and don't talk to their players anymore and its just up to them. I think overlays should be the same.

1

[u/ProfMerlyn](https://safereddit.com/user/ProfMerlyn) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvvgtfu/?context=3#mvvgtfu "Jun 04 2025, 01:12:44 UTC")

Overlays are cringe cheating, hope they get banned, love the writeup and thank you for bringing attention to this.

1

[u/educatedkoala](https://safereddit.com/user/educatedkoala) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvuhf66/?context=3#mvuhf66 "Jun 03 2025, 21:52:58 UTC")

Timers & rune/mastery selection & recommended items should be in the game as good as they are in 3rd party apps and I would be fine with it. Like I just wanna play arams and with my new player friends without stressing

1

[u/IKillerBee](https://safereddit.com/user/IKillerBee) this sub has brain damage [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvvvkka/?context=3#mvvvkka "Jun 04 2025, 02:40:46 UTC") edited Jun 04 '25

The overlay issue is so overblown by this subreddit lmfao

Get rid of the ult timers and there's legitimately nothing about them that is useful for high elo players (because they already track summoners and know the camp respawn timers), and low elo players aren't good enough to take advantage of any of the tools to the point that it makes a difference. It's such a nonissue that this sub is obsessed with for some reason

Edit: genuinely think no one in the comments here has ever used one of the overlay apps, they legit add nothing of value to gameplay, which is precisely why I ditched the one I had

2

[u/Ok\_Vanilla\_1943](https://safereddit.com/user/Ok_Vanilla_1943) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvw8o45/?context=3#mvw8o45 "Jun 04 2025, 04:10:03 UTC")

I agree, it is definitely overblown. The way people are acting you'd think every single player except them has an omnipotent overlay that's telling you your opponent's heartrate and shit.

I also think they should just be banned though. Marginal advantages _do_ add up. Simple as that. If people want certain features I'm sure Riot will eventually add them should they deem it appropriate.

I generally trust Riot on this and don't need to crusade about it though. Like...they know what's going on lol.

1

[u/IKillerBee](https://safereddit.com/user/IKillerBee) this sub has brain damage [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwaqdo/?context=3#mvwaqdo "Jun 04 2025, 04:25:29 UTC")

I really don't have an opinion on whether they should be allowed or not. I had one for a little bit before they added QoL features to the game (like recommended runes for characters I don't really play in aram) and yeah having the jungle timers is nice (would love this added for QoL), but I got nothing really out of it. The stats some of them collect are cool, but also can be misleading without context.

Like you said, Riot obviously knows they exist and what they do/don't do (considering they just updated ToS for the devs of these apps to follow). They can get rid of them or keep them for all I care, just getting tired of the sub coping that having blitz or u.gg installed is an elo hack.

1

[u/ghfhfhhhfg9](https://safereddit.com/user/ghfhfhhhfg9) [Jun 04 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvwa899/?context=3#mvwa899 "Jun 04 2025, 04:21:42 UTC")

I stopped caring about LoL because all my opponents use this bs that gives them an advantage.

Wish Riot banned 3rd party. This game is pretty crap like osrs now.

0

[u/AbyssalSolitude](https://safereddit.com/user/AbyssalSolitude) [Jun 03 '25](https://safereddit.com/r/leagueoflegends/comments/1l2d8vp/league_overlays_and_ai_when_data_analysis_becomes/mvsmdpq/?context=3#mvsmdpq "Jun 03 2025, 16:23:38 UTC")

I don't really care. People who just blindly repeat what assistant tools tells them to do w/o understanding the logic behind it will always be worse than those who do understand it. They might even perform worse than same skilled people who don't use these tools.

League isn't chess.
