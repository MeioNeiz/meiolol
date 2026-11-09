What is Leetify Rating? 

 ← Back to Leetify 

 Blog Home 

 Sign up for Leetify 

 What is Leetify Rating? 

 Leetify Rating 

 What is Leetify Rating?

 Edit: visit https://leetify.com/blog/leetify-rating-explained/ for the most up-to-date info

Here is the full explanation of how we compute Leetify Rating and the history of its updates. 

 Anders Ekman

 Read more posts by this author.

 Anders Ekman 

 16 Sep 2021 
 • 12 min read 

 THIS ARTICLE ONLY APPLIES TO MATCHES FROM BEFORE 2024-11-26! Go here instead for the newest info on how Leetify Rating works: https://leetify.com/blog/leetify-rating-explained/
 Leetify Rating is a win rate impact based and economy-adjusted player rating system for CS:GO. It rewards players based not only on who deals the final point of damage but also on the outcome of and contributions to all the kills they take part in.
 This rating solves a a key problem that plagues current advanced metrics: it is too easy to get a lot of credit from un-impactful kills. By this we mean kills against poorly equipped opponents or in situations where an opponent is heavily outnumbered. When playing these situations correctly, it is just a matter of who actually finishes them off, not if they will be finished off. With Leetify Rating, players will get punished harder for throwing rounds away against ecos, and the importance of that double-entry on a Deagle round will actually be rewarded.

 The four main concepts that work together to produce the Leetify rating are:
 Using the round win probability before/after key events to give out rating. Round win probability depends on the economy of both teams at the start of the round as well as the number of people that are alive on each team before a key event. These key events are either kills or a round ending with players alive on both teams. 
 Viewing kills that happen in quick succession as part of a kill chain and evaluating how critical the order of these kills is before awarding credit.
 Attributing points based on contributions to the outcome of a kill rather than just for dealing the final point of damage in a kill. Treating assists as binary is outdated, because players can deal varying amounts of damage, flash opponents, or push in and be a distraction before their teammate gets the kill.
 Assessing the impact of saved weapons and equipment on the win probability of the upcoming round to reward the players who saved. 
 That's the quick summary! If you want to get into the details, we will take an in-depth look at each of these concepts below.
 Win probability model based points
 To actually distribute rating to players, we evaluate the win probability before and after key events occur. These events currently are either kills or rounds ending with players alive on both teams. If your team gained win probability through the event (such as if you get an untraded kill) you will gain points. If your team lost win probability during a kill that you were involved in, then you will lose points. An example where you may lose points during a kill chain is if you trade 1 for 1 in a 2v3 situation. There are higher odds of winning a 2v3 than winning a 1v2, so by trading 1 for 1 you decreased the odds of your team winning the round. Consequentially, you will lose points according to the decrease in win probability.
 The idea behind using a win probability model as the basis for giving out points for a rating is that it gives us a way to gauge how important kills are across multiple dimensions at once. Most importantly we can include both the economy of the teams and, as the round progresses, how many players are still alive on each team. This means that the amount of points added or subtracted to a player’s rating is proportional to how much their actions changed the odds of their team winning, rather than kills being awarded points without context.
 The old system only looked at the change in win probability when kills occurred. This meant that if a round ended with players alive on both teams, some win probability would go undistributed. The system has been upgraded to account for these end-of-round situations. In the case where players do save, they also gain a reward at the start of the next round for carrying some gear forward and increasing their chances of winning the upcoming round. 
 Rewarding players for beating the odds
 An important thing to notice about a win probability model for this purpose is that it is not trying to be the perfect live-betting bot. We intentionally do not include things like specific positioning or specific skill levels of players, because a player over-performing in a round should be rewarded with points from our system. If our model knew that s1mple was more likely to win a 1v2 than the average player, then he would not be rewarded for doing so. Similarly, if our model included that someone had actually gotten into an insanely good position for an after plant and was a huge favorite in a big 1v1, then they, again, could not be rewarded properly for a great play. Focusing on the economic situation and the number of players alive on each team gives players plenty of room to differentiate themselves by making good decisions and hitting nice shots.
 Handing out points based on trades
 In practice, rounds of CS:GO are not described well as just a series of individual kills - trades are incredibly important for how the game is played. To account for this, we have chosen to break each round into a series of kill chains. A kill is added to the current chain if it occurs within four seconds of the previous kill. This has several implications for how to fairly distribute points as rounds progress.
 Once four seconds elapse without another kill happening, the results of the current kill chain are evaluated. Each kill is weighted based on how close it is to the previous kill in the chain. The weighting is then used to calculate the Leetify Rating gained or lost by that kill. The weighting factor is scaled linearly based on how much time from zero to four seconds has elapsed between the kills. You can see examples of how this weighting factor is applied in the third major section of the Leetify Rating Upgrade article . 
 For kill chains with several kills, the win probability can fluctuate greatly from kill to kill. When these happen rapidly, players can be unfairly punished if we evaluate the pure win probabilities in isolation. The weighting algorithm ensures that players are not arbitrarily punished for their position in the chain if it was not significantly different from the neighboring kills. 
 This solves a couple of issues that this kind of model would otherwise have. First of all, it removes some pretty big variations that would occur based on what is often a random order of kills in engagements between several players. A specific example: for a traded kill in a 3v4, it doesn’t matter which team got the first kill and which team traded it, because the resulting 2v3 will have the same win probabilities in both cases. If points were given out on a per-kill basis, there would be a rather large difference between the points given out for the two possible paths there. Any actual positional advantage for the trading players team, in the specific round, will instead only be rewarded if they can actually use that theoretical advantage to do well in the rest of the round.
 The kill chain handles macro-scale rewards, but sometimes fights lead to different situations even if they end with the same kill outcomes. A player can deal damage, flash an opponent, or get traded. The next section walks through how we award credit for these more granular contributions.
 Contributions to kills
 We use a weighting system that distributes the change in round win probability difference to the various individuals that contributed to each kill:
 Getting the kill - 35%
 Damage dealers - 30%
 Traded players - 20%
 Flash assisters - 15%

 Flash assists here are based on the Leetify definition, not the definition for the in-game scoreboard:

 Includes your own kills on an enemy that you flashed

 Does not include half-blind players

 If a kill doesn’t actually have all these contributions, the other ones will scale up to a total of 100%. For example: if there are no trades and no flash assists, the killer will instead get 54% and the damage dealers will share 46% of the contribution. It’s also worth noting that a player can be both the killer and damage dealer.
 Damage dealt outside of the current kill chain (for example 1 minute earlier at the start of the round on a player that only dies in a post-plant duel at the end of the round) will not make a player count as included in a negative score kill for the team. For a positive score kill, having dealt damage to a killed opponent earlier in the round will give you part of the damage dealers contribution, even if you didn’t actually participate in the actual kill where the opponent ended up dying.
 We have implemented a system to more evenly spread the damage credit in the case that someone does a ton of damage to a low-health opponent. This comes in the form of considering up to 50 overkill damage in the computation for the damage dealt portion of the kill reward. To get some context for why we implemented this, consider an opponent is hit for 99. Without overkill, the person who got the kill is only awarded 1% of the damage category, no matter how much damage they dealt. This can correspond to as low as 0.3% of the the full kill reward. This low of a damage reward is not appropriate in cases where it was not known that the opponent was low and the player goes for a shot that would be lethal even without the opponent being low. To see our full justification, check out the Overkill section of the Leetify Rating Upgrade article . 
 Save Rewards
 Saving is a fundamental part of good decision making in CS:GO. When a round ends with players alive, we do four extra calculations to award credit: 
 Compute the initial win probability of the team that saved
 Compute this win probability as if they had not saved any gear
 Reward the players who saved based on how much the saved gear increased their win probability
 Subtract this rewarded amount evenly from each of the opponents that were alive at the end of the previous round 
 Saving players cannot gain more rating than the opponents were rewarded to conclude the previous round. If the win probability increase at the start of the round exceeds the rating gained by the opponents to conclude the previous round, the total save reward is capped at the previous end of round reward. 
 Note that Leetify Rating is a zero-sum metric, so anything gained by one team must be lost by the other team. In the case of a save, this means that in order to give the saving team a reward for carrying their gear forward, the other team must lose an equal amount of rating. Since the players that were alive at the end of the round were awarded rating corresponding to the remaining win probability, these are the players that are penalized at the start of the following round. 
 The amount rewarded to each saving player is proportional to the value of the gear they saved. A player who saved an AWP will gain more rating than a player who saved an AK in the same round. 

 Save Reward Example: Two CTs save in a 2v3 situation, BOT Bill and BOT Tim. BOT Bill saves body armor, an AWP, and an incendiary grenade ($6000). BOT Tim saves head armor, an AK, and a smoke ($4000).

 Saving this $10000 in gear increases their team's win chance by 10% (+10 total LR) compared to if they had saved nothing. BOT Bill will get 60% of the total LR gained for the save, since their gear was 60% of the total value of the saved items (+6 LR). BOT Tim will get 40% of the total save reward (+4 LR).

 Since +10 LR is awarded to the CT team in total, -10 LR will be subtracted evenly from all three Ts that were alive at the end of the previous round.

 The saved equipment bonus is awarded at the start of the next round, so saving on the final round of a game will not lead to any bonus in Leetify Rating. 
 Examples of Leetify Rating calculated in a single round

 Leetify Rating got an upgrade! The graphics in this section are using the old method of computing rating, which was changed on 2022-03-11. Check out the "Leetify Rating Updates" section at end of this article for more details.

 Below are two examples of how Leetify Rating was calculated across a single round. Keep in mind that when someone gains rating, rating is also removed from the team (and players involved) that lost the duel.

 See a clip for the corresponding round here. Click the image for a larger version. 

 See a clip for the corresponding round here. Click the image for a larger version. 

 Benchmarks for Leetify Rating
 To more easily help you understand what is a good or bad performance in Leetify Rating, here are our single-match benchmarks for Leetify Rating:

 Single-Match Benchmark 
 Leetify Rating 

 Great 
 Above +6.10 

 Good 
 +2.50 to +6.10 

 Average 
 -2.49 to +2.49 

 Subpar 
 -2.50 to -6.10 

 Poor 
 Below -6.10 

 Benchmarks were updated for CS2 on 2024-03-27. We had to apply these updates globally, so old match pages will reflect these new benchmarks that are calibrated for CS2. 
 As you can see, this rating is symmetric about zero. Zero means you did not change your team’s odds of winning the round on average. A positive rating means the player tended to improve their team's odds of winning, and a negative rating means that the player tended to hurt their team’s odds of winning the round.

 These benchmarks are computed across all Leetify users on a single-match basis. These benchmarks are not applicable when rating is averaged across many matches, as this will change the variance of the dataset.

 Future upgrades
 While this rating improves on previously used ratings by taking more of what actually matters in terms of winning games of CS:GO into account, there are still limitations and edge-cases. Through chance or through actively looking to simply maximize your rating instead of winning the game, you can get to situations where the goals of getting a high rating and winning the match are not completely aligned.
 We recognize that Leetify Rating is not perfect and as such already have a few things we’re considering for future updates, among those are updates to the win probability model (or even possibly moving to a map win probability model instead of a round win probability model), even more advanced logic for handling trades and better dealing with calculating rating for players who (correctly) choose to save equipment and thereby lose the round. 

 Update : As of 2022-03-11 , we have updated the way we handle kills in quick succession and included rewards for saving!
 As of now, we feel like the rating system is already in a place where it’s significantly better than anything else out there, and will now enter a period of gathering data from its live implementation as well as feedback from both our user base and the wider CS:GO community as a whole. If more problems arrive, we intend to continue updating Leetify Rating until it’s as near a complete system as a “single metric” can be for valuing player’s impact.
 Any such future updates will be properly communicated with the community and will be made in a way that minimizes confusion when comparing matches from different versions of Leetify Rating.
 Speaking of which, the next section is a guide to all of the changes we have made so far!
 Leetify Rating Updates
 Here we have divided up the versions of Leetify Rating so that you can easily compare historical numbers. 
 Initial Release
 Any Leetify Rating numbers you see from before 2022-03-11 are computed using the initial version of the rating. This includes match pages, infographics, video contents, and any other Leetify Rating number. These operate on the duels system instead of the kill chain system, and do not take any end-of-round rating rewards into account. They also do not include any credit for saving weapons. 
 One goal of the duels system was to include trades meaningfully. We used the term duel to describe a continuous engagement between any number of players on opposing teams. Looking at entire duels instead of individual kills was supposed to remedy incorrect assignment of points when kills happen nearly simultaneously, as a traded kill has a dramatically different impact on the round than an untraded one. The problem here was that kills do not have to happen simultaneously and in the same location. So in the case where two kills happened nearly simultaneously but in different areas of the map, the rating awarded to the second kill that occurred could be wildly different than the rating awarded for the first kill. To resolve this, we switched to the kill chain system . 
 Below are the single-match benchmarks for this old version of the rating that operated on duels:

 Single Match Benchmark 
 Initial Leetify Rating 

 Great 
 Above +7.43 

 Good 
 +3.04 to +7.43 

 Average 
 -3.04 to +3.04 

 Subpar 
 -3.04 to -7.43 

 Poor 
 Below -7.43 

 2022-03-11 Upgrade
 After some time to see what we could improve about the initial release of Leetify Rating, we bundled a few changes into a single upgrade:
 The system now awards rating when the bomb is defused with Ts still alive, when the bomb explodes, or when a round ends due to time expiring (not just when a duel occurs)
 Leetify Rating is now awarded for saving weapons and equipment
 The kill reward system has been tweaked to favor kill order less heavily when kills happen in quick succession
 The damage reward is split more evenly when dealing a lot of damage to a low-health player
 If you want to learn more, here is a link to the in-depth explanation of changes made in this upgrade. 
 The single-match benchmarks are not significantly different than the original benchmarks. The standard deviation increased slightly for the new version of the rating, which means you will tend to see numbers that are a bit farther from zero: 

 Single-Match Benchmark 
 New Leetify Rating 

 Great 
 Above +8.10 

 Good 
 +3.31 to +8.10 

 Average 
 -3.31 to +3.31 

 Subpar 
 -3.31 to -8.10 

 Poor 
 Below -8.10 

 Any Leetify Rating that you see from after 2022-03-11 is computed using this new method. 
 We want your feedback!
 As always, you are our most valuable resource! Let us know on the Leetify Discord how you feel about the rating, if you find any situations where it behaves strangely, or how accurately you feel it depicts the different players' impact in a match.

 -->

 Track your CS Performance

 Celebrate your best plays, compare accomplishments with your friends, and see who carried with our automatic match reports.

 Sign up 

 More in Leetify Rating 

 Leetify Rating: clutch weighting changed & bug fixes 

 19 Mar 2026 –
 3 min read

 Leetify Rating has been updated for CS2 

 25 Nov 2024 –
 5 min read

 How does Leetify Rating actually work? 

 25 Nov 2024 –
 6 min read

 See all 7 posts
 → 

 Product Updates

 Leetify Rating - a quantum leap for measuring CS:GO performance

 Today we announce Leetify Rating, a win rate impact based and economy-adjusted player rating system for CS:GO. 

This rating solves a few existing problems in currently used ratings such as too much emphasis on kills and that it is too easy to get a lot of credit from un-impactful kills.

 Anders Ekman

 Anders Ekman 
 16 Sep 2021 • 10 min read 

 The State of CSGO

 The State of CSGO July 2021

 CS is now more than 20 years old and has suffered through many ups and downs. Recency bias often prevents us from objectively assessing the state of something, and as

 June

 June 
 20 Aug 2021 • 11 min read 

 Follow us for more content:

 ©2026 Leetify. All rights reserved.