---
title: 'MachineLoLing: The math behind champion blindability'
url: https://www.youtube.com/watch?v=3t5dEYyLua0
kind: video
commit: 
for: [blind-pick-safety]
looked: 2026-11-02
depth: listed (whole transcript, all 81 frames on the 6 sheets, 20 single frames for numbers and formulas, top 20 comments)
relevance: high
grade: B/fair
description: 17:48 explainer (Oct 2026, 357k views in 3 days) by a bioinformatics PhD building a would-be stats site: blindability as noise-corrected spread of a champion's matchup win rates, chance of being countered from meta shares and pool size, which roles care about which, and who gets counterpicked in practice
---
# MachineLoLing: The math behind champion blindability

Why: Jacob rates it highly; how does it measure blind-pick safety, and what should
meiolol's blind ranking, champion pages and Learn take from it?

## Assessment

- Evidence: B. A first-hand analysis on his own crawl (Ahri 301,828 matchup games,
  @6:20 frame), with method shown on screen: odds baseline, binomial noise correction,
  a subsample check. Patch, region and rank range not stated; no held-out test of
  whether the blindability score predicts anything.
- Reasoning: fair to strong in the first half (each step motivated, assumptions named
  as "bad but good enough"); weaker in the second: P(countered) is the chance a
  counter is in the opponent's pool, not that one is picked, and the rank and pro
  sections rest on thin data he admits to.
- Interests: building a public stats site ("coming once Riot approves it"), blog and a
  champion pool designer at machineloling.com, Ko-fi; the video is also its launch
  pitch. A direct competitor in the same production-key queue as meiolol.
- Weigh: trust the spread numbers (they match ours, see C-notes in the question);
  discount the 85%/10% countered figures as an upper bound; the "WR gained or lost from
  the opponents it draws" chart (@14:36) is the most useful idea, cheap for us to
  reproduce. Captions write Mel as "Mal" and the channel as "Machine Lolling".

## Findings

- [draft] Defines blindability as how much a champion's win rate varies with the other champions in the game, opponents and teammates. @0:48 ^f1
  > blindability is the variability of a champion win rate based on the opponents and teammates that are in the game
- [stats] [draft] Removes each champion's overall strength first: expected matchup odds are the ratio of the two champions' odds (an additive log-odds baseline); a matchup's "above expected" is its win rate minus that. Ahri 50.9% (odds 1.04) vs Mel 45.5% (0.83) expects 55.6%; the actual 51.5% is -4.1. @3:23, frames/3-59.jpg ^f2
  > we just take the ratio of their odds ratios
  > the actual win rates between Ahri and Mel, it's 51.5% about 4.1% lower than we would expect
- [stats] Correcting for both champions' strength shrinks Ahri's mid spread from 1.8% (raw win rates) to 1.3%; weighting by play rate leaves it at 1.3%. @4:16, frames/4-36.jpg ^f3
  > Ahri's spread has now fallen to 1.3%
- [stats] Observed spread falls with games sampled (3.5 at 10k Ahri games to 1.26 at 300k, frames/6-25.jpg); he subtracts binomial noise in quadrature: spread² = true spread² + noise², 1.26² = true² + 0.61², true spread 1.10%. @5:40, frames/6-20.jpg ^f4
  > we can simply subtract the noise from the observed spread to find the true spread
- [stats] The noise-corrected spread is already near its converged value at 10k games, within a shaded band, while the raw one keeps falling. @6:20, frames/6-35.jpg ^f5
  > even at low sample rates, it's already honed in on what the ultimate convergence point is going to be
- [draft] True spread of mid matchups: Ahri 1.1%, typical mid 1.8%, Yasuo 2.2% (best Akshan, worst Azir). @6:31, frames/7-01.jpg ^f6
  > A typical mid laner has a spread of 1.8%.
  > Yasuo has a spread of 2.2%
- [draft] Counter defined (arbitrarily, he says) as 2+ points below expected: 3.8% of Ahri's fitted curve vs 17.8% of Yasuo's; as discrete champions Ahri has one (Mel, -3.8, 1.4% of mid picks), Yasuo eleven (-2.1 to -3.7) adding to 24.0% of mid picks. @7:36, frames/7-22.jpg, frames/7-57.jpg ^f7
  > Mal accounts for 1.4% of the meta at the moment, where Yasuo's counters account for a whopping 24% of all mids picked
- [draft] (inferred) The counter lists are raw cell deltas thresholded at -2, not shrunk: Yasuo's cells are noisier than Ahri's (noise 0.6 at 300k games for her), so some of his -2.1/-2.2 counters may be noise. frames/7-57.jpg ^f8
- [draft] P(countered) = 1 - (1 - q)^N, q the meta share of a champion's counters, N draws from a bag of champions weighted by play rate, pools assumed random. @7:57, frames/8-28.jpg ^f9
  > the probability of being countered would be 1 minus the probability of not drawing a counter
  > assume that pools are an assembly of random champions, which as I know, a bit of a bad assumption
- [data] Pool size N estimated from champion mastery, as the number of champions that cover 80% of a mid player's mastery; his dev key limits him to this proxy. Mean 7.0; the distribution peaks at about 2 and has a long right tail to ~30; top-1 champion holds ~41% on average. @8:45, frames/9-38.jpg, frames/9-41.jpg ^f10
  > On average, mid laners have 80% of their mastery on just seven champions.
  > my current access to Riot's API is going to limit my answer
