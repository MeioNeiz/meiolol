# How Counterwatch calculates hero counters… | Counterwatch

<https://www.counterwatch.gg/blog/how-counterwatch-calculates-hero-counters-and-synergies-896ef42c>

[

CounterWatch

](https://www.counterwatch.gg/)

[Overwatch](https://www.counterwatch.gg/stats/overwatch)

[All Overwatch stats→](https://www.counterwatch.gg/stats/overwatch)

Stats & tools

[

Heroes

Every hero, with role, win rate and tier.

](https://www.counterwatch.gg/stats/overwatch/heroes)[

Tier List

Every hero ranked by shrunk win rate.

](https://www.counterwatch.gg/stats/overwatch/tier-list)[

Counters

How to counter any hero, from duel data.

](https://www.counterwatch.gg/stats/overwatch/counters)[

Team Builder

Counter picker with live win chance.

](https://www.counterwatch.gg/stats/overwatch/team-builder)[

Map Stats

Hero performance on every map.

](https://www.counterwatch.gg/stats/overwatch/maps)[

Player Tracker

Look up a player's rank and win rate.

](https://www.counterwatch.gg/stats/overwatch/tracker)

Find your hero

[

Best One Tricks

The strongest pick per role.

](https://www.counterwatch.gg/stats/overwatch/best-onetricks)[

Best Duos

Pair with a friend's main.

](https://www.counterwatch.gg/stats/overwatch/best-duos)[

Expand Hero Pool

Your next hero to learn.

](https://www.counterwatch.gg/stats/overwatch/expand-hero-pool)

[Marvel Rivals](https://www.counterwatch.gg/stats/marvel-rivals)

[All Marvel Rivals stats→](https://www.counterwatch.gg/stats/marvel-rivals)

Stats & tools

[

Heroes

Every hero, with role, win rate and tier.

](https://www.counterwatch.gg/stats/marvel-rivals/heroes)[

Tier List

Every hero ranked by shrunk win rate.

](https://www.counterwatch.gg/stats/marvel-rivals/tier-list)[

Counters

How to counter any hero, from duel data.

](https://www.counterwatch.gg/stats/marvel-rivals/counters)[

Team Builder

Counter picker with live win chance.

](https://www.counterwatch.gg/stats/marvel-rivals/team-builder)[

Map Stats

Hero performance on every map.

](https://www.counterwatch.gg/stats/marvel-rivals/maps)

Find your hero

[

Best One Tricks

The strongest pick per role.

](https://www.counterwatch.gg/stats/marvel-rivals/best-onetricks)[

Best Duos

Pair with a friend's main.

](https://www.counterwatch.gg/stats/marvel-rivals/best-duos)[

Expand Hero Pool

Your next hero to learn.

](https://www.counterwatch.gg/stats/marvel-rivals/expand-hero-pool)

[Blog](https://www.counterwatch.gg/blog)[FAQ](https://www.counterwatch.gg/faq)

[Sign in](https://www.counterwatch.gg/signin?next=%2Fblog%2Fhow-counterwatch-calculates-hero-counters-and-synergies-896ef42c)

[Download](https://download.overwolf.com/install/Download?Name=Counterwatch&ExtensionId=jibicdemenmbbgklpbgioihcacpgefpphlffhanp&Channel=website&utm_source=counterwatch.gg&utm_medium=website&utm_campaign=website_header)

[Home](https://www.counterwatch.gg/)/[Blog](https://www.counterwatch.gg/blog)/How Counterwatch calculates hero counters and synergies

# How Counterwatch calculates hero counters and synergies

April 21, 2026·Updated September 4, 2026|OverwatchMarvel Rivals

I posted a version of this on r/Overwatch and it turned into a good methodology thread, so I am putting it here too. This is the detailed version of how Counterwatch computes its counter and synergy rates, why counters use binary weighting while synergies use playtime weighting, and what the double-normalization pass is actually for. If you have ever wondered why these numbers look different from a raw-aggregate stats site, this is the answer.

## Source data

Counterwatch aggregates roughly 60,000 Overwatch matches a week from opted-in app users. Every match produces hero sessions, one per hero per player, and each session records the hero, the team side, the match outcome, and the match portion, a value from 0 to 1 based on how much of the match that hero was played. The data is processed weekly and sliced by rank division, game type, and stat category (5V5, 6V6, Stadium). Everything below runs on top of those hero sessions.

## Counter rate

For each match, every hero on one team is paired with every hero on the other. Each pair counts as 1.0 regardless of playtime, and that is deliberate. It is the single biggest difference between how Counterwatch computes counters and how a naive aggregate would.

Here is why it matters. When players get countered, they swap, so the countered hero has low playtime in exactly the matches where they lost hardest to a specific opponent. Weight pairs by playtime and you downweight the data that proves the counter works, the matches where someone got hard-countered and swapped out. Binary weighting avoids that trap: a hero who played 20% of a match still contributes a full data point to every enemy matchup, which preserves the signal that the swap was forced.

```
raw_counter_rate = wins / total_pairs   (for that hero-vs-opponent combo)
```

## Synergy rate

Synergies are the opposite problem. Every hero on a team is paired with every ally, and pairs are weighted by both heroes' match portions multiplied together, portion\_a × portion\_b. Swaps do not carry the same survivorship bias for synergies, and the goal is to measure how well two heroes do when both are actually being played together, not how well one does after the other has left. Weighting by the product of their match portions captures the window where both were on the roster at once.

```
raw_synergy_rate = weighted_wins / weighted_total
```

## Double normalization

Raw rates are useful but biased, in two systematic ways. First, some heroes are just stronger than others: if Hero A wins 55% overall, every counter pair involving Hero A looks inflated on the "A wins against" side and deflated on the "losing to A" side. Second, the Counterwatch user base wins more than 50% of matches overall, because people install an app like this to win more and they do, so without correcting for it every hero looks artificially strong across every matchup.

Two passes strip both effects out. Pass 1, opponent and ally normalization, subtracts each opponent's (or ally's) average win rate across all heroes, which removes the effect of facing or playing alongside a generally strong or weak hero. After it, a positive number means the hero is doing better than average against that specific opponent, controlling for how strong the opponent is overall. Pass 2, hero popularity normalization, subtracts each hero's average already-normalized rate across all their matchups, which removes the bias from the user base winning above 50% globally.

The output of the two passes is a delta, how much better or worse the matchup runs than each hero's overall strength alone predicts. That delta is anchored back into a familiar 50%-centred win-rate space for display, so the numbers on the site stay on the same scale as the tier list. A raw aggregate site might tell you Cassidy wins 48% against Winston, which looks like a losing matchup. After double normalization the displayed number is roughly 51%. Once you control for both heroes' overall strength, Cassidy actually does about 3 points better than expected into Winston.

## The Cassidy example, worked

Before I added the double normalization, an earlier version of the data showed Cassidy with lower win rates against all the heroes he is supposed to hard-counter. That looked obviously wrong, and it is what kicked the normalization work off. The explanation is simple in hindsight: Cassidy gets played into dive comps, against Tracer, Genji, and Winston, and those dive comps are strong in the current meta, so matches where Cassidy faces them tend to have higher enemy-team win rates overall. Raw aggregation blamed that on Cassidy losing the matchup, when the real signal is that Cassidy does better than expected against those dive heroes, relative to how well the dive team was going to do anyway. Pass 1 strips out how strong the enemy hero is overall. Pass 2 strips out how popular the friendly hero is among Counterwatch users. What is left is the matchup.

## Live match scoring

The tier list and the matchup tables aggregate daily, but in a live match both the overlay and the web team builder combine several stats into a real-time read for each player and the team. Each player's score combines three factors: the counter impact (this hero's average counter win rate against every enemy hero, with enemy scores as the inverse, zero-sum), the synergy score (average synergy win rate with every ally), and the map win rate (how this hero does on the current map). The in-game per-player badge expresses each factor as a delta from 50% and adds them up. A Tracer at +2% counter, +1.5% synergy, +0.7% map reads as +4.2 points.

The team-level win-chance prediction works differently. Instead of summing per-player deltas, the [web team builder](https://www.counterwatch.gg/stats/overwatch/team-builder) takes a weighted blend across the whole lineup and clamps it:

```
winChance = clamp(0.5 × counter + 0.3 × synergy + 0.2 × map, 0.05, 0.95)
```

Counter carries the most weight because counter-picking is the highest-leverage decision in a match. Synergy matters but less, since a comp that synergises perfectly against the wrong enemy still loses. Map is the smallest weight, because hero-versus-map effects are a weaker signal than hero-versus-hero, and plenty of players do not optimise by map anyway. The clamp keeps the prediction sane at the extremes, since even an unbeatable lineup on paper leaves room for human error and luck.

## What this does not handle yet

A couple of limits worth being upfront about. The first is map granularity. 60,000 matches a week is plenty for reliable hero-versus-hero numbers across the roster, but not enough to break those down per map. Pharah versus hitscan on Gibraltar is genuinely a different matchup than on King's Row, and folding maps together dilutes some real situational counters. I handle this partly in live scoring by pulling the map win rate as its own factor, but I do not currently slice the counter and synergy tables by map. Data volume is the gate.

The second is MMR spread inside a rank. Even within one rank tier there is real MMR variance between players, and higher-MMR players at the same tier play around counters and stack synergies more efficiently. For Overwatch I can only read the rank of players with public profiles, so I almost never have a full picture of the MMR gap between the two teams in a match. Marvel Rivals exposes rank more completely. For Overwatch the data simply is not there to weight by MMR spread, so rather than guess, I leave the factor out.

## Why it matters

A 48% counter rate on a raw aggregate site does not mean a hero is losing the matchup. It means the matchup reads that way before you correct for how strong the opponent is, the selection bias of the user base, and whatever else is baked into the raw numbers. Counterwatch's numbers are built to be actionable at the draft screen: does picking this hero into that one actually help me win. The double normalization is what makes that answer trustworthy.

For the tier list this feeds, see the [Overwatch tier list](https://www.counterwatch.gg/stats/overwatch/tier-list) or [Marvel Rivals tier list](https://www.counterwatch.gg/stats/marvel-rivals/tier-list). For the live surface, the [Counterwatch app](https://www.counterwatch.gg/app) runs the same logic on the data as it comes in. If you want to argue with any of this, I read every message at [oskar@counterwatch.gg](mailto:oskar@counterwatch.gg) and the [Discord](https://discord.counterwatch.gg/) is open.

[PreviousCommunity Stats Update](https://www.counterwatch.gg/blog/community-stats-update-73e1a40d)

[NextCounterwatch vs Blizzard's official Overwatch stats: what the rates page leaves out](https://www.counterwatch.gg/blog/counterwatch-vs-blizzard-s-official-overwatch-stats-what-the-3174349b)

## Ready for the live version?

Counterwatch runs inside Overwatch and Marvel Rivals. Live counter picks, win chance, and hero swaps without typing or tabbing out.

-   Deeper stats \- personal win rates, your Impact on every hero, and match history beyond what's shown here
-   Live match data \- real-time counter suggestions and win chance as heroes are picked
-   Performance tracking \- an Impact rating for every session, match and hero, read against the typical player at your rank
-   In-game overlay \- match roster, hero swaps, and counter picks right on your screen

[Download Free](https://download.overwolf.com/install/Download?Name=Counterwatch&ExtensionId=jibicdemenmbbgklpbgioihcacpgefpphlffhanp&Channel=website&utm_source=counterwatch.gg&utm_medium=website&utm_campaign=blog_promo)[Free on Windows via Overwolf](https://www.overwolf.com/app/oskar-counterwatch?utm_source=counterwatch.gg&utm_medium=website&utm_campaign=stats_tagline)

[

CounterWatch

](https://www.counterwatch.gg/)

The companion app for Overwatch and Marvel Rivals. Real-time counter picks, hero stats, and performance tracking.

### Overwatch

-   [Hero stats](https://www.counterwatch.gg/stats/overwatch)
-   [Tier list](https://www.counterwatch.gg/stats/overwatch/tier-list)
-   [Best one tricks](https://www.counterwatch.gg/stats/overwatch/best-onetricks)
-   [Team builder](https://www.counterwatch.gg/stats/overwatch/team-builder)
-   [Best duos](https://www.counterwatch.gg/stats/overwatch/best-duos)
-   [Expand hero pool](https://www.counterwatch.gg/stats/overwatch/expand-hero-pool)
-   [Map stats](https://www.counterwatch.gg/stats/overwatch/maps)

### Marvel Rivals

-   [Hero stats](https://www.counterwatch.gg/stats/marvel-rivals)
-   [Tier list](https://www.counterwatch.gg/stats/marvel-rivals/tier-list)
-   [Best one tricks](https://www.counterwatch.gg/stats/marvel-rivals/best-onetricks)
-   [Team builder](https://www.counterwatch.gg/stats/marvel-rivals/team-builder)
-   [Best duos](https://www.counterwatch.gg/stats/marvel-rivals/best-duos)
-   [Expand hero pool](https://www.counterwatch.gg/stats/marvel-rivals/expand-hero-pool)
-   [Map stats](https://www.counterwatch.gg/stats/marvel-rivals/maps)

### Resources

-   [The Counterwatch app](https://www.counterwatch.gg/app)
-   [Pricing](https://www.counterwatch.gg/pricing)
-   [Blog](https://www.counterwatch.gg/blog)
-   [FAQ](https://www.counterwatch.gg/faq)
-   [Methodology](https://www.counterwatch.gg/methodology)
-   [About](https://www.counterwatch.gg/about)
-   [Privacy Policy](https://www.counterwatch.gg/privacy)
-   [Terms of Service](https://www.counterwatch.gg/terms)
-   [Data request](https://www.counterwatch.gg/data-request)
-   

© 2026 Counterwatch. All rights reserved.

[Download Counterwatch](https://download.overwolf.com/install/Download?Name=Counterwatch&ExtensionId=jibicdemenmbbgklpbgioihcacpgefpphlffhanp&Channel=website&utm_source=counterwatch.gg&utm_medium=website&utm_campaign=website_footer)

 [English](javascript:;)

-   [Deutsch](javascript:;)
-   [English](javascript:;)
-   [Español](javascript:;)
-   [Français](javascript:;)
-   [Italiano](javascript:;)
-   [Nederlands](javascript:;)
-   [Polski](javascript:;)
-   [Português](javascript:;)
-   [Limba română](javascript:;)

## You control your privacy

We and up to [1223 vendors](javascript:;) process, store and/or access personal data from you and your device. This data can include your type of browser, settings, cookies, unique identifiers, IP address, and geo location. Your consent can be updated or withdrawn at any time by clicking the link in our privacy policy or footer.

We're requesting consent to offer: **Personalised advertising and content, advertising and content measurement, audience research and services development**

Advertising and content can be personalised based on your profile. Your activity on this service can be used to build or improve a profile about you for personalised advertising and content. Advertising and content performance can be measured. Reports can be generated based on your activity and those of others. Your activity on this service can help develop and improve products and services.

 

Your consents are specific to this site & device.
