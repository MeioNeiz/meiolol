# LoL Esports | Dev Diary: Win Probability Powered by AWS at Worlds

<https://lolesports.com/en-US/news/dev-diary-win-probability-powered-by-aws-at-worlds>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://lolesports.com/en-US/news/dev-diary-win-probability-powered-by-aws-at-worlds#5cc66725-9212-4c72-9b81-533cf21e23b0)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

[

HOME

](https://lolesports.com/en-US)

Events & Standings

[

POWER RANKINGS

](https://lolesports.com/en-US/gpr)

[

Pick'Ems

](https://lolesports.com/en-US/pickems)

[

REWARDS

](https://lolesports.com/rewards)

[

News

](https://lolesports.com/en-US/news)

[

Tickets

](https://lolesports.com/tickets)

[HOME](https://lolesports.com/en-US)Events & Standings[POWER RANKINGS](https://lolesports.com/en-US/gpr)[Pick'Ems](https://lolesports.com/en-US/pickems)[REWARDS](https://lolesports.com/rewards)[News](https://lolesports.com/en-US/news)[Tickets](https://lolesports.com/tickets)

LOGIN

LOGIN

October 9, 2023\-BY LoL Esports Staff

# Dev Diary: Win Probability Powered by AWS at Worlds

## Learn more about the latest stat deploying to our Worlds broadcasts

\*\*INTRODUCTION\*\* Hey LoL Esports fans, John “Riot JPham” Pham here, product lead for Win Probability (WP) powered by Amazon Web Services (AWS). We heard your feedback after MSI that you liked the stat, so we’re bringing it back for Worlds this year! We also understand that many of you were interested in better understanding what goes into the stat and how it works. To start, you might recall us testing the stat on the MSI broadcast under the name “Win Expectancy” (WE). We’ve rebranded to Win Probability to better reflect what the stat represents. \*\*WHAT IS WIN PROBABILITY\*\* WP is a machine learning-based tool that indicates how often teams won given a similar situation previously. WP in League’s case is expressed as a percentage, and is calculated by comparing the current game situation to similar historical situations using key considerations such as the side (red vs blue), game time, gold differences in real-time, and other in-game metrics. More specifically, the WP percentage is derived from the number of teams that faced a comparable situation in the past and went on to win the game. Our WP stat is developed using a \[machine learning\]\[1\] (ML) algorithm called xgboost, and takes into account many features in its current iteration. \[1\]: https://mitsloan.mit.edu/ideas-made-to-matter/machine-learning-explained#:~:text=Machine%20learning%20is%20a%20subfield,learn%20without%20explicitly%20being%20programmed.

\*\*HOW WIN PROBABILITY WORKS\*\* Now for a peek under the hood, we wanted to share some insight on what factors our WP ML model takes into consideration (see bulleted list below). The current version was trained using all professional LoL Esports games since patch 10.4 (early 2020). It accounts for changes over time as it incorporates new game results into the training set, allowing it to factor in meta shifts and game changes. - Game time (the in-game time) - Gold % (player gold / total gold in game) - Total team XP - # of players alive - Tower kills - Dragon kills (whether a team has dragon soul or not) - Herald trinket in Inventory - Inhibitor timers (how long until an inhibitor respawns) for each inhibitor - Baron timers (time until Baron buff expires for the team) - Elder timer (time until Elder Dragon buff expires for the team) - # of players with Baron active - # of players with Elder active \*\*HOW TO INTERPRET WIN PROBABILITY\*\* The below example from our pilot at MSI shows the WP (at the time called WE) for C9 vs BLG in Game 3 during the bracket stage. The x-axis shows the in-game time in minutes, and the y-axis shows the WP percentage for the teams playing on the blue side or red side. Each team is designated one half of the y-axis; the team logo shows which half of the graph belongs to which team, with blue side on the top half and red side on the bottom half. The y-axis center line indicates a 50% WP, meaning that if there is no area above or below the center line, the WP for either team is 50%. Every game starts with both teams having a 50% WP, which changes as events happen throughout the course of the game.

The colored slopes above or below the center line depict the WP for the corresponding team at x minutes into the game. A blue slope above the center line indicates a higher WP for the blue team (BLG), and a red slope below the center line indicates a higher WP for the red team (C9). Lastly, you can see icons indicating what objectives or events influenced the WP at certain times and the corresponding swing in WP as a result. WP models aren’t meant to predict which team will win at any given point in time. WP is meant to reflect the relative changes in game-state based on previous performances. By showing these changes visually via the WP graph, we aim to help fans, casters, and the community better appreciate the impact of pivotal moments or decisions and how they change the course of a game. Next, let’s discuss how WP compares to something you all might be more familiar with, the Gold Difference graph. \*\*WIN PROBABILITY VS. GOLD DIFFERENCE\*\* Prior to the introduction of WP, Gold Difference (GD) was the single best metric we had at describing the overall game state at any particular time. However, there were limitations of what GD was able to account for including: - Other in-game metrics aren’t considered (e.g. dragons, XP, who has the gold, etc.) - It doesn’t directly translate into a comparable meaningful number, whereas WP is portrayed as an easily understood probability percentage

We originally explored WP as a more robust methodology for visualizing game-state as it has the ability to factor in more variables than GD. This means that we can better track the flow of the game and represent that to fans. Overall, we see WP as having an advantage in that: WP has an intuitive meaning - 75% WP for team X is easy to understand without added context - +3k GD requires additional context to gauge it’s impact (see below) WP doesn’t change based on the game time - 40% WP at 14 minutes has the same meaning as WP at 25 minutes - 3K GD at 14 minutes and 3K GD at 25 minutes have different impacts; only those with deep LoL knowledge can correctly interpret that impact WP can better visualize impactful events when compared to just GD - In a game where there is already a large GD (ex: 10k+ GD) and a team gets Baron, the GD graph changes by just 1.5k gold, which isn’t visually that drastic of a change since the GD is already rather large at 10k+ gold - Using the same example, the WP graph would show a more discernible change if the team behind in gold got Baron as Baron buff is more meaningful than just the 1.5K gold spike

\*\*THE FUTURE OF WIN PROBABILITY\*\* For the sports data folks out there, WP is our initial foray into more predictive analytical stats using ML. As any League fan can tell you, there’s so much to consider when looking at League, including how strong a particular team comp is, champion positions, itemization, runes, etc. - This is no easy task. Our goal is to keep evolving WP to better represent the state of the game; some additional features we’re looking to add in future iterations of WP include: - Team comp data (strength & scaling) - Micro interactions in team-fights - Individual dragons taken and type of dragon souls To take this a step further, we could potentially explore Win Probability Added (WPA). WPA quantifies the percent change in a team's chances of winning from one event to the next. This is where the value of these stats might go beyond a narrative tool; we could potentially identify tangible value added from any specific action(s) in a specific game. This in-turn can help us understand which events are most impactful, which players are making the most impact, and maybe even answer the age-old question of “Is Faker the GOAT?” once-and-for-all.

\*\*WHAT TO EXPECT FROM WORLDS\*\* So, what goes into making WP a reality at Worlds? Well, tbh, there's a lot of collaboration going on behind the scenes! At MSI, we worked closely with our partners at AWS to build the initial machine learning model, output APIs, broadcast graphics, and more; this enabled us to take the idea of WP and turn it into a reality. For Worlds, we are going to continue refining what you’ll see including: - Refreshing the WP graphic to be more visually distinct - Increasing transparency about the underlying technology - Improving education for our fans, casters and community You also might be wondering when you’ll see WP as a fan. Our broadcast team and stats operators are monitoring each game, and it’s at their discretion when WP would be valuable to show. WP is meant to highlight the impact of key events (big team-fight or objectives like Baron). For that reason, we will only display WP after key plays or post-match to show how particular events contributed to swings in WP. \*\*FINAL THOUGHTS\*\* Taking a look back to last year’s Worlds, we can see just how insane game 5 of the grand final between T1 and DRX really was. Looking at what the WP graph would’ve looked like (see below), you can see how both T1 and DRX battled back and forth until the very end.

Gumayusi’s unforgettable Baron steals and DRX’s resilience that led them to take the Elder Dragon and win it all can be seen at a glance; that's what makes us so excited for the future of WP. At the end of the day, we hope that by using WP as a narrative tool, we can continue to deepen fandom by leveraging more ways to tell interesting stories about our players and our sport that matter to you, our fans.

© 2026 Riot Games. All Rights Reserved.

[Privacy Notice](https://www.riotgames.com/en/privacy-notice)[Terms of Service](https://www.riotgames.com/en/terms-of-service)[Accessibility](https://www.riotgames.com/en/accessibility)
