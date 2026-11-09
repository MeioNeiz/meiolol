---
title: 'Mobalytics: A letter to our users (Oct 2017)'
url: https://medium.com/mobalytics/a-letter-to-our-users-425f0520f1b7
kind: article
commit: 
for: [postgame-review-compare]
looked: 2026-11-06
depth: listed (whole letter, 11 topics)
relevance: high
grade: B/strong
description: Mobalytics' open-beta post-mortem, 9 Oct 2017, near 300k users: GPI scores are a play style not good or bad; single-game scores too binary and spiky against average standards; one bad tip makes players dismiss the whole system; few read metric descriptions; post game compares you with your lane opponent and your usual self
---
# Mobalytics: A letter to our users (Oct 2017)

Why: what went wrong when a tool scored single games and gave advice, in the vendor's own words.

## Assessment

- Evidence: B. First-hand report by Mobalytics' head of science ("Uthgar, Mobalytics Warchief of Science") after opening the beta to nearly 300k users; specific failures named with causes.
- Reasoning: strong. Each topic gives intent, what went wrong and why, and the planned fix; admits mistakes (Kill Stealing name, Build metric).
- Interests: vendor, but the letter is self-critical, which raises its credibility.
- Weigh: 2017 and since rebuilt; the lessons about single-game scores, naming and advice trust are general and match what we see in other tools.

## Findings

- [learning] [ux/trust] GPI scores show a play style, not whether a player is good or bad; Mobalytics found that message was not getting across. ^f1
  > Remember that the **GPI** primarily **illustrates your play style** and what you can improve. Scores don’t necessarily mean you’re a “good” or “bad” player.
  > We have realized that this message is not clear throughout different parts of our platform
- [ux/trust] [stats] Single-game scores against an average standard came out binary and spiky: Aggression was 0 far too often because it leaned on First Blood. ^f2
  > On a single game basis, our scores were way too binary, and people were getting an aggression score of 0 far too often.
  > However, in a single game, being compared to an average standard, a binary score like First Blood or being ahead is going to result in a zero.
- [ux/postgame] The post game is where the scoring flaws showed. ^f3
  > The Post game really exposed some of the flaws with the way we were calculating and weighing our scores.
- [stats] Conditional scores can't be judged in a game where the condition never arose (playing from behind when never behind). ^f4
  > For example, we can’t tell you how well you play ahead from behind if you are never behind.
- [ux/postgame] [learning] Post-game comparison basis: your lane opponent and your usual self. ^f5
  > It’s also incredibly satisfying to see how you stacked up compared to your lane opponent, and your usual self.
- [ux/trust] One wrong tip makes players throw out the whole system. ^f6
  > Advice is a tricky thing because players will read one inappropriate tip and then quickly dismiss the entire system and website as shit.
- [learning] [needs] Advice fails off-meta styles (a split-pushing Shaco top told he doesn't help his team) and is too general for better players. ^f7
  > I play Shaco Top every game and I split push, why are you telling me I don’t help my team enough?
  > The worst problems arise when the information is too general for the user. This is inversely correlated to their skill.
- [ux/trust] A familiar-sounding metric name with a different meaning (Kill Stealing) misled players; few hover to read descriptions. ^f8
  > What we did learn from this skill is that very few people hover over our metrics to read the descriptions (feelsbadman).
- [learning] A metric can be measurable but not actionable (Build); Mobalytics dropped advice built on it. ^f9
  > Where we failed miserably is realizing although this property might be cool to measure, it is not suitable for giving people actionable advice.
- [learning] Wanted next: show mistakes more clearly and let players review them any time. ^f10
  > We also want to be able to show you your mistakes more clearly and allow you to review them whenever you want.
- [learning] The Dashboard's purpose: every game in detail, and progress over time with comparable time windows. ^f11
  > more importantly to see how you have progressed over time.
- [learning] Feedback loop: thumbs up and down on each advice piece. ^f12
  > Make sure to thumbs up and thumbs down advice you see.
- [ux/trust] (inferred) For meiolol's review: single-game facts with a fair baseline beat a single-game score; a named fault must hold in that game or players stop trusting the rest. ^f13

## Read

- Whole letter

## Not read

- The linked images (dashboard screenshots)
