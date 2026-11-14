---
title: 'Push Notifications: What to Push, What Not to Push, and How Often (Eugene Yan, Dec 2023)'
url: https://eugeneyan.com/writing/push/
kind: article
commit: 
for: [stat-site-retention]
looked: 2026-11-14
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Survey of published push and email systems (Alibaba, JOOL Health, Duolingo, LinkedIn, Pinterest, Twitter) and their measured effects
---
# Push Notifications: What to Push, What Not to Push, and How Often (Eugene Yan, Dec 2023)

Why: what published industry work says about which pushes and digests help and how many
is too many.

## Assessment

- Evidence: B. A respected practitioner's summary of KDD/SIGIR papers and engineering
  blogs; each number traces to a named paper.
- Reasoning: fair. Explains each system; secondary, so read the papers for detail.
- Interests: none known.
- Weigh: effects are from large consumer apps; direction more than size carries over.

## Findings

- [retention] Unwelcome pushes cost the channel: users disable notifications, uninstall
  or learn to ignore them. ^f1
  > irrelevant or unwelcomed pushes risk having the user disable notifications, uninstall apps, or start ignoring them due to low usefulness.
- [retention] Pushes tied to the user's own past activity open better: Alibaba's
  complements of past purchases beat generic personalised picks by 44% open rate. ^f2
  > Overall, complementary recommendation (CPR) increased open rate by 44% relative to generic personalized recommendations (PPR).
- [retention] In a self-monitoring app, insights from the user's own data worked for
  highly active users, generic tips worked better for new ones (little data yet). ^f3
  > However, for highly active users, insights increased engagement while the generic suggestions reduced interaction and monitoring.
- [retention] Pinterest's volume model sent 6-24% fewer notifications yet raised CTR
  11-31% and engagement 1-3%. ^f4
  > As a result, they were able to reduce notification volume by 6-24% while increasing CTR by 11-31% and site engagement metrics by 1-3%.
- [retention] Core users got fewer emails with no drop in daily or weekly actives;
  marginal users (active 1-3 days in 28) got more and came back more. ^f5
  > Meanwhile, marginal users (who were active 1-3 days in the past 28 days) received more emails which also increased their email clicks, DAU, and WAU.
- [retention] Twitter measured push caps over two months because users first respond to
  more pushes, then become desensitised. ^f6
  > they may eventually become desensitized and reduce log-ins over a longer period of time.
- [retention] Explaining why a user gets a notification (signed up for it, topic) is
  recommended. ^f7
  > suggests explaining why users are receiving new notifications

## Read

- Whole post.

## Not read

- The underlying papers (Pinterest KDD 2018, Twitter arXiv 2202.08812, JOOL PMC6080195).
