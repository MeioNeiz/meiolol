# Four months of Valve balancing Deadlock, told in 2.9 million matches

<https://deadlock-api.com/blog/2026-patches-meta-shift>

[Skip to content](https://deadlock-api.com/blog/2026-patches-meta-shift#main-content)

[Deadlock API](https://deadlock-api.com/)

/

[Home](https://deadlock-api.com/)

Patron

[Prioritized Fetching](https://deadlock-api.com/patron)[Player Tracker](https://deadlock-api.com/tracker/demo)

Analytics

[Games](https://deadlock-api.com/analytics/games)[Heroes](https://deadlock-api.com/analytics/heroes)[Items](https://deadlock-api.com/analytics/items)[Builds](https://deadlock-api.com/analytics/builds)[Abilities](https://deadlock-api.com/analytics/abilities)[Patch Changes](https://deadlock-api.com/patches)[Players](https://deadlock-api.com/analytics/players)[Team Builder](https://deadlock-api.com/analytics/team-builder)

Community

[Leaderboard](https://deadlock-api.com/community/leaderboard)[Rank Distribution](https://deadlock-api.com/community/badge-distribution)[Kill Heatmap](https://deadlock-api.com/community/heatmap)

Tools

[Stream Kit](https://deadlock-api.com/streamkit)[MCP & Data Dumps](https://deadlock-api.com/data-dumps)[Crosshair Editor](https://deadlock-api.com/crosshair)[Sounds](https://deadlock-api.com/sounds)[Blog](https://deadlock-api.com/blog)

Games

[Deadlockdle](https://deadlock-api.com/games/deadlockdle)[Flashcards](https://deadlock-api.com/games/flashcards)[Guess the Rank](https://deadlock-api.com/games/guess-the-rank)

Resources

[API Documentation](https://api.deadlock-api.com/docs)[Data Ingest](https://deadlock-api.com/ingest-cache)[Data Privacy](https://deadlock-api.com/data-privacy)

-   
-   
-   
-   

1.  
2.  [Blog](https://deadlock-api.com/blog)
3.  Four months of Valve balancing Deadlock, told in 2.9 million matches

[All posts](https://deadlock-api.com/blog)

# Four months of Valve balancing Deadlock, told in 2.9 million matches

April 18, 2026|Manuel Raimann|7 min read

datametapatch

In the eleven days before the 01-30 patch, the single most-picked hero in Deadlock was **Calico**. She showed up in **95.7%** of ranked matches across that window. Three months and five patches later, she is in roughly half. **Seven**, who was not even a top-3 pick before the 01-30 update, now wins 55% of his games and plays nearly seven out of every ten. Lash quietly took the pickrate crown. Calico got softer. Haze got reworked twice. And if you built a pure bullet carry, your item list is almost unrecognizable from the one you were running at the start of the year.

Five patches landed between January and April. We pulled hero stats, item stats and game-level averages from the API for windows just before and just after each one, and this is the story the numbers tell.

**The five patches at a glance:**

-   **01-30**: Seven gets buffed into the best hero in the game. Calico starts her long slide.
-   **03-06**: Map and economy rework. Games get longer, fights bigger, souls richer.
-   **03-21**: Ability range pulled down across twelve items. Long-range casters take a hit.
-   **03-25**: Mid-cycle corrections. Silence Wave keeps climbing.
-   **04-10**: Silence Wave walks back. Apollo ships. Roster settles.

## Seven's coronation

The 01-30 patch is where it starts. On paper the changes looked like routine tuning. In practice Seven's win rate jumped from **54.1% to 57.6%** in the two weeks after release, and his pickrate went from **45.0% of matches to 76.9%**. No other hero moved that much.

He has never left the top slot since. **Every single one of the five windows we sampled has Seven as the highest win rate hero in the game.** He cooled a bit through the spring (55.1% in the post 04-10 window) but stayed comfortably ahead of the pack. In the same week Bebop cratered by 3.6 percentage points and Infernus by 2.5, two of the biggest single-patch drops of the year.

Holliday is the mirror case. She was the worst-winrate hero in our January window at 43.6%, and the patches have been kind to her: 46.0%, 46.3%, 47.9%, 47.6%. A nearly four-point climb over three months. It is not enough to make her a pickrate staple, but it is the biggest positive trend in the dataset.

## The map patch made games longer and fights messier

The 03-06 patch touched almost every hero, but its fingerprints are clearer in the game-level stats than in any one hero's numbers. Matches went from averaging 33 minutes 17 seconds to 35 minutes 58 seconds, **roughly a 2.7 minute increase**. Average end-game [net worth](https://deadlock-api.com/analytics/games/economy) jumped from 32,640 souls to 37,531. Average max health climbed **10%** to 2,652. Spirit power averages rose **25%**, from 81.7 to 101.9.

That patch rebalanced the Shrines (the first one down to 5,000 HP, the second up to 10,000), bumped Mid Boss HP to 13,000 and gave it 35% debuff resist, added two new neutral camps at the Hidden King and Archmother Park walkers, and introduced the Golden Goose Egg as a brand new T1 spirit item. Teams take longer to commit to objectives now. The average first Mid Boss kill time went from 27 minutes to 29.

Assists per player rose from 9.0 to 10.3 in the same window. Teamfights got bigger and they took longer. You can feel it when you play; the averages confirm it is not just vibes.

## Ability range got deflated

The 03-21 patch will be remembered for a single systemic change: Valve pulled ability range bonuses down across twelve items at once. Greater Expansion went from 35% to 30%. Ballistic Enchantment from 25% to 20%. Echo Shard lost its 5% range. Guardian Ward, Cultist Sacrifice, Divine Barrier, Arcane Surge, Spirit Burn, Vortex Web, Knockdown, Rescue Beam and Healing Nova all took smaller cuts.

**Arcane Surge tells the clearest story.** It was in 16.6% of games before the first patch of the year. It is in 9.1% now. The 03-21 patch also reverted the vitality investment tree to percent-based health scaling and compressed the late-game spirit curve (from 52/64/76/89/101 to 48/57/66/75/100). Long-range poke casters got clipped from three directions at once.

## The Silence Wave pendulum

Silence Wave is the cleanest example of a buff-and-revert cycle we found. The 03-06 patch doubled its spirit scaling from 0.6 to 1.0 and cut its cooldown from 35s to 30s. The pickrate climbed: 6.9% pre 01-30, 8.0% post 01-30, 9.4% post 03-06, 9.4% post 03-25. Then 04-10 arrived and took it apart: damage 100 to 75, scaling 1.0 to 0.7, cooldown back up to 42s. Pickrate immediately dropped to 7.3%.

Echo Shard followed a different pattern. The 01-30 patch removed its cast time, which felt like an unambiguous buff. Pickrate jumped from 16.1% to 20.3% to 24.7%, climbing patch after patch all the way to 27.1%. But the win rate moved in the opposite direction: 55.3% before the buff, 52.1% after. A classic "more players bought it, the average skilled-user winrate regressed" curve. The 04-10 cooldown nerf (30s to 35s) barely budged the pickrate.

## The bullet carry that quietly died

If you are looking for the sleeper headline of the year, it is this: **traditional bullet-damage stacking fell out of favor without a single dramatic nerf.** Five staple gun items all lost between 17 and 22 percentage points of pickrate from January to April.

Close Quarters dropped 21.7 points. Point Blank lost 20.6. Sharpshooter 17.7. Headhunter 17.2. Bullet Lifesteal 17.1. In the same period, Dispel Magic (renamed from Debuff Remover and reworked on 01-30) gained 21.4 points and sits in 46% of games. Debuff Reducer climbed 18.7 points. Infuser added 20.8. **Decay** added 15.1 and was **the single biggest win rate gainer of the year (+2.4pp)**. The bullet tree did not crash; it just stopped being the first thing everyone builds into.

## The new roster

The patch notes also tell a story the analytics endpoint cannot: **in 2026 Valve shipped an entire expansion of new heroes.** Celeste arrived in early February and proceeded to eat a balance change in four consecutive patches (base HP down 90, fire rate cut 8%, Light Eater debuff cut from 12s to 8s, repeated barrier trims). Venator, Silver, Rem, Doorman, Graves, Billy, Drifter, Mina, Paige and Victor filled in through the spring. Apollo shipped on April 7 as the closer and picked up a gun damage buff in the 04-10 patch a few days later.

Those heroes are not yet in the ranked analytics dataset we pulled for this post, so we cannot show you their win rates. But the patch notes are blunt about the pattern: the most-touched hero of the year was a new release (Celeste), and almost every new addition got a balance pass within two patches of launch.

## High-rank and low-rank reacted differently

We split the data into two brackets: **Initiate through Arcanist** (badge 11 to 46) at the bottom, and **Oracle through Eternus** (badge 81 to 116) at the top. The same patches did not land the same way at both ends.

High-rank players reacted faster in almost every direction. Seven's pickrate jumped +25.7 points at high rank versus +18.9 at low, even though his winrate gained _more_ at low rank (+1.8 vs +0.7). Calico's winrate fell 4.2 points at high rank against 1.9 at low, even though her pickrate collapsed by a nearly identical amount in both brackets.

Top-five winrate lists share only two heroes between the brackets in both January and April. "Best hero right now" has never had one answer.

## A more balanced roster than we started with

One quiet number is worth calling out. The standard deviation of hero win rates across our sample went from **2.52 percentage points** in the pre 01-30 window to **2.13** after 04-10. **That is a roughly 15% compression in how spread out the roster is.** The best heroes are still good (Seven remains dominant, Lash at 52.4%, Mo & Krill at 52.1%) and the weakest are still below water (Viscous 46.4%, Shiv 46.6%, McGinnis 46.7%), but the range got tighter. Five patches of tuning got the roster closer together than it was in January.

The top-five most-picked heroes in January combined to fill 4.08 of the 12 slots in an average match. By mid-April that was down to 3.62. Pick diversity is up, win rates are closer together, and the games themselves are longer.

Valve spent the first four months of 2026 steadily balancing Deadlock. The roster expanded. The map pressure changed. The build spreadsheet got redrawn. If you want to dig deeper into any specific hero or item, the [hero stats](https://deadlock-api.com/analytics/heroes) and [item stats](https://deadlock-api.com/analytics/items) pages let you slice the windows yourself. For the broad picture: Seven is still king, the map wants longer games than it did in January, and the item you skipped last year might be the one everyone is building this week.

## The year in one figure

The whole story in one grid: Seven's rise (a), hero trajectories (b, c), a tightening balance spread (d), the gun-to-utility item migration (e, f), the 03-06 pacing shift (g), and the Silence Wave and Echo Shard cycles (h, i).

[

Older post

### How Deadlock API started: from frustrated meetings to 20 million daily requests

](https://deadlock-api.com/blog/how-deadlock-api-started)[

Newer post

### Valve rebuilt Deadlock's Urn three times in six weeks

](https://deadlock-api.com/blog/urn-rework-2026)

## More posts

[

September 7, 2026

### Solo vs duo queue win rates in Deadlock ranked

Deadlock duos win 50.9% of ranked games, solos 50.0%. New duo pairs win 54%, pairs with 500+ games together 49%. 641k ranked matches through 6 Sep 2026.

](https://deadlock-api.com/blog/solo-vs-duo-queue-ranked)[

July 23, 2026

### Valve rebuilt Deadlock's Urn three times in six weeks

Deadlock's Urn became a King of the Hill point, then a courier job and the Unstable Rift. Its souls barely moved; who collects them changed completely.

](https://deadlock-api.com/blog/urn-rework-2026)[

March 16, 2026

### How Deadlock API started: from frustrated meetings to 20 million daily requests

How Deadlock API grew from one developer's frustration with endless meetings into an open API serving 20 million requests a day to half a million users.

](https://deadlock-api.com/blog/how-deadlock-api-started)