- [draft] With N = 7: blinding Yasuo gets countered 85% of the time, Ahri about 10%; Viktor or Yone alone is 30% for Yasuo. @9:14, frames/9-49.jpg, frames/10-14.jpg ^f11
  > if you're blinding Yasuo, you're probably getting countered 85% of the time
  > if you're blinding Ahri, then probability is only about 10%
- [draft] (inferred) The 85% is the chance a counter is in the pool, not that it is picked: it assumes the opponent picks after you and always counters when able; and plugging in the mean N of a right-skewed distribution overstates the average (1-(1-q)^N is concave in N: N = 2 gives 42% for Yasuo). ^f12
- [draft] Across mids, each +0.1 point of true spread adds about 4.7 points of chance to be countered blind (fit from his own model, so close to a restatement of it). @10:15, frames/10-32.jpg ^f13
  > for every 0.1% spread that a mid laner's matchups has, it adds approximately 4.7% chance that they will be countered
- [draft] Ahri's true spread by enemy role: mid 1.1, jungle 0.9, top 0.6, bot and support 0.4; by ally role: top and jungle 0.4, support 0.4, bot 0.1. @10:33, frames/11-42.jpg ^f14
  > Her spread versus mid lane is by far the largest, where her spread versus bot lane is the lowest
- [draft] Role heat map (spread vs the role's average pair, frames/12-58.jpg): top cares only about enemy top (+109%), mid about enemy mid (+71%) and its own jungler (+28%), jungle most balanced (enemy jungle +28%, ally mid +24%), bot about enemy bot (+29%) and support (+28%) and its own support (+73%), support its ADC (+53%) and both bot laners (+19%, +36%). @11:42 ^f15
  > top laners really only care about top lane and pretty much nothing else
  > Bot laners basically only care about their matchup in bot lane and the interaction they have with their support
- [draft] Matchup and synergy spread correlate across mids; Malzahar is the outlier (cares about matchups, not teammates); Yasuo is lowest on synergy consistency (about -2.5σ). @12:59, frames/13-40.jpg ^f16
  > Champions that tend to be good into any matchup also tend to be good with any teammate
- [draft] [method/causal] Without pick order he measures counterpicking from who each champion actually faced: "WR gained or lost from the opponents it draws" runs only -0.34 (Yasuo) to +0.36 points; counterpick champions (Galio, Taliyah, Vex, Lissandra) gain, Ahri loses about 0.1. @13:40, frames/14-36.jpg ^f17
  > Riot doesn't share pick order, but I do know who's in every game
  > Yasuo by far faces the most counter matchups of any champion in mid lane
- [draft] (inferred) So the realised cost of being counterpicked is small: Yasuo's 85% "countered" and ~-2.8 average counter would cost ~2.4 points if every opponent countered, yet he loses 0.34 to the opponents he actually draws. frames/7-57.jpg, frames/14-36.jpg ^f18
- [draft] Plotting matchup consistency against that drawn-opponent gain, most mids sit where expected (blindable ones blinded, counterpicks used as counterpicks); Yasuo is the exception, low consistency yet drawn into counters. He can't tell blind picks from players picking into counters regardless. @14:36, frames/15-24.jpg ^f19
  > the community as a whole has a pretty decent idea about which champions are blindable
  > Technically, we can't tell the difference here.
- [draft] By rank (Gold to Master+, in σ units), Ahri ~+1.5σ and Yasuo ~-0.5σ with wide error bars (Yasuo Emerald -2σ ± 0.7); he calls the data thin. @15:25, frames/15-40.jpg ^f20
  > Ahri tends to be mildly more blindable at higher elos, while Yasuo tends to get less blindable
- [draft] [data] Pro 2026 mids (Oracle's Elixir, play rate above 1%, which has pick order): share of picks made blind Ryze and Cassiopeia 87%, Orianna 70%, Ahri 47%, Galio 17%, Sylas 15%; rough agreement with solo-queue matchup consistency, but Anivia, LeBlanc and Twisted Fate are counterpicks in pro play. @16:11, frames/16-56.jpg ^f21
  > Anivia, LeBlanc, and Twisted Fate are used more as counter picks where in solo queue they're considered to be blindable
- [tools] Site pending Riot approval; data per position to follow in shorts; old blog and a champion pool designer at machineloling.com. @16:56, frames/17-31.jpg ^f22
  > once Riot approves my website will appear here on the screen
- [stats] A top comment raises selection bias: champions rarely blinded have win rates built from favourable matchups, which inflates their expected rate and makes them look less blindable. Unanswered in the video. ^f23
  > your approach will show the most blindability for champions that are being blinded the most

## Read

- Whole transcript; all six contact sheets; single frames 6-20, 6-25, 7-51, 7-57, 9-38,
  9-54, 10-32, 10-49, 11-42, 12-58, 13-40, 14-36, 15-01, 15-24, 15-40, 16-14, 16-56
- Top 20 comments

## Not read

- machineloling.com blog and champion pool designer (lead logged)
- How he assigns mastery to "Mid", his patch and region window, and whether the heat
  map's role spreads are noise-corrected: not said in the video
